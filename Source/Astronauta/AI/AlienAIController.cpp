#include "AI/AlienAIController.h"
#include "AI/AlienCharacter.h"
#include "AI/PatrolPath.h"
#include "AI/StealthTarget.h"
#include "Gameplay/AlarmConsole.h"
#include "Gameplay/HidingSpot.h"
#include "Gameplay/VentDuct.h"
#include "Player/AstronautaCharacter.h"
#include "Kismet/GameplayStatics.h"
#include "CollisionQueryParams.h"
#include "Engine/World.h"
#include "Gameplay/StationAlarmSubsystem.h"
#include "Gameplay/StationGameState.h"
#include "Astronauta.h"

#include "BehaviorTree/BehaviorTree.h"
#include "BehaviorTree/BlackboardComponent.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "Perception/AIPerceptionComponent.h"
#include "Perception/AIPerceptionSystem.h"
#include "Perception/AISenseConfig_Sight.h"
#include "Perception/AISenseConfig_Hearing.h"
#include "Perception/AISense_Sight.h"
#include "Perception/AISense_Hearing.h"

namespace
{
	/** Distancia mínima para considerar que el estímulo se ha movido y re-dirigir la investigación. */
	constexpr double InvestigationRetargetDistSq = 200.0 * 200.0;
}

AAlienAIController::AAlienAIController()
{
	AlienPerception = CreateDefaultSubobject<UAIPerceptionComponent>(TEXT("AlienPerception"));
	SetPerceptionComponent(*AlienPerception);

	SightConfig = CreateDefaultSubobject<UAISenseConfig_Sight>(TEXT("SightConfig"));
	SightConfig->SightRadius = 2000.f;
	SightConfig->LoseSightRadius = 2300.f;
	SightConfig->PeripheralVisionAngleDegrees = 50.f;
	SightConfig->SetMaxAge(2.f);
	SightConfig->DetectionByAffiliation.bDetectEnemies = true;
	SightConfig->DetectionByAffiliation.bDetectNeutrals = true;
	SightConfig->DetectionByAffiliation.bDetectFriendlies = true;

	HearingConfig = CreateDefaultSubobject<UAISenseConfig_Hearing>(TEXT("HearingConfig"));
	HearingConfig->HearingRange = 1500.f;
	HearingConfig->SetMaxAge(3.f);
	HearingConfig->DetectionByAffiliation.bDetectEnemies = true;
	HearingConfig->DetectionByAffiliation.bDetectNeutrals = true;
	HearingConfig->DetectionByAffiliation.bDetectFriendlies = true;

	AlienPerception->ConfigureSense(*SightConfig);
	AlienPerception->ConfigureSense(*HearingConfig);
	AlienPerception->SetDominantSense(SightConfig->GetSenseImplementation());
}

void AAlienAIController::OnPossess(APawn* InPawn)
{
	Super::OnPossess(InPawn);

	AlienPerception->OnTargetPerceptionUpdated.AddUniqueDynamic(this, &AAlienAIController::HandleTargetPerceptionUpdated);

	if (AStationGameState* GS = GetWorld()->GetGameState<AStationGameState>())
	{
		GS->OnRedAlert.AddUniqueDynamic(this, &AAlienAIController::HandleRedAlert);
		GS->OnIntruderReported.AddUniqueDynamic(this, &AAlienAIController::HandleIntruderReported);
		bIsAlarmTriggered = GS->IsAlarmTriggered();
	}
	else
	{
		UE_LOG(LogAlienAI, Warning, TEXT("%s: el GameState no es AStationGameState; la alerta roja global no funcionará."), *GetName());
	}

	if (BehaviorTreeAsset)
	{
		RunBehaviorTree(BehaviorTreeAsset);
	}
	else
	{
		UE_LOG(LogAlienAI, Error, TEXT("%s: falta BehaviorTreeAsset."), *GetName());
	}

	if (const AAlienCharacter* Alien = Cast<AAlienCharacter>(InPawn); Alien && Alien->PatrolPath)
	{
		PatrolIndex = Alien->PatrolPath->FindNearestIndex(Alien->GetActorLocation());
	}

	SetAlienState(bIsAlarmTriggered ? EAlienAIState::AlertaRoja : EAlienAIState::Patrullar);
}

void AAlienAIController::OnUnPossess()
{
	AlienPerception->OnTargetPerceptionUpdated.RemoveDynamic(this, &AAlienAIController::HandleTargetPerceptionUpdated);
	if (AStationGameState* GS = GetWorld()->GetGameState<AStationGameState>())
	{
		GS->OnRedAlert.RemoveDynamic(this, &AAlienAIController::HandleRedAlert);
		GS->OnIntruderReported.RemoveDynamic(this, &AAlienAIController::HandleIntruderReported);
	}
	// Si el corredor muere o pierde el pawn, otro alien puede tomar el relevo.
	ReleaseRunnerReservation();
	if (AStationGameState* GS = GetWorld()->GetGameState<AStationGameState>())
	{
		GS->ReportAlienSuspicion(GetPawn(), -1.f); // -1 = retirar del agregado
	}
	Super::OnUnPossess();
}

