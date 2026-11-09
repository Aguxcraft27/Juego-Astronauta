#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Character.h"
#include "AlienCharacter.generated.h"

class APatrolPath;
class UAnimMontage;

UCLASS()
class ASTRONAUTA_API AAlienCharacter : public ACharacter
{
	GENERATED_BODY()

public:
	AAlienCharacter();

	/** Ruta de patrulla asignada en el nivel. */
	UPROPERTY(EditInstanceOnly, BlueprintReadOnly, Category = "Alien")
	TObjectPtr<APatrolPath> PatrolPath;

	/** Animación de accionar la palanca / consola (opcional). */
	UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Alien")
	TObjectPtr<UAnimMontage> ConsoleMontage;

	/** Animación de olfatear / acechar frente a un escondite (opcional). */
	UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Alien")
	TObjectPtr<UAnimMontage> SniffMontage;

	/** Gancho para el sonido de olfateo (empieza la pausa de inspección). */
	UFUNCTION(BlueprintImplementableEvent, Category = "Alien")
	void OnInspectHidingSpot(AActor* Spot);
};
