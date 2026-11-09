#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "ThrowableDistractionActor.generated.h"

class UStaticMeshComponent;

/**
 * Lata / herramienta que el jugador lanza para desviar aliens.
 * Al chocar por encima de MinImpactSpeed emite un ruido (UAISense_Hearing) proporcional a la energía cinética.
 * Los aliens en Patrullar/Investigar acuden; en CorrerHaciaAlarma lo ignoran (lo filtra AAlienAIController).
 */
UCLASS()
class ASTRONAUTA_API AThrowableDistractionActor : public AActor
{
	GENERATED_BODY()

public:
	AThrowableDistractionActor();

	virtual void Tick(float DeltaSeconds) override;

	/** Lanza el objeto con la velocidad dada (uu/s). Thrower queda como Instigator. */
	UFUNCTION(BlueprintCallable, Category = "Distraction")
	void Launch(const FVector& Velocity, APawn* Thrower);

	/** Velocidad mínima de impacto (uu/s) para hacer ruido. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Distraction")
	float MinImpactSpeed = 300.f;

	/** Energía (julios, con masa en kg y velocidad en m/s) que equivale a Loudness 1.0. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Distraction")
	float ReferenceImpactEnergy = 20.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Distraction")
	float MaxLoudness = 2.f;

	/** Alcance del ruido con Loudness 1.0; escala linealmente con el volumen. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Distraction")
	float BaseNoiseRange = 1500.f;

	/** Evita ráfagas de ruidos al rebotar varias veces seguidas. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Distraction")
	float NoiseCooldown = 0.3f;

	/** Gancho para el sonido real del impacto (volumen 0..MaxLoudness). */
	UFUNCTION(BlueprintImplementableEvent, Category = "Distraction")
	void OnNoisyImpact(float Loudness, const FVector& ImpactLocation);

protected:
	virtual void BeginPlay() override;

	UFUNCTION()
	void HandleHit(UPrimitiveComponent* HitComp, AActor* OtherActor, UPrimitiveComponent* OtherComp,
		FVector NormalImpulse, const FHitResult& Hit);

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
	TObjectPtr<UStaticMeshComponent> Mesh;

private:
	/** Velocidad del frame anterior: en OnComponentHit la física ya ha aplicado el rebote. */
	FVector PreviousVelocity = FVector::ZeroVector;
	float LastNoiseTime = -1000.f;
};
