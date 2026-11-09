#pragma once

#include "CoreMinimal.h"
#include "GameFramework/GameModeBase.h"
#include "StationGameMode.generated.h"

UENUM(BlueprintType)
enum class EGameOverCause : uint8
{
	Captured  UMETA(DisplayName = "Capturado"),
	Died      UMETA(DisplayName = "Muerto")
};

/**
 * Ciclo de partida:
 * - "?load=1" en las opciones del nivel → aplica el slot de guardado al empezar.
 * - Captura (GameState) o muerte (HealthComponent) → controles congelados y, tras GameOverDelay,
 *   OnGameOverScreenRequested (pantalla "SIN SEÑAL / CAPTURADO"). Desde esa UI: ReloadLastSave / RestartFromLastCheckpoint.
 */
UCLASS()
class ASTRONAUTA_API AStationGameMode : public AGameModeBase
{
	GENERATED_BODY()

public:
	AStationGameMode();

	/** Reabre el nivel actual con "load=1". Sin partida guardada, reinicia el nivel desde cero. */
	UFUNCTION(BlueprintCallable, Category = "GameMode")
	void ReloadLastSave();

	UFUNCTION(BlueprintCallable, Category = "GameMode")
	void RestartFromLastCheckpoint(APlayerController* PC);

	UFUNCTION(BlueprintPure, Category = "GameMode")
	bool IsGameOver() const { return bGameOver; }

	UFUNCTION(BlueprintImplementableEvent, Category = "GameMode")
	void OnGameOverScreenRequested(EGameOverCause Cause, AActor* Instigator);

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "GameMode")
	float GameOverDelay = 3.f;

protected:
	virtual void BeginPlay() override;
	virtual void HandleStartingNewPlayer_Implementation(APlayerController* NewPlayer) override;

	UFUNCTION()
	void HandlePlayerCaptured(AActor* Player, AActor* CapturedBy);

	UFUNCTION()
	void HandlePlayerDied(AActor* Killer);

private:
	void TriggerGameOver(EGameOverCause Cause, AActor* Instigator);
	void ShowGameOverScreen();
	void ApplySaveIfRequested();

	bool bGameOver = false;
	EGameOverCause PendingCause = EGameOverCause::Died;
	TWeakObjectPtr<AActor> PendingInstigator;
	FTimerHandle GameOverTimer;
};
