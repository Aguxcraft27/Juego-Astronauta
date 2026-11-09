#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "VacuumZone.generated.h"

class UBoxComponent;

/** Zona sin presurización: mientras el jugador está dentro, su oxígeno decae. Se puede (des)activar desde una esclusa. */
UCLASS()
class ASTRONAUTA_API AVacuumZone : public AActor
{
	GENERATED_BODY()

public:
	AVacuumZone();

	UFUNCTION(BlueprintCallable, Category = "Vacuum")
	void SetVacuumActive(bool bActive);

	UFUNCTION(BlueprintPure, Category = "Vacuum")
	bool IsVacuumActive() const { return bVacuumActive; }

protected:
	virtual void BeginPlay() override;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
	TObjectPtr<UBoxComponent> Volume;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Vacuum")
	bool bVacuumActive = true;

	UFUNCTION()
	void OnBeginOverlap(UPrimitiveComponent* OverlappedComp, AActor* OtherActor, UPrimitiveComponent* OtherComp,
		int32 OtherBodyIndex, bool bFromSweep, const FHitResult& SweepResult);

	UFUNCTION()
	void OnEndOverlap(UPrimitiveComponent* OverlappedComp, AActor* OtherActor, UPrimitiveComponent* OtherComp, int32 OtherBodyIndex);

private:
	void SetActorInVacuum(AActor* Actor, bool bInside);
	TSet<TWeakObjectPtr<AActor>> Affected;
};
