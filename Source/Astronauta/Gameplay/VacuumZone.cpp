#include "Gameplay/VacuumZone.h"
#include "Gameplay/HealthComponent.h"
#include "Components/BoxComponent.h"

AVacuumZone::AVacuumZone()
{
	PrimaryActorTick.bCanEverTick = false;
	Volume = CreateDefaultSubobject<UBoxComponent>(TEXT("Volume"));
	RootComponent = Volume;
	Volume->SetBoxExtent(FVector(300.f));
	Volume->SetCollisionProfileName(TEXT("OverlapAllDynamic"));
	Volume->SetGenerateOverlapEvents(true);
}

void AVacuumZone::BeginPlay()
{
	Super::BeginPlay();
	Volume->OnComponentBeginOverlap.AddDynamic(this, &AVacuumZone::OnBeginOverlap);
	Volume->OnComponentEndOverlap.AddDynamic(this, &AVacuumZone::OnEndOverlap);
}

void AVacuumZone::SetActorInVacuum(AActor* Actor, bool bInside)
{
	UHealthComponent* Health = Actor ? Actor->FindComponentByClass<UHealthComponent>() : nullptr;
	if (!Health)
	{
		return;
	}
	if (bInside && !Affected.Contains(Actor))
	{
		Affected.Add(Actor);
		Health->EnterVacuum();
	}
	else if (!bInside && Affected.Remove(Actor) > 0)
	{
		Health->ExitVacuum();
	}
}

void AVacuumZone::OnBeginOverlap(UPrimitiveComponent*, AActor* OtherActor, UPrimitiveComponent*, int32, bool, const FHitResult&)
{
	if (bVacuumActive)
	{
		SetActorInVacuum(OtherActor, true);
	}
}

void AVacuumZone::OnEndOverlap(UPrimitiveComponent*, AActor* OtherActor, UPrimitiveComponent*, int32)
{
	SetActorInVacuum(OtherActor, false);
}

void AVacuumZone::SetVacuumActive(bool bActive)
{
	if (bVacuumActive == bActive)
	{
		return;
	}
	bVacuumActive = bActive;

	if (!bActive)
	{
		TArray<TWeakObjectPtr<AActor>> Current = Affected.Array();
		for (const TWeakObjectPtr<AActor>& A : Current)
		{
			SetActorInVacuum(A.Get(), false);
		}
		Affected.Empty();
	}
	else
	{
		TArray<AActor*> Inside;
		Volume->GetOverlappingActors(Inside);
		for (AActor* A : Inside)
		{
			SetActorInVacuum(A, true);
		}
	}
}