// ---------------------------------------------------------------------------
// Percepción
// ---------------------------------------------------------------------------

void AAlienAIController::HandleTargetPerceptionUpdated(AActor* Actor, FAIStimulus Stimulus)
{
	if (!Actor)
	{
		return;
	}

	const TSubclassOf<UAISense> Sense = UAIPerceptionSystem::GetSenseClassForStimulus(this, Stimulus);
	const bool bSensed = Stimulus.WasSuccessfullySensed();

	if (Sense == UAISense_Sight::StaticClass())
	{
		if (Actor->Implements<UStealthTarget>())
		{
			// El aumento continuo se aplica en UpdateSuspicion mientras siga a la vista.
			PlayerInSight = bSensed ? Actor : nullptr;
			return;
		}

		if (bSensed && Actor->ActorHasTag(CorpseTag))
		{
			HandleCorpseSeen(Actor);
		}
		else if (bSensed && Actor->ActorHasTag(BloodTag))
		{
			HandleBloodSeen(Actor);
		}
		else if (bSensed && Actor->ActorHasTag(ClueTag))
		{
			HandleClueSeen(Actor);
		}
	}
	else if (Sense == UAISense_Hearing::StaticClass() && bSensed)
	{
		// En AlertaRoja el ruido también atrae al alien, salvo que ya esté persiguiendo al jugador.
		const bool bAlertaRojaListening = CurrentState == EAlienAIState::AlertaRoja && !IsHunting();
		if (CurrentState == EAlienAIState::Patrullar || CurrentState == EAlienAIState::Investigar || bAlertaRojaListening)
		{
			// Resolución del Lead (punto 4): el delta escala con la intensidad del estímulo.
			// M4 (módulo C): la firma electrónica del Motion Tracker suma un delta fijo.
			const bool bTrackerPing = Stimulus.Tag == FName(TEXT("MotionTrackerPing"));
			AddSuspicion(bTrackerPing
				? SuspicionInstantDelta_TrackerPing
				: SuspicionInstantDelta_Noise * FMath::Clamp(Stimulus.Strength, 0.5f, 2.0f));
			SetInvestigationTarget(Stimulus.StimulusLocation, nullptr);
			EvaluateTransitions();
		}
	}
}

void AAlienAIController::HandleCorpseSeen(AActor* Corpse)
{
	if (!Corpse || PendingCorpse == Corpse)
	{
		return;
	}
	if (CurrentState != EAlienAIState::Patrullar && CurrentState != EAlienAIState::Investigar)
	{
		return;
	}

	if (const FVector* ReportedAt = ReportedCorpses.Find(Corpse))
	{
		// Resolución del Lead: un cadáver reportado que alguien movió > 300 uu vuelve a alertar.
		if (FVector::Dist(*ReportedAt, Corpse->GetActorLocation()) <= CorpseMovedDistance)
		{
			return;
		}
		ReportedCorpses.Remove(Corpse);
	}

	PendingCorpse = Corpse;
	bHasSeenCorpse = true;
	AddSuspicion(SuspicionInstantDelta_Corpse);
	SetInvestigationTarget(Corpse->GetActorLocation(), Corpse);
	EvaluateTransitions();
}

void AAlienAIController::HandleClueSeen(AActor* Clue)
{
	// Resolución del Lead (M2): una pista (p. ej. rejilla rota) hace que un alien en patrulla investigue.
	if (!Clue || CurrentState != EAlienAIState::Patrullar || InvestigatedClues.Contains(Clue))
	{
		return;
	}
	InvestigatedClues.Add(Clue);
	SuspicionMeter = FMath::Max(SuspicionMeter, Threshold_Investigate);
	SetInvestigationTarget(Clue->GetActorLocation(), Clue);
	SetAlienState(EAlienAIState::Investigar);
	UE_LOG(LogAlienAI, Log, TEXT("%s investiga la pista %s"), *GetName(), *Clue->GetName());
}

void AAlienAIController::HandleBloodSeen(AActor* Blood)
{
	// M5: sangre fresca = +30 y seguir el rastro. En Investigar cada gota nueva redirige al alien,
	// así encadena las gotas hasta el jugador. El corredor y AlertaRoja la ignoran.
	if (!Blood || InvestigatedClues.Contains(Blood) ||
		(CurrentState != EAlienAIState::Patrullar && CurrentState != EAlienAIState::Investigar))
	{
		return;
	}
	InvestigatedClues.Add(Blood);
	AddSuspicion(SuspicionInstantDelta_Blood);
	SuspicionMeter = FMath::Max(SuspicionMeter, Threshold_Investigate);
	SetInvestigationTarget(Blood->GetActorLocation(), Blood);
	EvaluateTransitions();
	if (CurrentState == EAlienAIState::Patrullar)
	{
		SetAlienState(EAlienAIState::Investigar);
	}
	UE_LOG(LogAlienAI, Log, TEXT("%s sigue el rastro de sangre %s"), *GetName(), *Blood->GetName());
}

