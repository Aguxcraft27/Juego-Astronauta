#include "Gameplay/VentGrate.h"
#include "AI/StealthTarget.h"
#include "Astronauta.h"
#include "Components/BoxComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Perception/AISense_Hearing.h"
#include "Perception/AISense_Sight.h"
#include "Perception/AIPerceptionStimuliSourceComponent.h"
#include "TimerManager.h"

AVentGrate::AVentGrate()
{
	PrimaryActorTick.bCanEverTick = false;

	Mesh = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Mesh"));
	RootComponent = Mesh;
	Mesh->SetCollisionProfileName(TEXT("BlockAll"));

	InteractionVolume = CreateDefaultSubobject<UBoxComponent>(TEXT("InteractionVolume"));
	InteractionVolume->SetupAttachment(Mesh);
	InteractionVolume->SetBoxExtent(FVector(100.f, 80.f, 80.f));
	InteractionVolume->SetCollisionProfileName(TEXT("Trigger"));

	StimuliSource = CreateDefaultSubobject<UAIPerceptionStimuliSourceComponent>(TEXT("StimuliSource"));
	StimuliSource->bAutoRegister = false; // intacta o retirada en silencio no es una pista
}

void AVentGrate::BeginPlay()
{
	Super::BeginPlay();
	Mesh->OnComponentHit.AddDynamic(this, &AVentGrate::HandleMeshHit);
	InteractionVolume->OnComponentEndOverlap.AddDynamic(this, &AVentGrate::HandleVolumeEndOverlap);
}

void AVentGrate::StartQuietRemoval(AActor* Remover)
{
	if (GrateState != EVentGrateState::Intact || GetWorldTimerManager().IsTimerActive(RemovalTimer))
	{
		return;
	}
	CurrentRemover = Remover;
	GetWorldTimerManager().SetTimer(RemovalTimer, this, &AVentGrate::CompleteRemoval, RemovalTime, false);
}

void AVentGrate::CancelQuietRemoval(AActor* Remover)
{
	if (CurrentRemover == Remover)
	{
		GetWorldTimerManager().ClearTimer(RemovalTimer);
		CurrentRemover = nullptr;
	}
}

float AVentGrate::GetRemovalProgress() const
{
	if (GrateState != EVentGrateState::Intact)
	{
		return 1.f;
	}
	const FTimerManager& Timers = GetWorldTimerManager();
	return Timers.IsTimerActive(RemovalTimer) && RemovalTime > 0.f
		? FMath::Clamp(Timers.GetTimerElapsed(RemovalTimer) / RemovalTime, 0.f, 1.f)
		: 0.f;
}

void AVentGrate::CompleteRemoval()
{
	if (GrateState != EVentGrateState::Intact)
	{
		return;
	}
	GrateState = EVentGrateState::Removed;
	CurrentRemover = nullptr;
	OpenPassage();
	OnGrateRemoved(); // sin ruido
}

void AVentGrate::BreakGrate(AActor* Breaker)
{
	if (GrateState != EVentGrateState::Intact)
	{
		return;
	}
	GetWorldTimerManager().ClearTimer(RemovalTimer);
	GrateState = EVentGrateState::Broken;
	OpenPassage();

	APawn* NoiseInstigator = Cast<APawn>(Breaker);
	UAISense_Hearing::ReportNoiseEvent(this, GetActorLocation(), BreakLoudness, NoiseInstigator ? static_cast<AActor*>(NoiseInstigator) : this, BreakNoiseRange);
	UE_LOG(LogAlienAI, Log, TEXT("%s rota por %s (ruido %.1f)"), *GetName(), *GetNameSafe(Breaker), BreakLoudness);

	// Resolución del Lead (M2): la rejilla rota queda como pista visual.
	Tags.AddUnique(ClueTag);
	StimuliSource->RegisterForSense(UAISense_Sight::StaticClass());
	StimuliSource->RegisterWithPerceptionSystem();
	OnGrateBroken();
}

void AVentGrate::OpenPassage()
{
	Mesh->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	Mesh->SetVisibility(false);
}

void AVentGrate::HandleMeshHit(UPrimitiveComponent* HitComp, AActor* OtherActor, UPrimitiveComponent* OtherComp,
	FVector NormalImpulse, const FHitResult& Hit)
{
	// Chocar corriendo contra la rejilla equivale a patearla.
	if (OtherActor && OtherActor->Implements<UStealthTarget>() && IStealthTarget::Execute_IsRunning(OtherActor))
	{
		BreakGrate(OtherActor);
	}
}

void AVentGrate::HandleVolumeEndOverlap(UPrimitiveComponent* OverlappedComp, AActor* OtherActor,
	UPrimitiveComponent* OtherComp, int32 OtherBodyIndex)
{
	// Alejarse cancela la retirada silenciosa.
	CancelQuietRemoval(OtherActor);
}
