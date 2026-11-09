#include "Gameplay/ChokepointMarker.h"
#include "Gameplay/StationAlarmSubsystem.h"
#include "Components/BillboardComponent.h"
#include "Components/SphereComponent.h"
#include "Engine/World.h"

AChokepointMarker::AChokepointMarker()
{
	PrimaryActorTick.bCanEverTick = false;

	Area = CreateDefaultSubobject<USphereComponent>(TEXT("Area"));
	Area->InitSphereRadius(150.f);
	Area->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	Area->ShapeColor = FColor::Orange;
	Area->SetHiddenInGame(true);
	RootComponent = Area;

#if WITH_EDITORONLY_DATA
	Billboard = CreateEditorOnlyDefaultSubobject<UBillboardComponent>(TEXT("Billboard"));
	if (Billboard)
	{
		Billboard->SetupAttachment(Area);
	}
#endif
}

void AChokepointMarker::BeginPlay()
{
	Super::BeginPlay();
	if (UStationAlarmSubsystem* Subsystem = GetWorld()->GetSubsystem<UStationAlarmSubsystem>())
	{
		Subsystem->RegisterChokepoint(this);
	}
}

void AChokepointMarker::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
	if (UStationAlarmSubsystem* Subsystem = GetWorld()->GetSubsystem<UStationAlarmSubsystem>())
	{
		Subsystem->UnregisterChokepoint(this);
	}
	Super::EndPlay(EndPlayReason);
}