void AAlienAIController::UpdateSuspicion(float DeltaSeconds)
{
	bool bActiveStimulus = false;

	CheckFlashlightExposure();

	// Alien de apoyo vigilando un casillero (resolución del cierre M1): mantiene la sospecha y la posición.
	if (AHidingSpot* Guarded = SpotToGuard.Get())
	{
		if (CurrentState == EAlienAIState::Investigar && Guarded->IsOccupied())
		{
			SuspicionMeter = Threshold_ConfirmPlayer;
			SetInvestigationTarget(Guarded->GetExitLocation(), Guarded);
			bActiveStimulus = true;
		}
		else
		{
			SpotToGuard = nullptr;
		}
	}

	// La percepción solo avisa al ganar/perder la vista; un cadáver arrastrado sin salir del cono
	// no generaría evento, así que se revisan los cadáveres visibles en cada tick del servicio.
	if (!ReportedCorpses.IsEmpty())
	{
		TArray<AActor*> Visible;
		AlienPerception->GetCurrentlyPerceivedActors(UAISense_Sight::StaticClass(), Visible);
		for (AActor* Seen : Visible)
		{
			if (Seen && Seen->ActorHasTag(CorpseTag))
			{
				HandleCorpseSeen(Seen);
			}
		}
	}

	if (AActor* Player = PlayerInSight.Get())
	{
		const bool bRunning = IStealthTarget::Execute_IsRunning(Player);
		const bool bCamouflaged = IStealthTarget::Execute_IsCamouflaged(Player);

		// Resolución del Lead (punto 3): las tasas se suman.
		// Corriendo sin camuflaje 55/s, corriendo camuflado 35/s, andando sin camuflaje 20/s, andando camuflado 0/s.
		float Rate = 0.f;
		if (bRunning)
		{
			Rate += SuspicionIncreaseRate_Running;
		}
		if (!bCamouflaged)
		{
			Rate += SuspicionIncreaseRate_NoCamouflage;
		}

		if (Rate > 0.f)
		{
			bActiveStimulus = true;
			AddSuspicion(Rate * DeltaSeconds);
			// Con el jugador en un conducto o escondite no se persigue su posición (inalcanzable):
			// se mantiene el destino de emboscada / vigilancia.
			if ((CurrentState == EAlienAIState::Patrullar || CurrentState == EAlienAIState::Investigar)
				&& !IsPlayerUnreachable(Player) && !SpotToGuard.IsValid())
			{
				SetInvestigationTarget(Player->GetActorLocation(), Player);
			}
		}
	}

	// En Investigar solo se enfría tras llegar al punto (duda 5); si no, caería a 0 durante el trayecto.
	const bool bCanDecay = CurrentState == EAlienAIState::Patrullar
		|| CurrentState == EAlienAIState::AlertaRoja
		|| (CurrentState == EAlienAIState::Investigar && bArrivedAtInvestigation);

	if (!bActiveStimulus && bCanDecay && SuspicionMeter > 0.f)
	{
		SuspicionMeter = FMath::Max(0.f, SuspicionMeter - SuspicionDecayRate * DeltaSeconds);
	}

	if (CurrentState == EAlienAIState::AlertaRoja)
	{
		UpdateHunt();
	}

	SyncBlackboard();
	EvaluateTransitions();

	// HUD: el GameState agrega la sospecha máxima de todos los aliens.
	if (AStationGameState* GS = GetWorld()->GetGameState<AStationGameState>())
	{
		GS->ReportAlienSuspicion(GetPawn(), SuspicionMeter);
	}
}

void AAlienAIController::AddSuspicion(float Amount)
{
	SuspicionMeter = FMath::Clamp(SuspicionMeter + Amount, 0.f, Threshold_ConfirmPlayer);
}

void AAlienAIController::SetInvestigationTarget(const FVector& Location, AActor* Actor)
{
	UBlackboardComponent* BB = GetBlackboardComponent();
	if (!BB)
	{
		return;
	}

	const FVector Current = BB->GetValueAsVector(AlienBBKeys::InvestigationLocation);
	const bool bIsSet = BB->IsVectorValueSet(AlienBBKeys::InvestigationLocation);
	if (!bIsSet || FVector::DistSquared(Current, Location) > InvestigationRetargetDistSq)
	{
		BB->SetValueAsVector(AlienBBKeys::InvestigationLocation, Location);
		// Nuevo foco: hay que volver a desplazarse y buscar.
		bArrivedAtInvestigation = false;
		bSearchFinished = false;
	}
	BB->SetValueAsObject(AlienBBKeys::TargetActor, Actor);
}

