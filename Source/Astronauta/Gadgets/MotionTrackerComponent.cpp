#include "Gadgets/MotionTrackerComponent.h"
#include "GameFramework/Character.h"
#include "Kismet/GameplayStatics.h"
#include "Perception/AISense_Hearing.h"
#include "AI/AlienCharacter.h"

UMotionTrackerComponent::UMotionTrackerComponent()
{
	PrimaryComponentTick.bCanEverTick = true;
	PrimaryComponentTick.TickInterval = 0.05f; // Evaluación a 20 Hz
}

void UMotionTrackerComponent::BeginPlay()
{
	Super::BeginPlay();
	CurrentInterval = BasePingInterval;
}

void UMotionTrackerComponent::SetTrackerActive(bool bActive)
{
	if (bIsActive == bActive)
	{
		return;
	}

	bIsActive = bActive;
	PingTimer = 0.f;

	if (!bIsActive)
	{
		CurrentBlips.Empty();
		OnMotionTrackerUpdated.Broadcast(CurrentBlips);
	}
}

void UMotionTrackerComponent::TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction)
{
	Super::TickComponent(DeltaTime, TickType, ThisTickFunction);

	if (!bIsActive)
	{
		return;
	}

	PingTimer += DeltaTime;
	if (PingTimer >= CurrentInterval)
	{
		PingTimer = 0.f;
		ScanForMotion();
	}
}

void UMotionTrackerComponent::ScanForMotion()
{
	AActor* OwnerActor = GetOwner();
	if (!OwnerActor)
	{
		return;
	}

	const FVector TrackerLocation = OwnerActor->GetActorLocation();
	const FVector TrackerForward = OwnerActor->GetActorForwardVector();

	CurrentBlips.Reset();
	float ClosestDistance = MaxRange;

	// Buscar todos los personajes en el nivel (Aliens, NPCs, objetos en movimiento)
	TArray<AActor*> FoundCharacters;
	UGameplayStatics::GetAllActorsOfClass(GetWorld(), ACharacter::StaticClass(), FoundCharacters);

	for (AActor* Actor : FoundCharacters)
	{
		if (!Actor || Actor == OwnerActor)
		{
			continue;
		}

		const ACharacter* Char = Cast<ACharacter>(Actor);
		if (!Char)
		{
			continue;
		}

		// Filtrar por velocidad mínima de movimiento
		const float VelocitySize = Char->GetVelocity().Size();
		if (VelocitySize < MinTargetSpeedForDetection)
		{
			continue;
		}

		const FVector DirectionToTarget = (Char->GetActorLocation() - TrackerLocation);
		const float Distance = DirectionToTarget.Size();

		if (Distance > MaxRange)
		{
			continue;
		}

		const FVector DirNormalized = DirectionToTarget / Distance;
		const float DotForward = FVector::DotProduct(TrackerForward, DirNormalized);
		const float AngleDeg = FMath::RadiansToDegrees(FMath::Acos(FMath::Clamp(DotForward, -1.0f, 1.0f)));

		if (AngleDeg <= ConeHalfAngleDegrees)
		{
			// Calcular ángulo relativo (-1 a 1) usando el vector derecho
			const FVector TrackerRight = OwnerActor->GetActorRightVector();
			const float DotRight = FVector::DotProduct(TrackerRight, DirNormalized);

			FMotionTrackerBlip Blip;
			Blip.RawDistance = Distance;
			Blip.NormalizedDistance = FMath::Clamp(Distance / MaxRange, 0.0f, 1.0f);
			Blip.NormalizedAngle = DotRight; // -1 = izquierda, +1 = derecha
			Blip.bIsAlien = Char->IsA<AAlienCharacter>();

			CurrentBlips.Add(Blip);

			if (Distance < ClosestDistance)
			{
				ClosestDistance = Distance;
			}
		}
	}

	// Notificar actualización visual
	OnMotionTrackerUpdated.Broadcast(CurrentBlips);

	// Disparar ping acústico
	TriggerPing(ClosestDistance);
}

void UMotionTrackerComponent::TriggerPing(float ClosestDist)
{
	AActor* OwnerActor = GetOwner();
	if (!OwnerActor)
	{
		return;
	}

	OnMotionTrackerPing.Broadcast(ClosestDist);

	if (CurrentBlips.Num() > 0)
	{
		// Escalar frecuencia de pings según cercanía
		const float Alpha = FMath::Clamp(ClosestDist / MaxRange, 0.0f, 1.0f);
		CurrentInterval = FMath::Lerp(MinPingInterval, BasePingInterval, Alpha);

		// Peligro acústico: Si la amenaza está a corta distancia, el pitido emite sonido para la IA
		if (ClosestDist <= AcousticDangerDistance)
		{
			UAISense_Hearing::ReportNoiseEvent(
				GetWorld(),
				OwnerActor->GetActorLocation(),
				TrackerPingLoudness,
				OwnerActor,
				AcousticDangerDistance * 1.2f,
				FName(TEXT("MotionTrackerPing")) // AAlienAIController lo reconoce (+25 de sospecha)
			);
		}
	}
	else
	{
		CurrentInterval = BasePingInterval;
	}
}
