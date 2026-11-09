#include "Gameplay/BloodDropActor.h"
#include "Components/DecalComponent.h"
#include "Perception/AIPerceptionStimuliSourceComponent.h"
#include "Perception/AISense_Sight.h"
#include "TimerManager.h"
#include "Engine/World.h"

ABloodDropActor::ABloodDropActor()
{
	PrimaryActorTick.bCanEverTick = false;

	RootComponent = CreateDefaultSubobject<USceneComponent>(TEXT("Root"));

	Decal = CreateDefaultSubobject<UDecalComponent>(TEXT("Decal"));
	Decal->SetupAttachment(RootComponent);
	Decal->DecalSize = FVector(8.f, 20.f, 20.f);
	Decal->SetRelativeRotation(FRotator(-90.f, 0.f, 0.f)); // proyecta hacia el suelo

	StimuliSource = CreateDefaultSubobject<UAIPerceptionStimuliSourceComponent>(TEXT("StimuliSource"));
	StimuliSource->bAutoRegister = false;
}

void ABloodDropActor::BeginPlay()
{
	Super::BeginPlay();
	Tags.AddUnique(BloodTag);
	StimuliSource->RegisterForSense(UAISense_Sight::StaticClass());
	StimuliSource->RegisterWithPerceptionSystem();
	SetLifeSpan(TotalLifeSpan);
	GetWorldTimerManager().SetTimer(DryTimer, this, &ABloodDropActor::Dry, FreshDuration, false);
}

void ABloodDropActor::Dry()
{
	bFresh = false;
	Tags.Remove(BloodTag);
	StimuliSource->UnregisterFromPerceptionSystem();
	OnDried();
}
