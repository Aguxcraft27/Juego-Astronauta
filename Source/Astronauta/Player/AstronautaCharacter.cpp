#include "Player/AstronautaCharacter.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "Perception/AISense_Hearing.h"
#include "Gameplay/HidingSpot.h"
#include "Gameplay/ThrowableDistractionActor.h"
#include "Gameplay/VentDuct.h"
#include "Gameplay/VentGrate.h"
#include "Components/SpotLightComponent.h"
#include "Components/CapsuleComponent.h"
#include "Components/SkeletalMeshComponent.h"
#include "Engine/World.h"
#include "Items/InventoryComponent.h"
#include "Crafting/CraftingComponent.h"
#include "Gameplay/HealthComponent.h"
#include "Gadgets/MotionTrackerComponent.h"

AAstronautaCharacter::AAstronautaCharacter()
{
	PrimaryActorTick.bCanEverTick = true;
	GetCharacterMovement()->GetNavAgentPropertiesRef().bCanCrouch = true;
	GetCharacterMovement()->MaxWalkSpeed = WalkSpeed;
	GetCharacterMovement()->MaxWalkSpeedCrouched = CrouchSpeed;

	FlashlightComponent = CreateDefaultSubobject<USpotLightComponent>(TEXT("Flashlight"));
	FlashlightComponent->SetupAttachment(GetCapsuleComponent());
	FlashlightComponent->SetRelativeLocation(FVector(30.f, 0.f, 60.f));
	FlashlightComponent->SetAttenuationRadius(1500.f);
	FlashlightComponent->SetInnerConeAngle(12.f);
	FlashlightComponent->SetOuterConeAngle(25.f);
	FlashlightComponent->SetIntensity(5000.f);
	FlashlightComponent->SetVisibility(false);

	InventoryComponent = CreateDefaultSubobject<UInventoryComponent>(TEXT("InventoryComponent"));
	CraftingComponent = CreateDefaultSubobject<UCraftingComponent>(TEXT("CraftingComponent"));
	HealthComponent = CreateDefaultSubobject<UHealthComponent>(TEXT("HealthComponent"));
	MotionTrackerComponent = CreateDefaultSubobject<UMotionTrackerComponent>(TEXT("MotionTrackerComponent"));
}

void AAstronautaCharacter::BeginPlay()
{
	Super::BeginPlay();
	CurrentCamouflageBattery = MaxCamouflageBattery;
	BroadcastBatteryIfChanged();
	OnThrowableCountChanged.Broadcast(ThrowablesLeft);
	OnFlashlightToggled.Broadcast(IsFlashlightOn());
	GetCharacterMovement()->MaxWalkSpeedCrouched = CrouchSpeed;
	RefreshMaxSpeed();
}

void AAstronautaCharacter::StartSprint()
{
	if (IsInVentDuct() || IsHiddenInSpot())
	{
		return;
	}
	if (bIsCrouched)
	{
		UnCrouch();
	}
	bWantsToSprint = true;
	RefreshMaxSpeed();
}

void AAstronautaCharacter::StopSprint()
{
	bWantsToSprint = false;
	RefreshMaxSpeed();
}

void AAstronautaCharacter::ToggleCrouch()
{
	if (IsInVentDuct())
	{
		return; // dentro del conducto no se puede levantar
	}
	if (bIsCrouched)
	{
		UnCrouch();
	}
	else
	{
		bWantsToSprint = false;
		RefreshMaxSpeed();
		Crouch();
	}
}

void AAstronautaCharacter::SetCamouflageActive(bool bActive)
{
	if (bActive && CurrentCamouflageBattery <= 0.f)
	{
		return;
	}

	if (bCamouflageActive != bActive)
	{
		bCamouflageActive = bActive;
		OnCamouflageChanged(bActive);
	}
}

bool AAstronautaCharacter::IsRunning_Implementation() const
{
	if (IsHiddenInSpot())
	{
		return false;
	}
	// Solo cuenta como carrera si realmente se mueve por encima de la velocidad de andar.
	return bWantsToSprint && !bIsCrouched && GetVelocity().Size2D() > WalkSpeed + 10.f;
}

void AAstronautaCharacter::RefreshMaxSpeed()
{
	GetCharacterMovement()->MaxWalkSpeed = bWantsToSprint ? SprintSpeed : WalkSpeed;
}

