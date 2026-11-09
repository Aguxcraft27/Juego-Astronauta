#pragma once

#include "CoreMinimal.h"
#include "BehaviorTree/BTTaskNode.h"
#include "BTTask_InspectHidingSpot.generated.h"

class AHidingSpot;

/**
 * Milestone 2 — tensión en AlertaRoja. Con probabilidad Chance, si hay un AHidingSpot a menos de
 * SearchRadius, el alien va a su ExitPoint y olfatea InspectDuration segundos.
 * Si el jugador está dentro y hace ruido durante el olfateo (incluido el del camuflaje agotándose), el alien lo detecta
 * (fuerza el escondite y captura). Si no, termina y el cerco continúa.
 * Siempre termina en Succeeded para no romper la secuencia de chokepoints.
 */
UCLASS()
class ASTRONAUTA_API UBTTask_InspectHidingSpot : public UBTTaskNode
{
	GENERATED_BODY()

public:
	UBTTask_InspectHidingSpot();

	UPROPERTY(EditAnywhere, Category = "Inspect", meta = (ClampMin = "0", ClampMax = "1"))
	float Chance = 0.2f;

	UPROPERTY(EditAnywhere, Category = "Inspect", meta = (ClampMin = "0"))
	float SearchRadius = 500.f;

	UPROPERTY(EditAnywhere, Category = "Inspect", meta = (ClampMin = "0.1"))
	float InspectDuration = 3.f;

	/** Si no llega al escondite en este tiempo, se da por terminada la inspección. */
	UPROPERTY(EditAnywhere, Category = "Inspect", meta = (ClampMin = "0.5"))
	float MoveTimeout = 8.f;

protected:
	virtual EBTNodeResult::Type ExecuteTask(UBehaviorTreeComponent& OwnerComp, uint8* NodeMemory) override;
	virtual void TickTask(UBehaviorTreeComponent& OwnerComp, uint8* NodeMemory, float DeltaSeconds) override;
	virtual EBTNodeResult::Type AbortTask(UBehaviorTreeComponent& OwnerComp, uint8* NodeMemory) override;
	virtual uint16 GetInstanceMemorySize() const override;

private:
	enum class EPhase : uint8 { Moving, Sniffing };

	struct FInspectMemory
	{
		TWeakObjectPtr<AHidingSpot> Spot;
		EPhase Phase = EPhase::Moving;
		float Elapsed = 0.f;
		float SniffStartTime = 0.f;
	};

	void StartSniffing(UBehaviorTreeComponent& OwnerComp, FInspectMemory& Mem) const;
	void Cleanup(UBehaviorTreeComponent& OwnerComp) const;
};