// ---------------------------------------------------------------------------
// Transiciones
// ---------------------------------------------------------------------------

void AAlienAIController::EvaluateTransitions()
{
	if (CurrentState == EAlienAIState::AlertaRoja || CurrentState == EAlienAIState::CorrerHaciaAlarma)
	{
		return; // Estados terminales para este sistema; no se abandonan por percepción.
	}

	// Transición 3: Patrullar / Investigar -> CorrerHaciaAlarma
	if (SuspicionMeter >= Threshold_ConfirmPlayer)
	{
		if (IsGlobalAlarmTriggered())
		{
			// Resolución del Lead (punto 7): con la alarma sonando no corre a la consola, pasa a cacería.
			bPlayerIdentified = true;
			SetAlienState(EAlienAIState::AlertaRoja);
			return;
		}

		UStationAlarmSubsystem* Subsystem = GetWorld()->GetSubsystem<UStationAlarmSubsystem>();
		if (!Subsystem || !GetPawn())
		{
			return;
		}

		// Resolución del Lead (punto 8): solo un corredor a la vez. Los demás siguen investigando.
		if (!Subsystem->TryReserveRunner(GetPawn()))
		{
			if (CurrentState == EAlienAIState::Patrullar)
			{
				SetAlienState(EAlienAIState::Investigar);
			}
			return;
		}

		AAlarmConsole* Console = Subsystem->FindNearestConsole(GetPawn()->GetActorLocation());
		if (!Console)
		{
			Subsystem->ReleaseRunner(GetPawn());
			UE_LOG(LogAlienAI, Warning, TEXT("%s: jugador confirmado pero no hay ninguna AAlarmConsole en el nivel."), *GetName());
			return;
		}

		bPlayerIdentified = true;
		TargetAlarmConsole = Console;

		const AActor* Player = PlayerInSight.Get();
		const UBlackboardComponent* BB = GetBlackboardComponent();
		const FVector LastKnown = Player ? Player->GetActorLocation()
			: (BB ? BB->GetValueAsVector(AlienBBKeys::InvestigationLocation) : GetPawn()->GetActorLocation());

		SetAlienState(EAlienAIState::CorrerHaciaAlarma);

		if (AStationGameState* GS = GetWorld()->GetGameState<AStationGameState>())
		{
			GS->ReportIntruder(LastKnown, GetPawn());
		}
		return;
	}

	// Transición 1: Patrullar -> Investigar
	if (CurrentState == EAlienAIState::Patrullar)
	{
		if (SuspicionMeter >= Threshold_Investigate || bHasSeenCorpse)
		{
			SetAlienState(EAlienAIState::Investigar);
		}
		return;
	}

	// Transición 2: Investigar -> Patrullar (falso positivo)
	if (CurrentState == EAlienAIState::Investigar
		&& bSearchFinished
		&& SuspicionMeter <= 0.f
		&& !bPlayerIdentified)
	{
		SetAlienState(EAlienAIState::Patrullar);
	}
}

void AAlienAIController::SetAlienState(EAlienAIState NewState)
{
	const EAlienAIState OldState = CurrentState;
	CurrentState = NewState;
	UBlackboardComponent* BB = GetBlackboardComponent();

	switch (NewState)
	{
	case EAlienAIState::Patrullar:
		SetMaxWalkSpeed(PatrolSpeed);
		// Cadáver investigado = cadáver reportado (duda 6).
		if (const AActor* Corpse = PendingCorpse.Get())
		{
			ReportedCorpses.Add(PendingCorpse, Corpse->GetActorLocation());
		}
		PendingCorpse = nullptr;
		bHasSeenCorpse = false;
		bArrivedAtInvestigation = false;
		bSearchFinished = false;
		if (BB)
		{
			BB->ClearValue(AlienBBKeys::InvestigationLocation);
			BB->ClearValue(AlienBBKeys::TargetActor);
		}
		if (const AAlienCharacter* Alien = Cast<AAlienCharacter>(GetPawn()); Alien && Alien->PatrolPath)
		{
			PatrolIndex = Alien->PatrolPath->FindNearestIndex(Alien->GetActorLocation());
		}
		break;

	case EAlienAIState::Investigar:
		SetMaxWalkSpeed(InvestigateSpeed);
		bArrivedAtInvestigation = false;
		bSearchFinished = false;
		break;

	case EAlienAIState::CorrerHaciaAlarma:
		SetMaxWalkSpeed(SprintToAlarmSpeed);
		SpotToGuard = nullptr; // el corredor ignora el casillero: prioridad absoluta a la alarma
		ClearFocus(EAIFocusPriority::Gameplay);
		if (BB)
		{
			BB->SetValueAsObject(AlienBBKeys::TargetAlarmConsole, TargetAlarmConsole.Get());
		}
		break;

	case EAlienAIState::AlertaRoja:
		SetMaxWalkSpeed(RedAlertSpeed);
		bIsAlarmTriggered = true;
		ReleaseRunnerReservation();
		ClearFocus(EAIFocusPriority::Gameplay);
		bArrivedAtInvestigation = false;
		bSearchFinished = false;
		// Se conserva InvestigationLocation: si había un último punto conocido, el BT lo registra primero.
		if (BB)
		{
			BB->ClearValue(AlienBBKeys::TargetAlarmConsole);
			BB->ClearValue(AlienBBKeys::TargetActor);
		}
		break;
	}

	if (BB)
	{
		BB->SetValueAsEnum(AlienBBKeys::AlienState, static_cast<uint8>(NewState));
	}
	SyncBlackboard();

	if (OldState != NewState)
	{
		UE_LOG(LogAlienAI, Log, TEXT("%s: %s -> %s (sospecha %.1f)"), *GetName(),
			*UEnum::GetValueAsString(OldState), *UEnum::GetValueAsString(NewState), SuspicionMeter);
	}
}

