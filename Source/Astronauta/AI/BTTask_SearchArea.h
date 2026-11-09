#pragma once

#include "CoreMinimal.h"
#include "BehaviorTree/BTTaskNode.h"
#include "BTTask_SearchArea.generated.h"

/**
 * Se ejecuta al llegar a InvestigationLocation: el alien gira mirando a direcciones aleatorias
 * durante SearchDuration y luego avisa al controlador (transición 2 si la sospecha llegó a 0).
 */
UCLASS()
class ASTRONAUTA_API UBTTask_SearchArea : public UBTTaskNode
{
	GENERATED_BODY()

public:
	UBTTask_SearchArea();

	UPROPERTY(EditAnywhere, Category = "Search", meta = (ClampMin = "0.1"))
	float SearchDuration = 5.f;

	UPROPERTY(EditAnywhere, Category = "Search", meta = (ClampMin = "0.1"))
	float LookInterval = 1.25f;

protected:
	virtual EBTNodeResult::Type ExecuteTask(UBehaviorTreeComponent& OwnerComp, uint8* NodeMemory) override;
	virtual void TickTask(UBehaviorTreeComponent& OwnerComp, uint8* NodeMemory, float DeltaSeconds) override;
	virtual EBTNodeResult::Type AbortTask(UBehaviorTreeComponent& OwnerComp, uint8* NodeMemory) override;
	virtual uint16 GetInstanceMemorySize() const override;

private:
	struct FSearchMemory
	{
		float Elapsed = 0.f;
		float NextLook = 0.f;
	};

	void LookAtRandomDirection(UBehaviorTreeComponent& OwnerComp) const;
};
