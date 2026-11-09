#include "AI/BTTask_InspectHidingSpot.h"
#include "AI/AlienAIController.h"
#include "AI/AlienCharacter.h"
#include "Gameplay/HidingSpot.h"
#include "Gameplay/StationAlarmSubsystem.h"
#include "Player/AstronautaCharacter.h"
#include "Navigation/PathFollowingComponent.h"

UBTTask_InspectHidingSpot::UBTTask_InspectHidingSpot()
{
	NodeName = TEXT("Inspect Hiding Spot");
	bNotifyTick = true;
}

uint16 UBTTask_InspectHidingSpot::GetInstanceMemorySize() const
{
	return sizeof(FInspectMemory);
}

EBTNodeResult::Type UBTTask_InspectHidingSpot::ExecuteTask(UBehaviorTreeComponent& OwnerComp, uint8* NodeMemory)
{
	FInspectMemory* Mem = new (NodeMemory) FInspectMemory();

	AAlienAIController* Controller = Cast<AAlienAIController>(OwnerComp.GetAIOwner());
	const APawn* Pawn = Controller ? Controller->GetPawn() : nullptr;
	if (!Pawn || Controller->GetAlienState() != EAlienAIState::AlertaRoja || FMath::FRand() > Chance)
	{
		return EBTNodeResult::Succeeded; // no toca inspeccionar esta vez
	}

	const UStationAlarmSubsystem* Subsystem = Controller->GetWorld()->GetSubsystem<UStationAlarmSubsystem>();
	AHidingSpot* Spot = Subsystem ? Subsystem->FindNearestHidingSpot(Pawn->GetActorLocation(), SearchRadius) : nullptr;
	if (!Spot)
	{
		return EBTNodeResult::Succeeded;
	}

	const EPathFollowingRequestResult::Type Move = Controller->MoveToLocation(Spot->GetExitLocation(), 50.f);
	if (Move == EPathFollowingRequestResult::Failed)
	{
		return EBTNodeResult::Succeeded;
	}

	Mem->Spot = Spot;
	if (Move == EPathFollowingRequestResult::AlreadyAtGoal)
	{
		StartSniffing(OwnerComp, *Mem);
	}
	return EBTNodeResult::InProgress;
}

void UBTTask_InspectHidingSpot::StartSniffing(UBehaviorTreeComponent& OwnerComp, FInspectMemory& Mem) const
{
	Mem.Phase = EPhase::Sniffing;
	Mem.Elapsed = 0.f;

	AAIController* Controller = OwnerComp.GetAIOwner();
	AHidingSpot* Spot = Mem.Spot.Get();
	Mem.SniffStartTime = Controller ? Controller->GetWorld()->GetTimeSeconds() : 0.f;
	if (!Controller || !Spot)
	{
		return;
	}
	Controller->SetFocalPoint(Spot->GetActorLocation(), EAIFocusPriority::Gameplay);
	if (AAlienCharacter* Alien = Cast<AAlienCharacter>(Controller->GetPawn()))
	{
		if (Alien->SniffMontage)
		{
			Alien->PlayAnimMontage(Alien->SniffMontage);
		}
		Alien->OnInspectHidingSpot(Spot);
	}
}

void UBTTask_InspectHidingSpot::TickTask(UBehaviorTreeComponent& OwnerComp, uint8* NodeMemory, float DeltaSeconds)
{
	FInspectMemory* Mem = reinterpret_cast<FInspectMemory*>(NodeMemory);
	AAlienAIController* Controller = Cast<AAlienAIController>(OwnerComp.GetAIOwner());
	AHidingSpot* Spot = Mem->Spot.Get();
	if (!Controller || !Spot)
	{
		Cleanup(OwnerComp);
		FinishLatentTask(OwnerComp, EBTNodeResult::Succeeded);
		return;
	}

	Mem->Elapsed += DeltaSeconds;

	if (Mem->Phase == EPhase::Moving)
	{
		if (Controller->GetMoveStatus() == EPathFollowingStatus::Idle)
		{
			StartSniffing(OwnerComp, *Mem);
		}
		else if (Mem->Elapsed >= MoveTimeout)
		{
			Cleanup(OwnerComp);
			FinishLatentTask(OwnerComp, EBTNodeResult::Succeeded);
		}
		return;
	}

	// Olfateando: ¿se delata el jugador escondido?
	if (const AAstronautaCharacter* Hidden = Spot->GetOccupant())
	{
		// Resolución del Lead (M2): el casillero es opaco; solo delata el ruido emitido durante el olfateo
		// (movimiento brusco o el chisporroteo de un camuflaje que se agota dentro).
		const bool bMadeNoise = Hidden->GetLastNoiseTime() >= Mem->SniffStartTime;
		if (bMadeNoise)
		{
			Cleanup(OwnerComp);
			FinishLatentTask(OwnerComp, EBTNodeResult::Succeeded);
			Controller->NotifyInspectionDetectedPlayer(Spot); // tras terminar: activa la rama de forzar
			return;
		}
	}

	if (Mem->Elapsed >= InspectDuration)
	{
		Cleanup(OwnerComp);
		FinishLatentTask(OwnerComp, EBTNodeResult::Succeeded);
	}
}

EBTNodeResult::Type UBTTask_InspectHidingSpot::AbortTask(UBehaviorTreeComponent& OwnerComp, uint8* NodeMemory)
{
	if (AAIController* Controller = OwnerComp.GetAIOwner())
	{
		Controller->StopMovement();
	}
	Cleanup(OwnerComp);
	return EBTNodeResult::Aborted;
}

void UBTTask_InspectHidingSpot::Cleanup(UBehaviorTreeComponent& OwnerComp) const
{
	AAIController* Controller = OwnerComp.GetAIOwner();
	if (!Controller)
	{
		return;
	}
	Controller->ClearFocus(EAIFocusPriority::Gameplay);
	if (AAlienCharacter* Alien = Cast<AAlienCharacter>(Controller->GetPawn()); Alien && Alien->SniffMontage)
	{
		Alien->StopAnimMontage(Alien->SniffMontage);
	}
}
