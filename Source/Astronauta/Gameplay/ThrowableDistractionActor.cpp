#include "Gameplay/ThrowableDistractionActor.h"
#include "Astronauta.h"
#include "Components/StaticMeshComponent.h"
#include "Engine/World.h"
#include "GameFramework/Pawn.h"
#include "Perception/AISense_Hearing.h"

AThrowableDistractionActor::AThrowableDistractionActor()
{
	PrimaryActorTick.bCanEverTick = true;
	PrimaryActorTick.TickGroup = TG_PostPhysics;

	Mesh = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Mesh"));
	RootComponent = Mesh;
	Mesh->SetCollisionProfileName(TEXT("PhysicsActor"));
	Mesh->SetSimulatePhysics(true);
	Mesh->SetNotifyRigidBodyCollision(true); // necesario para OnComponentHit con física
}

void AThrowableDistractionActor::BeginPlay()
{
	Super::BeginPlay();
	Mesh->OnComponentHit.AddDynamic(this, &AThrowableDistractionActor::HandleHit);
}

void AThrowableDistractionActor::Tick(float DeltaSeconds)
{
	Super::Tick(DeltaSeconds);
	PreviousVelocity = Mesh->GetPhysicsLinearVelocity();
}

void AThrowableDistractionActor::Launch(const FVector& Velocity, APawn* Thrower)
{
	SetInstigator(Thrower);
	if (Thrower)
	{
		Mesh->IgnoreActorWhenMoving(Thrower, true);
	}
	Mesh->SetPhysicsLinearVelocity(Velocity);
	PreviousVelocity = Velocity;
}

void AThrowableDistractionActor::HandleHit(UPrimitiveComponent* HitComp, AActor* OtherActor, UPrimitiveComponent* OtherComp,
	FVector NormalImpulse, const FHitResult& Hit)
{
	if (OtherActor && OtherActor == GetInstigator())
	{
		return;
	}

	const UWorld* World = GetWorld();
	const float Now = World ? World->GetTimeSeconds() : 0.f;
	if (Now - LastNoiseTime < NoiseCooldown)
	{
		return;
	}

	// Velocidad de impacto = la mayor entre la del frame previo y la actual (por si el tick aún no corrió).
	const float ImpactSpeed = FMath::Max(PreviousVelocity.Size(), Mesh->GetPhysicsLinearVelocity().Size());
	if (ImpactSpeed < MinImpactSpeed)
	{
		return;
	}

	// Energía cinética en unidades SI: masa (kg), velocidad uu/s -> m/s.
	const float SpeedMS = ImpactSpeed / 100.f;
	const float Energy = 0.5f * Mesh->GetMass() * SpeedMS * SpeedMS;
	const float Loudness = FMath::Clamp(Energy / FMath::Max(ReferenceImpactEnergy, KINDA_SMALL_NUMBER), 0.f, MaxLoudness);
	if (Loudness <= KINDA_SMALL_NUMBER)
	{
		return;
	}

	LastNoiseTime = Now;
	const FVector Location = Hit.ImpactPoint.IsNearlyZero() ? GetActorLocation() : FVector(Hit.ImpactPoint);
	// El instigador del ruido es el propio objeto: los aliens van hacia aquí, no hacia quien lo lanzó.
	UAISense_Hearing::ReportNoiseEvent(this, Location, Loudness, this, BaseNoiseRange * Loudness);
	UE_LOG(LogAlienAI, Verbose, TEXT("%s: impacto %.0f uu/s, energía %.1f J, volumen %.2f"), *GetName(), ImpactSpeed, Energy, Loudness);
	OnNoisyImpact(Loudness, Location);
}
