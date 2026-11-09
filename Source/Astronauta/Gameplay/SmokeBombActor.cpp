#include "Gameplay/SmokeBombActor.h"
#include "Components/SphereComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Perception/AISense_Hearing.h"

ASmokeBombActor::ASmokeBombActor()
{
	PrimaryActorTick.bCanEverTick = false;

	CollisionSphere = CreateDefaultSubobject<USphereComponent>(TEXT("CollisionSphere"));
	SetRootComponent(CollisionSphere);
	CollisionSphere->SetSphereRadius(12.f);
	CollisionSphere->SetCollisionProfileName(TEXT("BlockAll"));
	CollisionSphere->SetSimulatePhysics(true);

	BombMesh = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("BombMesh"));
	BombMesh->SetupAttachment(CollisionSphere);
	BombMesh->SetCollisionEnabled(ECollisionEnabled::NoCollision);

	SmokeBlockerVolume = CreateDefaultSubobject<USphereComponent>(TEXT("SmokeBlockerVolume"));
	SmokeBlockerVolume->SetupAttachment(CollisionSphere);
	SmokeBlockerVolume->SetSphereRadius(SmokeRadius);
	SmokeBlockerVolume->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	SmokeBlockerVolume->SetCollisionResponseToAllChannels(ECR_Ignore);
	// Bloquear canal de visibilidad para que los traces de la IA no atraviesen la nube
	SmokeBlockerVolume->SetCollisionResponseToChannel(ECC_Visibility, ECR_Block);
}

void ASmokeBombActor::BeginPlay()
{
	Super::BeginPlay();

	GetWorld()->GetTimerManager().SetTimer(FuseTimerHandle, this, &ASmokeBombActor::DeploySmoke, FuseTime, false);
}

void ASmokeBombActor::DeploySmoke()
{
	if (bIsDeployed)
	{
		return;
	}
	bIsDeployed = true;

	GetWorld()->GetTimerManager().ClearTimer(FuseTimerHandle);

	// Detener físicas y activar volumen oclusor de visión
	CollisionSphere->SetSimulatePhysics(false);
	SmokeBlockerVolume->SetCollisionEnabled(ECollisionEnabled::QueryOnly);

	// Disparar VFX en Blueprint
	OnSmokeSpawnVisual(SmokeRadius, SmokeDuration);

	// Ruido de liberación de gas a presión
	UAISense_Hearing::ReportNoiseEvent(GetWorld(), GetActorLocation(), 0.7f, this, SmokeRadius * 1.5f);

	// Temporizador de duración de la nube
	GetWorld()->GetTimerManager().SetTimer(DurationTimerHandle, this, &ASmokeBombActor::OnSmokeEnd, SmokeDuration, false);
}

void ASmokeBombActor::OnSmokeEnd()
{
	SmokeBlockerVolume->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	OnSmokeCloudDispelled.Broadcast(GetActorLocation());
	Destroy();
}
