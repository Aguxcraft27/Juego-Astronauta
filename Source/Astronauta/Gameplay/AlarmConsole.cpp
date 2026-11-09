#include "Gameplay/AlarmConsole.h"
#include "Gameplay/StationAlarmSubsystem.h"
#include "Gameplay/StationGameState.h"
#include "Components/StaticMeshComponent.h"
#include "Engine/World.h"

AAlarmConsole::AAlarmConsole()
{
	PrimaryActorTick.bCanEverTick = false;
	Mesh = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Mesh"));
	RootComponent = Mesh;
	InteractionPoint = CreateDefaultSubobject<USceneComponent>(TEXT("InteractionPoint"));
	InteractionPoint->SetupAttachment(Mesh);
	InteractionPoint->SetRelativeLocation(FVector(100.f, 0.f, 0.f));
}

void AAlarmConsole::BeginPlay()
{
	Super::BeginPlay();
	if (UStationAlarmSubsystem* Subsystem = GetWorld()->GetSubsystem<UStationAlarmSubsystem>())
	{
		Subsystem->RegisterConsole(this);
	}
}

void AAlarmConsole::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
	if (UStationAlarmSubsystem* Subsystem = GetWorld()->GetSubsystem<UStationAlarmSubsystem>())
	{
		Subsystem->UnregisterConsole(this);
	}
	Super::EndPlay(EndPlayReason);
}

FVector AAlarmConsole::GetInteractionLocation() const
{
	return InteractionPoint->GetComponentLocation();
}

void AAlarmConsole::ActivateAlarm(AActor* ActivatedBy)
{
	if (AStationGameState* GS = GetWorld()->GetGameState<AStationGameState>())
	{
		GS->TriggerRedAlert(ActivatedBy);
	}
	OnAlarmActivated(ActivatedBy);
}
