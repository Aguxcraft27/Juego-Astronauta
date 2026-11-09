#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "EMPMineActor.generated.h"

class USphereComponent;
class UStaticMeshComponent;

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnEMPMineDetonated, const FVector&, Location);

/**
 * Mina de Pulso Electromagnético (PEM) desplegable.
 * Se adhiere a superficies y detona por proximidad de hostiles.
 * Aturde al alienígena e inutiliza temporalmente dispositivos electrónicos.
 */
UCLASS()
class ASTRONAUTA_API AEMPMineActor : public AActor
{
	GENERATED_BODY()

public:
	AEMPMineActor();

	virtual void BeginPlay() override;

	/** Arma la mina tras un delay inicial de seguridad (1.0 s). */
	UFUNCTION(BlueprintCallable, Category = "Astronauta|Gadgets")
	void ArmMine();

	UFUNCTION(BlueprintCallable, Category = "Astronauta|Gadgets")
	void Detonate();

	UFUNCTION(BlueprintPure, Category = "Astronauta|Gadgets")
	bool IsArmed() const { return bIsArmed; }

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "EMP Mine")
	float TriggerRadius = 250.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "EMP Mine")
	float BlastRadius = 600.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "EMP Mine")
	float StunDuration = 6.0f;

	UPROPERTY(BlueprintAssignable, Category = "EMP Mine")
	FOnEMPMineDetonated OnEMPMineDetonated;

protected:
	UFUNCTION()
	void OnProximityOverlap(UPrimitiveComponent* OverlappedComp, AActor* OtherActor,
		UPrimitiveComponent* OtherComp, int32 OtherBodyIndex, bool bFromSweep, const FHitResult& SweepResult);

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
	TObjectPtr<USphereComponent> CollisionSphere;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
	TObjectPtr<UStaticMeshComponent> MineMesh;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
	TObjectPtr<USphereComponent> TriggerVolume;

	UPROPERTY(VisibleInstanceOnly, BlueprintReadOnly, Category = "EMP Mine")
	bool bIsArmed = false;

	UPROPERTY(BlueprintImplementableEvent, Category = "EMP Mine")
	void OnMineArmedVisual();

	UPROPERTY(BlueprintImplementableEvent, Category = "EMP Mine")
	void OnDetonationVisual();

private:
	FTimerHandle ArmTimerHandle;
};
