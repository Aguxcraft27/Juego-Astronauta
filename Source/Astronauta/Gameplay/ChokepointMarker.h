#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "ChokepointMarker.generated.h"

class UBillboardComponent;
class USphereComponent;

/** Punto de estrangulamiento de la estación. En AlertaRoja los aliens patrullan entre los más cercanos al jugador. */
UCLASS()
class ASTRONAUTA_API AChokepointMarker : public AActor
{
	GENERATED_BODY()

public:
	AChokepointMarker();

	/** Mayor = preferido cuando dos chokepoints están a la misma distancia. */
	UPROPERTY(EditInstanceOnly, BlueprintReadOnly, Category = "Chokepoint")
	int32 Priority = 0;

protected:
	virtual void BeginPlay() override;
	virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;

	/** Solo visual en el editor; no colisiona. */
	UPROPERTY(VisibleAnywhere, Category = "Chokepoint")
	TObjectPtr<USphereComponent> Area;

#if WITH_EDITORONLY_DATA
	UPROPERTY(VisibleAnywhere, Category = "Chokepoint")
	TObjectPtr<UBillboardComponent> Billboard;
#endif
};
