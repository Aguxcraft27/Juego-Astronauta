#pragma once

#include "CoreMinimal.h"
#include "AIController.h"
#include "Perception/AIPerceptionTypes.h"
#include "AI/AlienAITypes.h"
#include "AlienAIController.generated.h"

class UAIPerceptionComponent;
class UAISenseConfig_Sight;
class UAISenseConfig_Hearing;
class UBehaviorTree;
class AAlarmConsole;
class AHidingSpot;
class AVentDuct;

/**
 * Dueño único del SuspicionMeter y de las transiciones de estado del alien.
 * El Behavior Tree solo lee el estado del Blackboard; todos los cambios pasan por SetAlienState().
 */
UCLASS()
class ASTRONAUTA_API AAlienAIController : public AAIController
{
	GENERATED_BODY()

public:
	AAlienAIController();

	// --- API usada por los nodos del Behavior Tree ---
	/** Lo llama UBTService_UpdateSuspicion en cada tick del servicio. */
	void UpdateSuspicion(float DeltaSeconds);
	/** BTTask_SearchArea: el alien ha llegado a InvestigationLocation (empieza el enfriamiento). */
	void NotifyArrivedAtInvestigation();
	/** BTTask_SearchArea: terminó el barrido de búsqueda de 5 s. */
	void NotifySearchFinished();
	/** BTTask_TriggerAlarmConsole: la consola se activó (transición 4). */
	void NotifyAlarmConsoleActivated(AAlarmConsole* Console);
	/**
	 * AHidingSpot avisa a todos los aliens antes de esconder al jugador.
	 * Si este alien lo perseguía con LOS (AlertaRoja), va a forzar el escondite.
	 */
	void NotifyPlayerEnteringHidingSpot(AActor* Player, AHidingSpot* Spot);

	/** AVentDuct: si este alien ve entrar al jugador, va a emboscar a la salida más cercana. */
	void NotifyPlayerEnteredVentDuct(AActor* Player, AVentDuct* Duct);

	/** BTTask_InspectHidingSpot: el jugador escondido se delató durante la inspección -> forzar y capturar. */
	void NotifyInspectionDetectedPlayer(AHidingSpot* Spot);

	/** BTTask_FindPatrolPoint: devuelve el siguiente punto de patrulla y avanza el índice. */
	bool GetNextPatrolPoint(FVector& OutLocation);

	UFUNCTION(BlueprintPure, Category = "Alien AI")
	EAlienAIState GetAlienState() const { return CurrentState; }

	/** M5 (SaveTerminal): persecución activa = AlertaRoja viendo al jugador, o corriendo a la alarma. */
	UFUNCTION(BlueprintPure, Category = "Alien AI")
	bool IsInActivePursuit() const { return IsHunting() || CurrentState == EAlienAIState::CorrerHaciaAlarma; }

	UFUNCTION(BlueprintPure, Category = "Alien AI")
	float GetSuspicion() const { return SuspicionMeter; }

	// --- Tuning (valores de la especificación del Lead) ---
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Alien AI|Suspicion")
	float SuspicionIncreaseRate_Running = 35.f;
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Alien AI|Suspicion")
	float SuspicionIncreaseRate_NoCamouflage = 20.f;
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Alien AI|Suspicion")
	float SuspicionInstantDelta_Corpse = 50.f;
	/** Se multiplica por Clamp(Stimulus.Strength, 0.5, 2.0). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Alien AI|Suspicion")
	float SuspicionInstantDelta_Noise = 15.f;

	/** M4: pitido del Motion Tracker oído a corta distancia (ruido con tag "MotionTrackerPing"). Fijo, no escala con la intensidad. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Alien AI|Suspicion")
	float SuspicionInstantDelta_TrackerPing = 25.f;
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Alien AI|Suspicion")
	float SuspicionDecayRate = 12.f;
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Alien AI|Suspicion")
	float Threshold_Investigate = 30.f;
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Alien AI|Suspicion")
	float Threshold_ConfirmPlayer = 100.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Alien AI|Movement")
	float PatrolSpeed = 250.f;
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Alien AI|Movement")
	float InvestigateSpeed = 380.f;
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Alien AI|Movement")
	float SprintToAlarmSpeed = 700.f;
	/** PROVISIONAL: la spec no fija velocidad para AlertaRoja. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Alien AI|Movement")
	float RedAlertSpeed = 450.f;
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Alien AI|Movement")
	float AlarmInteractionRadius = 150.f;
	/** En AlertaRoja, distancia de contacto que dispara la captura / Game Over. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Alien AI|Movement")
	float CaptureRadius = 100.f;

	UPROPERTY(EditDefaultsOnly, Category = "Alien AI")
	TObjectPtr<UBehaviorTree> BehaviorTreeAsset;

	/** Los actores con esta etiqueta (y un UAIPerceptionStimuliSourceComponent) cuentan como cadáveres. */
	UPROPERTY(EditDefaultsOnly, Category = "Alien AI")
	FName CorpseTag = TEXT("Corpse");

