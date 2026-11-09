#include "AI/PatrolPath.h"
#include "Components/SceneComponent.h"

APatrolPath::APatrolPath()
{
	PrimaryActorTick.bCanEverTick = false;
	RootComponent = CreateDefaultSubobject<USceneComponent>(TEXT("Root"));
}

FVector APatrolPath::GetWorldPoint(int32 Index) const
{
	return Points.IsValidIndex(Index) ? GetActorTransform().TransformPosition(Points[Index]) : GetActorLocation();
}

int32 APatrolPath::FindNearestIndex(const FVector& WorldLocation) const
{
	int32 Best = 0;
	double BestDistSq = TNumericLimits<double>::Max();
	for (int32 i = 0; i < Points.Num(); ++i)
	{
		const double DistSq = FVector::DistSquared(WorldLocation, GetWorldPoint(i));
		if (DistSq < BestDistSq)
		{
			BestDistSq = DistSq;
			Best = i;
		}
	}
	return Best;
}
