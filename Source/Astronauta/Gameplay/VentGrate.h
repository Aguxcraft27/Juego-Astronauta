#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "VentGrate.generated.h"

class UBoxComponent;
class UStaticMeshComponent;
class UAIPerceptionStimuliSourceComponent;

UENUM(BlueprintType)
enum class EVentGrateState : uint8
{
	Intact   UMETA(DisplayName = "Intacta"),
	Removed  UMETA(DisplayName = "Retirada (silencio)"),
	Broken   UMETA(DisplayName = "Rota (ruido)")
};

/**
 * Rejilla de la boca de un conducto.
 * - Retirada silenciosa: mantener la interacción RemovalTime segundos dentro del volumen. Sin ruido.
 * - Patada o choque corriendo: se rompe al instante y emite ruido fuerte (BreakLoudness 1.8).
 */
UCLASS()
class ASTRONAUTA_API AVentGrate : public AActor
{
	GENERATED_BODY()

public:
	AVentGrate();

	UFUNCTION(BlueprintCallable, Category = "Vent")
	void StartQuietRemoval(AActor* Remover);

	UFUNCTION(BlueprintCallable, Category = "Vent")
	void CancelQuietRemoval(AActor* Remover);

	UFUNCTION(BlueprintCallable, Category = "Vent")
	void BreakGrate(AActor* Breaker);

	UFUNCTION(BlueprintPure, Category = "Vent")
	EVentGrateState GetGrateState() const { return GrateState; }

	/** 0..1 para la barra de progreso de la UI. */
	UFUNCTION(BlueprintPure, Category = "Vent")
	float GetRemovalProgress() const;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Vent")
	float RemovalTime = 2.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Vent")
	float BreakLoudness = 1.8f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Vent")
	float BreakNoiseRange = 1800.f;

	UFUNCTION(BlueprintImplementableEvent, Category = "Vent")
	void OnGrateRemoved();

	UFUNCTION(BlueprintImplementableEvent, Category = "Vent")
	void OnGrateBroken();

protected:
	virtual void BeginPlay() override;

	UFUNCTION()
	void HandleMeshHit(UPrimitiveComponent* HitComp, AActor* OtherActor, UPrimitiveComponent* OtherComp,
		FVector NormalImpulse, const FHitResult& Hit);

	UFUNCTION()
	void HandleVolumeEndOverlap(UPrimitiveComponent* OverlappedComp, AActor* OtherActor,
		UPrimitiveComponent* OtherComp, int32 OtherBodyIndex);

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
	TObjectPtr<UStaticMeshComponent> Mesh;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
	TObjectPtr<UBoxComponent> InteractionVolume;

	/** Se registra para Sight solo al romperse: la rejilla rota pasa a ser una pista visual. */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
	TObjectPtr<UAIPerceptionStimuliSourceComponent> StimuliSource;

	/** Debe coincidir con AAlienAIController::ClueTag. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Vent")
	FName ClueTag = TEXT("InvestigationClue");

	UPROPERTY(VisibleInstanceOnly, BlueprintReadOnly, Category = "Vent")
	EVentGrateState GrateState = EVentGrateState::Intact;

private:
	void CompleteRemoval();
	void OpenPassage();

	FTimerHandle RemovalTimer;
	TWeakObjectPtr<AActor> CurrentRemover;
};
