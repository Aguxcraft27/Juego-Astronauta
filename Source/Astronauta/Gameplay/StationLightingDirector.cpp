#include "Gameplay/StationLightingDirector.h"
#include "Gameplay/StationGameState.h"
#include "Components/AudioComponent.h"
#include "Components/LightComponent.h"
#include "Sound/SoundBase.h"
#include "Sound/SoundAttenuation.h"
#include "Engine/World.h"
#include "TimerManager.h"

AStationLightingDirector::AStationLightingDirector()
{
	PrimaryActorTick.bCanEverTick = false;

	RootComponent = CreateDefaultSubobject<USceneComponent>(TEXT("Root"));
	SirenAudio = CreateDefaultSubobject<UAudioComponent>(TEXT("SirenAudio"));
	SirenAudio->SetupAttachment(RootComponent);
	SirenAudio->bAutoActivate = false;
	SirenAudio->bAllowSpatialization = true;
}

void AStationLightingDirector::BeginPlay()
{
	Super::BeginPlay();

	if (SirenSound)
	{
		SirenAudio->SetSound(SirenSound);
	}
	if (SirenAttenuation)
	{
		SirenAudio->AttenuationSettings = SirenAttenuation;
	}

	if (AStationGameState* GS = GetWorld()->GetGameState<AStationGameState>())
	{
		GS->OnRedAlert.AddUniqueDynamic(this, &AStationLightingDirector::HandleRedAlert);
		Mode = GS->IsAlarmTriggered() ? EStationLightingMode::RedAlert : EStationLightingMode::Normal;
	}
	ApplyMode();
}

void AStationLightingDirector::HandleRedAlert(AActor* AlarmInstigator)
{
	SetLightingMode(EStationLightingMode::RedAlert);
}

void AStationLightingDirector::SetLightingMode(EStationLightingMode NewMode)
{
	if (Mode == NewMode)
	{
		return;
	}
	Mode = NewMode;
	ApplyMode();
}

void AStationLightingDirector::ApplyMode()
{
	FTimerManager& Timers = GetWorldTimerManager();
	Timers.ClearTimer(BlinkTimer);

	const bool bRedAlert = Mode == EStationLightingMode::RedAlert;

	for (AActor* Light : NormalLights)
	{
		SetActorLightsVisible(Light, !bRedAlert);
	}

	for (AActor* Beacon : EmergencyLights)
	{
		if (!Beacon)
		{
			continue;
		}
		TArray<ULightComponent*> Lights;
		Beacon->GetComponents<ULightComponent>(Lights);
		for (ULightComponent* Light : Lights)
		{
			if (bRedAlert)
			{
				Light->SetLightColor(EmergencyColor);
			}
			Light->SetVisibility(bRedAlert);
		}
	}
	bBeaconsOn = bRedAlert;

	if (bRedAlert)
	{
		if (BeaconBlinkRate > 0.f)
		{
			Timers.SetTimer(BlinkTimer, this, &AStationLightingDirector::ToggleBeacons, 0.5f / BeaconBlinkRate, true);
		}
		if (SirenAudio->Sound && !SirenAudio->IsPlaying())
		{
			SirenAudio->Play();
		}
	}
	else
	{
		SirenAudio->Stop();
	}

	OnLightingModeChanged.Broadcast(Mode);
	OnLightingModeApplied(Mode);
}

void AStationLightingDirector::ToggleBeacons()
{
	bBeaconsOn = !bBeaconsOn;
	for (AActor* Beacon : EmergencyLights)
	{
		SetActorLightsVisible(Beacon, bBeaconsOn);
	}
}

void AStationLightingDirector::SetActorLightsVisible(AActor* Actor, bool bVisible)
{
	if (!Actor)
	{
		return;
	}
	TArray<ULightComponent*> Lights;
	Actor->GetComponents<ULightComponent>(Lights);
	for (ULightComponent* Light : Lights)
	{
		Light->SetVisibility(bVisible);
	}
}
