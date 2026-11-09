#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "HidingSpot.generated.h"

class UBoxComponent;
class UStaticMeshComponent;
class AAstronautaCharacter;
class ACorpseActor;

DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FOnHidingSpotOccupancyChanged, AHidingSpot*, Spot, AAstronautaCharacter*, Player);

/**
 * Casillero / conducto de mantenimiento. El jugador puede meterse dentro u ocultar cadáveres.
 * La malla debe bloquear el canal Visibility para cortar la línea de visión de los aliens.
 */
UCLASS()
class ASTRONAUTA_API AHidingSpot : public AActor
{
	GENERATED_BODY()

public:
	AHidingSpot();

	/** Mete al jugador. false si ya hay alguien dentro. */
	UFUNCTION(BlueprintCallable, Category = "Hiding")
	bool EnterHidingSpot(AAstronautaCharacter* Player);

	/** Saca al jugador por ExitPoint. */
	UFUNCTION(BlueprintCallable, Category = "Hiding")
	void ExitHidingSpot();

	/** Un alien abre a la fuerza: saca al jugador (la captura la notifica el alien). */
	UFUNCTION(BlueprintCallable, Category = "Hiding")
	void ForceOpen(AActor* OpenedBy);

	/** Oculta un cadáver aquí dentro (lo desregistra de la vista de los aliens). */
	UFUNCTION(BlueprintCallable, Category = "Hiding")
	bool StoreCorpse(ACorpseActor* Corpse);

	UFUNCTION(BlueprintPure, Category = "Hiding")
	AAstronautaCharacter* GetOccupant() const { return Occupant.Get(); }

	UFUNCTION(BlueprintPure, Category = "Hiding")
	bool IsOccupied() const { return Occupant.IsValid(); }

	/** Punto delante de la puerta; los aliens navegan aquí. */
	UFUNCTION(BlueprintPure, Category = "Hiding")
	FVector GetExitLocation() const;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Hiding")
	int32 MaxStoredCorpses = 1;

	UPROPERTY(BlueprintAssignable, Category = "Hiding")
	FOnHidingSpotOccupancyChanged OnPlayerEntered;

	UPROPERTY(BlueprintAssignable, Category = "Hiding")
	FOnHidingSpotOccupancyChanged OnPlayerExited;

	/** Animación / sonido de la puerta forzada. */
	UFUNCTION(BlueprintImplementableEvent, Category = "Hiding")
	void OnForcedOpen(AActor* OpenedBy);

protected:
	virtual void BeginPlay() override;
	virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
	TObjectPtr<UStaticMeshComponent> Mesh;

	/** El jugador debe estar dentro para poder interactuar. */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
	TObjectPtr<UBoxComponent> InteractionVolume;

	/** Anclaje del pawn / cámara mientras está escondido. */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
	TObjectPtr<USceneComponent> HidePoint;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
	TObjectPtr<USceneComponent> ExitPoint;

private:
	TWeakObjectPtr<AAstronautaCharacter> Occupant;
	TArray<TWeakObjectPtr<ACorpseActor>> StoredCorpses;
};
