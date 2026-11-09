#include "AI/BTService_UpdateSuspicion.h"
#include "AI/AlienAIController.h"
#include "BehaviorTree/BehaviorTreeComponent.h"

UBTService_UpdateSuspicion::UBTService_UpdateSuspicion()
{
	NodeName = TEXT("Update Suspicion");
	Interval = 0.1f;
	RandomDeviation = 0.f;
	bNotifyTick = true;
}

void UBTService_UpdateSuspicion::TickNode(UBehaviorTreeComponent& OwnerComp, uint8* NodeMemory, float DeltaSeconds)
{
	Super::TickNode(OwnerComp, NodeMemory, DeltaSeconds);
	if (AAlienAIController* Controller = Cast<AAlienAIController>(OwnerComp.GetAIOwner()))
	{
		Controller->UpdateSuspicion(DeltaSeconds);
	}
}
