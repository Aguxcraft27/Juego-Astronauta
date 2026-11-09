#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "StationDoor.generated.h"

class UStaticMeshComponent;
class UBoxComponent;
class UNavModifierComponent;

UENUM(BlueprintType)
enum class EStationDoorState : uint8
{
	Open       UMETA(DisplayName = "Open"),
	Closed     UMETA(DisplayName = "Closed"),
	LockedDown UMETA(DisplayName = "Locked Down (Red Alert)")
};

/**
 * Compuerta de seguridad de la estación espacial.
 * Se bloquea automáticamente durante la Alerta Roja, canalizando el flujo hacia los Chokepoints.
 */
UCLASS()
class ASTRONAUTA_API AStationDoor : public AActor
{
	GENERATED_BODY()

public:
	AStationDoor();

	virtual void BeginPlay() override;

	UFUNCTION(BlueprintCallable, Category = "Station Door")
	void OpenDoor();

	UFUNCTION(BlueprintCallable, Category = "Station Door")
	void CloseDoor();

	UFUNCTION(BlueprintCallable, Category = "Station Door")
	void SetDoorState(EStationDoorState NewState);

	UFUNCTION(BlueprintPure, Category = "Station Door")
	EStationDoorState GetDoorState() const { return DoorState; }

	UFUNCTION(BlueprintPure, Category = "Station Door")
	bool IsLocked() const { return DoorState == EStationDoorState::LockedDown; }

protected:
	UFUNCTION()
	void HandleRedAlert(AActor* AlarmInstigator);

	UFUNCTION()
	void OnOverlapBegin(UPrimitiveComponent* OverlappedComp, AActor* OtherActor,
		UPrimitiveComponent* OtherComp, int32 OtherBodyIndex, bool bFromSweep, const FHitResult& SweepResult);

	UFUNCTION()
	void OnOverlapEnd(UPrimitiveComponent* OverlappedComp, AActor* OtherActor,
		UPrimitiveComponent* OtherComp, int32 OtherBodyIndex);

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
	TObjectPtr<USceneComponent> SceneRoot;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
	TObjectPtr<UStaticMeshComponent> DoorFrame;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
	TObjectPtr<UStaticMeshComponent> DoorPanelLeft;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
	TObjectPtr<UStaticMeshComponent> DoorPanelRight;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
	TObjectPtr<UBoxComponent> TriggerBox;

	/** Con LockedDown marca el hueco de la puerta como NavArea_Null: los aliens recalculan ruta. */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
	TObjectPtr<UNavModifierComponent> NavModifier;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Station Door")
	bool bLocksOnRedAlert = true;

	UPROPERTY(VisibleInstanceOnly, BlueprintReadOnly, Category = "Station Door")
	EStationDoorState DoorState = EStationDoorState::Closed;

	UFUNCTION(BlueprintImplementableEvent, Category = "Station Door")
	void OnDoorVisualStateChanged(EStationDoorState NewState);

private:
	void UpdateNavArea();

	int32 OverlappingActorsCount = 0;
};
