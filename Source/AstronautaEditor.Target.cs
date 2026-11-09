using UnrealBuildTool;

public class AstronautaEditorTarget : TargetRules
{
	public AstronautaEditorTarget(TargetInfo Target) : base(Target)
	{
		Type = TargetType.Editor;
		DefaultBuildSettings = BuildSettingsVersion.V5;
		IncludeOrderVersion = EngineIncludeOrderVersion.Latest;
		ExtraModuleNames.Add("Astronauta");
	}
}
