#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "BloodDropActor.generated.h"

class UAIPerceptionStimuliSourceComponent;
class UDecalComponent;

/**
 * Gota / charco de sangre. Mientras está fresca lleva el tag "BloodTrail" y es estímulo de Sight:
 * un alien que la ve suma +30 y la investiga. Al secarse (FreshDuration) deja de ser estímulo; desaparece en LifeSpan.
 */
UCLASS()
class ASTRONAUTA_API ABloodDropActor : public AActor
{
	GENERATED_BODY()

public:
	ABloodDropActor();

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Blood")
	float FreshDuration = 30.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Blood")
	float TotalLifeSpan = 90.f;

	/** Debe coincidir con AAlienAIController::BloodTag. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Blood")
	FName BloodTag = TEXT("BloodTrail");

	UFUNCTION(BlueprintPure, Category = "Blood")
	bool IsFresh() const { return bFresh; }

	UFUNCTION(BlueprintImplementableEvent, Category = "Blood")
	void OnDried();

protected:
	virtual void BeginPlay() override;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
	TObjectPtr<UDecalComponent> Decal;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
	TObjectPtr<UAIPerceptionStimuliSourceComponent> StimuliSource;

private:
	void Dry();
	bool bFresh = true;
	FTimerHandle DryTimer;
};
