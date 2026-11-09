#include "AI/BTTask_FindChokepoint.h"
#include "AI/AlienAITypes.h"
#include "Gameplay/ChokepointMarker.h"
#include "Gameplay/StationAlarmSubsystem.h"
#include "AIController.h"
#include "BehaviorTree/BlackboardComponent.h"
#include "Gameplay/StationGameState.h"

UBTTask_FindChokepoint::UBTTask_FindChokepoint()
{
	NodeName = TEXT("Find Chokepoint");
}

EBTNodeResult::Type UBTTask_FindChokepoint::ExecuteTask(UBehaviorTreeComponent& OwnerComp, uint8* NodeMemory)
{
	const AAIController* Controller = OwnerComp.GetAIOwner();
	UBlackboardComponent* BB = OwnerComp.GetBlackboardComponent();
	const UWorld* World = Controller ? Controller->GetWorld() : nullptr;
	const UStationAlarmSubsystem* Subsystem = World ? World->GetSubsystem<UStationAlarmSubsystem>() : nullptr;
	if (!BB || !Subsystem)
	{
		return EBTNodeResult::Failed;
	}

	// Sin trampas (decisión del Lead): el cerco se centra en la última posición confirmada por algún alien.
	// Si nadie ha visto nunca al jugador, en la posición del propio alien.
	FVector Center = Controller->GetPawn() ? Controller->GetPawn()->GetActorLocation() : FVector::ZeroVector;
	if (const AStationGameState* GS = World->GetGameState<AStationGameState>())
	{
		FVector LastKnown;
		if (GS->GetLastReportedIntruderLocation(LastKnown))
		{
			Center = LastKnown;
		}
	}

	const AChokepointMarker* Marker = Subsystem->PickChokepointNear(Center, NearestCandidates);
	if (!Marker)
	{
		return EBTNodeResult::Failed;
	}
	BB->SetValueAsVector(AlienBBKeys::PatrolLocation, Marker->GetActorLocation());
	return EBTNodeResult::Succeeded;
}
