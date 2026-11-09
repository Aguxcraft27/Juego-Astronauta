#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "Items/ItemTypes.h"
#include "CraftingComponent.generated.h"

class UInventoryComponent;

UENUM(BlueprintType)
enum class ECraftInterruptReason : uint8
{
	Cancelled  UMETA(DisplayName = "Cancelado"),
	Running    UMETA(DisplayName = "Correr"),
	Jumping    UMETA(DisplayName = "Saltar / caer"),
	Damaged    UMETA(DisplayName = "Golpe recibido"),
	NoResources UMETA(DisplayName = "Sin materiales"),
	InventoryFull UMETA(DisplayName = "Inventario lleno")
};

USTRUCT(BlueprintType)
struct ASTRONAUTA_API FCraftingRecipe
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Crafting")
	EGadgetType Result = EGadgetType::None;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Crafting")
	TMap<EResourceType, int32> Cost;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Crafting", meta = (ClampMin = "0.1"))
	float Duration = 2.f;
};

DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FOnCraftStarted, EGadgetType, Gadget, float, Duration);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnCraftProgress, float, Percent01);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnCraftCompleted, EGadgetType, Gadget);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnCraftInterrupted, ECraftInterruptReason, Reason);

/**
 * Fabricación en tiempo real. Los materiales se comprueban al empezar y se consumen SOLO al completar:
 * correr, saltar/caer o recibir daño durante el proceso lo interrumpe sin gastar nada.
 */
UCLASS(ClassGroup = (Custom), meta = (BlueprintSpawnableComponent))
class ASTRONAUTA_API UCraftingComponent : public UActorComponent
{
	GENERATED_BODY()

public:
	UCraftingComponent();

	UFUNCTION(BlueprintCallable, Category = "Astronauta|Crafting")
	bool StartCraft(EGadgetType Gadget);

	UFUNCTION(BlueprintCallable, Category = "Astronauta|Crafting")
	void CancelCraft() { InterruptCraft(ECraftInterruptReason::Cancelled); }

	/** Llamar desde fuera si hay otra causa de interrupción (p. ej. una animación de golpe). */
	UFUNCTION(BlueprintCallable, Category = "Astronauta|Crafting")
	void InterruptCraft(ECraftInterruptReason Reason);

	UFUNCTION(BlueprintPure, Category = "Astronauta|Crafting")
	bool CanCraft(EGadgetType Gadget) const;

	UFUNCTION(BlueprintPure, Category = "Astronauta|Crafting")
	bool IsCrafting() const { return CurrentGadget != EGadgetType::None; }

	UFUNCTION(BlueprintPure, Category = "Astronauta|Crafting")
	float GetCraftProgress() const;

	UFUNCTION(BlueprintPure, Category = "Astronauta|Crafting")
	bool FindRecipe(EGadgetType Gadget, FCraftingRecipe& OutRecipe) const;

	UPROPERTY(BlueprintAssignable, Category = "Astronauta|Crafting")
	FOnCraftStarted OnCraftStarted;

	UPROPERTY(BlueprintAssignable, Category = "Astronauta|Crafting")
	FOnCraftProgress OnCraftProgress;

	UPROPERTY(BlueprintAssignable, Category = "Astronauta|Crafting")
	FOnCraftCompleted OnCraftCompleted;

	UPROPERTY(BlueprintAssignable, Category = "Astronauta|Crafting")
	FOnCraftInterrupted OnCraftInterrupted;

	/** Recetas (se rellenan con los valores del M4 en el constructor; editables en el BP). */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Crafting")
	TArray<FCraftingRecipe> Recipes;

protected:
	virtual void BeginPlay() override;
	virtual void TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction) override;

	UFUNCTION()
	void HandleOwnerDamaged(AActor* DamagedActor, float Damage, const class UDamageType* DamageType,
		class AController* InstigatedBy, AActor* DamageCauser);

private:
	UInventoryComponent* GetInventory() const;
	bool CheckInterruptConditions(ECraftInterruptReason& OutReason) const;
	void FinishCraft();
	void ResetCraft();

	EGadgetType CurrentGadget = EGadgetType::None;
	float CraftDuration = 0.f;
	float CraftElapsed = 0.f;
};
