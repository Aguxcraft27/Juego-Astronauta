#include "Gameplay/HealthComponent.h"
#include "Gameplay/BloodDropActor.h"
#include "Items/InventoryComponent.h"
#include "Crafting/CraftingComponent.h"
#include "Engine/World.h"

UHealthComponent::UHealthComponent()
{
	PrimaryComponentTick.bCanEverTick = true;
	PrimaryComponentTick.TickInterval = 0.1f;
	BloodDropClass = ABloodDropActor::StaticClass();
}

void UHealthComponent::BeginPlay()
{
	Super::BeginPlay();
	Health = MaxHealth;
	Oxygen = MaxOxygen;
	if (AActor* Owner = GetOwner())
	{
		Owner->OnTakeAnyDamage.AddUniqueDynamic(this, &UHealthComponent::HandleOwnerDamaged);
	}
	OnHealthChanged.Broadcast(Health);
	OnOxygenChanged.Broadcast(Oxygen);
	OnBleedingStateChanged.Broadcast(bIsBleeding);
}

void UHealthComponent::HandleOwnerDamaged(AActor* DamagedActor, float Damage, const UDamageType* DamageType,
	AController* InstigatedBy, AActor* DamageCauser)
{
	ApplyHealthDamage(Damage, DamageCauser);
}

void UHealthComponent::ApplyHealthDamage(float Amount, AActor* Causer)
{
	if (Amount > 0.f && !bIsDead)
	{
		SetHealthInternal(Health - Amount, Causer);
	}
}

void UHealthComponent::Heal(float Amount)
{
	if (Amount > 0.f && !bIsDead)
	{
		SetHealthInternal(Health + Amount, nullptr);
	}
}

bool UHealthComponent::ApplyMedkit()
{
	if (bIsDead || Health >= MaxHealth)
	{
		return false;
	}
	UInventoryComponent* Inv = GetOwner() ? GetOwner()->FindComponentByClass<UInventoryComponent>() : nullptr;
	if (!Inv || !Inv->ConsumeGadget(EGadgetType::Medkit))
	{
		return false;
	}
	Heal(MedkitHealAmount);
	return true;
}

void UHealthComponent::SetVitals(float NewHealth, float NewOxygen)
{
	bIsDead = false;
	SetOxygenInternal(NewOxygen);
	SetHealthInternal(NewHealth, nullptr);
}

void UHealthComponent::SetHealthInternal(float NewHealth, AActor* Causer)
{
	NewHealth = FMath::Clamp(NewHealth, 0.f, MaxHealth);
	if (FMath::IsNearlyEqual(NewHealth, Health))
	{
		return;
	}
	const bool bTookDamage = NewHealth < Health;
	Health = NewHealth;
	OnHealthChanged.Broadcast(Health);
	UpdateBleeding();

	// La asfixia no llega por OnTakeAnyDamage: interrumpimos el crafteo aquí también.
	if (bTookDamage)
	{
		if (UCraftingComponent* Craft = GetOwner()->FindComponentByClass<UCraftingComponent>())
		{
			Craft->InterruptCraft(ECraftInterruptReason::Damaged);
		}
	}

	if (Health <= 0.f && !bIsDead)
	{
		bIsDead = true;
		OnPlayerDied.Broadcast(Causer);
	}
}

void UHealthComponent::SetOxygenInternal(float NewOxygen)
{
	NewOxygen = FMath::Clamp(NewOxygen, 0.f, MaxOxygen);
	if (FMath::Abs(NewOxygen - Oxygen) < 0.01f)
	{
		return;
	}
	Oxygen = NewOxygen;
	OnOxygenChanged.Broadcast(Oxygen);
}

void UHealthComponent::UpdateBleeding()
{
	const bool bShouldBleed = !bIsDead && Health > 0.f && Health < BleedThreshold;
	if (bShouldBleed != bIsBleeding)
	{
		bIsBleeding = bShouldBleed;
		BleedTimer = 0.f;
		OnBleedingStateChanged.Broadcast(bIsBleeding);
	}
}

void UHealthComponent::TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction)
{
	Super::TickComponent(DeltaTime, TickType, ThisTickFunction);
	if (bIsDead)
	{
		return;
	}

	if (IsInVacuum())
	{
		SetOxygenInternal(Oxygen - OxygenDrainRate * DeltaTime);
		if (Oxygen <= 0.f)
		{
			SetHealthInternal(Health - SuffocationDamagePerSecond * DeltaTime, nullptr);
		}
	}
	else if (OxygenRefillRate > 0.f)
	{
		SetOxygenInternal(Oxygen + OxygenRefillRate * DeltaTime);
	}

	if (bIsBleeding && GetOwner())
	{
		const bool bMoving = GetOwner()->GetVelocity().SizeSquared() > 25.f * 25.f;
		BleedTimer += DeltaTime;
		if (BleedTimer >= (bMoving ? BleedDropInterval : BleedDropInterval * 2.f))
		{
			BleedTimer = 0.f;
			SpawnBloodDrop();
		}
	}
}

void UHealthComponent::SpawnBloodDrop()
{
	AActor* Owner = GetOwner();
	if (!Owner || !BloodDropClass)
	{
		return;
	}
	// Al suelo bajo el jugador.
	const FVector Start = Owner->GetActorLocation();
	const FVector End = Start - FVector(0.f, 0.f, 300.f);
	FHitResult Hit;
	FCollisionQueryParams Params(SCENE_QUERY_STAT(BloodDrop), false, Owner);
	const FVector Location = GetWorld()->LineTraceSingleByChannel(Hit, Start, End, ECC_Visibility, Params)
		? Hit.ImpactPoint + FVector(0.f, 0.f, 2.f) : Start;

	FActorSpawnParameters SpawnParams;
	SpawnParams.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AlwaysSpawn;
	GetWorld()->SpawnActor<ABloodDropActor>(BloodDropClass, Location, FRotator::ZeroRotator, SpawnParams);
}
