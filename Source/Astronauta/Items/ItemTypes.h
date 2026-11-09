#pragma once

#include "CoreMinimal.h"
#include "ItemTypes.generated.h"

UENUM(BlueprintType)
enum class EResourceType : uint8
{
	Scrap       UMETA(DisplayName = "Chatarra Mecánica"),
	Chemicals   UMETA(DisplayName = "Compuestos Químicos"),
	Batteries   UMETA(DisplayName = "Células de Energía"),
	Sensors     UMETA(DisplayName = "Sensores Electrónicos")
};

UENUM(BlueprintType)
enum class EGadgetType : uint8
{
	None         UMETA(DisplayName = "Ninguno"),
	Noisemaker   UMETA(DisplayName = "Emisor de Ruido / Señuelo"),
	EMPMine      UMETA(DisplayName = "Mina PEM"),
	SmokeBomb    UMETA(DisplayName = "Bomba de Humo"),
	Medkit       UMETA(DisplayName = "Inyector Médico")
};

USTRUCT(BlueprintType)
struct ASTRONAUTA_API FGadgetItem
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Item")
	EGadgetType Type = EGadgetType::None;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Item")
	int32 Quantity = 1;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Item")
	int32 MaxStack = 3;
};
