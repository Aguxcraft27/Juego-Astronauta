#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "StationLightingDirector.generated.h"

class UAudioComponent;
class USoundBase;
class ULightComponent;

UENUM(BlueprintType)
enum class EStationLightingMode : uint8
{
	Normal    UMETA(DisplayName = "Normal (servicio)"),
	RedAlert  UMETA(DisplayName = "Alerta Roja")
};

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnLightingModeChanged, EStationLightingMode, NewMode);

/**
 * Director de atmósfera de la estación (uno por nivel).
 * - Normal: luces de servicio (NormalLights) encendidas, balizas apagadas, sirena parada.
 * - Alerta Roja: luces principales apagadas, balizas rojas (EmergencyLights) parpadeando y sirena en bucle.
 * Escucha AStationGameState::OnRedAlert. Las luces se asignan arrastrando actores (PointLight, SpotLight, BP con luces...).
 */
UCLASS()
class ASTRONAUTA_API AStationLightingDirector : public AActor
{
	GENERATED_BODY()

public:
	AStationLightingDirector();

	UFUNCTION(BlueprintCallable, Category = "Lighting")
	void SetLightingMode(EStationLightingMode NewMode);

	UFUNCTION(BlueprintPure, Category = "Lighting")
	EStationLightingMode GetLightingMode() const { return Mode; }

	UPROPERTY(BlueprintAssignable, Category = "Lighting")
	FOnLightingModeChanged OnLightingModeChanged;

	/** Para Sequencer / VFX extra al cambiar de modo. */
	UFUNCTION(BlueprintImplementableEvent, Category = "Lighting")
	void OnLightingModeApplied(EStationLightingMode NewMode);

	// --- Configuración (en la instancia del nivel) ---
	/** Luces frías / tenues de servicio. Se apagan en Alerta Roja. */
	UPROPERTY(EditInstanceOnly, BlueprintReadOnly, Category = "Lighting")
	TArray<TObjectPtr<AActor>> NormalLights;

	/** Balizas de emergencia. Apagadas en Normal; rojas y parpadeando en Alerta Roja. */
	UPROPERTY(EditInstanceOnly, BlueprintReadOnly, Category = "Lighting")
	TArray<TObjectPtr<AActor>> EmergencyLights;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Lighting")
	FLinearColor EmergencyColor = FLinearColor(1.f, 0.05f, 0.02f);

	/** Parpadeos por segundo de las balizas (0 = fijas). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Lighting", meta = (ClampMin = "0"))
	float BeaconBlinkRate = 1.5f;

	/** Sonido en bucle de la sirena (marcar Looping en el asset). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Audio")
	TObjectPtr<USoundBase> SirenSound;

	/** Opcional: atenuación espacial; si está vacío se usa la por defecto del componente. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Audio")
	TObjectPtr<class USoundAttenuation> SirenAttenuation;

protected:
	virtual void BeginPlay() override;

	UFUNCTION()
	void HandleRedAlert(AActor* AlarmInstigator);

	/** Sirena espacializada, situada donde se coloque el director. */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
	TObjectPtr<UAudioComponent> SirenAudio;

	UPROPERTY(VisibleInstanceOnly, BlueprintReadOnly, Category = "Lighting")
	EStationLightingMode Mode = EStationLightingMode::Normal;

private:
	void ApplyMode();
	void ToggleBeacons();
	static void SetActorLightsVisible(AActor* Actor, bool bVisible);

	FTimerHandle BlinkTimer;
	bool bBeaconsOn = false;
};
