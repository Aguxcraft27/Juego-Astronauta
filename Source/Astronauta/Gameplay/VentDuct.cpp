#include "Gameplay/VentDuct.h"
#include "Gameplay/StationAlarmSubsystem.h"
#include "Player/AstronautaCharacter.h"
#include "AI/AlienAIController.h"
#include "Components/BoxComponent.h"
#include "EngineUtils.h"

AVentDuct::AVentDuct()
{
	PrimaryActorTick.bCanEverTick = false;

	DuctVolume = CreateDefaultSubobject<UBoxComponent>(TEXT("DuctVolume"));
	RootComponent = DuctVolume;
	DuctVolume->SetBoxExtent(FVector(300.f, 60.f, 50.f));
	DuctVolume->SetCollisionProfileName(TEXT("Trigger"));
	DuctVolume->SetCanEverAffectNavigation(false);

	Exits = { FVector(-350.f, 0.f, 0.f), FVector(350.f, 0.f, 0.f) };
}

void AVentDuct::BeginPlay()
{
	Super::BeginPlay();
	DuctVolume->OnComponentBeginOverlap.AddDynamic(this, &AVentDuct::OnDuctBeginOverlap);
	DuctVolume->OnComponentEndOverlap.AddDynamic(this, &AVentDuct::OnDuctEndOverlap);
	if (UStationAlarmSubsystem* Subsystem = GetWorld()->GetSubsystem<UStationAlarmSubsystem>())
	{
		Subsystem->RegisterVentDuct(this);
	}
}

void AVentDuct::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
	if (UStationAlarmSubsystem* Subsystem = GetWorld()->GetSubsystem<UStationAlarmSubsystem>())
	{
		Subsystem->UnregisterVentDuct(this);
	}
	Super::EndPlay(EndPlayReason);
}

TArray<FVector> AVentDuct::GetWorldExits() const
{
	TArray<FVector> World;
	World.Reserve(Exits.Num());
	for (const FVector& Local : Exits)
	{
		World.Add(GetActorTransform().TransformPosition(Local));
	}
	return World;
}

void AVentDuct::OnDuctBeginOverlap(UPrimitiveComponent* OverlappedComp, AActor* OtherActor,
	UPrimitiveComponent* OtherComp, int32 OtherBodyIndex, bool bFromSweep, const FHitResult& SweepResult)
{
	AAstronautaCharacter* Player = Cast<AAstronautaCharacter>(OtherActor);
	if (!Player || Player->IsInVentDuct())
	{
		return;
	}

	// Avisar antes de marcarlo dentro: los aliens que aún lo tienen a la vista lo ven entrar.
	for (TActorIterator<AAlienAIController> It(GetWorld()); It; ++It)
	{
		It->NotifyPlayerEnteredVentDuct(Player, this);
	}
	Player->SetInVentDuct(this);
}

void AVentDuct::OnDuctEndOverlap(UPrimitiveComponent* OverlappedComp, AActor* OtherActor,
	UPrimitiveComponent* OtherComp, int32 OtherBodyIndex)
{
	AAstronautaCharacter* Player = Cast<AAstronautaCharacter>(OtherActor);
	if (Player && Player->IsInVentDuct())
	{
		Player->SetInVentDuct(nullptr);
	}
}
