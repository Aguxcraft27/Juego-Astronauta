#include "Items/InventoryComponent.h"

UInventoryComponent::UInventoryComponent()
{
	PrimaryComponentTick.bCanEverTick = false;

	Resources.Add(EResourceType::Scrap, 0);
	Resources.Add(EResourceType::Chemicals, 0);
	Resources.Add(EResourceType::Batteries, 0);
	Resources.Add(EResourceType::Sensors, 0);
}

void UInventoryComponent::BeginPlay()
{
	Super::BeginPlay();

	GadgetSlots.SetNum(MaxGadgetSlots);
}

void UInventoryComponent::AddResource(EResourceType Type, int32 Amount)
{
	if (Amount <= 0)
	{
		return;
	}

	int32& Current = Resources.FindOrAdd(Type);
	Current += Amount;
	OnResourceQuantityChanged.Broadcast(Type, Current);
}

bool UInventoryComponent::ConsumeResource(EResourceType Type, int32 Amount)
{
	if (Amount <= 0)
	{
		return true;
	}

	int32* Current = Resources.Find(Type);
	if (!Current || *Current < Amount)
	{
		return false;
	}

	*Current -= Amount;
	OnResourceQuantityChanged.Broadcast(Type, *Current);
	return true;
}

int32 UInventoryComponent::GetResourceAmount(EResourceType Type) const
{
	if (const int32* Found = Resources.Find(Type))
	{
		return *Found;
	}
	return 0;
}

bool UInventoryComponent::HasResources(const TMap<EResourceType, int32>& RequiredResources) const
{
	for (const auto& KVP : RequiredResources)
	{
		if (GetResourceAmount(KVP.Key) < KVP.Value)
		{
			return false;
		}
	}
	return true;
}

bool UInventoryComponent::AddGadget(EGadgetType Type, int32 Quantity)
{
	if (Type == EGadgetType::None || Quantity <= 0)
	{
		return false;
	}

	// 1. Intentar apilar en slot existente del mismo tipo
	for (int32 i = 0; i < GadgetSlots.Num(); ++i)
	{
		if (GadgetSlots[i].Type == Type && GadgetSlots[i].Quantity < GadgetSlots[i].MaxStack)
		{
			const int32 CanAdd = FMath::Min(Quantity, GadgetSlots[i].MaxStack - GadgetSlots[i].Quantity);
			GadgetSlots[i].Quantity += CanAdd;
			Quantity -= CanAdd;
			OnGadgetUpdated.Broadcast(i, GadgetSlots[i]);

			if (Quantity <= 0)
			{
				return true;
			}
		}
	}

	// 2. Usar un slot vacío
	for (int32 i = 0; i < GadgetSlots.Num(); ++i)
	{
		if (GadgetSlots[i].Type == EGadgetType::None)
		{
			GadgetSlots[i].Type = Type;
			GadgetSlots[i].Quantity = Quantity;
			OnGadgetUpdated.Broadcast(i, GadgetSlots[i]);
			return true;
		}
	}

	return false; // Inventario lleno
}

bool UInventoryComponent::ConsumeGadget(EGadgetType Type)
{
	for (int32 i = 0; i < GadgetSlots.Num(); ++i)
	{
		if (GadgetSlots[i].Type == Type && GadgetSlots[i].Quantity > 0)
		{
			GadgetSlots[i].Quantity--;
			if (GadgetSlots[i].Quantity <= 0)
			{
				GadgetSlots[i].Type = EGadgetType::None;
			}
			OnGadgetUpdated.Broadcast(i, GadgetSlots[i]);
			return true;
		}
	}
	return false;
}

int32 UInventoryComponent::GetGadgetCount(EGadgetType Type) const
{
	int32 Total = 0;
	for (const FGadgetItem& Item : GadgetSlots)
	{
		if (Item.Type == Type)
		{
			Total += Item.Quantity;
		}
	}
	return Total;
}