// ---------------------------------------------------------------------------
// Notificaciones desde el Behavior Tree / GameState
// ---------------------------------------------------------------------------

void AAlienAIController::NotifyArrivedAtInvestigation()
{
	bArrivedAtInvestigation = true;
}

void AAlienAIController::NotifySearchFinished()
{
	if (CurrentState == EAlienAIState::AlertaRoja)
	{
		// Punto registrado: el BT pasa a recorrer chokepoints.
		bArrivedAtInvestigation = false;
		if (UBlackboardComponent* BB = GetBlackboardComponent())
		{
			BB->ClearValue(AlienBBKeys::InvestigationLocation);
		}
		return;
	}
	bSearchFinished = true;
	EvaluateTransitions();
}

void AAlienAIController::HandleIntruderReported(FVector LastKnownLocation, AActor* Reporter)
{
	if (Reporter == GetPawn())
	{
		return;
	}
	if (CurrentState != EAlienAIState::Patrullar && CurrentState != EAlienAIState::Investigar)
	{
		return;
	}
	// Resolución del Lead (punto 8): los demás aliens investigan la última posición conocida para cerrar rutas.
	SuspicionMeter = FMath::Max(SuspicionMeter, Threshold_Investigate);
	SetInvestigationTarget(LastKnownLocation, nullptr);
	if (CurrentState == EAlienAIState::Patrullar)
	{
		SetAlienState(EAlienAIState::Investigar);
	}
	SyncBlackboard();
}

bool AAlienAIController::IsHunting() const
{
	return CurrentState == EAlienAIState::AlertaRoja && bPlayerIdentified && PlayerInSight.IsValid()
		&& !IsPlayerUnreachable(PlayerInSight.Get());
}

void AAlienAIController::UpdateHunt()
{
	UBlackboardComponent* BB = GetBlackboardComponent();
	const APawn* MyPawn = GetPawn();
	if (!BB || !MyPawn)
	{
		return;
	}

	// Milestone 1, módulo B: lo vio entrar en un escondite durante la persecución -> abrir y capturar.
	if (AHidingSpot* Spot = SpotToForceOpen.Get())
	{
		AActor* Hidden = Spot->GetOccupant();
		if (!Hidden)
		{
			// Salió por su cuenta antes de que llegara: vuelve a la lógica normal.
			SpotToForceOpen = nullptr;
			BB->ClearValue(AlienBBKeys::TargetActor);
		}
		else
		{
			BB->SetValueAsObject(AlienBBKeys::TargetActor, Spot);
			if (FVector::Dist2D(MyPawn->GetActorLocation(), Spot->GetExitLocation()) <= CaptureRadius)
			{
				SpotToForceOpen = nullptr;
				Spot->ForceOpen(GetPawn());
				if (AStationGameState* GS = GetWorld()->GetGameState<AStationGameState>())
				{
					GS->NotifyPlayerCaptured(Hidden, GetPawn());
				}
			}
			return;
		}
	}

	AActor* Player = PlayerInSight.Get();

	// Resolución del Lead (v0.2, duda 1):
	// - Con la persecución en curso y LOS mantenida, el camuflaje NO despista (se sigue persiguiendo).
	// - Si se rompió la LOS (bPlayerIdentified ya es false), un jugador camuflado que no corre
	//   no puede ser re-identificado aunque vuelva a entrar en el cono de visión.
	if (Player && !bPlayerIdentified && SuspicionMeter >= Threshold_ConfirmPlayer)
	{
		const bool bCamouflagedAndStill = IStealthTarget::Execute_IsCamouflaged(Player)
			&& !IStealthTarget::Execute_IsRunning(Player);
		if (!bCamouflagedAndStill)
		{
			bPlayerIdentified = true;
		}
	}

	if (IsHunting())
	{
		BB->SetValueAsObject(AlienBBKeys::TargetActor, Player);
		BB->SetValueAsVector(AlienBBKeys::InvestigationLocation, Player->GetActorLocation());
		if (AStationGameState* GS = GetWorld()->GetGameState<AStationGameState>())
		{
			GS->UpdateLastKnownIntruderLocation(Player->GetActorLocation());
		}

		if (FVector::Dist(MyPawn->GetActorLocation(), Player->GetActorLocation()) <= CaptureRadius)
		{
			if (AStationGameState* GS = GetWorld()->GetGameState<AStationGameState>())
			{
				GS->NotifyPlayerCaptured(Player, GetPawn());
			}
		}
		return;
	}

	// Perdió de vista al jugador: deja de perseguir y registra el último punto conocido.
	if (BB->GetValueAsObject(AlienBBKeys::TargetActor))
	{
		BB->ClearValue(AlienBBKeys::TargetActor);
		bPlayerIdentified = false;
		bArrivedAtInvestigation = false;
	}
}

