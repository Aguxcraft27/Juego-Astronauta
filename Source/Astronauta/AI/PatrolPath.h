#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "PatrolPath.generated.h"

UCLASS()
class ASTRONAUTA_API APatrolPath : public AActor
{
	GENERATED_BODY()

public:
	APatrolPath();

	UFUNCTION(BlueprintPure, Category = "Patrol")
	int32 NumPoints() const { return Points.Num(); }

	UFUNCTION(BlueprintPure, Category = "Patrol")
	FVector GetWorldPoint(int32 Index) const;

	UFUNCTION(BlueprintPure, Category = "Patrol")
	int32 FindNearestIndex(const FVector& WorldLocation) const;

protected:
	/** Puntos en espacio local; se editan con el gizmo en el viewport. */
	UPROPERTY(EditAnywhere, Category = "Patrol", meta = (MakeEditWidget = true))
	TArray<FVector> Points;
};
