#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "MotionTrackerComponent.generated.h"

USTRUCT(BlueprintType)
struct ASTRONAUTA_API FMotionTrackerBlip
{
	GENERATED_BODY()

	/** Ángulo relativo respecto al frente del jugador (-1.0 = izquierda extrema, 0.0 = frente, 1.0 = derecha extrema). */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Motion Tracker")
	float NormalizedAngle = 0.f;

	/** Distancia normalizada [0.0 = contacto inmediato, 1.0 = alcance máximo]. */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Motion Tracker")
	float NormalizedDistance = 0.f;

	/** Distancia real en unidades de Unreal. */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Motion Tracker")
	float RawDistance = 0.f;

	/** Indica si el objetivo detectado es un alienígena o una amenaza hostil. */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Motion Tracker")
	bool bIsAlien = true;
};

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnMotionTrackerUpdated, const TArray<FMotionTrackerBlip>&, Blips);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnMotionTrackerPing, float, ClosestDistance);

/**
 * Detector de movimiento de mano / muñeca para el astronauta.
 * Rastrea movimiento en un cono frontal de 180°.
 * A corta distancia, el pitido acústico puede ser escuchado por el alienígena.
 */
UCLASS(ClassGroup = (Custom), meta = (BlueprintSpawnableComponent))
class ASTRONAUTA_API UMotionTrackerComponent : public UActorComponent
{
	GENERATED_BODY()

public:
	UMotionTrackerComponent();

	virtual void TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction) override;

	UFUNCTION(BlueprintCallable, Category = "Astronauta|Motion Tracker")
	void SetTrackerActive(bool bActive);

	UFUNCTION(BlueprintCallable, Category = "Astronauta|Motion Tracker")
	void ToggleTracker() { SetTrackerActive(!bIsActive); }

	UFUNCTION(BlueprintPure, Category = "Astronauta|Motion Tracker")
	bool IsTrackerActive() const { return bIsActive; }

	// --- Parámetros de Detección ---
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Motion Tracker")
	float MaxRange = 2500.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Motion Tracker")
	float ConeHalfAngleDegrees = 90.f; // Cono frontal completo de 180°

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Motion Tracker")
	float MinTargetSpeedForDetection = 40.f;

	/** Segundos entre escaneos acústicos cuando no hay amenazas detectadas. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Motion Tracker")
	float BasePingInterval = 1.2f;

	/** Segundos mínimos entre pings cuando la amenaza está muy cerca. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Motion Tracker")
	float MinPingInterval = 0.25f;

	/** Distancia bajo la cual el pitido del tracker emite ruido audible para la IA. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Motion Tracker|Stealth")
	float AcousticDangerDistance = 450.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Motion Tracker|Stealth")
	float TrackerPingLoudness = 0.5f;

	UPROPERTY(BlueprintAssignable, Category = "Motion Tracker")
	FOnMotionTrackerUpdated OnMotionTrackerUpdated;

	UPROPERTY(BlueprintAssignable, Category = "Motion Tracker")
	FOnMotionTrackerPing OnMotionTrackerPing;

protected:
	virtual void BeginPlay() override;

	UPROPERTY(VisibleInstanceOnly, BlueprintReadOnly, Category = "Motion Tracker")
	bool bIsActive = false;

	UPROPERTY(VisibleInstanceOnly, BlueprintReadOnly, Category = "Motion Tracker")
	TArray<FMotionTrackerBlip> CurrentBlips;

private:
	void ScanForMotion();
	void TriggerPing(float ClosestDist);

	float PingTimer = 0.f;
	float CurrentInterval = 1.2f;
};
