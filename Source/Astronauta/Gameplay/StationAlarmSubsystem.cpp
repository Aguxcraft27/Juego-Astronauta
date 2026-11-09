#include "Gameplay/StationAlarmSubsystem.h"
#include "Gameplay/AlarmConsole.h"
#include "Gameplay/ChokepointMarker.h"
#include "Gameplay/HidingSpot.h"
#include "Gameplay/VentDuct.h"

void UStationAlarmSubsystem::RegisterConsole(AAlarmConsole* Console)
{
	Consoles.AddUnique(Console);
}

void UStationAlarmSubsystem::UnregisterConsole(AAlarmConsole* Console)
{
	Consoles.Remove(Console);
}

AAlarmConsole* UStationAlarmSubsystem::FindNearestConsole(const FVector& FromLocation) const
{
	AAlarmConsole* Best = nullptr;
	double BestDistSq = TNumericLimits<double>::Max();
	for (const TWeakObjectPtr<AAlarmConsole>& Weak : Consoles)
	{
		if (AAlarmConsole* Console = Weak.Get())
		{
			const double DistSq = FVector::DistSquared(FromLocation, Console->GetInteractionLocation());
			if (DistSq < BestDistSq)
			{
				BestDistSq = DistSq;
				Best = Console;
			}
		}
	}
	return Best;
}

bool UStationAlarmSubsystem::TryReserveRunner(AActor* Runner)
{
	if (!CurrentRunner.IsValid() || CurrentRunner == Runner)
	{
		CurrentRunner = Runner;
		return true;
	}
	return false;
}

void UStationAlarmSubsystem::ReleaseRunner(AActor* Runner)
{
	if (CurrentRunner == Runner)
	{
		CurrentRunner = nullptr;
	}
}

void UStationAlarmSubsystem::RegisterChokepoint(AChokepointMarker* Marker)
{
	Chokepoints.AddUnique(Marker);
}

void UStationAlarmSubsystem::UnregisterChokepoint(AChokepointMarker* Marker)
{
	Chokepoints.Remove(Marker);
}

AChokepointMarker* UStationAlarmSubsystem::PickChokepointNear(const FVector& NearLocation, int32 MaxCandidates) const
{
	TArray<AChokepointMarker*> Sorted;
	for (const TWeakObjectPtr<AChokepointMarker>& Weak : Chokepoints)
	{
		if (AChokepointMarker* Marker = Weak.Get())
		{
			Sorted.Add(Marker);
		}
	}
	if (Sorted.IsEmpty())
	{
		return nullptr;
	}

	// Más cerca primero; a igual distancia (redondeada a 1 m), mayor prioridad primero.
	Sorted.Sort([&NearLocation](const AChokepointMarker& A, const AChokepointMarker& B)
	{
		const int64 DA = FMath::RoundToInt64(FVector::Dist(NearLocation, A.GetActorLocation()) / 100.0);
		const int64 DB = FMath::RoundToInt64(FVector::Dist(NearLocation, B.GetActorLocation()) / 100.0);
		return DA != DB ? DA < DB : A.Priority > B.Priority;
	});

	const int32 Count = FMath::Clamp(MaxCandidates, 1, Sorted.Num());
	return Sorted[FMath::RandRange(0, Count - 1)];
}

void UStationAlarmSubsystem::RegisterHidingSpot(AHidingSpot* Spot)
{
	HidingSpots.AddUnique(Spot);
}

void UStationAlarmSubsystem::UnregisterHidingSpot(AHidingSpot* Spot)
{
	HidingSpots.Remove(Spot);
}

AHidingSpot* UStationAlarmSubsystem::FindNearestHidingSpot(const FVector& FromLocation, float MaxDistance) const
{
	AHidingSpot* Best = nullptr;
	double BestDistSq = FMath::Square(static_cast<double>(MaxDistance));
	for (const TWeakObjectPtr<AHidingSpot>& Weak : HidingSpots)
	{
		if (AHidingSpot* Spot = Weak.Get())
		{
			const double DistSq = FVector::DistSquared(FromLocation, Spot->GetExitLocation());
			if (DistSq <= BestDistSq)
			{
				BestDistSq = DistSq;
				Best = Spot;
			}
		}
	}
	return Best;
}

void UStationAlarmSubsystem::RegisterVentDuct(AVentDuct* Duct)
{
	VentDucts.AddUnique(Duct);
}

void UStationAlarmSubsystem::UnregisterVentDuct(AVentDuct* Duct)
{
	VentDucts.Remove(Duct);
}

bool UStationAlarmSubsystem::FindDuctAmbushExit(const AVentDuct* Duct, const FVector& EntryLocation, const FVector& AlienLocation, FVector& OutExit) const
{
	if (!Duct)
	{
		return false;
	}
	const TArray<FVector> Exits = Duct->GetWorldExits();
	if (Exits.IsEmpty())
	{
		return false;
	}

	int32 EntryIndex = 0;
	double EntryDistSq = TNumericLimits<double>::Max();
	for (int32 i = 0; i < Exits.Num(); ++i)
	{
		const double DistSq = FVector::DistSquared(EntryLocation, Exits[i]);
		if (DistSq < EntryDistSq)
		{
			EntryDistSq = DistSq;
			EntryIndex = i;
		}
	}

	int32 Best = INDEX_NONE;
	double BestDistSq = TNumericLimits<double>::Max();
	for (int32 i = 0; i < Exits.Num(); ++i)
	{
		if (i == EntryIndex && Exits.Num() > 1)
		{
			continue;
		}
		const double DistSq = FVector::DistSquared(AlienLocation, Exits[i]);
		if (DistSq < BestDistSq)
		{
			BestDistSq = DistSq;
			Best = i;
		}
	}
	OutExit = Exits[Best];
	return true;
}