void AAlienAIController::ReleaseRunnerReservation()
{
	if (UStationAlarmSubsystem* Subsystem = GetWorld() ? GetWorld()->GetSubsystem<UStationAlarmSubsystem>() : nullptr)
	{
		Subsystem->ReleaseRunner(GetPawn());
	}
}

void AAlienAIController::NotifyAlarmConsoleActivated(AAlarmConsole* Console)
{
	if (Console)
	{
		Console->ActivateAlarm(GetPawn()); // -> GameState->TriggerRedAlert() -> HandleRedAlert en todos los aliens
	}
	bIsAlarmTriggered = true;
	SetAlienState(EAlienAIState::AlertaRoja);
}

void AAlienAIController::HandleRedAlert(AActor* AlarmInstigator)
{
	bIsAlarmTriggered = true;
	AHidingSpot* Guarded = SpotToGuard.Get();
	SpotToGuard = nullptr;
	if (CurrentState != EAlienAIState::AlertaRoja)
	{
		SetAlienState(EAlienAIState::AlertaRoja);
	}
	// Resolución del cierre M1: el alien de apoyo que vigilaba un casillero lo fuerza al sonar la alarma.
	if (Guarded && Guarded->IsOccupied())
	{
		SpotToForceOpen = Guarded;
		if (UBlackboardComponent* BB = GetBlackboardComponent())
		{
			BB->SetValueAsObject(AlienBBKeys::TargetActor, Guarded);
		}
	}
}

bool AAlienAIController::GetNextPatrolPoint(FVector& OutLocation)
{
	const AAlienCharacter* Alien = Cast<AAlienCharacter>(GetPawn());
	if (!Alien || !Alien->PatrolPath || Alien->PatrolPath->NumPoints() == 0)
	{
		return false;
	}
	const APatrolPath* Path = Alien->PatrolPath;
	PatrolIndex = PatrolIndex % Path->NumPoints();
	OutLocation = Path->GetWorldPoint(PatrolIndex);
	PatrolIndex = (PatrolIndex + 1) % Path->NumPoints();
	return true;
}

// ---------------------------------------------------------------------------
// Utilidades
// ---------------------------------------------------------------------------

void AAlienAIController::SetMaxWalkSpeed(float Speed) const
{
	if (const ACharacter* Char = Cast<ACharacter>(GetPawn()))
	{
		Char->GetCharacterMovement()->MaxWalkSpeed = Speed;
	}
}

bool AAlienAIController::IsGlobalAlarmTriggered() const
{
	if (const AStationGameState* GS = GetWorld()->GetGameState<AStationGameState>())
	{
		return GS->IsAlarmTriggered();
	}
	return bIsAlarmTriggered;
}

void AAlienAIController::SyncBlackboard() const
{
	if (UBlackboardComponent* BB = GetBlackboardComponent())
	{
		BB->SetValueAsFloat(AlienBBKeys::SuspicionMeter, SuspicionMeter);
		BB->SetValueAsBool(AlienBBKeys::bPlayerIdentified, bPlayerIdentified);
		BB->SetValueAsBool(AlienBBKeys::bIsAlarmTriggered, bIsAlarmTriggered);
		BB->SetValueAsBool(AlienBBKeys::bHasSeenCorpse, bHasSeenCorpse);
	}
}

