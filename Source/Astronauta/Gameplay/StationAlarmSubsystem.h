#pragma once

#include "CoreMinimal.h"
#include "Subsystems/WorldSubsystem.h"
#include "StationAlarmSubsystem.generated.h"

class AAlarmConsole;
class AChokepointMarker;
class AHidingSpot;
class AVentDuct;

/**
 * Registro de consolas de alarma y chokepoints del nivel, y reserva del único alien "corredor".
 * Sustituye a consultas EQS (más barato y determinista).
 */
UCLASS()
class ASTRONAUTA_API UStationAlarmSubsystem : public UWorldSubsystem
{
	GENERATED_BODY()

public:
	// --- Consolas ---
	void RegisterConsole(AAlarmConsole* Console);
	void UnregisterConsole(AAlarmConsole* Console);

	/** Consola más cercana en línea recta (no por distancia de navegación). */
	UFUNCTION(BlueprintCallable, Category = "Alarm")
	AAlarmConsole* FindNearestConsole(const FVector& FromLocation) const;

	// --- Corredor (solo un alien puede correr a la alarma a la vez) ---
	/** true si Runner obtiene (o ya tenía) la reserva. */
	bool TryReserveRunner(AActor* Runner);
	void ReleaseRunner(AActor* Runner);
	bool HasRunner() const { return CurrentRunner.IsValid(); }

	// --- Chokepoints ---
	void RegisterChokepoint(AChokepointMarker* Marker);
	void UnregisterChokepoint(AChokepointMarker* Marker);

	/** Elige al azar uno de los MaxCandidates chokepoints más cercanos a NearLocation (desempate por prioridad). */
	UFUNCTION(BlueprintCallable, Category = "Alarm")
	AChokepointMarker* PickChokepointNear(const FVector& NearLocation, int32 MaxCandidates = 3) const;

	// --- Escondites ---
	void RegisterHidingSpot(AHidingSpot* Spot);
	void UnregisterHidingSpot(AHidingSpot* Spot);

	/** Escondite más cercano dentro de MaxDistance (nullptr si no hay). */
	UFUNCTION(BlueprintCallable, Category = "Alarm")
	AHidingSpot* FindNearestHidingSpot(const FVector& FromLocation, float MaxDistance) const;

	// --- Conductos ---
	void RegisterVentDuct(AVentDuct* Duct);
	void UnregisterVentDuct(AVentDuct* Duct);

	/**
	 * Salida del conducto donde emboscar: descarta la boca por la que entró el jugador
	 * (la más cercana a EntryLocation) y devuelve la más cercana al alien.
	 */
	bool FindDuctAmbushExit(const AVentDuct* Duct, const FVector& EntryLocation, const FVector& AlienLocation, FVector& OutExit) const;

private:
	TArray<TWeakObjectPtr<AHidingSpot>> HidingSpots;
	TArray<TWeakObjectPtr<AVentDuct>> VentDucts;
	TArray<TWeakObjectPtr<AAlarmConsole>> Consoles;
	TArray<TWeakObjectPtr<AChokepointMarker>> Chokepoints;
	TWeakObjectPtr<AActor> CurrentRunner;
};
