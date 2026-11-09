#include "Gameplay/CorpseActor.h"
#include "Components/SkeletalMeshComponent.h"
#include "Perception/AIPerceptionStimuliSourceComponent.h"
#include "Perception/AISense_Sight.h"

ACorpseActor::ACorpseActor()
{
	PrimaryActorTick.bCanEverTick = false;

	MeshComponent = CreateDefaultSubobject<USkeletalMeshComponent>(TEXT("MeshComponent"));
	SetRootComponent(MeshComponent);

	MeshComponent->SetCollisionProfileName(TEXT("Ragdoll"));
	MeshComponent->SetSimulatePhysics(true);
	MeshComponent->SetGenerateOverlapEvents(true);

	StimuliSource = CreateDefaultSubobject<UAIPerceptionStimuliSourceComponent>(TEXT("StimuliSource"));
	StimuliSource->RegisterForSense(UAISense_Sight::StaticClass());
	StimuliSource->bAutoRegister = true;

	Tags.AddUnique(CorpseIdentificationTag);
}

void ACorpseActor::BeginPlay()
{
	Super::BeginPlay();
	// Por si CorpseIdentificationTag se cambió en la instancia después del constructor.
	Tags.AddUnique(CorpseIdentificationTag);

	if (StimuliSource)
	{
		StimuliSource->RegisterWithPerceptionSystem();
	}
}

void ACorpseActor::OnConstruction(const FTransform& Transform)
{
	Super::OnConstruction(Transform);
	Tags.AddUnique(CorpseIdentificationTag);
}

void ACorpseActor::SetBeingDragged(bool bDragged, AActor* DraggingInstigator)
{
	if (bIsBeingDragged == bDragged)
	{
		return;
	}

	bIsBeingDragged = bDragged;
	CurrentDragger = DraggingInstigator;

	if (bIsBeingDragged)
	{
		OnCorpseDisturbed.Broadcast(this);
	}
}

void ACorpseActor::SetHiddenFromSight(bool bHidden)
{
	if (bIsHidden == bHidden)
	{
		return;
	}

	bIsHidden = bHidden;

	if (StimuliSource)
	{
		if (bIsHidden)
		{
			StimuliSource->UnregisterFromSense(UAISense_Sight::StaticClass());
		}
		else
		{
			StimuliSource->RegisterForSense(UAISense_Sight::StaticClass());
			StimuliSource->RegisterWithPerceptionSystem();
		}
	}
}
