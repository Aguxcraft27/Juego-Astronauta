#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "SmokeBombActor.generated.h"

class USphereComponent;
class UStaticMeshComponent;

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnSmokeCloudDispelled, const FVector&, Location);

/**
 * Granada de humo táctica arrojable.
 * Al detonar, genera una densa nube de humo que bloquea el canal de Visibilidad de la IA.
 */
UCLASS()
class ASTRONAUTA_API ASmokeBombActor : public AActor
{
	GENERATED_BODY()

public:
	ASmokeBombActor();

	virtual void BeginPlay() override;

	UFUNCTION(BlueprintCallable, Category = "Astronauta|Gadgets")
	void DeploySmoke();

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Smoke Bomb")
	float FuseTime = 1.2f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Smoke Bomb")
	float SmokeDuration = 8.0f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Smoke Bomb")
	float SmokeRadius = 450.f;

	UPROPERTY(BlueprintAssignable, Category = "Smoke Bomb")
	FOnSmokeCloudDispelled OnSmokeCloudDispelled;

protected:
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
	TObjectPtr<USphereComponent> CollisionSphere;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
	TObjectPtr<UStaticMeshComponent> BombMesh;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
	TObjectPtr<USphereComponent> SmokeBlockerVolume;

	UPROPERTY(VisibleInstanceOnly, BlueprintReadOnly, Category = "Smoke Bomb")
	bool bIsDeployed = false;

	UPROPERTY(BlueprintImplementableEvent, Category = "Smoke Bomb")
	void OnSmokeSpawnVisual(float Radius, float Duration);

private:
	void OnSmokeEnd();
	FTimerHandle FuseTimerHandle;
	FTimerHandle DurationTimerHandle;
};