void AAstronautaCharacter::EmitNoise(float Loudness, float MaxRange)
{
	LastNoiseTime = GetWorld() ? GetWorld()->GetTimeSeconds() : 0.f;
	UAISense_Hearing::ReportNoiseEvent(this, GetActorLocation(), Loudness, this, MaxRange);
}

void AAstronautaCharacter::Tick(float DeltaSeconds)
{
	Super::Tick(DeltaSeconds);

	// Gestión de batería de camuflaje
	if (bCamouflageActive)
	{
		CurrentCamouflageBattery = FMath::Max(0.f, CurrentCamouflageBattery - CamouflageDrainRate * DeltaSeconds);
		if (CurrentCamouflageBattery <= 0.f)
		{
			SetCamouflageActive(false);
			// Resolución del Lead (M2): el agotamiento hace ruido, que es lo que delata al jugador escondido.
			EmitNoise(CamouflageDepletedLoudness, CamouflageDepletedNoiseRange);
			OnCamouflageDepleted();
		}
	}
	else if (CurrentCamouflageBattery < MaxCamouflageBattery)
	{
		CurrentCamouflageBattery = FMath::Min(MaxCamouflageBattery, CurrentCamouflageBattery + CamouflageRechargeRate * DeltaSeconds);
	}
	BroadcastBatteryIfChanged();

	const bool bMovingOnGround = GetCharacterMovement()->IsMovingOnGround() && GetVelocity().Size2D() > 10.f;
	if (!bMovingOnGround || bIsCrouched)
	{
		FootstepTimer = 0.f;
		return;
	}

	const bool bRunning = IStealthTarget::Execute_IsRunning(this);
	FootstepTimer += DeltaSeconds;
	const float Interval = bRunning ? FootstepInterval * 0.5f : FootstepInterval;
	if (FootstepTimer >= Interval)
	{
		FootstepTimer = 0.f;
		const float Modifier = IStealthTarget::Execute_GetLoudnessModifier(this);
		EmitNoise((bRunning ? SprintLoudness : WalkLoudness) * Modifier,
		          (bRunning ? SprintNoiseRange : WalkNoiseRange) * Modifier);
	}
}

// ---------------------------------------------------------------------------
// Escondites
// ---------------------------------------------------------------------------

void AAstronautaCharacter::InteractHidingSpot()
{
	if (AHidingSpot* Spot = CurrentHidingSpot.Get())
	{
		Spot->ExitHidingSpot();
		return;
	}

	TArray<AActor*> Spots;
	GetOverlappingActors(Spots, AHidingSpot::StaticClass());
	AHidingSpot* Nearest = nullptr;
	double BestDistSq = TNumericLimits<double>::Max();
	for (AActor* Actor : Spots)
	{
		const double DistSq = FVector::DistSquared(GetActorLocation(), Actor->GetActorLocation());
		if (DistSq < BestDistSq)
		{
			BestDistSq = DistSq;
			Nearest = Cast<AHidingSpot>(Actor);
		}
	}
	if (Nearest)
	{
		Nearest->EnterHidingSpot(this);
	}
}

void AAstronautaCharacter::EnterHiding(AHidingSpot* Spot, const FTransform& HideTransform)
{
	CurrentHidingSpot = Spot;
	bWantsToSprint = false;
	if (bIsCrouched)
	{
		UnCrouch();
	}
	GetCharacterMovement()->StopMovementImmediately();
	GetCharacterMovement()->DisableMovement();
	// Sin colisión: los aliens no chocan con él y la traza de visión no lo alcanza (la malla del escondite la corta).
	SetActorEnableCollision(false);
	SetActorLocationAndRotation(HideTransform.GetLocation(), HideTransform.GetRotation(), false, nullptr, ETeleportType::TeleportPhysics);
	GetMesh()->SetVisibility(false, true);
	FootstepTimer = 0.f;
}

void AAstronautaCharacter::ExitHiding(const FTransform& ExitTransform)
{
	CurrentHidingSpot = nullptr;
	SetActorLocationAndRotation(ExitTransform.GetLocation(), ExitTransform.GetRotation(), false, nullptr, ETeleportType::TeleportPhysics);
	SetActorEnableCollision(true);
	GetCharacterMovement()->SetMovementMode(MOVE_Walking);
	GetMesh()->SetVisibility(true, true);
	RefreshMaxSpeed();
}

