--!strict
-- PowerGridService: Maneja la energía eléctrica de la estación y eventos de impacto de meteoritos.
-- Iluminación base: Luz tenue cálida estilo DOORS (totalmente visible y navegable).
-- Evento: Lluvia de meteoritos -> Parpadeo de luces -> Corte total de energía (requiere linterna) -> Restablecimiento.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Astronauta")
local Types = require(Shared:WaitForChild("Types"))
local StationAlarmService = require(script.Parent:WaitForChild("StationAlarmService"))

local PowerGridService = {}

local meteorRemote: RemoteEvent
local isBlackout = false
local blackoutAmbient = Color3.fromRGB(12, 10, 16)

function PowerGridService.IsBlackout(): boolean
	return isBlackout
end

local function setLampsEnabled(enabled: boolean)
	for _, lamp in CollectionService:GetTagged(Types.Tags.StationLamp) do
		for _, desc in lamp:GetDescendants() do
			if desc:IsA("Light") then
				desc.Enabled = enabled
			elseif desc:IsA("BasePart") and desc.Name == "Bulb" then
				desc.Material = enabled and Enum.Material.Neon or Enum.Material.SmoothPlastic
			end
		end
	end
end

local function triggerMeteorShower()
	if isBlackout then
		return
	end

	print("[POWER GRID] ☄️ ¡Lluvia de meteoritos detectada en el sector!")
	meteorRemote:FireAllClients("warning", "☄️ ¡ALERTA: IMPACTO DE MICROMETEORITOS! FALLA DE ENERGÍA")

	-- Sonido de impacto / alarma estructural
	local alarmPart = Workspace:FindFirstChild("TestStation") and Workspace.TestStation:FindFirstChild("Floor")
	if alarmPart then
		local boom = Instance.new("Sound")
		boom.SoundId = "rbxasset://sounds/collide.wav"
		boom.Volume = 1.8
		boom.PlaybackSpeed = 0.5 -- Estruendo grave y lejano
		boom.Parent = alarmPart
		boom:Play()
		game:GetService("Debris"):AddItem(boom, 4)
	end

	task.wait(3)

	-- Fase de parpadeo violento estilo DOORS
	print("[POWER GRID] Las luces parpadean...")
	for _ = 1, 8 do
		setLampsEnabled(false)
		Lighting.Brightness = 0.2
		task.wait(math.random(5, 15) / 100)
		setLampsEnabled(true)
		Lighting.Brightness = StationAlarmService.GetTargetLighting().Brightness -- 1.0 normal / 0.5 en Alerta Roja
		task.wait(math.random(5, 20) / 100)
	end

	-- APAGÓN TOTAL
	isBlackout = true
	Lighting:SetAttribute("Blackout", true) -- StationAlarmService no toca Lighting mientras dure
	setLampsEnabled(false)
	TweenService:Create(Lighting, TweenInfo.new(0.5), {
		Ambient = blackoutAmbient,
		Brightness = 0.1,
	}):Play()

	meteorRemote:FireAllClients("blackout", "⚡ ¡CORTE DE ENERGÍA! USA TU LINTERNA [F]")

	-- Duración del apagón (15 a 18 segundos)
	task.wait(16)

	-- RESTABLECIMIENTO DE ENERGÍA
	print("[POWER GRID] Generadores auxiliares en línea. Restableciendo iluminación...")
	meteorRemote:FireAllClients("restored", "💡 ENERGÍA RESTABLECIDA")

	-- Parpadeo de arranque
	setLampsEnabled(true)
	task.wait(0.1)
	setLampsEnabled(false)
	task.wait(0.2)
	setLampsEnabled(true)

	-- Restaura según el estado de alarma ACTUAL: rojo si saltó durante el apagón, base cálida si no.
	Lighting:SetAttribute("Blackout", nil)
	TweenService:Create(Lighting, TweenInfo.new(1.0), StationAlarmService.GetTargetLighting()):Play()

	isBlackout = false
end

function PowerGridService.Init(runtimeFolder: Folder)
	meteorRemote = Instance.new("RemoteEvent")
	meteorRemote.Name = Types.Remotes.MeteorEvent
	meteorRemote.Parent = runtimeFolder

	-- Ciclo recurrente de eventos de meteoritos (cada 65 a 85 segundos)
	task.spawn(function()
		task.wait(40) -- Primer evento a los 40s de iniciar la partida
		while true do
			triggerMeteorShower()
			task.wait(math.random(60, 85))
		end
	end)
end

return PowerGridService
