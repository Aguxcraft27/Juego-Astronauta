#include "Crafting/CraftingComponent.h"
#include "Items/InventoryComponent.h"
#include "AI/StealthTarget.h"
#include "GameFramework/Character.h"
#include "GameFramework/CharacterMovementComponent.h"

namespace
{
	FCraftingRecipe MakeRecipe(EGadgetType Result, float Duration,
		std::initializer_list<TPair<EResourceType, int32>> Cost)
	{
		FCraftingRecipe R;
		R.Result = Result;
		R.Duration = Duration;
		for (const TPair<EResourceType, int32>& C : Cost)
		{
			R.Cost.Add(C.Key, C.Value);
		}
		return R;
	}
}

UCraftingComponent::UCraftingComponent()
{
	PrimaryComponentTick.bCanEverTick = true;
	PrimaryComponentTick.bStartWithTickEnabled = false;

	Recipes.Add(MakeRecipe(EGadgetType::Noisemaker, 2.5f, { {EResourceType::Scrap, 2}, {EResourceType::Sensors, 1} }));
	Recipes.Add(MakeRecipe(EGadgetType::EMPMine, 4.0f, { {EResourceType::Scrap, 3}, {EResourceType::Batteries, 2}, {EResourceType::Chemicals, 1} }));
	Recipes.Add(MakeRecipe(EGadgetType::SmokeBomb, 3.0f, { {EResourceType::Chemicals, 2}, {EResourceType::Scrap, 1} }));
	Recipes.Add(MakeRecipe(EGadgetType::Medkit, 2.0f, { {EResourceType::Chemicals, 2}, {EResourceType::Batteries, 1} }));
}

void UCraftingComponent::BeginPlay()
{
	Super::BeginPlay();
	if (AActor* Owner = GetOwner())
	{
		Owner->OnTakeAnyDamage.AddUniqueDynamic(this, &UCraftingComponent::HandleOwnerDamaged);
	}
}

UInventoryComponent* UCraftingComponent::GetInventory() const
{
	return GetOwner() ? GetOwner()->FindComponentByClass<UInventoryComponent>() : nullptr;
}

bool UCraftingComponent::FindRecipe(EGadgetType Gadget, FCraftingRecipe& OutRecipe) const
{
	for (const FCraftingRecipe& R : Recipes)
	{
		if (R.Result == Gadget)
		{
			OutRecipe = R;
			return true;
		}
	}
	return false;
}

bool UCraftingComponent::CanCraft(EGadgetType Gadget) const
{
	FCraftingRecipe Recipe;
	const UInventoryComponent* Inv = GetInventory();
	return Inv && FindRecipe(Gadget, Recipe) && Inv->HasResources(Recipe.Cost);
}

bool UCraftingComponent::StartCraft(EGadgetType Gadget)
{
	if (IsCrafting() || !CanCraft(Gadget))
	{
		return false;
	}

	ECraftInterruptReason Reason;
	if (CheckInterruptConditions(Reason))
	{
		return false; // no se puede empezar corriendo o en el aire
	}

	FCraftingRecipe Recipe;
	FindRecipe(Gadget, Recipe);

	CurrentGadget = Gadget;
	CraftDuration = Recipe.Duration;
	CraftElapsed = 0.f;
	SetComponentTickEnabled(true);

	OnCraftStarted.Broadcast(Gadget, CraftDuration);
	OnCraftProgress.Broadcast(0.f);
	return true;
}

float UCraftingComponent::GetCraftProgress() const
{
	return IsCrafting() && CraftDuration > 0.f ? FMath::Clamp(CraftElapsed / CraftDuration, 0.f, 1.f) : 0.f;
}

bool UCraftingComponent::CheckInterruptConditions(ECraftInterruptReason& OutReason) const
{
	const AActor* Owner = GetOwner();
	if (!Owner)
	{
		return false;
	}

	if (Owner->Implements<UStealthTarget>() && IStealthTarget::Execute_IsRunning(Owner))
	{
		OutReason = ECraftInterruptReason::Running;
		return true;
	}

	if (const ACharacter* Char = Cast<ACharacter>(Owner))
	{
		if (Char->GetCharacterMovement() && Char->GetCharacterMovement()->IsFalling())
		{
			OutReason = ECraftInterruptReason::Jumping;
			return true;
		}
	}
	return false;
}

void UCraftingComponent::TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction)
{
	Super::TickComponent(DeltaTime, TickType, ThisTickFunction);

	if (!IsCrafting())
	{
		SetComponentTickEnabled(false);
		return;
	}

	ECraftInterruptReason Reason;
	if (CheckInterruptConditions(Reason))
	{
		InterruptCraft(Reason);
		return;
	}

	CraftElapsed += DeltaTime;
	OnCraftProgress.Broadcast(GetCraftProgress());

	if (CraftElapsed >= CraftDuration)
	{
		FinishCraft();
	}
}

void UCraftingComponent::FinishCraft()
{
	const EGadgetType Gadget = CurrentGadget;
	UInventoryComponent* Inv = GetInventory();
	FCraftingRecipe Recipe;

	if (!Inv || !FindRecipe(Gadget, Recipe) || !Inv->HasResources(Recipe.Cost))
	{
		InterruptCraft(ECraftInterruptReason::NoResources);
		return;
	}

	// Primero el hueco del gadget: si el inventario está lleno no se gastan materiales.
	if (!Inv->AddGadget(Gadget, 1))
	{
		InterruptCraft(ECraftInterruptReason::InventoryFull);
		return;
	}

	for (const TPair<EResourceType, int32>& Cost : Recipe.Cost)
	{
		Inv->ConsumeResource(Cost.Key, Cost.Value);
	}

	ResetCraft();
	OnCraftProgress.Broadcast(1.f);
	OnCraftCompleted.Broadcast(Gadget);
}

void UCraftingComponent::InterruptCraft(ECraftInterruptReason Reason)
{
	if (!IsCrafting())
	{
		return;
	}
	ResetCraft();
	OnCraftProgress.Broadcast(0.f);
	OnCraftInterrupted.Broadcast(Reason);
}

void UCraftingComponent::ResetCraft()
{
	CurrentGadget = EGadgetType::None;
	CraftElapsed = 0.f;
	CraftDuration = 0.f;
	SetComponentTickEnabled(false);
}

void UCraftingComponent::HandleOwnerDamaged(AActor* DamagedActor, float Damage, const UDamageType* DamageType,
	AController* InstigatedBy, AActor* DamageCauser)
{
	if (Damage > 0.f)
	{
		InterruptCraft(ECraftInterruptReason::Damaged);
	}
}