void AAlienAIController::NotifyPlayerEnteringHidingSpot(AActor* Player, AHidingSpot* Spot)
{
	// Solo si lo perseguía con LOS activa en ese momento. Si había roto la LOS antes,
	// la lógica normal ya lo manda a investigar el último punto visto (fuera del casillero) y luego retoma la ruta.
	if (Spot && IsHunting() && PlayerInSight == Player)
	{
		SpotToForceOpen = Spot;
		if (UBlackboardComponent* BB = GetBlackboardComponent())
		{
			BB->SetValueAsObject(AlienBBKeys::TargetActor, Spot);
		}
		UE_LOG(LogAlienAI, Log, TEXT("%s vio al jugador entrar en %s"), *GetName(), *Spot->GetName());
		return;
	}

	// Resolución del cierre M1: fuera de AlertaRoja, verlo entrar = humano confirmado (sospecha 100).
	// - Si este alien obtiene la reserva de corredor -> corre a la consola e ignora el casillero.
	// - Si no (alien de apoyo) -> vigila el casillero hasta la alarma y entonces lo fuerza.
	if (Spot && PlayerInSight == Player
		&& (CurrentState == EAlienAIState::Patrullar || CurrentState == EAlienAIState::Investigar))
	{
		SuspicionMeter = Threshold_ConfirmPlayer;
		SpotToGuard = Spot;
		SetInvestigationTarget(Spot->GetExitLocation(), Spot);
		if (AStationGameState* GS = GetWorld()->GetGameState<AStationGameState>())
		{
			GS->UpdateLastKnownIntruderLocation(Spot->GetExitLocation());
		}
		EvaluateTransitions(); // CorrerHaciaAlarma (limpia SpotToGuard) o Investigar como apoyo
		SyncBlackboard();
		UE_LOG(LogAlienAI, Log, TEXT("%s vio al jugador entrar en %s fuera de AlertaRoja (%s)"), *GetName(), *Spot->GetName(),
			SpotToGuard.IsValid() ? TEXT("vigila") : TEXT("corre a la alarma"));
	}
}

void AAlienAIController::NotifyInspectionDetectedPlayer(AHidingSpot* Spot)
{
	if (Spot && Spot->IsOccupied() && CurrentState == EAlienAIState::AlertaRoja)
	{
		SpotToForceOpen = Spot;
		if (UBlackboardComponent* BB = GetBlackboardComponent())
		{
			BB->SetValueAsObject(AlienBBKeys::TargetActor, Spot);
		}
		UE_LOG(LogAlienAI, Log, TEXT("%s detectó al jugador dentro de %s durante la inspección"), *GetName(), *Spot->GetName());
	}
}

void AAlienAIController::NotifyPlayerEnteredVentDuct(AActor* Player, AVentDuct* Duct)
{
	if (!Duct || !Player || PlayerInSight != Player || !GetPawn() || CurrentState == EAlienAIState::CorrerHaciaAlarma)
	{
		return;
	}
	const UStationAlarmSubsystem* Subsystem = GetWorld()->GetSubsystem<UStationAlarmSubsystem>();
	FVector Exit;
	if (!Subsystem || !Subsystem->FindDuctAmbushExit(Duct, Player->GetActorLocation(), GetPawn()->GetActorLocation(), Exit))
	{
		return;
	}

	if (AStationGameState* GS = GetWorld()->GetGameState<AStationGameState>())
	{
		GS->UpdateLastKnownIntruderLocation(Player->GetActorLocation());
	}

	UBlackboardComponent* BB = GetBlackboardComponent();
	if (CurrentState == EAlienAIState::AlertaRoja)
	{
		bPlayerIdentified = false; // deja de perseguir: no cabe en el conducto
		if (BB)
		{
			BB->ClearValue(AlienBBKeys::TargetActor);
			BB->SetValueAsVector(AlienBBKeys::InvestigationLocation, Exit);
		}
		bArrivedAtInvestigation = false;
	}
	else
	{
		SuspicionMeter = FMath::Max(SuspicionMeter, Threshold_Investigate);
		SetInvestigationTarget(Exit, nullptr);
		if (CurrentState == EAlienAIState::Patrullar)
		{
			SetAlienState(EAlienAIState::Investigar);
		}
		EvaluateTransitions();
	}
	SyncBlackboard();
	UE_LOG(LogAlienAI, Log, TEXT("%s embosca la salida del conducto %s en %s"), *GetName(), *Duct->GetName(), *Exit.ToCompactString());
}

bool AAlienAIController::IsPlayerUnreachable(const AActor* Player)
{
	const AAstronautaCharacter* Astro = Cast<AAstronautaCharacter>(Player);
	return Astro && (Astro->IsInVentDuct() || Astro->IsHiddenInSpot());
}

void AAlienAIController::FaceLocation(const FVector& Location) const
{
	if (APawn* MyPawn = GetPawn())
	{
		const FVector ToTarget = (Location - MyPawn->GetActorLocation()).GetSafeNormal2D();
		if (!ToTarget.IsNearlyZero())
		{
			MyPawn->SetActorRotation(ToTarget.Rotation());
		}
	}
}

