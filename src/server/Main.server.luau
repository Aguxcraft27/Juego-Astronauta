--!strict
-- Server Entry Point for Astronauta
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Astronauta.Types)
local StationAlarmService = require(script.Parent.StationAlarmService)
local PlayerStateService = require(script.Parent.PlayerStateService)
local AlienAIService = require(script.Parent.AlienAIService)
local TestStationBuilder = require(script.Parent.TestStationBuilder)
local HidingSpotService = require(script.Parent.HidingSpotService)
local VacuumService = require(script.Parent.VacuumService)
local BloodTrailService = require(script.Parent.BloodTrailService)
local GadgetService = require(script.Parent.GadgetService)
local CraftingService = require(script.Parent.CraftingService)
local MissionService = require(script.Parent.MissionService)
local PowerGridService = require(script.Parent.PowerGridService)
local ShipBuilder = require(script.Parent.ShipGen.ShipBuilder)

-- Rediseño de infiltración (GDD_Infiltracion.md). true = nave procedural (Etapa S1);
-- false = demo antigua (estación gris + misión de la tarjeta + alien). No se borra nada.
local USE_PROCEDURAL_SHIP = true

print("[ASTRONAUTA SERVER] Iniciando subsistemas espaciales...")

-- Carpeta de runtime: RemoteEvents + atributos que lee el HUD (MaxSuspicion, StationStatus, AlarmActive)
local runtimeFolder = Instance.new("Folder")
runtimeFolder.Name = Types.RuntimeFolderName
runtimeFolder.Parent = ReplicatedStorage

if USE_PROCEDURAL_SHIP then
	-- La nave se construye antes que los servicios para que encuentren lámparas, armarios y recursos
	ShipBuilder.Init(runtimeFolder)
else
	-- Nivel gris solo si el place no tiene aliens propios
	TestStationBuilder.BuildIfEmpty()
end

StationAlarmService.Init(runtimeFolder)
StationAlarmService.Start()
PlayerStateService.Init(runtimeFolder, AlienAIService.ReportNoise)
HidingSpotService.Init()
VacuumService.Init()
AlienAIService.Init(runtimeFolder)
BloodTrailService.Init()
GadgetService.Init()
CraftingService.Init(runtimeFolder)
if not USE_PROCEDURAL_SHIP then
	MissionService.Init(runtimeFolder)
end
PowerGridService.Init(runtimeFolder)

print("[ASTRONAUTA SERVER] IA del alien, misión y red de energía en línea.")
