#include "Gameplay/HidingSpot.h"
#include "Gameplay/CorpseActor.h"
#include "Player/AstronautaCharacter.h"
#include "AI/AlienAIController.h"
#include "Astronauta.h"
#include "Components/BoxComponent.h"
#include "Components/StaticMeshComponent.h"
#include "EngineUtils.h"
#include "Gameplay/StationAlarmSubsystem.h"

AHidingSpot::AHidingSpot()
{
	PrimaryActorTick.bCanEverTick = false;

	Mesh = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Mesh"));
	RootComponent = Mesh;
	Mesh->SetCollisionProfileName(TEXT("BlockAll")); // bloquea Visibility: corta la LOS de los aliens

	InteractionVolume = CreateDefaultSubobject<UBoxComponent>(TEXT("InteractionVolume"));
	InteractionVolume->SetupAttachment(Mesh);
	InteractionVolume->SetBoxExtent(FVector(120.f, 100.f, 100.f));
	InteractionVolume->SetRelativeLocation(FVector(100.f, 0.f, 100.f));
	InteractionVolume->SetCollisionProfileName(TEXT("Trigger"));

	HidePoint = CreateDefaultSubobject<USceneComponent>(TEXT("HidePoint"));
	HidePoint->SetupAttachment(Mesh);
	HidePoint->SetRelativeLocation(FVector(0.f, 0.f, 100.f));

	ExitPoint = CreateDefaultSubobject<USceneComponent>(TEXT("ExitPoint"));
	ExitPoint->SetupAttachment(Mesh);
	ExitPoint->SetRelativeLocation(FVector(120.f, 0.f, 100.f));
}

void AHidingSpot::BeginPlay()
{
	Super::BeginPlay();
	if (UStationAlarmSubsystem* Subsystem = GetWorld()->GetSubsystem<UStationAlarmSubsystem>())
	{
		Subsystem->RegisterHidingSpot(this);
	}
}

void AHidingSpot::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
	if (UStationAlarmSubsystem* Subsystem = GetWorld()->GetSubsystem<UStationAlarmSubsystem>())
	{
		Subsystem->UnregisterHidingSpot(this);
	}
	Super::EndPlay(EndPlayReason);
}

FVector AHidingSpot::GetExitLocation() const
{
	return ExitPoint->GetComponentLocation();
}

bool AHidingSpot::EnterHidingSpot(AAstronautaCharacter* Player)
{
	if (!Player || Occupant.IsValid() || Player->IsHiddenInSpot())
	{
		return false;
	}

	// Regla de IA: los aliens que lo están persiguiendo con LOS lo ven entrar y vienen a abrir.
	// Se evalúa ANTES de esconderlo, mientras la percepción todavía lo tiene a la vista.
	for (TActorIterator<AAlienAIController> It(GetWorld()); It; ++It)
	{
		It->NotifyPlayerEnteringHidingSpot(Player, this);
	}

	Occupant = Player;
	Player->EnterHiding(this, HidePoint->GetComponentTransform());
	OnPlayerEntered.Broadcast(this, Player);
	return true;
}

void AHidingSpot::ExitHidingSpot()
{
	AAstronautaCharacter* Player = Occupant.Get();
	if (!Player)
	{
		return;
	}
	Occupant = nullptr;
	Player->ExitHiding(ExitPoint->GetComponentTransform());
	OnPlayerExited.Broadcast(this, Player);
}

void AHidingSpot::ForceOpen(AActor* OpenedBy)
{
	UE_LOG(LogAlienAI, Warning, TEXT("%s forzó %s"), *GetNameSafe(OpenedBy), *GetName());
	OnForcedOpen(OpenedBy);
	ExitHidingSpot();
}

bool AHidingSpot::StoreCorpse(ACorpseActor* Corpse)
{
	StoredCorpses.RemoveAll([](const TWeakObjectPtr<ACorpseActor>& C) { return !C.IsValid(); });
	if (!Corpse || StoredCorpses.Num() >= MaxStoredCorpses || StoredCorpses.Contains(Corpse))
	{
		return false;
	}

	Corpse->SetBeingDragged(false);
	Corpse->SetHiddenFromSight(true);
	if (UPrimitiveComponent* Root = Cast<UPrimitiveComponent>(Corpse->GetRootComponent()))
	{
		Root->SetSimulatePhysics(false);
	}
	Corpse->SetActorEnableCollision(false);
	Corpse->SetActorHiddenInGame(true);
	Corpse->SetActorLocation(HidePoint->GetComponentLocation(), false, nullptr, ETeleportType::TeleportPhysics);

	StoredCorpses.Add(Corpse);
	return true;
}
