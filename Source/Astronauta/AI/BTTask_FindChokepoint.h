#pragma once

#include "CoreMinimal.h"
#include "BehaviorTree/BTTaskNode.h"
#include "BTTask_FindChokepoint.generated.h"

/** AlertaRoja: escribe en PatrolLocation un chokepoint aleatorio entre los más cercanos a la última posición conocida del jugador. */
UCLASS()
class ASTRONAUTA_API UBTTask_FindChokepoint : public UBTTaskNode
{
	GENERATED_BODY()

public:
	UBTTask_FindChokepoint();

	/** Cuántos chokepoints cercanos entran en el sorteo. */
	UPROPERTY(EditAnywhere, Category = "Chokepoint", meta = (ClampMin = "1"))
	int32 NearestCandidates = 3;

protected:
	virtual EBTNodeResult::Type ExecuteTask(UBehaviorTreeComponent& OwnerComp, uint8* NodeMemory) override;
};
