#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "SecurityTerminal.generated.h"

class UStaticMeshComponent;
class USphereComponent;
class AStationDoor;
class ASmokeBombActor;

UENUM(BlueprintType)
enum class ETerminalAction : uint8
{
	CutLocalLights   UMETA(DisplayName = "Apagar iluminación local"),
	OverrideDoors    UMETA(DisplayName = "Sobrecargar esclusas"),
	SteamPurge       UMETA(DisplayName = "Purga de vapor")
};

DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FOnTerminalHackStarted, ETerminalAction, Action, float, Duration);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnTerminalHackProgress, float, Percent01);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FOnTerminalHackFinished, ETerminalAction, Action, bool, bSuccess);

/**
 * Terminal de desvío de energía. El jugador elige una acción y mantiene un hackeo de HackDuration s.
 * Si se aleja, corre o lo cancela, el hackeo falla y la terminal emite un pitido de error audible (riesgo acústico).
 */
UCLASS()
class ASTRONAUTA_API ASecurityTerminal : public AActor
{
	GENERATED_BODY()

public:
	ASecurityTerminal();

	UFUNCTION(BlueprintCallable, Category = "Terminal")
	bool BeginHack(ETerminalAction Action, AActor* User);

	UFUNCTION(BlueprintCallable, Category = "Terminal")
	void CancelHack();

	/** Ejecuta la acción sin hackeo (scripting de nivel / tests). */
	UFUNCTION(BlueprintCallable, Category = "Terminal")
	void ExecuteAction(ETerminalAction Action);

	UFUNCTION(BlueprintPure, Category = "Terminal")
	bool IsActionAvailable(ETerminalAction Action) const;

	UFUNCTION(BlueprintPure, Category = "Terminal")
	bool IsHacking() const { return HackUser != nullptr; }

	UPROPERTY(BlueprintAssignable, Category = "Terminal")
	FOnTerminalHackStarted OnHackStarted;

	UPROPERTY(BlueprintAssignable, Category = "Terminal")
	FOnTerminalHackProgress OnHackProgress;

	UPROPERTY(BlueprintAssignable, Category = "Terminal")
	FOnTerminalHackFinished OnHackFinished;

	/** Pantalla, VFX, sonidos. */
	UFUNCTION(BlueprintImplementableEvent, Category = "Terminal")
	void OnActionExecuted(ETerminalAction Action);

	// --- Configuración en la instancia ---
	UPROPERTY(EditInstanceOnly, BlueprintReadOnly, Category = "Terminal|Targets")
	TArray<TObjectPtr<AActor>> LocalLights;

	UPROPERTY(EditInstanceOnly, BlueprintReadOnly, Category = "Terminal|Targets")
	TArray<TObjectPtr<AStationDoor>> Doors;

	/** Puntos (TargetPoint, etc.) donde sale el vapor. */
	UPROPERTY(EditInstanceOnly, BlueprintReadOnly, Category = "Terminal|Targets")
	TArray<TObjectPtr<AActor>> SteamVents;

	/** Actor que bloquea la visión (por defecto la bomba de humo del Lead, detonada al instante). */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Terminal|Targets")
	TSubclassOf<ASmokeBombActor> SteamClass;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Terminal", meta = (ClampMin = "0"))
	float HackDuration = 3.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Terminal", meta = (ClampMin = "0"))
	float SteamCooldown = 20.f;

	/** El jugador debe quedarse dentro de este radio mientras hackea. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Terminal")
	float MaxUseDistance = 200.f;

	/** Pitido de error al fallar: intensidad y alcance para la IA. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Terminal")
	float FailNoiseLoudness = 1.2f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Terminal")
	float FailNoiseRange = 1400.f;

protected:
	virtual void Tick(float DeltaSeconds) override;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
	TObjectPtr<UStaticMeshComponent> TerminalMesh;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
	TObjectPtr<UStaticMeshComponent> ScreenMesh;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
	TObjectPtr<USphereComponent> InteractionVolume;

private:
	void FailHack();

	UPROPERTY()
	TObjectPtr<AActor> HackUser;

	ETerminalAction HackAction = ETerminalAction::CutLocalLights;
	float HackElapsed = 0.f;
	bool bLightsCut = false;
	bool bDoorsOverridden = false;
	float LastSteamTime = -1000.f;
};
