#include "Gameplay/SecurityTerminal.h"
#include "Gameplay/StationDoor.h"
#include "Gameplay/SmokeBombActor.h"
#include "AI/StealthTarget.h"
#include "Components/StaticMeshComponent.h"
#include "Components/SphereComponent.h"
#include "Components/LightComponent.h"
#include "Perception/AISense_Hearing.h"
#include "Engine/World.h"

ASecurityTerminal::ASecurityTerminal()
{
	PrimaryActorTick.bCanEverTick = true;
	PrimaryActorTick.bStartWithTickEnabled = false;

	TerminalMesh = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("TerminalMesh"));
	RootComponent = TerminalMesh;

	ScreenMesh = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("ScreenMesh"));
	ScreenMesh->SetupAttachment(RootComponent);
	ScreenMesh->SetCollisionEnabled(ECollisionEnabled::NoCollision);

	InteractionVolume = CreateDefaultSubobject<USphereComponent>(TEXT("InteractionVolume"));
	InteractionVolume->SetupAttachment(RootComponent);
	InteractionVolume->SetSphereRadius(150.f);
	InteractionVolume->SetCollisionProfileName(TEXT("OverlapAllDynamic"));

	SteamClass = ASmokeBombActor::StaticClass();
}

bool ASecurityTerminal::IsActionAvailable(ETerminalAction Action) const
{
	switch (Action)
	{
	case ETerminalAction::CutLocalLights:
		return LocalLights.Num() > 0;
	case ETerminalAction::OverrideDoors:
		return !bDoorsOverridden && Doors.Num() > 0;
	case ETerminalAction::SteamPurge:
		return SteamVents.Num() > 0 && GetWorld() && GetWorld()->GetTimeSeconds() - LastSteamTime >= SteamCooldown;
	}
	return false;
}

bool ASecurityTerminal::BeginHack(ETerminalAction Action, AActor* User)
{
	if (!User || IsHacking() || !IsActionAvailable(Action))
	{
		return false;
	}
	if (FVector::Dist(User->GetActorLocation(), GetActorLocation()) > MaxUseDistance)
	{
		return false;
	}

	if (HackDuration <= 0.f)
	{
		ExecuteAction(Action);
		OnHackFinished.Broadcast(Action, true);
		return true;
	}

	HackUser = User;
	HackAction = Action;
	HackElapsed = 0.f;
	SetActorTickEnabled(true);
	OnHackStarted.Broadcast(Action, HackDuration);
	return true;
}

void ASecurityTerminal::CancelHack()
{
	if (IsHacking())
	{
		FailHack();
	}
}

void ASecurityTerminal::Tick(float DeltaSeconds)
{
	Super::Tick(DeltaSeconds);

	if (!IsHacking())
	{
		SetActorTickEnabled(false);
		return;
	}

	const bool bLeft = !IsValid(HackUser) ||
		FVector::Dist(HackUser->GetActorLocation(), GetActorLocation()) > MaxUseDistance;
	const bool bRunning = IsValid(HackUser) && HackUser->Implements<UStealthTarget>() &&
		IStealthTarget::Execute_IsRunning(HackUser);
	if (bLeft || bRunning)
	{
		FailHack();
		return;
	}

	HackElapsed += DeltaSeconds;
	OnHackProgress.Broadcast(FMath::Clamp(HackElapsed / HackDuration, 0.f, 1.f));

	if (HackElapsed >= HackDuration)
	{
		const ETerminalAction Action = HackAction;
		HackUser = nullptr;
		SetActorTickEnabled(false);
		ExecuteAction(Action);
		OnHackFinished.Broadcast(Action, true);
	}
}

void ASecurityTerminal::FailHack()
{
	const ETerminalAction Action = HackAction;
	HackUser = nullptr;
	HackElapsed = 0.f;
	SetActorTickEnabled(false);

	// Pitido de error: la IA lo oye y viene a la terminal.
	UAISense_Hearing::ReportNoiseEvent(GetWorld(), GetActorLocation(), FailNoiseLoudness, this, FailNoiseRange);

	OnHackProgress.Broadcast(0.f);
	OnHackFinished.Broadcast(Action, false);
}

void ASecurityTerminal::ExecuteAction(ETerminalAction Action)
{
	switch (Action)
	{
	case ETerminalAction::CutLocalLights:
	{
		bLightsCut = !bLightsCut; // vuelve a pulsarse para restaurar
		for (AActor* LightActor : LocalLights)
		{
			if (!LightActor)
			{
				continue;
			}
			TArray<ULightComponent*> Lights;
			LightActor->GetComponents<ULightComponent>(Lights);
			for (ULightComponent* Light : Lights)
			{
				Light->SetVisibility(!bLightsCut);
			}
		}
		break;
	}
	case ETerminalAction::OverrideDoors:
		bDoorsOverridden = true;
		for (AStationDoor* Door : Doors)
		{
			if (Door)
			{
				// SetDoorState ignora el bloqueo de Alerta Roja (OpenDoor no).
				Door->SetDoorState(EStationDoorState::Open);
			}
		}
		break;
	case ETerminalAction::SteamPurge:
		LastSteamTime = GetWorld()->GetTimeSeconds();
		if (SteamClass)
		{
			for (AActor* Vent : SteamVents)
			{
				if (!Vent)
				{
					continue;
				}
				FActorSpawnParameters Params;
				Params.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AlwaysSpawn;
				Params.Owner = this;
				if (ASmokeBombActor* Steam = GetWorld()->SpawnActor<ASmokeBombActor>(SteamClass, Vent->GetActorTransform(), Params))
				{
					Steam->DeploySmoke();
				}
			}
		}
		break;
	}
	OnActionExecuted(Action);
}
