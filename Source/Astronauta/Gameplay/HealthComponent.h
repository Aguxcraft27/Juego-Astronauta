#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "HealthComponent.generated.h"

class ABloodDropActor;

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnHealthChanged, float, NewHealth);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnOxygenChanged, float, NewOxygen);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnBleedingStateChanged, bool, bIsBleeding);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnPlayerDied, AActor*, Killer);

/**
 * Salud, oxígeno y desangrado del astronauta.
 * - El daño llega por OnTakeAnyDamage del dueño (UGameplayStatics::ApplyDamage).
 * - Oxígeno: decae en vacío (AVacuumZone llama a EnterVacuum/ExitVacuum); a 0 quita salud.
 * - Salud < BleedThreshold: deja gotas de sangre (ABloodDropActor) que la IA ve y sigue.
 */
UCLASS(ClassGroup = (Custom), meta = (BlueprintSpawnableComponent))
class ASTRONAUTA_API UHealthComponent : public UActorComponent
{
	GENERATED_BODY()

public:
	UHealthComponent();

	UFUNCTION(BlueprintCallable, Category = "Astronauta|Health")
	void ApplyHealthDamage(float Amount, AActor* Causer = nullptr);

	UFUNCTION(BlueprintCallable, Category = "Astronauta|Health")
	void Heal(float Amount);

	/** Consume un Medkit del inventario y cura. Devuelve false si no hay o la salud está llena. */
	UFUNCTION(BlueprintCallable, Category = "Astronauta|Health")
	bool ApplyMedkit();

	/** Contador: varias zonas solapadas funcionan. */
	UFUNCTION(BlueprintCallable, Category = "Astronauta|Health")
	void EnterVacuum() { ++VacuumZoneCount; }

	UFUNCTION(BlueprintCallable, Category = "Astronauta|Health")
	void ExitVacuum() { VacuumZoneCount = FMath::Max(0, VacuumZoneCount - 1); }

	/** Para cargar partida. */
	UFUNCTION(BlueprintCallable, Category = "Astronauta|Health")
	void SetVitals(float NewHealth, float NewOxygen);

	UFUNCTION(BlueprintPure, Category = "Astronauta|Health")
	float GetHealth() const { return Health; }

	UFUNCTION(BlueprintPure, Category = "Astronauta|Health")
	float GetOxygen() const { return Oxygen; }

	UFUNCTION(BlueprintPure, Category = "Astronauta|Health")
	bool IsBleeding() const { return bIsBleeding; }

	UFUNCTION(BlueprintPure, Category = "Astronauta|Health")
	bool IsDead() const { return bIsDead; }

	UFUNCTION(BlueprintPure, Category = "Astronauta|Health")
	bool IsInVacuum() const { return VacuumZoneCount > 0; }

	UPROPERTY(BlueprintAssignable, Category = "Astronauta|Health")
	FOnHealthChanged OnHealthChanged;

	UPROPERTY(BlueprintAssignable, Category = "Astronauta|Health")
	FOnOxygenChanged OnOxygenChanged;

	UPROPERTY(BlueprintAssignable, Category = "Astronauta|Health")
	FOnBleedingStateChanged OnBleedingStateChanged;

	UPROPERTY(BlueprintAssignable, Category = "Astronauta|Health")
	FOnPlayerDied OnPlayerDied;

	// --- Ajuste ---
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Health")
	float MaxHealth = 100.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Health")
	float MaxOxygen = 100.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Health")
	float OxygenDrainRate = 5.f;

	/** Recarga fuera del vacío (no estaba en el spec; 0 = no recarga). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Health")
	float OxygenRefillRate = 10.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Health")
	float SuffocationDamagePerSecond = 10.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Health")
	float BleedThreshold = 40.f;

	/** Segundos entre gotas mientras se mueve; quieto gotea al doble de intervalo. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Health")
	float BleedDropInterval = 1.5f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Health")
	float MedkitHealAmount = 50.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Health")
	TSubclassOf<ABloodDropActor> BloodDropClass;

protected:
	virtual void BeginPlay() override;
	virtual void TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction) override;

	UFUNCTION()
	void HandleOwnerDamaged(AActor* DamagedActor, float Damage, const class UDamageType* DamageType,
		class AController* InstigatedBy, AActor* DamageCauser);

private:
	void SetHealthInternal(float NewHealth, AActor* Causer);
	void SetOxygenInternal(float NewOxygen);
	void UpdateBleeding();
	void SpawnBloodDrop();

	float Health = 100.f;
	float Oxygen = 100.f;
	bool bIsBleeding = false;
	bool bIsDead = false;
	int32 VacuumZoneCount = 0;
	float BleedTimer = 0.f;
};
