using UnrealBuildTool;

public class AstronautaTarget : TargetRules
{
	public AstronautaTarget(TargetInfo Target) : base(Target)
	{
		Type = TargetType.Game;
		DefaultBuildSettings = BuildSettingsVersion.V5;
		IncludeOrderVersion = EngineIncludeOrderVersion.Latest;
		ExtraModuleNames.Add("Astronauta");
	}
}