void AAlienAIController::CheckFlashlightExposure()
{
	const float Now = GetWorld()->GetTimeSeconds();

	if (CurrentState == EAlienAIState::CorrerHaciaAlarma)
	{
		PendingLightReactionTime = -1.f; // el corredor ignora estímulos
		bLitFromBehindLastCheck = false;
		return;
	}

	// Reacción diferida a una luz recibida por la espalda (resolución del Lead M2: 0.5 s).
	if (PendingLightReactionTime > 0.f && Now >= PendingLightReactionTime)
	{
		PendingLightReactionTime = -1.f;
		if (CurrentState == EAlienAIState::AlertaRoja)
		{
			if (!IsHunting())
			{
				if (UBlackboardComponent* BB = GetBlackboardComponent())
				{
					BB->SetValueAsVector(AlienBBKeys::InvestigationLocation, PendingLightOrigin);
				}
				bArrivedAtInvestigation = false;
			}
		}
		else
		{
			SuspicionMeter = FMath::Max(SuspicionMeter, Threshold_Investigate);
			SetInvestigationTarget(PendingLightOrigin, nullptr);
			if (CurrentState == EAlienAIState::Patrullar)
			{
				SetAlienState(EAlienAIState::Investigar);
			}
		}
	}

	FVector Origin;
	bool bFromFront = false;
	const bool bLit = IsLitByFlashlight(Origin, bFromFront);
	if (!bLit)
	{
		bLitFromBehindLastCheck = false;
		return;
	}

	if (AStationGameState* GS = GetWorld()->GetGameState<AStationGameState>())
	{
		GS->UpdateLastKnownIntruderLocation(Origin);
	}

	if (bFromFront)
	{
		// De frente o lateral (≤ 110°): sospecha a 100 y giro inmediato hacia la linterna.
		bLitFromBehindLastCheck = false;
		PendingLightReactionTime = -1.f;
		SuspicionMeter = Threshold_ConfirmPlayer;
		FaceLocation(Origin);
		if (CurrentState == EAlienAIState::AlertaRoja)
		{
			if (!IsHunting())
			{
				if (UBlackboardComponent* BB = GetBlackboardComponent())
				{
					BB->SetValueAsVector(AlienBBKeys::InvestigationLocation, Origin);
				}
				bArrivedAtInvestigation = false;
			}
		}
		else
		{
			SetInvestigationTarget(Origin, UGameplayStatics::GetPlayerPawn(this, 0));
		}
		return;
	}

	// Por la espalda (> 110°): +40 una sola vez por exposición e investigar el origen tras 0.5 s.
	PendingLightOrigin = Origin;
	if (!bLitFromBehindLastCheck)
	{
		bLitFromBehindLastCheck = true;
		AddSuspicion(FlashlightBehindSuspicionDelta);
		PendingLightReactionTime = Now + FlashlightBehindReactionDelay;
	}
}

bool AAlienAIController::IsLitByFlashlight(FVector& OutOrigin, bool& bOutFromFront) const
{
	const APawn* MyPawn = GetPawn();
	APawn* Player = UGameplayStatics::GetPlayerPawn(this, 0);
	if (!MyPawn || !Player || !Player->Implements<UStealthTarget>())
	{
		return false;
	}

	FVector Origin, Direction;
	float Range = 0.f, HalfAngle = 0.f;
	if (!IStealthTarget::Execute_GetFlashlightBeam(Player, Origin, Direction, Range, HalfAngle))
	{
		return false;
	}

	// ¿Está el cuerpo del alien dentro del cono? Se amplía el ángulo con el radio de la cápsula.
	const FVector Target = MyPawn->GetActorLocation();
	const FVector ToAlien = Target - Origin;
	const float Dist = ToAlien.Size();
	if (Dist > Range || Dist < KINDA_SMALL_NUMBER)
	{
		return false;
	}
	const float BodyRadius = MyPawn->GetSimpleCollisionRadius();
	const float Cos = FMath::Clamp(static_cast<float>(FVector::DotProduct(Direction.GetSafeNormal(), ToAlien / Dist)), -1.f, 1.f);
	const float AngleToAlien = FMath::RadiansToDegrees(FMath::Acos(Cos));
	const float Tolerance = FMath::RadiansToDegrees(FMath::Atan2(BodyRadius, Dist));
	if (AngleToAlien > HalfAngle + Tolerance)
	{
		return false;
	}

	// Sin oclusores entre la linterna y el alien.
	FCollisionQueryParams Params(SCENE_QUERY_STAT(AlienFlashlightLOS), false, Player);
	FHitResult Hit;
	if (GetWorld()->LineTraceSingleByChannel(Hit, Origin, Target, ECC_Visibility, Params) && Hit.GetActor() != MyPawn)
	{
		return false;
	}

	// Ángulo entre hacia dónde mira el alien y la dirección hacia la linterna.
	const FVector ToLight = (Origin - Target).GetSafeNormal2D();
	const FVector Forward = MyPawn->GetActorForwardVector().GetSafeNormal2D();
	const float FacingCos = FMath::Clamp(static_cast<float>(FVector::DotProduct(Forward, ToLight)), -1.f, 1.f);
	bOutFromFront = FMath::RadiansToDegrees(FMath::Acos(FacingCos)) <= FlashlightFrontalAngle;
	OutOrigin = Origin;
	return true;
}