// ---------------------------------------------------------------------------
// Distracciones
// ---------------------------------------------------------------------------

AThrowableDistractionActor* AAstronautaCharacter::ThrowDistraction()
{
	if (!ThrowableClass || ThrowablesLeft == 0 || IsHiddenInSpot())
	{
		return nullptr;
	}

	const FRotator Aim = GetControlRotation();
	const FVector SpawnLocation = GetActorLocation() + Aim.Vector() * 80.f + FVector(0.f, 0.f, 50.f);

	FActorSpawnParameters Params;
	Params.Owner = this;
	Params.Instigator = this;
	Params.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AdjustIfPossibleButAlwaysSpawn;

	AThrowableDistractionActor* Throwable = GetWorld()->SpawnActor<AThrowableDistractionActor>(ThrowableClass, SpawnLocation, Aim, Params);
	if (Throwable)
	{
		Throwable->Launch(Aim.Vector() * ThrowSpeed + GetVelocity(), this);
		if (ThrowablesLeft > 0)
		{
			--ThrowablesLeft;
			OnThrowableCountChanged.Broadcast(ThrowablesLeft);
		}
	}
	return Throwable;
}

// ---------------------------------------------------------------------------
// Linterna
// ---------------------------------------------------------------------------

void AAstronautaCharacter::ToggleFlashlight()
{
	SetFlashlightOn(!IsFlashlightOn());
}

void AAstronautaCharacter::ToggleMotionTracker()
{
	if (MotionTrackerComponent)
	{
		MotionTrackerComponent->ToggleTracker();
	}
}

void AAstronautaCharacter::SetFlashlightOn(bool bOn)
{
	if (IsFlashlightOn() == bOn)
	{
		return;
	}
	FlashlightComponent->SetVisibility(bOn);
	OnFlashlightToggled.Broadcast(bOn);
}

bool AAstronautaCharacter::IsFlashlightOn() const
{
	return FlashlightComponent && FlashlightComponent->IsVisible();
}

bool AAstronautaCharacter::GetFlashlightBeam_Implementation(FVector& Origin, FVector& Direction, float& Range, float& HalfAngleDegrees) const
{
	if (!IsFlashlightOn() || IsHiddenInSpot())
	{
		return false;
	}
	Origin = FlashlightComponent->GetComponentLocation();
	Direction = FlashlightComponent->GetForwardVector();
	Range = FMath::Min(FlashlightRange, FlashlightComponent->AttenuationRadius);
	HalfAngleDegrees = FlashlightComponent->OuterConeAngle;
	return true;
}

// ---------------------------------------------------------------------------
// Conductos y rejillas
// ---------------------------------------------------------------------------

void AAstronautaCharacter::SetInVentDuct(AVentDuct* Duct)
{
	CurrentVentDuct = Duct;
	if (Duct)
	{
		bWantsToSprint = false;
		RefreshMaxSpeed();
		Crouch();
	}
	else
	{
		UnCrouch(); // si el techo no lo permite, el CharacterMovement lo mantiene agachado
	}
}

AVentGrate* AAstronautaCharacter::FindOverlappingGrate() const
{
	TArray<AActor*> Grates;
	GetOverlappingActors(Grates, AVentGrate::StaticClass());
	return Grates.Num() > 0 ? Cast<AVentGrate>(Grates[0]) : nullptr;
}

void AAstronautaCharacter::StartRemoveGrate()
{
	if (AVentGrate* Grate = FindOverlappingGrate())
	{
		Grate->StartQuietRemoval(this);
	}
}

void AAstronautaCharacter::CancelRemoveGrate()
{
	if (AVentGrate* Grate = FindOverlappingGrate())
	{
		Grate->CancelQuietRemoval(this);
	}
}

void AAstronautaCharacter::KickGrate()
{
	if (AVentGrate* Grate = FindOverlappingGrate())
	{
		Grate->BreakGrate(this);
	}
}

void AAstronautaCharacter::BroadcastBatteryIfChanged()
{
	const float Percent = GetCamouflageBatteryPercent();
	if (!FMath::IsNearlyEqual(Percent, LastBroadcastBatteryPercent, 0.001f))
	{
		LastBroadcastBatteryPercent = Percent;
		OnCamouflageBatteryUpdated.Broadcast(Percent);
	}
}
