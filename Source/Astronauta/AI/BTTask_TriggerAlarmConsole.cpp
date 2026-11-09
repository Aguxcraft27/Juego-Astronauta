#include "AI/BTTask_TriggerAlarmConsole.h"
#include "AI/AlienAIController.h"
#include "AI/AlienAITypes.h"
#include "AI/AlienCharacter.h"
#include "Gameplay/AlarmConsole.h"
#include "Astronauta.h"
#include "BehaviorTree/BlackboardComponent.h"

UBTTask_TriggerAlarmConsole::UBTTask_TriggerAlarmConsole()
{
	NodeName = TEXT("Trigger Alarm Console");
	bNotifyTick = true;
}

uint16 UBTTask_TriggerAlarmConsole::GetInstanceMemorySize() const
{
	return sizeof(FTriggerMemory);
}

EBTNodeResult::Type UBTTask_TriggerAlarmConsole::ExecuteTask(UBehaviorTreeComponent& OwnerComp, uint8* NodeMemory)
{
	AAlienAIController* Controller = Cast<AAlienAIController>(OwnerComp.GetAIOwner());
	AAlienCharacter* Alien = Controller ? Cast<AAlienCharacter>(Controller->GetPawn()) : nullptr;
	const UBlackboardComponent* BB = OwnerComp.GetBlackboardComponent();
	const AAlarmConsole* Console = BB ? Cast<AAlarmConsole>(BB->GetValueAsObject(AlienBBKeys::TargetAlarmConsole)) : nullptr;
	if (!Controller || !Alien || !Console)
	{
		return EBTNodeResult::Failed;
	}

	const float Dist2D = FVector::Dist2D(Alien->GetActorLocation(), Console->GetInteractionLocation());
	if (Dist2D > Controller->AlarmInteractionRadius)
	{
		UE_LOG(LogAlienAI, Verbose, TEXT("%s: demasiado lejos de la consola (%.0f)."), *Controller->GetName(), Dist2D);
		return EBTNodeResult::Failed; // El BT repetirá el MoveTo.
	}

	Controller->SetFocalPoint(Console->GetActorLocation(), EAIFocusPriority::Gameplay);

	FTriggerMemory* Mem = reinterpret_cast<FTriggerMemory*>(NodeMemory);
	Mem->RemainingTime = Alien->ConsoleMontage ? Alien->PlayAnimMontage(Alien->ConsoleMontage) : 0.f;

	if (Mem->RemainingTime <= 0.f)
	{
		Complete(OwnerComp);
		return EBTNodeResult::Succeeded;
	}
	return EBTNodeResult::InProgress;
}

void UBTTask_TriggerAlarmConsole::TickTask(UBehaviorTreeComponent& OwnerComp, uint8* NodeMemory, float DeltaSeconds)
{
	FTriggerMemory* Mem = reinterpret_cast<FTriggerMemory*>(NodeMemory);
	Mem->RemainingTime -= DeltaSeconds;
	if (Mem->RemainingTime <= 0.f)
	{
		FinishLatentTask(OwnerComp, EBTNodeResult::Succeeded);
		Complete(OwnerComp);
	}
}

EBTNodeResult::Type UBTTask_TriggerAlarmConsole::AbortTask(UBehaviorTreeComponent& OwnerComp, uint8* NodeMemory)
{
	if (AAIController* Controller = OwnerComp.GetAIOwner())
	{
		Controller->ClearFocus(EAIFocusPriority::Gameplay);
		if (AAlienCharacter* Alien = Cast<AAlienCharacter>(Controller->GetPawn()); Alien && Alien->ConsoleMontage)
		{
			Alien->StopAnimMontage(Alien->ConsoleMontage);
		}
	}
	return EBTNodeResult::Aborted;
}

void UBTTask_TriggerAlarmConsole::Complete(UBehaviorTreeComponent& OwnerComp) const
{
	AAlienAIController* Controller = Cast<AAlienAIController>(OwnerComp.GetAIOwner());
	const UBlackboardComponent* BB = OwnerComp.GetBlackboardComponent();
	if (!Controller || !BB)
	{
		return;
	}
	Controller->ClearFocus(EAIFocusPriority::Gameplay);
	Controller->NotifyAlarmConsoleActivated(Cast<AAlarmConsole>(BB->GetValueAsObject(AlienBBKeys::TargetAlarmConsole)));
}
