--!strict
-- Shared types and state enums for Astronauta Stealth & Horror

local Types = {}

export type AlienState = "Patrullar" | "Investigar" | "Advertencia" | "CorrerHaciaAlarma" | "AlertaRoja"

Types.AlienState = {
	Patrullar = "Patrullar" :: AlienState,
	Advertencia = "Advertencia" :: AlienState, -- R5: rugido de 2.5 s antes de cazar / dar la alarma
	Investigar = "Investigar" :: AlienState,
	CorrerHaciaAlarma = "CorrerHaciaAlarma" :: AlienState,
	AlertaRoja = "AlertaRoja" :: AlienState,
}

export type MoveMode = "Walk" | "Run" | "Crouch"

Types.MoveMode = {
	Walk = "Walk" :: MoveMode,
	Run = "Run" :: MoveMode,
	Crouch = "Crouch" :: MoveMode,
}

-- Estado global que ve el HUD (atributo "StationStatus" de ReplicatedStorage.AstronautaRuntime)
export type StationStatus = "Desapercibido" | "Sospecha" | "Advertencia" | "CorriendoAlarma" | "AlertaRoja" | "Escapado"

Types.StationStatus = {
	Desapercibido = "Desapercibido" :: StationStatus,
	Sospecha = "Sospecha" :: StationStatus,
	Advertencia = "Advertencia" :: StationStatus,
	CorriendoAlarma = "CorriendoAlarma" :: StationStatus,
	AlertaRoja = "AlertaRoja" :: StationStatus,
	Escapado = "Escapado" :: StationStatus,
}

-- Tags de CollectionService que usa el nivel
Types.Tags = {
	Alien = "Alien", -- Model con Humanoid + HumanoidRootPart
	PatrolPoint = "PatrolPoint", -- BasePart (atributo opcional "Order": number)
	AlarmConsole = "AlarmConsole", -- BasePart
	SecurityConsole = "SecurityConsole", -- BasePart con ProximityPrompt para abrir esclusa
	Keycard = "Keycard", -- Part tarjeta con ProximityPrompt
	EscapeZone = "EscapeZone", -- Part volumen para escapar
	StationDoor = "StationDoor", -- BasePart (o Model con PrimaryPart)
	AlarmLight = "AlarmLight", -- BasePart con una Light dentro
	StationLamp = "StationLamp", -- Lámparas de la estación para el sistema de energía
	Corpse = "Corpse", -- BasePart / Model
	HidingSpot = "HidingSpot", -- Model/Part (hijos opcionales "HidePoint", "ExitPoint")
	VacuumZone = "VacuumZone", -- Part volumen (atributo "Active": bool, por defecto true)
	ResourcePickup = "ResourcePickup", -- Part con atributos "Resource" (string) y "Amount" (number)
	BloodDrop = "BloodDrop", -- creado por BloodTrailService
	SmokeCloud = "SmokeCloud", -- creado por GadgetService (Part esférica; bloquea la vista del alien)
	EMPMine = "EMPMine", -- creado por GadgetService
	EscapeDoor = "EscapeDoor", -- R5: compuerta que se abre con la consola de seguridad
}

-- Nombres de runtime (creados por el servidor)
Types.RuntimeFolderName = "AstronautaRuntime"
Types.Remotes = {
	SetMoveMode = "SetMoveMode", -- cliente -> servidor (MoveMode)
	ToggleFlashlight = "ToggleFlashlight", -- cliente -> servidor ()
	PlayerCaptured = "PlayerCaptured", -- servidor -> cliente (alienName)
	PlayerEscaped = "PlayerEscaped", -- servidor -> cliente ()
	SetTrackerActive = "SetTrackerActive", -- cliente -> servidor (bool)
	RequestCraft = "RequestCraft", -- cliente -> servidor (gadgetId)
	CancelCraft = "CancelCraft", -- cliente -> servidor ()
	UseGadget = "UseGadget", -- cliente -> servidor (gadgetId)
	MissionEvent = "MissionEvent", -- servidor -> cliente (eventName, text)
	MeteorEvent = "MeteorEvent", -- servidor -> cliente (phase: "warning"|"blackout"|"restored")
	CraftState = "CraftState", -- servidor -> cliente ("started"|"completed"|"cancelled", gadgetId, durationOrReason)
}

return Types
