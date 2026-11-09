#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "AlarmConsole.generated.h"

class UStaticMeshComponent;

UCLASS()
class ASTRONAUTA_API AAlarmConsole : public AActor
{
	GENERATED_BODY()

public:
	AAlarmConsole();

	UFUNCTION(BlueprintCallable, Category = "Alarm")
	void ActivateAlarm(AActor* ActivatedBy);

	/** Punto al que navega el alien (delante del panel). */
	UFUNCTION(BlueprintPure, Category = "Alarm")
	FVector GetInteractionLocation() const;

	/** Gancho para efectos visuales y de sonido de la consola. */
	UFUNCTION(BlueprintImplementableEvent, Category = "Alarm")
	void OnAlarmActivated(AActor* ActivatedBy);

protected:
	virtual void BeginPlay() override;
	virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Alarm")
	TObjectPtr<UStaticMeshComponent> Mesh;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Alarm")
	TObjectPtr<USceneComponent> InteractionPoint;
};
