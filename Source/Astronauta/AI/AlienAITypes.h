#pragma once

#include "CoreMinimal.h"
#include "AlienAITypes.generated.h"

UENUM(BlueprintType)
enum class EAlienAIState : uint8
{
	Patrullar           UMETA(DisplayName = "Patrullar"),
	Investigar          UMETA(DisplayName = "Investigar"),
	CorrerHaciaAlarma   UMETA(DisplayName = "Correr Hacia Alarma"),
	AlertaRoja          UMETA(DisplayName = "Alerta Roja")
};

/** Nombres de las claves del Blackboard. BB_Alien debe declararlas con estos nombres exactos. */
namespace AlienBBKeys
{
	inline const FName AlienState(TEXT("AlienState"));                       // Enum (EAlienAIState)
	inline const FName TargetActor(TEXT("TargetActor"));                     // Object (Actor)
	inline const FName InvestigationLocation(TEXT("InvestigationLocation")); // Vector
	inline const FName TargetAlarmConsole(TEXT("TargetAlarmConsole"));       // Object (AlarmConsole)
	inline const FName SuspicionMeter(TEXT("SuspicionMeter"));               // Float
	inline const FName bPlayerIdentified(TEXT("bPlayerIdentified"));         // Bool
	inline const FName bIsAlarmTriggered(TEXT("bIsAlarmTriggered"));         // Bool
	inline const FName bHasSeenCorpse(TEXT("bHasSeenCorpse"));               // Bool
	inline const FName PatrolLocation(TEXT("PatrolLocation"));               // Vector
}
