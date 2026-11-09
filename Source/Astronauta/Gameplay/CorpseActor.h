#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "CorpseActor.generated.h"

class USkeletalMeshComponent;
class UAIPerceptionStimuliSourceComponent;

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnCorpseDisturbed, ACorpseActor*, Corpse);

/**
 * Cadáver de tripulante espacial en el nivel.
 * Registrado automáticamente con UAISense_Sight y con la etiqueta "Corpse".
 * El jugador puede arrastrarlo/ocultarlo para evitar que aumente la sospecha alienígena.
 */
UCLASS()
class ASTRONAUTA_API ACorpseActor : public AActor
{
	GENERATED_BODY()

public:
	ACorpseActor();

	virtual void BeginPlay() override;
	virtual void OnConstruction(const FTransform& Transform) override;

	/** Alterna el modo arrastre / física para que el jugador pueda esconder el cuerpo. */
	UFUNCTION(BlueprintCallable, Category = "Astronauta|Corpse")
	void SetBeingDragged(bool bDragged, AActor* DraggingInstigator = nullptr);

	/** Marca el cuerpo como oculto (ej. dentro de un casillero o ducto de ventilación). */
	UFUNCTION(BlueprintCallable, Category = "Astronauta|Corpse")
	void SetHiddenFromSight(bool bHidden);

	UFUNCTION(BlueprintPure, Category = "Astronauta|Corpse")
	bool IsHiddenFromSight() const { return bIsHidden; }

	UFUNCTION(BlueprintPure, Category = "Astronauta|Corpse")
	bool IsBeingDragged() const { return bIsBeingDragged; }

	UPROPERTY(BlueprintAssignable, Category = "Astronauta|Corpse")
	FOnCorpseDisturbed OnCorpseDisturbed;

protected:
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
	TObjectPtr<USkeletalMeshComponent> MeshComponent;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
	TObjectPtr<UAIPerceptionStimuliSourceComponent> StimuliSource;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Corpse")
	FName CorpseIdentificationTag = TEXT("Corpse");

	UPROPERTY(VisibleInstanceOnly, BlueprintReadOnly, Category = "Corpse")
	bool bIsHidden = false;

	UPROPERTY(VisibleInstanceOnly, BlueprintReadOnly, Category = "Corpse")
	bool bIsBeingDragged = false;

	UPROPERTY(VisibleInstanceOnly, BlueprintReadOnly, Category = "Corpse")
	TWeakObjectPtr<AActor> CurrentDragger;
};
