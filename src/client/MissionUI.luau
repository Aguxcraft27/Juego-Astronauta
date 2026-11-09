--!nonstrict
-- Objetivo actual, avisos grandes y pantalla de victoria (Milestone R5).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Types = require(ReplicatedStorage:WaitForChild("Astronauta"):WaitForChild("Types"))

local MissionUI = {}

local player = Players.LocalPlayer
local ui = {}

local COLORS = {
	objective = Color3.fromRGB(255, 200, 90),
	keycard = Color3.fromRGB(120, 220, 255),
	denied = Color3.fromRGB(255, 90, 70),
	unlocked = Color3.fromRGB(90, 255, 140),
	escaped = Color3.fromRGB(90, 255, 140),
}

local function buildGui()
	local gui = Instance.new("ScreenGui")
	gui.Name = "MissionHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5

	local objective = Instance.new("TextLabel")
	objective.Name = "Objective"
	objective.AnchorPoint = Vector2.new(1, 0)
	objective.Position = UDim2.new(1, -20, 0, 24)
	objective.Size = UDim2.fromOffset(380, 40)
	objective.BackgroundTransparency = 1
	objective.Font = Enum.Font.GothamBold
	objective.TextSize = 14
	objective.TextWrapped = true
	objective.TextXAlignment = Enum.TextXAlignment.Right
	objective.TextYAlignment = Enum.TextYAlignment.Top
	objective.TextStrokeTransparency = 0.4
	objective.TextColor3 = COLORS.objective
	objective.Text = "OBJETIVO: Encuentra la TARJETA DE SEGURIDAD (mesa del módulo habitacional, Sala A)"
	objective.Parent = gui

	local banner = Instance.new("TextLabel")
	banner.Name = "Banner"
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = UDim2.fromScale(0.5, 0.3)
	banner.Size = UDim2.new(0.8, 0, 0, 60)
	banner.BackgroundTransparency = 1
	banner.Font = Enum.Font.GothamBlack
	banner.TextSize = 30
	banner.TextWrapped = true
	banner.TextStrokeTransparency = 0.2
	banner.TextTransparency = 1
	banner.TextStrokeColor3 = Color3.new(0, 0, 0)
	banner.Parent = gui

	local victory = Instance.new("Frame")
	victory.Name = "Victory"
	victory.Size = UDim2.fromScale(1, 1)
	victory.BackgroundColor3 = Color3.fromRGB(5, 25, 15)
	victory.BackgroundTransparency = 1
	victory.ZIndex = 20
	victory.Parent = gui
	local victoryText = Instance.new("TextLabel")
	victoryText.Size = UDim2.fromScale(1, 0.5)
	victoryText.Position = UDim2.fromScale(0, 0.2)
	victoryText.BackgroundTransparency = 1
	victoryText.Font = Enum.Font.GothamBlack
	victoryText.TextSize = 44
	victoryText.TextWrapped = true
	victoryText.TextColor3 = Color3.fromRGB(140, 255, 170)
	victoryText.TextTransparency = 1
	victoryText.Text = "¡MISIÓN CUMPLIDA — HAS ESCAPADO CON VIDA!"
	victoryText.ZIndex = 21
	victoryText.Parent = victory
	local victorySub = Instance.new("TextLabel")
	victorySub.Size = UDim2.fromScale(1, 0.1)
	victorySub.Position = UDim2.fromScale(0, 0.62)
	victorySub.BackgroundTransparency = 1
	victorySub.Font = Enum.Font.Code
	victorySub.TextSize = 18
	victorySub.TextColor3 = Color3.fromRGB(120, 200, 140)
	victorySub.TextTransparency = 1
	victorySub.Text = "СОЮЗ-ОРБИТА 7 · TRANSMISIÓN FINALIZADA"
	victorySub.ZIndex = 21
	victorySub.Parent = victory

	gui.Parent = player:WaitForChild("PlayerGui")
	ui.objective = objective
	ui.banner = banner
	ui.victory = victory
	ui.victoryText = victoryText
	ui.victorySub = victorySub
end

local function showBanner(text: string, color: Color3)
	ui.banner.Text = text
	ui.banner.TextColor3 = color
	ui.banner.TextTransparency = 0
	ui.banner.TextStrokeTransparency = 0.2
	local info = TweenInfo.new(1.2, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 3)
	TweenService:Create(ui.banner, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
end

local function showVictory()
	local camera = Workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	local info = TweenInfo.new(1.5)
	TweenService:Create(ui.victory, info, { BackgroundTransparency = 0.05 }):Play()
	TweenService:Create(ui.victoryText, info, { TextTransparency = 0 }):Play()
	TweenService:Create(ui.victorySub, info, { TextTransparency = 0 }):Play()
	ui.objective.Text = ""
end

local function onMissionEvent(event: string, text: string)
	local color = COLORS[event] or COLORS.objective
	if event == "objective" then
		ui.objective.Text = "OBJETIVO: " .. text
		ui.objective.TextColor3 = color
	elseif event == "keycard" then
		ui.objective.Text = "OBJETIVO: Usa la tarjeta en la consola de seguridad (Sala B, pared este)"
		ui.objective.TextColor3 = color
		showBanner(text, color)
	elseif event == "denied" then
		showBanner(text, color)
	elseif event == "unlocked" then
		ui.objective.Text = "OBJETIVO: ¡Corre a la esclusa de salida! (pasillo sur, extremo este)"
		ui.objective.TextColor3 = color
		showBanner(text, color)
	elseif event == "escaped" then
		showVictory()
	end
end

function MissionUI.Start()
	local runtime = ReplicatedStorage:WaitForChild(Types.RuntimeFolderName)
	local missionRemote = runtime:WaitForChild(Types.Remotes.MissionEvent)
	local escapedRemote = runtime:WaitForChild(Types.Remotes.PlayerEscaped)
	buildGui()
	missionRemote.OnClientEvent:Connect(onMissionEvent)
	escapedRemote.OnClientEvent:Connect(showVictory)
end

return MissionUI