	/** Los actores con esta etiqueta (y StimuliSource de Sight) son pistas: un alien en patrulla que las ve va a investigarlas. */
	UPROPERTY(EditDefaultsOnly, Category = "Alien AI")
	FName ClueTag = TEXT("InvestigationClue");

	/** M5: charcos de sangre frescos (ABloodDropActor). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Alien AI|Perception")
	FName BloodTag = TEXT("BloodTrail");

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Alien AI|Suspicion")
	float SuspicionInstantDelta_Blood = 30.f;

	/** Linterna: ángulo máximo (respecto a hacia dónde mira el alien) para considerarlo "de frente o lateral". */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Alien AI|Flashlight")
	float FlashlightFrontalAngle = 110.f;
	/** Linterna por la espalda: sospecha añadida una vez por exposición. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Alien AI|Flashlight")
	float FlashlightBehindSuspicionDelta = 40.f;
	/** Linterna por la espalda: retardo antes de ir a investigar el origen. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Alien AI|Flashlight")
	float FlashlightBehindReactionDelay = 0.5f;

	/** Si un cadáver reportado aparece a más de esta distancia de donde se reportó, vuelve a alertar. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Alien AI|Suspicion")
	float CorpseMovedDistance = 300.f;

protected:
	virtual void OnPossess(APawn* InPawn) override;
	virtual void OnUnPossess() override;

	UFUNCTION()
	void HandleTargetPerceptionUpdated(AActor* Actor, FAIStimulus Stimulus);

	UFUNCTION()
	void HandleRedAlert(AActor* AlarmInstigator);

	UFUNCTION()
	void HandleIntruderReported(FVector LastKnownLocation, AActor* Reporter);

	UPROPERTY(VisibleAnywhere, Category = "Alien AI")
	TObjectPtr<UAIPerceptionComponent> AlienPerception;

	UPROPERTY()
	TObjectPtr<UAISenseConfig_Sight> SightConfig;

	UPROPERTY()
	TObjectPtr<UAISenseConfig_Hearing> HearingConfig;

private:
	void SetAlienState(EAlienAIState NewState);
	void EvaluateTransitions();
	void AddSuspicion(float Amount);
	/** Reacción a un cadáver a la vista (evento de percepción o escaneo por tick). */
	void HandleCorpseSeen(AActor* Corpse);
	void SetInvestigationTarget(const FVector& Location, AActor* Actor);
	void SetMaxWalkSpeed(float Speed) const;
	bool IsGlobalAlarmTriggered() const;
	void SyncBlackboard() const;
	/** AlertaRoja: persigue al jugador mientras lo ve y comprueba la captura. */
	void UpdateHunt();
	bool IsHunting() const;
	void ReleaseRunnerReservation();
	/** Haz de linterna del jugador sobre este alien (cono, alcance y sin oclusores). */
	void CheckFlashlightExposure();
	bool IsLitByFlashlight(FVector& OutOrigin, bool& bOutFromFront) const;
	void HandleClueSeen(AActor* Clue);
	void HandleBloodSeen(AActor* Blood);
	/** El jugador está en un conducto o escondite: no se le puede alcanzar andando. */
	static bool IsPlayerUnreachable(const AActor* Player);
	void FaceLocation(const FVector& Location) const;

	EAlienAIState CurrentState = EAlienAIState::Patrullar;
	float SuspicionMeter = 0.f;
	bool bPlayerIdentified = false;
	bool bHasSeenCorpse = false;
	bool bIsAlarmTriggered = false;

	bool bArrivedAtInvestigation = false;
	bool bSearchFinished = false;

	TWeakObjectPtr<AActor> PlayerInSight;
	TWeakObjectPtr<AActor> PendingCorpse;
	/** Cadáver -> posición en la que se reportó. */
	TMap<TWeakObjectPtr<AActor>, FVector> ReportedCorpses;
	TWeakObjectPtr<AAlarmConsole> TargetAlarmConsole;
	/** Escondite en el que vio entrar al jugador durante una persecución. */
	TWeakObjectPtr<AHidingSpot> SpotToForceOpen;
	/** Fuera de AlertaRoja: escondite que vigila (alien de apoyo) hasta que suene la alarma. */
	TWeakObjectPtr<AHidingSpot> SpotToGuard;

	int32 PatrolIndex = 0;

	float PendingLightReactionTime = -1.f;
	FVector PendingLightOrigin = FVector::ZeroVector;
	bool bLitFromBehindLastCheck = false;
	TSet<TWeakObjectPtr<AActor>> InvestigatedClues;
};
