#pragma once

#include "CoreMinimal.h"
#include "BehaviorTree/BTTaskNode.h"
#include "BTTask_TriggerAlarmConsole.generated.h"

/**
 * Transición 4: si el alien está dentro de AlarmInteractionRadius de TargetAlarmConsole,
 * reproduce el montage de la consola y, al terminar, activa la alarma (-> AlertaRoja).
 */
UCLASS()
class ASTRONAUTA_API UBTTask_TriggerAlarmConsole : public UBTTaskNode
{
	GENERATED_BODY()

public:
	UBTTask_TriggerAlarmConsole();

protected:
	virtual EBTNodeResult::Type ExecuteTask(UBehaviorTreeComponent& OwnerComp, uint8* NodeMemory) override;
	virtual void TickTask(UBehaviorTreeComponent& OwnerComp, uint8* NodeMemory, float DeltaSeconds) override;
	virtual EBTNodeResult::Type AbortTask(UBehaviorTreeComponent& OwnerComp, uint8* NodeMemory) override;
	virtual uint16 GetInstanceMemorySize() const override;

private:
	struct FTriggerMemory
	{
		float RemainingTime = 0.f;
	};

	void Complete(UBehaviorTreeComponent& OwnerComp) const;
};
