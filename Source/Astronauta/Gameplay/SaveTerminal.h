#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "SaveTerminal.generated.h"

class UStaticMeshComponent;
class USphereComponent;

UENUM(BlueprintType)
enum class ESaveFailReason : uint8
{
	HostileNearby  UMETA(DisplayName = "HOSTIL CERCANO"),
	Interrupted    UMETA(DisplayName = "Interrumpido"),
	WriteFailed    UMETA(DisplayName = "Error de escritura")
};

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnSaveStarted, float, Duration);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnSaveProgress, float, Percent01);
DECLARE_DYNAMIC_MULTICAST_DELEGATE(FOnSaveSuccess);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnSaveFailed, ESaveFailReason, Reason);

/**
 * Terminal de guardado. Insertar la tarjeta lleva CardInsertDuration s SIN pausar el juego.
 * Se comprueba la presencia de hostiles al empezar y al terminar: si un alien en persecución activa
 * está a menos de HostileCheckRadius, el guardado se bloquea (pantalla roja "HOSTIL CERCANO").
 */
UCLASS()
class ASTRONAUTA_API ASaveTerminal : public AActor
{
	GENERATED_BODY()

public:
	ASaveTerminal();

	UFUNCTION(BlueprintCallable, Category = "Save Terminal")
	bool BeginSave(AActor* User);

	UFUNCTION(BlueprintCallable, Category = "Save Terminal")
	void CancelSave();

	UFUNCTION(BlueprintPure, Category = "Save Terminal")
	bool IsSaving() const { return SaveUser != nullptr; }

	UFUNCTION(BlueprintPure, Category = "Save Terminal")
	bool IsHostileNearby() const;

	/** Carga el slot por defecto y lo aplica (desde menú / GameMode). */
	UFUNCTION(BlueprintCallable, Category = "Save Terminal", meta = (WorldContext = "WorldContextObject"))
	static bool LoadStationGame(UObject* WorldContextObject);

	UPROPERTY(BlueprintAssignable, Category = "Save Terminal")
	FOnSaveStarted OnSaveStarted;

	UPROPERTY(BlueprintAssignable, Category = "Save Terminal")
	FOnSaveProgress OnSaveProgress;

	UPROPERTY(BlueprintAssignable, Category = "Save Terminal")
	FOnSaveSuccess OnSaveSuccess;

	UPROPERTY(BlueprintAssignable, Category = "Save Terminal")
	FOnSaveFailed OnSaveFailed;

	/** Parpadeo rojo, texto "HOSTIL CERCANO", sonidos. */
	UFUNCTION(BlueprintImplementableEvent, Category = "Save Terminal")
	void OnHostileWarning();

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Save Terminal")
	float CardInsertDuration = 2.5f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Save Terminal")
	float HostileCheckRadius = 1000.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Save Terminal")
	float MaxUseDistance = 200.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Save Terminal")
	FString SaveSlot = TEXT("StationSave");

protected:
	virtual void Tick(float DeltaSeconds) override;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
	TObjectPtr<UStaticMeshComponent> TerminalMesh;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
	TObjectPtr<USphereComponent> InteractionVolume;

private:
	void Fail(ESaveFailReason Reason);
	void Complete();

	UPROPERTY()
	TObjectPtr<AActor> SaveUser;

	float Elapsed = 0.f;
};
