#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "VentDuct.generated.h"

class UBoxComponent;

/**
 * Conducto de mantenimiento. Solo el jugador cabe (agachado): la geometría debe ser más baja
 * que la altura del agente de navegación del alien, así que el NavMesh del alien no entra.
 * DuctVolume detecta al jugador; Exits son las bocas, colocadas FUERA del conducto y sobre el NavMesh.
 */
UCLASS()
class ASTRONAUTA_API AVentDuct : public AActor
{
	GENERATED_BODY()

public:
	AVentDuct();

	/** Bocas del conducto en coordenadas de mundo. */
	UFUNCTION(BlueprintPure, Category = "Vent")
	TArray<FVector> GetWorldExits() const;

protected:
	virtual void BeginPlay() override;
	virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;

	UFUNCTION()
	void OnDuctBeginOverlap(UPrimitiveComponent* OverlappedComp, AActor* OtherActor,
		UPrimitiveComponent* OtherComp, int32 OtherBodyIndex, bool bFromSweep, const FHitResult& SweepResult);

	UFUNCTION()
	void OnDuctEndOverlap(UPrimitiveComponent* OverlappedComp, AActor* OtherActor,
		UPrimitiveComponent* OtherComp, int32 OtherBodyIndex);

	/** Volumen interior del conducto (ajustar al tramo completo). */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
	TObjectPtr<UBoxComponent> DuctVolume;

	/** Bocas (espacio local), editables con el gizmo. */
	UPROPERTY(EditAnywhere, Category = "Vent", meta = (MakeEditWidget = true))
	TArray<FVector> Exits;
};
