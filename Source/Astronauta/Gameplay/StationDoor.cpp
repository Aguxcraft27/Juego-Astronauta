#include "Gameplay/StationDoor.h"
#include "Gameplay/StationGameState.h"
#include "Components/StaticMeshComponent.h"
#include "Components/BoxComponent.h"
#include "NavModifierComponent.h"
#include "GameFramework/Pawn.h"
#include "NavAreas/NavArea_Default.h"
#include "NavAreas/NavArea_Null.h"

AStationDoor::AStationDoor()
{
	PrimaryActorTick.bCanEverTick = false;

	SceneRoot = CreateDefaultSubobject<USceneComponent>(TEXT("SceneRoot"));
	SetRootComponent(SceneRoot);

	DoorFrame = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("DoorFrame"));
	DoorFrame->SetupAttachment(SceneRoot);

	DoorPanelLeft = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("DoorPanelLeft"));
	DoorPanelLeft->SetupAttachment(SceneRoot);

	DoorPanelRight = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("DoorPanelRight"));
	DoorPanelRight->SetupAttachment(SceneRoot);

	TriggerBox = CreateDefaultSubobject<UBoxComponent>(TEXT("TriggerBox"));
	TriggerBox->SetupAttachment(SceneRoot);
	TriggerBox->SetBoxExtent(FVector(150.f, 150.f, 120.f));
	TriggerBox->SetCollisionProfileName(TEXT("Trigger"));

	NavModifier = CreateDefaultSubobject<UNavModifierComponent>(TEXT("NavModifier"));
	NavModifier->SetAreaClass(UNavArea_Default::StaticClass());
	// Volumen usado si los paneles no tienen colisión: cubre el hueco de la puerta.
	NavModifier->FailsafeExtent = FVector(60.f, 150.f, 120.f);
}

void AStationDoor::BeginPlay()
{
	Super::BeginPlay();

	TriggerBox->OnComponentBeginOverlap.AddDynamic(this, &AStationDoor::OnOverlapBegin);
	TriggerBox->OnComponentEndOverlap.AddDynamic(this, &AStationDoor::OnOverlapEnd);

	if (AStationGameState* GS = GetWorld()->GetGameState<AStationGameState>())
	{
		GS->OnRedAlert.AddUniqueDynamic(this, &AStationDoor::HandleRedAlert);
		if (GS->IsAlarmTriggered() && bLocksOnRedAlert)
		{
			SetDoorState(EStationDoorState::LockedDown);
		}
	}
}

void AStationDoor::HandleRedAlert(AActor* AlarmInstigator)
{
	if (bLocksOnRedAlert)
	{
		SetDoorState(EStationDoorState::LockedDown);
	}
}

void AStationDoor::OpenDoor()
{
	if (DoorState != EStationDoorState::LockedDown)
	{
		SetDoorState(EStationDoorState::Open);
	}
}

void AStationDoor::CloseDoor()
{
	if (DoorState != EStationDoorState::LockedDown)
	{
		SetDoorState(EStationDoorState::Closed);
	}
}

void AStationDoor::SetDoorState(EStationDoorState NewState)
{
	if (DoorState == NewState)
	{
		return;
	}

	DoorState = NewState;
	UpdateNavArea();
	OnDoorVisualStateChanged(NewState);
}

void AStationDoor::OnOverlapBegin(UPrimitiveComponent* OverlappedComp, AActor* OtherActor,
	UPrimitiveComponent* OtherComp, int32 OtherBodyIndex, bool bFromSweep, const FHitResult& SweepResult)
{
	// Solo Pawns (jugador / aliens): ni cadáveres arrastrados ni objetos físicos abren la puerta.
	if (!Cast<APawn>(OtherActor))
	{
		return;
	}

	OverlappingActorsCount++;
	if (DoorState != EStationDoorState::LockedDown)
	{
		OpenDoor();
	}
}

void AStationDoor::OnOverlapEnd(UPrimitiveComponent* OverlappedComp, AActor* OtherActor,
	UPrimitiveComponent* OtherComp, int32 OtherBodyIndex)
{
	if (!Cast<APawn>(OtherActor))
	{
		return;
	}

	OverlappingActorsCount = FMath::Max(0, OverlappingActorsCount - 1);
	if (OverlappingActorsCount == 0 && DoorState != EStationDoorState::LockedDown)
	{
		CloseDoor();
	}
}

void AStationDoor::UpdateNavArea()
{
	if (NavModifier)
	{
		NavModifier->SetAreaClass(DoorState == EStationDoorState::LockedDown
			? TSubclassOf<UNavAreaBase>(UNavArea_Null::StaticClass())
			: TSubclassOf<UNavAreaBase>(UNavArea_Default::StaticClass()));
	}
}
