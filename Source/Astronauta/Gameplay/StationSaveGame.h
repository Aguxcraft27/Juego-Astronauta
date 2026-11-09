#pragma once

#include "CoreMinimal.h"
#include "GameFramework/SaveGame.h"
#include "Items/ItemTypes.h"
#include "Gameplay/StationDoor.h"
#include "StationSaveGame.generated.h"

/** Partida guardada desde un ASaveTerminal. Las puertas se identifican por el nombre del actor en el nivel. */
UCLASS()
class ASTRONAUTA_API UStationSaveGame : public USaveGame
{
	GENERATED_BODY()

public:
	UPROPERTY(SaveGame, VisibleAnywhere, BlueprintReadOnly, Category = "Save")
	FName LevelName;

	UPROPERTY(SaveGame, VisibleAnywhere, BlueprintReadOnly, Category = "Save")
	FDateTime Timestamp;

	UPROPERTY(SaveGame, VisibleAnywhere, BlueprintReadOnly, Category = "Save|Player")
	FVector PlayerLocation = FVector::ZeroVector;

	UPROPERTY(SaveGame, VisibleAnywhere, BlueprintReadOnly, Category = "Save|Player")
	FRotator PlayerRotation = FRotator::ZeroRotator;

	UPROPERTY(SaveGame, VisibleAnywhere, BlueprintReadOnly, Category = "Save|Player")
	float Health = 100.f;

	UPROPERTY(SaveGame, VisibleAnywhere, BlueprintReadOnly, Category = "Save|Player")
	float Oxygen = 100.f;

	UPROPERTY(SaveGame, VisibleAnywhere, BlueprintReadOnly, Category = "Save|Player")
	TMap<EResourceType, int32> Resources;

	UPROPERTY(SaveGame, VisibleAnywhere, BlueprintReadOnly, Category = "Save|Player")
	TArray<FGadgetItem> Gadgets;

	UPROPERTY(SaveGame, VisibleAnywhere, BlueprintReadOnly, Category = "Save|World")
	bool bAlarmTriggered = false;

	UPROPERTY(SaveGame, VisibleAnywhere, BlueprintReadOnly, Category = "Save|World")
	TMap<FName, EStationDoorState> DoorStates;

	/** Captura el estado actual del mundo y del jugador 0. */
	void CaptureFrom(UWorld* World);

	/** Aplica el estado al mundo cargado (llamar tras abrir el nivel, p. ej. desde el GameMode en BeginPlay). */
	UFUNCTION(BlueprintCallable, Category = "Save")
	void ApplyTo(UObject* WorldContextObject) const;

	static const FString DefaultSlot;
};
