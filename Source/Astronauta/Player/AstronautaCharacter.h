#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Character.h"
#include "AI/StealthTarget.h"
#include "AstronautaCharacter.generated.h"

class AHidingSpot;
class AThrowableDistractionActor;
class AVentDuct;
class AVentGrate;
class USpotLightComponent;
class UInventoryComponent;
class UCraftingComponent;
class UHealthComponent;
class UMotionTrackerComponent;

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnFlashlightToggled, bool, bIsOn);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnCamouflageBatteryUpdated, float, Percent);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnThrowableCountChanged, int32, Remaining);

/**
 * Clase base del jugador. Implementa IStealthTarget (correr, camuflaje, multiplicador de ruido)
 * y emite pasos audibles para la IA con UAISense_Hearing::ReportNoiseEvent.
 * El input se conecta en el Blueprint hijo (Enhanced Input) llamando a las funciones BlueprintCallable.
 */
UCLASS()
class ASTRONAUTA_API AAstronautaCharacter : public ACharacter, public IStealthTarget
{
	GENERATED_BODY()

public:
	AAstronautaCharacter();

	virtual void Tick(float DeltaSeconds) override;

	// --- Acciones (llamar desde input) ---
	UFUNCTION(BlueprintCallable, Category = "Astronauta|Movement")
	void StartSprint();
	UFUNCTION(BlueprintCallable, Category = "Astronauta|Movement")
	void StopSprint();
	UFUNCTION(BlueprintCallable, Category = "Astronauta|Movement")
	void ToggleCrouch();
	UFUNCTION(BlueprintCallable, Category = "Astronauta|Stealth")
	void SetCamouflageActive(bool bActive);
	UFUNCTION(BlueprintCallable, Category = "Astronauta|Stealth")
	void ToggleCamouflage() { SetCamouflageActive(!bCamouflageActive); }

	/** Para ruidos puntuales (objetos que caen, golpes...). Loudness ya multiplicado por superficie. */
	UFUNCTION(BlueprintCallable, Category = "Astronauta|Stealth")
	void EmitNoise(float Loudness, float MaxRange);

	// --- Escondites ---
	/** Entra al escondite que tenga delante o sale del actual. */
	UFUNCTION(BlueprintCallable, Category = "Astronauta|Hiding")
	void InteractHidingSpot();

	UFUNCTION(BlueprintPure, Category = "Astronauta|Hiding")
	bool IsHiddenInSpot() const { return CurrentHidingSpot.IsValid(); }

	/** Los llama AHidingSpot; no usar directamente. */
	void EnterHiding(AHidingSpot* Spot, const FTransform& HideTransform);
	void ExitHiding(const FTransform& ExitTransform);

	// --- Linterna ---
	UFUNCTION(BlueprintCallable, Category = "Astronauta|Flashlight")
	void ToggleFlashlight();

	UFUNCTION(BlueprintCallable, Category = "Astronauta|Flashlight")
	void SetFlashlightOn(bool bOn);

	UFUNCTION(BlueprintPure, Category = "Astronauta|Flashlight")
	bool IsFlashlightOn() const;

	/** Alcance máximo con el que la linterna delata al jugador si alumbra a un alien. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Astronauta|Flashlight")
	float FlashlightRange = 1500.f;

	// --- Detector de Movimiento e Inventario ---
	UFUNCTION(BlueprintCallable, Category = "Astronauta|Motion Tracker")
	void ToggleMotionTracker();

	UFUNCTION(BlueprintPure, Category = "Astronauta|Components")
	UInventoryComponent* GetInventoryComponent() const { return InventoryComponent; }

	UFUNCTION(BlueprintPure, Category = "Astronauta|Components")
	UCraftingComponent* GetCraftingComponent() const { return CraftingComponent; }

	UFUNCTION(BlueprintPure, Category = "Astronauta|Components")
	UHealthComponent* GetHealthComponent() const { return HealthComponent; }

	UFUNCTION(BlueprintPure, Category = "Astronauta|Components")
	UMotionTrackerComponent* GetMotionTrackerComponent() const { return MotionTrackerComponent; }

	// --- Conductos y rejillas ---
	/** Lo llama AVentDuct al entrar/salir. Dentro: agachado forzado, sin sprint. */
	void SetInVentDuct(AVentDuct* Duct);

	UFUNCTION(BlueprintPure, Category = "Astronauta|Vents")
	bool IsInVentDuct() const { return CurrentVentDuct.IsValid(); }

	/** Mantener pulsado: retirada silenciosa (2 s). Soltar = CancelRemoveGrate. */
	UFUNCTION(BlueprintCallable, Category = "Astronauta|Vents")
	void StartRemoveGrate();

	UFUNCTION(BlueprintCallable, Category = "Astronauta|Vents")
	void CancelRemoveGrate();

	/** Patada: rompe la rejilla al instante con ruido fuerte. */
	UFUNCTION(BlueprintCallable, Category = "Astronauta|Vents")
	void KickGrate();

	/** Momento (World time) del último ruido emitido. Lo usa la inspección de escondites. */
	UFUNCTION(BlueprintPure, Category = "Astronauta|Stealth")
	float GetLastNoiseTime() const { return LastNoiseTime; }

	UFUNCTION(BlueprintPure, Category = "Astronauta|Stealth")
	bool IsCamouflageBatteryDepleted() const { return CurrentCamouflageBattery <= 0.f; }

