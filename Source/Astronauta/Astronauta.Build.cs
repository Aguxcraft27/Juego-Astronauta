using UnrealBuildTool;

public class Astronauta : ModuleRules
{
	public Astronauta(ReadOnlyTargetRules Target) : base(Target)
	{
		PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;
		PublicIncludePaths.Add(ModuleDirectory);
		PublicDependencyModuleNames.AddRange(new string[] {
			"Core", "CoreUObject", "Engine", "InputCore",
			"AIModule", "GameplayTasks", "NavigationSystem"
		});
	}
}
