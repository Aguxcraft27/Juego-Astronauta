#include "AI/BTTask_FindPatrolPoint.h"
#include "AI/AlienAIController.h"
#include "AI/AlienAITypes.h"
#include "BehaviorTree/BlackboardComponent.h"

UBTTask_FindPatrolPoint::UBTTask_FindPatrolPoint()
{
	NodeName = TEXT("Find Patrol Point");
}

EBTNodeResult::Type UBTTask_FindPatrolPoint::ExecuteTask(UBehaviorTreeComponent& OwnerComp, uint8* NodeMemory)
{
	AAlienAIController* Controller = Cast<AAlienAIController>(OwnerComp.GetAIOwner());
	UBlackboardComponent* BB = OwnerComp.GetBlackboardComponent();
	FVector Location;
	if (!Controller || !BB || !Controller->GetNextPatrolPoint(Location))
	{
		return EBTNodeResult::Failed;
	}
	BB->SetValueAsVector(AlienBBKeys::PatrolLocation, Location);
	return EBTNodeResult::Succeeded;
}