	// --- Delegados para el HUD (UMG) ---
	UPROPERTY(BlueprintAssignable, Category = "Astronauta|HUD")
	FOnFlashlightToggled OnFlashlightToggled;

	/** 0..1. Se emite solo cuando cambia (como mucho una vez por frame). */
	UPROPERTY(BlueprintAssignable, Category = "Astronauta|HUD")
	FOnCamouflageBatteryUpdated OnCamouflageBatteryUpdated;

	UPROPERTY(BlueprintAssignable, Category = "Astronauta|HUD")
	FOnThrowableCountChanged OnThrowableCountChanged;

	/** Chisporroteo eléctrico al agotarse el camuflaje: delata al jugador (también dentro de un casillero). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Astronauta|Stealth")
	float CamouflageDepletedLoudness = 0.8f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Astronauta|Stealth")
	float CamouflageDepletedNoiseRange = 700.f;

	// --- Distracciones ---
	/** Lanza un objeto de ThrowableClass en la dirección de la cámara. */
	UFUNCTION(BlueprintCallable, Category = "Astronauta|Distraction")
	AThrowableDistractionActor* ThrowDistraction();

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Astronauta|Distraction")
	TSubclassOf<AThrowableDistractionActor> ThrowableClass;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Astronauta|Distraction")
	float ThrowSpeed = 1500.f;

	/** -1 = infinitos. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Astronauta|Distraction")
	int32 ThrowablesLeft = 3;

	// --- IStealthTarget ---
	virtual bool IsRunning_Implementation() const override;
	/** Escondido en un casillero = ocultamiento total. */
	virtual bool IsCamouflaged_Implementation() const override { return bCamouflageActive || IsHiddenInSpot(); }
	virtual float GetLoudnessModifier_Implementation() const override { return SurfaceLoudnessModifier; }
	virtual bool GetFlashlightBeam_Implementation(FVector& Origin, FVector& Direction, float& Range, float& HalfAngleDegrees) const override;

	// --- Tuning ---
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Astronauta|Movement")
	float WalkSpeed = 300.f;
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Astronauta|Movement")
	float SprintSpeed = 600.f;
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Astronauta|Movement")
	float CrouchSpeed = 150.f;

	/** Segundos entre pasos (andando). Al correr se usa la mitad. Agachado no emite pasos. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Astronauta|Noise")
	float FootstepInterval = 0.5f;
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Astronauta|Noise")
	float WalkLoudness = 0.5f;
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Astronauta|Noise")
	float SprintLoudness = 1.5f;
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Astronauta|Noise")
	float WalkNoiseRange = 500.f;
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Astronauta|Noise")
	float SprintNoiseRange = 1200.f;

	/** Lo modifican volúmenes de superficie ruidosa (rejillas metálicas, etc.). 1.0 = normal. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Astronauta|Noise")
	float SurfaceLoudnessModifier = 1.f;

	// --- Batería de Camuflaje ---
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Astronauta|Stealth")
	float MaxCamouflageBattery = 100.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Astronauta|Stealth")
	float CamouflageDrainRate = 20.f; // 5 segundos de uso continuo a máxima carga

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Astronauta|Stealth")
	float CamouflageRechargeRate = 10.f; // 10 segundos de recarga completa

	UFUNCTION(BlueprintPure, Category = "Astronauta|Stealth")
	float GetCamouflageBatteryPercent() const { return MaxCamouflageBattery > 0.f ? (CurrentCamouflageBattery / MaxCamouflageBattery) : 0.f; }

	/** Gancho para VFX/sonido del camuflaje. */
	UFUNCTION(BlueprintImplementableEvent, Category = "Astronauta|Stealth")
	void OnCamouflageChanged(bool bActive);

	UFUNCTION(BlueprintImplementableEvent, Category = "Astronauta|Stealth")
	void OnCamouflageDepleted();

protected:
	virtual void BeginPlay() override;

	/** Por defecto va en la raíz; en el BP se puede re-anclar a la cámara. */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Astronauta|Flashlight")
	TObjectPtr<USpotLightComponent> FlashlightComponent;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
	TObjectPtr<UInventoryComponent> InventoryComponent;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
	TObjectPtr<UCraftingComponent> CraftingComponent;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
	TObjectPtr<UHealthComponent> HealthComponent;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
	TObjectPtr<UMotionTrackerComponent> MotionTrackerComponent;

	UPROPERTY(VisibleInstanceOnly, BlueprintReadOnly, Category = "Astronauta|Stealth")
	bool bCamouflageActive = false;

	UPROPERTY(VisibleInstanceOnly, BlueprintReadOnly, Category = "Astronauta|Stealth")
	float CurrentCamouflageBattery = 100.f;

	UPROPERTY(VisibleInstanceOnly, BlueprintReadOnly, Category = "Astronauta|Movement")
	bool bWantsToSprint = false;

private:
	void RefreshMaxSpeed();
	TWeakObjectPtr<AHidingSpot> CurrentHidingSpot;
	TWeakObjectPtr<AVentDuct> CurrentVentDuct;
	AVentGrate* FindOverlappingGrate() const;
	float LastNoiseTime = -1000.f;
	float LastBroadcastBatteryPercent = -1.f;
	void BroadcastBatteryIfChanged();
	float FootstepTimer = 0.f;
};
