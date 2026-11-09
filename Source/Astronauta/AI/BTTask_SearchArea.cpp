#include "AI/BTTask_SearchArea.h"
#include "AI/AlienAIController.h"
#include "GameFramework/Pawn.h"

UBTTask_SearchArea::UBTTask_SearchArea()
{
	NodeName = TEXT("Search Area");
	bNotifyTick = true;
}

uint16 UBTTask_SearchArea::GetInstanceMemorySize() const
{
	return sizeof(FSearchMemory);
}

EBTNodeResult::Type UBTTask_SearchArea::ExecuteTask(UBehaviorTreeComponent& OwnerComp, uint8* NodeMemory)
{
	AAlienAIController* Controller = Cast<AAlienAIController>(OwnerComp.GetAIOwner());
	if (!Controller || !Controller->GetPawn())
	{
		return EBTNodeResult::Failed;
	}

	FSearchMemory* Mem = reinterpret_cast<FSearchMemory*>(NodeMemory);
	Mem->Elapsed = 0.f;
	Mem->NextLook = 0.f;

	Controller->NotifyArrivedAtInvestigation();
	return EBTNodeResult::InProgress;
}

void UBTTask_SearchArea::TickTask(UBehaviorTreeComponent& OwnerComp, uint8* NodeMemory, float DeltaSeconds)
{
	FSearchMemory* Mem = reinterpret_cast<FSearchMemory*>(NodeMemory);
	Mem->Elapsed += DeltaSeconds;

	if (Mem->Elapsed >= Mem->NextLook)
	{
		LookAtRandomDirection(OwnerComp);
		Mem->NextLook = Mem->Elapsed + LookInterval;
	}

	if (Mem->Elapsed >= SearchDuration)
	{
		AAlienAIController* Controller = Cast<AAlienAIController>(OwnerComp.GetAIOwner());
		if (Controller)
		{
			Controller->ClearFocus(EAIFocusPriority::Gameplay);
		}
		FinishLatentTask(OwnerComp, EBTNodeResult::Succeeded);
		if (Controller)
		{
			// Después de terminar la tarea: puede cambiar de estado y abortar esta rama.
			Controller->NotifySearchFinished();
		}
	}
}

EBTNodeResult::Type UBTTask_SearchArea::AbortTask(UBehaviorTreeComponent& OwnerComp, uint8* NodeMemory)
{
	if (AAIController* Controller = OwnerComp.GetAIOwner())
	{
		Controller->ClearFocus(EAIFocusPriority::Gameplay);
	}
	return EBTNodeResult::Aborted;
}

void UBTTask_SearchArea::LookAtRandomDirection(UBehaviorTreeComponent& OwnerComp) const
{
	AAIController* Controller = OwnerComp.GetAIOwner();
	const APawn* Pawn = Controller ? Controller->GetPawn() : nullptr;
	if (!Pawn)
	{
		return;
	}
	const float Yaw = FMath::FRandRange(0.f, 360.f);
	const FVector Dir = FRotator(0.f, Yaw, 0.f).Vector();
	Controller->SetFocalPoint(Pawn->GetActorLocation() + Dir * 500.f, EAIFocusPriority::Gameplay);
}
