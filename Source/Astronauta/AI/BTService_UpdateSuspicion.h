#pragma once

#include "CoreMinimal.h"
#include "BehaviorTree/BTService.h"
#include "BTService_UpdateSuspicion.generated.h"

/** Colocar en el nodo raíz del BT. Acumula/decae el SuspicionMeter y evalúa las transiciones 1-3. */
UCLASS()
class ASTRONAUTA_API UBTService_UpdateSuspicion : public UBTService
{
	GENERATED_BODY()

public:
	UBTService_UpdateSuspicion();

protected:
	virtual void TickNode(UBehaviorTreeComponent& OwnerComp, uint8* NodeMemory, float DeltaSeconds) override;
};
