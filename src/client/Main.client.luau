--!strict
-- Client Entry Point for Astronauta
local FirstPersonController = require(script.Parent.FirstPersonController)
local AstronautController = require(script.Parent.AstronautController)
local MotionTrackerController = require(script.Parent.MotionTrackerController)
local InventoryUI = require(script.Parent.InventoryUI)
local AmbienceController = require(script.Parent.AmbienceController)
local MissionUI = require(script.Parent.MissionUI)
local PSXPostProcessing = require(script.Parent.PSXPostProcessing)

PSXPostProcessing.Start()
FirstPersonController.Start()
AstronautController.Start()
MotionTrackerController.Start()
InventoryUI.Start()
AmbienceController.Start()
MissionUI.Start()
print("[ASTRONAUTA CLIENT] Primera persona, traje, filtros PSX y sigilo listos.")
