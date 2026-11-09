#include "Gameplay/StationSaveGame.h"
#include "Gameplay/StationGameState.h"
#include "Gameplay/HealthComponent.h"
#include "Items/InventoryComponent.h"
#include "Kismet/GameplayStatics.h"
#include "EngineUtils.h"
#include "Engine/World.h"
#include "GameFramework/Pawn.h"
#include "GameFramework/Controller.h"

const FString UStationSaveGame::DefaultSlot = TEXT("StationSave");

void UStationSaveGame::CaptureFrom(UWorld* World)
{
	if (!World)
	{
		return;
	}
	LevelName = FName(*UGameplayStatics::GetCurrentLevelName(World));
	Timestamp = FDateTime::Now();

	if (APawn* Player = UGameplayStatics::GetPlayerPawn(World, 0))
	{
		PlayerLocation = Player->GetActorLocation();
		PlayerRotation = Player->GetControlRotation();
		if (const UHealthComponent* HC = Player->FindComponentByClass<UHealthComponent>())
		{
			Health = HC->GetHealth();
			Oxygen = HC->GetOxygen();
		}
		if (const UInventoryComponent* Inv = Player->FindComponentByClass<UInventoryComponent>())
		{
			Resources = Inv->GetResources();
			Gadgets = Inv->GetGadgetSlots();
		}
	}

	if (const AStationGameState* GS = World->GetGameState<AStationGameState>())
	{
		bAlarmTriggered = GS->IsAlarmTriggered();
	}

	DoorStates.Reset();
	for (TActorIterator<AStationDoor> It(World); It; ++It)
	{
		DoorStates.Add(It->GetFName(), It->GetDoorState());
	}
}

void UStationSaveGame::ApplyTo(UObject* WorldContextObject) const
{
	UWorld* World = WorldContextObject ? WorldContextObject->GetWorld() : nullptr;
	if (!World)
	{
		return;
	}

	if (APawn* Player = UGameplayStatics::GetPlayerPawn(World, 0))
	{
		Player->TeleportTo(PlayerLocation, FRotator(0.f, PlayerRotation.Yaw, 0.f), false, true);
		if (AController* PC = Player->GetController())
		{
			PC->SetControlRotation(PlayerRotation);
		}
		if (UHealthComponent* HC = Player->FindComponentByClass<UHealthComponent>())
		{
			HC->SetVitals(Health, Oxygen);
		}
		if (UInventoryComponent* Inv = Player->FindComponentByClass<UInventoryComponent>())
		{
			Inv->RestoreState(Resources, Gadgets);
		}
	}

	// La alarma antes que las puertas: la Alerta Roja bloquea compuertas y el estado guardado debe prevalecer.
	if (bAlarmTriggered)
	{
		if (AStationGameState* GS = World->GetGameState<AStationGameState>())
		{
			if (!GS->IsAlarmTriggered())
			{
				GS->TriggerRedAlert(nullptr);
			}
		}
	}

	for (TActorIterator<AStationDoor> It(World); It; ++It)
	{
		if (const EStationDoorState* State = DoorStates.Find(It->GetFName()))
		{
			It->SetDoorState(*State);
		}
	}
}
