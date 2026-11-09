#include "AI/AlienCharacter.h"
#include "AI/AlienAIController.h"
#include "GameFramework/CharacterMovementComponent.h"

AAlienCharacter::AAlienCharacter()
{
	AIControllerClass = AAlienAIController::StaticClass();
	AutoPossessAI = EAutoPossessAI::PlacedInWorldOrSpawned;

	bUseControllerRotationYaw = false;
	GetCharacterMovement()->bOrientRotationToMovement = true;
	GetCharacterMovement()->bUseControllerDesiredRotation = true; // necesario para que SetFocalPoint gire al alien
	GetCharacterMovement()->RotationRate = FRotator(0.f, 360.f, 0.f);
}
