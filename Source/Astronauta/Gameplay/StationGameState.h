#pragma once

#include "CoreMinimal.h"
#include "GameFramework/GameStateBase.h"
#include "StationGameState.generated.h"

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnRedAlert, AActor*, AlarmInstigator);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FOnIntruderReported, FVector, LastKnownLocation, AActor*, Reporter);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FOnPlayerCaptured, AActor*, Player, AActor*, CapturedBy);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnSuspicionUpdated, float, NewValue);

UCLASS()
class ASTRONAUTA_API AStationGameState : public AGameStateBase
{
	GENERATED_BODY()

public:
	/** Activa la alerta roja global. Llamarla más de una vez no hace nada. */
	UFUNCTION(BlueprintCallable, Category = "Station")
	void TriggerRedAlert(AActor* AlarmInstigator);

	/** Un alien ha confirmado al jugador y corre a la alarma: el resto investiga esa posición. */
	UFUNCTION(BlueprintCallable, Category = "Station")
	void ReportIntruder(const FVector& LastKnownLocation, AActor* Reporter);

	/** Captura / Game Over. Llamarla más de una vez no hace nada. */
	UFUNCTION(BlueprintCallable, Category = "Station")
	void NotifyPlayerCaptured(AActor* Player, AActor* CapturedBy);

	/** Lo llama cualquier alien que vea al jugador de forma confirmada. */
	void UpdateLastKnownIntruderLocation(const FVector& Location);

	/** false si ningún alien ha confirmado nunca la posición del jugador. */
	UFUNCTION(BlueprintPure, Category = "Station")
	bool GetLastReportedIntruderLocation(FVector& OutLocation) const;

	UFUNCTION(BlueprintPure, Category = "Station")
	bool IsAlarmTriggered() const { return bIsAlarmTriggered; }

	/** Lo llama cada alien en cada tick del servicio. Value < 0 retira al alien (muerto / sin pawn). */
	void ReportAlienSuspicion(AActor* Alien, float Value);

	/** Sospecha máxima entre todos los aliens (0-100), la que muestra el HUD. */
	UFUNCTION(BlueprintPure, Category = "Station|HUD")
	float GetMaxSuspicion() const { return LastBroadcastSuspicion < 0.f ? 0.f : LastBroadcastSuspicion; }

	/** HUD: medidor de sospecha 0-100 (máximo entre aliens). Solo se emite al cambiar. */
	UPROPERTY(BlueprintAssignable, Category = "Station|HUD")
	FOnSuspicionUpdated OnSuspicionUpdated;

	UFUNCTION(BlueprintPure, Category = "Station")
	bool IsPlayerCaptured() const { return bIsPlayerCaptured; }

	/** Luces de emergencia, sirenas, esclusas y el resto de aliens se suscriben aquí. */
	UPROPERTY(BlueprintAssignable, Category = "Station")
	FOnRedAlert OnRedAlert;

	UPROPERTY(BlueprintAssignable, Category = "Station")
	FOnIntruderReported OnIntruderReported;

	/** La UI de Game Over se suscribe aquí. */
	UPROPERTY(BlueprintAssignable, Category = "Station")
	FOnPlayerCaptured OnPlayerCaptured;

protected:
	UPROPERTY(VisibleInstanceOnly, BlueprintReadOnly, Category = "Station")
	bool bIsAlarmTriggered = false;

	UPROPERTY(VisibleInstanceOnly, BlueprintReadOnly, Category = "Station")
	bool bIsPlayerCaptured = false;

	UPROPERTY(VisibleInstanceOnly, BlueprintReadOnly, Category = "Station")
	FVector LastKnownIntruderLocation = FVector::ZeroVector;

	UPROPERTY(VisibleInstanceOnly, BlueprintReadOnly, Category = "Station")
	bool bHasLastKnownIntruderLocation = false;

private:
	TMap<TWeakObjectPtr<AActor>, float> AlienSuspicion;
	float LastBroadcastSuspicion = -1.f;
};
