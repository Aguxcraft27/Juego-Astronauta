#include "Gameplay/SaveTerminal.h"
#include "Gameplay/StationSaveGame.h"
#include "AI/AlienCharacter.h"
#include "AI/AlienAIController.h"
#include "Components/StaticMeshComponent.h"
#include "Components/SphereComponent.h"
#include "Kismet/GameplayStatics.h"
#include "EngineUtils.h"

ASaveTerminal::ASaveTerminal()
{
	PrimaryActorTick.bCanEverTick = true;
	PrimaryActorTick.bStartWithTickEnabled = false;

	TerminalMesh = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("TerminalMesh"));
	RootComponent = TerminalMesh;

	InteractionVolume = CreateDefaultSubobject<USphereComponent>(TEXT("InteractionVolume"));
	InteractionVolume->SetupAttachment(RootComponent);
	InteractionVolume->SetSphereRadius(150.f);
	InteractionVolume->SetCollisionProfileName(TEXT("OverlapAllDynamic"));
}

bool ASaveTerminal::IsHostileNearby() const
{
	const float RadiusSq = FMath::Square(HostileCheckRadius);
	for (TActorIterator<AAlienCharacter> It(GetWorld()); It; ++It)
	{
		if (FVector::DistSquared(It->GetActorLocation(), GetActorLocation()) > RadiusSq)
		{
			continue;
		}
		if (const AAlienAIController* AI = Cast<AAlienAIController>(It->GetController()))
		{
			if (AI->IsInActivePursuit())
			{
				return true;
			}
		}
	}
	return false;
}

bool ASaveTerminal::BeginSave(AActor* User)
{
	if (!User || IsSaving() || FVector::Dist(User->GetActorLocation(), GetActorLocation()) > MaxUseDistance)
	{
		return false;
	}
	if (IsHostileNearby())
	{
		OnHostileWarning();
		OnSaveFailed.Broadcast(ESaveFailReason::HostileNearby);
		return false;
	}

	SaveUser = User;
	Elapsed = 0.f;
	SetActorTickEnabled(true);
	OnSaveStarted.Broadcast(CardInsertDuration);
	return true;
}

void ASaveTerminal::CancelSave()
{
	if (IsSaving())
	{
		Fail(ESaveFailReason::Interrupted);
	}
}

void ASaveTerminal::Tick(float DeltaSeconds)
{
	Super::Tick(DeltaSeconds);
	if (!IsSaving())
	{
		SetActorTickEnabled(false);
		return;
	}

	if (!IsValid(SaveUser) || FVector::Dist(SaveUser->GetActorLocation(), GetActorLocation()) > MaxUseDistance)
	{
		Fail(ESaveFailReason::Interrupted);
		return;
	}

	Elapsed += DeltaSeconds;
	OnSaveProgress.Broadcast(CardInsertDuration > 0.f ? FMath::Clamp(Elapsed / CardInsertDuration, 0.f, 1.f) : 1.f);
	if (Elapsed >= CardInsertDuration)
	{
		Complete();
	}
}

void ASaveTerminal::Complete()
{
	SaveUser = nullptr;
	SetActorTickEnabled(false);

	// El jugador estuvo expuesto 2.5 s: si en ese tiempo llegó un hostil, no se guarda.
	if (IsHostileNearby())
	{
		OnHostileWarning();
		OnSaveFailed.Broadcast(ESaveFailReason::HostileNearby);
		return;
	}

	UStationSaveGame* Save = Cast<UStationSaveGame>(UGameplayStatics::CreateSaveGameObject(UStationSaveGame::StaticClass()));
	Save->CaptureFrom(GetWorld());
	if (UGameplayStatics::SaveGameToSlot(Save, SaveSlot, 0))
	{
		OnSaveSuccess.Broadcast();
	}
	else
	{
		OnSaveFailed.Broadcast(ESaveFailReason::WriteFailed);
	}
}

void ASaveTerminal::Fail(ESaveFailReason Reason)
{
	SaveUser = nullptr;
	Elapsed = 0.f;
	SetActorTickEnabled(false);
	OnSaveProgress.Broadcast(0.f);
	OnSaveFailed.Broadcast(Reason);
}

bool ASaveTerminal::LoadStationGame(UObject* WorldContextObject)
{
	if (!UGameplayStatics::DoesSaveGameExist(UStationSaveGame::DefaultSlot, 0))
	{
		return false;
	}
	const UStationSaveGame* Save = Cast<UStationSaveGame>(UGameplayStatics::LoadGameFromSlot(UStationSaveGame::DefaultSlot, 0));
	if (!Save)
	{
		return false;
	}
	Save->ApplyTo(WorldContextObject);
	return true;
}
