#include "Gameplay/EMPMineActor.h"
#include "Components/SphereComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Kismet/GameplayStatics.h"
#include "Perception/AISense_Hearing.h"
#include "AI/AlienCharacter.h"
#include "Gameplay/StationDoor.h"

AEMPMineActor::AEMPMineActor()
{
	PrimaryActorTick.bCanEverTick = false;

	CollisionSphere = CreateDefaultSubobject<USphereComponent>(TEXT("CollisionSphere"));
	SetRootComponent(CollisionSphere);
	CollisionSphere->SetSphereRadius(15.f);
	CollisionSphere->SetCollisionProfileName(TEXT("BlockAll"));

	MineMesh = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("MineMesh"));
	MineMesh->SetupAttachment(CollisionSphere);
	MineMesh->SetCollisionEnabled(ECollisionEnabled::NoCollision);

	TriggerVolume = CreateDefaultSubobject<USphereComponent>(TEXT("TriggerVolume"));
	TriggerVolume->SetupAttachment(CollisionSphere);
	TriggerVolume->SetSphereRadius(TriggerRadius);
	TriggerVolume->SetCollisionProfileName(TEXT("Trigger"));
}

void AEMPMineActor::BeginPlay()
{
	Super::BeginPlay();

	TriggerVolume->OnComponentBeginOverlap.AddDynamic(this, &AEMPMineActor::OnProximityOverlap);

	// Armar automáticamente tras 1.5 segundos
	GetWorld()->GetTimerManager().SetTimer(ArmTimerHandle, this, &AEMPMineActor::ArmMine, 1.5f, false);
}

void AEMPMineActor::ArmMine()
{
	bIsArmed = true;
	OnMineArmedVisual();
}

void AEMPMineActor::OnProximityOverlap(UPrimitiveComponent* OverlappedComp, AActor* OtherActor,
	UPrimitiveComponent* OtherComp, int32 OtherBodyIndex, bool bFromSweep, const FHitResult& SweepResult)
{
	if (!bIsArmed || !OtherActor || OtherActor == this)
	{
		return;
	}

	// Detonar si un alien entra en el radio
	if (OtherActor->IsA<AAlienCharacter>())
	{
		Detonate();
	}
}

void AEMPMineActor::Detonate()
{
	if (!bIsArmed)
	{
		return;
	}
	bIsArmed = false;

	const FVector BlastLocation = GetActorLocation();

	// Efectos visuales en Blueprint
	OnDetonationVisual();
	OnEMPMineDetonated.Broadcast(BlastLocation);

	// Ruido de la explosión eléctrica
	UAISense_Hearing::ReportNoiseEvent(GetWorld(), BlastLocation, 1.5f, this, BlastRadius * 2.f);

	// Afectar actores en el radio de explosión
	TArray<FOverlapResult> Overlaps;
	FCollisionShape SphereShape = FCollisionShape::MakeSphere(BlastRadius);
	FCollisionQueryParams QueryParams;
	QueryParams.AddIgnoredActor(this);

	GetWorld()->OverlapMultiByChannel(Overlaps, BlastLocation, FQuat::Identity, ECC_WorldDynamic, SphereShape, QueryParams);

	for (const FOverlapResult& Overlap : Overlaps)
	{
		AActor* HitActor = Overlap.GetActor();
		if (!HitActor)
		{
			continue;
		}

		// Aturdir alienígenas
		if (AAlienCharacter* Alien = Cast<AAlienCharacter>(HitActor))
		{
			// Evento de aturdimiento en el alien
			Alien->TakeDamage(10.f, FDamageEvent(), nullptr, this);
		}
		// Sobrecargar compuertas de seguridad
		else if (AStationDoor* Door = Cast<AStationDoor>(HitActor))
		{
			if (Door->IsLocked())
			{
				Door->OpenDoor();
			}
		}
	}

	SetLifeSpan(0.2f);
}
