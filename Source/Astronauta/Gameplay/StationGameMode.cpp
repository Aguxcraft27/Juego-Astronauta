#include "Gameplay/StationGameMode.h"
#include "Gameplay/StationGameState.h"
#include "Gameplay/StationSaveGame.h"
#include "Gameplay/SaveTerminal.h"
#include "Gameplay/HealthComponent.h"
#include "Player/AstronautaCharacter.h"
#include "Kismet/GameplayStatics.h"
#include "GameFramework/PlayerController.h"
#include "TimerManager.h"
#include "Engine/World.h"

AStationGameMode::AStationGameMode()
{
	GameStateClass = AStationGameState::StaticClass();
	DefaultPawnClass = AAstronautaCharacter::StaticClass(); // sustituir por BP_Astronauta en un BP hijo del GameMode
}

void AStationGameMode::BeginPlay()
{
	Super::BeginPlay();

	if (AStationGameState* GS = GetGameState<AStationGameState>())
	{
		GS->OnPlayerCaptured.AddUniqueDynamic(this, &AStationGameMode::HandlePlayerCaptured);
	}

	// Un tick después: garantiza que el pawn y los BeginPlay de puertas / GameState ya corrieron.
	if (UGameplayStatics::HasOption(OptionsString, TEXT("load")))
	{
		GetWorldTimerManager().SetTimerForNextTick(this, &AStationGameMode::ApplySaveIfRequested);
	}
}

void AStationGameMode::ApplySaveIfRequested()
{
	if (!ASaveTerminal::LoadStationGame(this))
	{
		UE_LOG(LogTemp, Warning, TEXT("StationGameMode: ?load=1 pero no hay partida en el slot %s"), *UStationSaveGame::DefaultSlot);
	}
}

void AStationGameMode::HandleStartingNewPlayer_Implementation(APlayerController* NewPlayer)
{
	Super::HandleStartingNewPlayer_Implementation(NewPlayer);

	if (APawn* Pawn = NewPlayer ? NewPlayer->GetPawn() : nullptr)
	{
		if (UHealthComponent* Health = Pawn->FindComponentByClass<UHealthComponent>())
		{
			Health->OnPlayerDied.AddUniqueDynamic(this, &AStationGameMode::HandlePlayerDied);
		}
	}
}

void AStationGameMode::HandlePlayerCaptured(AActor* Player, AActor* CapturedBy)
{
	TriggerGameOver(EGameOverCause::Captured, CapturedBy);
}

void AStationGameMode::HandlePlayerDied(AActor* Killer)
{
	TriggerGameOver(EGameOverCause::Died, Killer);
}

void AStationGameMode::TriggerGameOver(EGameOverCause Cause, AActor* Instigator)
{
	if (bGameOver)
	{
		return; // captura y muerte en el mismo frame: solo la primera cuenta
	}
	bGameOver = true;
	PendingCause = Cause;
	PendingInstigator = Instigator;

	if (APlayerController* PC = UGameplayStatics::GetPlayerController(this, 0))
	{
		if (APawn* Pawn = PC->GetPawn())
		{
			Pawn->DisableInput(PC);
		}
		PC->SetIgnoreMoveInput(true);
		PC->SetIgnoreLookInput(true);
	}

	if (GameOverDelay > 0.f)
	{
		GetWorldTimerManager().SetTimer(GameOverTimer, this, &AStationGameMode::ShowGameOverScreen, GameOverDelay, false);
	}
	else
	{
		ShowGameOverScreen();
	}
}

void AStationGameMode::ShowGameOverScreen()
{
	if (APlayerController* PC = UGameplayStatics::GetPlayerController(this, 0))
	{
		// La UI de Game Over necesita cursor; el BP crea el widget.
		PC->SetShowMouseCursor(true);
		PC->SetInputMode(FInputModeUIOnly());
	}
	OnGameOverScreenRequested(PendingCause, PendingInstigator.Get());
}

void AStationGameMode::ReloadLastSave()
{
	const bool bHasSave = UGameplayStatics::DoesSaveGameExist(UStationSaveGame::DefaultSlot, 0);
	const FName Level(*UGameplayStatics::GetCurrentLevelName(this, true));
	UGameplayStatics::OpenLevel(this, Level, true, bHasSave ? TEXT("load=1") : TEXT(""));
}

void AStationGameMode::RestartFromLastCheckpoint(APlayerController* PC)
{
	if (PC)
	{
		PC->SetShowMouseCursor(false);
		PC->SetInputMode(FInputModeGameOnly());
	}
	ReloadLastSave();
}
