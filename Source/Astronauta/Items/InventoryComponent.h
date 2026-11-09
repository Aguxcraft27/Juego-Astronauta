#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "Items/ItemTypes.h"
#include "InventoryComponent.generated.h"

DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FOnResourceQuantityChanged, EResourceType, Type, int32, NewAmount);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FOnGadgetUpdated, int32, SlotIndex, const FGadgetItem&, Item);

/**
 * Componente de inventario táctico limitado para el astronauta.
 * Gestiona recursos de supervivencia y gadgets fabricados.
 */
UCLASS(ClassGroup = (Custom), meta = (BlueprintSpawnableComponent))
class ASTRONAUTA_API UInventoryComponent : public UActorComponent
{
	GENERATED_BODY()

public:
	UInventoryComponent();

	// --- Gestión de Recursos ---
	UFUNCTION(BlueprintCallable, Category = "Astronauta|Inventory")
	void AddResource(EResourceType Type, int32 Amount);

	UFUNCTION(BlueprintCallable, Category = "Astronauta|Inventory")
	bool ConsumeResource(EResourceType Type, int32 Amount);

	UFUNCTION(BlueprintPure, Category = "Astronauta|Inventory")
	int32 GetResourceAmount(EResourceType Type) const;

	UFUNCTION(BlueprintPure, Category = "Astronauta|Inventory")
	bool HasResources(const TMap<EResourceType, int32>& RequiredResources) const;

	// --- Gestión de Gadgets ---
	UFUNCTION(BlueprintCallable, Category = "Astronauta|Inventory")
	bool AddGadget(EGadgetType Type, int32 Quantity = 1);

	UFUNCTION(BlueprintCallable, Category = "Astronauta|Inventory")
	bool ConsumeGadget(EGadgetType Type);

	UFUNCTION(BlueprintPure, Category = "Astronauta|Inventory")
	int32 GetGadgetCount(EGadgetType Type) const;

	UFUNCTION(BlueprintPure, Category = "Astronauta|Inventory")
	const TArray<FGadgetItem>& GetGadgetSlots() const { return GadgetSlots; }

	/** M5 (guardado): estado completo del inventario. */
	const TMap<EResourceType, int32>& GetResources() const { return Resources; }

	void RestoreState(const TMap<EResourceType, int32>& InResources, const TArray<FGadgetItem>& InGadgets)
	{
		Resources = InResources;
		GadgetSlots = InGadgets;
		for (const TPair<EResourceType, int32>& R : Resources)
		{
			OnResourceQuantityChanged.Broadcast(R.Key, R.Value);
		}
		for (int32 Idx = 0; Idx < GadgetSlots.Num(); ++Idx)
		{
			OnGadgetUpdated.Broadcast(Idx, GadgetSlots[Idx]);
		}
	}

	UPROPERTY(BlueprintAssignable, Category = "Astronauta|Inventory")
	FOnResourceQuantityChanged OnResourceQuantityChanged;

	UPROPERTY(BlueprintAssignable, Category = "Astronauta|Inventory")
	FOnGadgetUpdated OnGadgetUpdated;

protected:
	virtual void BeginPlay() override;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Inventory")
	int32 MaxGadgetSlots = 4;

	UPROPERTY(VisibleInstanceOnly, BlueprintReadOnly, Category = "Inventory")
	TMap<EResourceType, int32> Resources;

	UPROPERTY(VisibleInstanceOnly, BlueprintReadOnly, Category = "Inventory")
	TArray<FGadgetItem> GadgetSlots;
};
