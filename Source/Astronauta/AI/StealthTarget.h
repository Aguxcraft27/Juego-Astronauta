#pragma once

#include "CoreMinimal.h"
#include "UObject/Interface.h"
#include "StealthTarget.generated.h"

UINTERFACE(BlueprintType, MinimalAPI)
class UStealthTarget : public UInterface
{
	GENERATED_BODY()
};

/** La implementa el personaje del jugador para que el alien pueda calcular la sospecha. */
class ASTRONAUTA_API IStealthTarget
{
	GENERATED_BODY()

public:
	UFUNCTION(BlueprintNativeEvent, BlueprintCallable, Category = "Stealth")
	bool IsRunning() const;

	UFUNCTION(BlueprintNativeEvent, BlueprintCallable, Category = "Stealth")
	bool IsCamouflaged() const;

	/** Multiplicador de ruido (superficies ruidosas, etc.). 1.0 = normal. */
	UFUNCTION(BlueprintNativeEvent, BlueprintCallable, Category = "Stealth")
	float GetLoudnessModifier() const;

	/** Haz de linterna. false si está apagada. HalfAngleDegrees = semiángulo del cono. */
	UFUNCTION(BlueprintNativeEvent, BlueprintCallable, Category = "Stealth")
	bool GetFlashlightBeam(FVector& Origin, FVector& Direction, float& Range, float& HalfAngleDegrees) const;
};
