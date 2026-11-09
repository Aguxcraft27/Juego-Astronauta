#include "Gameplay/StationGameState.h"
#include "Astronauta.h"

void AStationGameState::TriggerRedAlert(AActor* AlarmInstigator)
{
	if (bIsAlarmTriggered)
	{
		return;
	}
	bIsAlarmTriggered = true;
	UE_LOG(LogAlienAI, Warning, TEXT("ALERTA ROJA activada por %s"), *GetNameSafe(AlarmInstigator));
	OnRedAlert.Broadcast(AlarmInstigator);
}

void AStationGameState::ReportIntruder(const FVector& LastKnownLocation, AActor* Reporter)
{
	UE_LOG(LogAlienAI, Log, TEXT("%s reporta intruso en %s"), *GetNameSafe(Reporter), *LastKnownLocation.ToCompactString());
	UpdateLastKnownIntruderLocation(LastKnownLocation);
	OnIntruderReported.Broadcast(LastKnownLocation, Reporter);
}

void AStationGameState::NotifyPlayerCaptured(AActor* Player, AActor* CapturedBy)
{
	if (bIsPlayerCaptured)
	{
		return;
	}
	bIsPlayerCaptured = true;
	UE_LOG(LogAlienAI, Warning, TEXT("JUGADOR CAPTURADO por %s"), *GetNameSafe(CapturedBy));
	OnPlayerCaptured.Broadcast(Player, CapturedBy);
}

void AStationGameState::UpdateLastKnownIntruderLocation(const FVector& Location)
{
	LastKnownIntruderLocation = Location;
	bHasLastKnownIntruderLocation = true;
}

bool AStationGameState::GetLastReportedIntruderLocation(FVector& OutLocation) const
{
	OutLocation = LastKnownIntruderLocation;
	return bHasLastKnownIntruderLocation;
}

void AStationGameState::ReportAlienSuspicion(AActor* Alien, float Value)
{
	if (Value < 0.f)
	{
		AlienSuspicion.Remove(Alien);
	}
	else
	{
		AlienSuspicion.Add(Alien, Value);
	}

	float MaxValue = 0.f;
	for (auto It = AlienSuspicion.CreateIterator(); It; ++It)
	{
		if (!It.Key().IsValid())
		{
			It.RemoveCurrent();
			continue;
		}
		MaxValue = FMath::Max(MaxValue, It.Value());
	}

	// Solo se emite si cambia de forma apreciable, o al tocar los extremos (0 / 100).
	const bool bEdge = (MaxValue <= 0.f || MaxValue >= 100.f) && MaxValue != LastBroadcastSuspicion;
	if (bEdge || FMath::Abs(MaxValue - LastBroadcastSuspicion) >= 0.5f)
	{
		LastBroadcastSuspicion = MaxValue;
		OnSuspicionUpdated.Broadcast(MaxValue);
	}
}
