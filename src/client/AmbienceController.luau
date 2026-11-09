--!nonstrict
-- Paisaje sonoro (Milestone R4), local a cada cliente.
--   Reactor : zumbido grave continuo de la estación (no posicional).
--   Respiración: dentro del casco, sincronizada con el modo de movimiento (más rápida al correr,
--                agitada sin oxígeno), y se corta al morir o ser capturado.
--
-- Sin assets propios todavía: los valores por defecto usan sonidos que vienen con el cliente de Roblox
-- (rbxasset://), procesados con ecualizador y tono para que suenen a ventilación y respiración.
-- Para la versión final basta con poner rbxassetid://… en ReactorSoundId / BreathSoundId.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local AmbienceController = {}

AmbienceController.ReactorSoundId = "rbxasset://sounds/action_swim.mp3" -- muy grave + low-pass = rumor de ventilación
AmbienceController.ReactorSpeed = 0.18
AmbienceController.ReactorVolume = 0.35
AmbienceController.BreathSoundId = "rbxasset://sounds/action_swim.mp3" -- filtrado = aire en el casco
AmbienceController.BreathVolume = 0.12
AmbienceController.SparkSoundId = "rbxasset://sounds/impact_explosion_03.mp3" -- chasquido eléctrico lejano

local player = Players.LocalPlayer

local function makeSound(name: string, id: string, volume: number, speed: number, looped: boolean): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = id
	sound.Volume = volume
	sound.PlaybackSpeed = speed
	sound.Looped = looped
	sound.Parent = SoundService
	return sound
end

local function addLowPass(sound: Sound, high: number)
	local eq = Instance.new("EqualizerSoundEffect")
	eq.LowGain = 6
	eq.MidGain = -12
	eq.HighGain = high
	eq.Parent = sound
end

function AmbienceController.Start()
	-- Reactor / ventilación
	local reactor = makeSound("ReactorHum", AmbienceController.ReactorSoundId, AmbienceController.ReactorVolume,
		AmbienceController.ReactorSpeed, true)
	addLowPass(reactor, -40)
	local reverb = Instance.new("ReverbSoundEffect")
	reverb.DecayTime = 4
	reverb.WetLevel = -2
	reverb.Parent = reactor
	reactor:Play()

	-- Segunda capa más aguda y muy baja: zumbido eléctrico
	local hum = makeSound("ElectricHum", AmbienceController.ReactorSoundId, 0.08, 0.6, true)
	addLowPass(hum, -18)
	hum:Play()

	-- Respiración en el casco
	local breath = makeSound("SuitBreath", AmbienceController.BreathSoundId, AmbienceController.BreathVolume, 0.55, true)
	addLowPass(breath, -6)
	breath:Play()

	-- Chasquidos eléctricos esporádicos y lejanos
	local spark = makeSound("DistantSpark", AmbienceController.SparkSoundId, 0.06, 1.8, false)
	addLowPass(spark, -24)
	task.spawn(function()
		while true do
			task.wait(18 + math.random() * 25)
			spark.PlaybackSpeed = 1.5 + math.random() * 0.8
			spark:Play()
		end
	end)

	-- Ajuste continuo de la respiración según el estado del personaje
	RunService.Heartbeat:Connect(function()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 or character:GetAttribute("Captured") then
			breath.Volume = 0
			return
		end
		local mode = character:GetAttribute("MoveMode")
		local oxygen = character:GetAttribute("Oxygen") or 100
		local speed, volume = 0.55, AmbienceController.BreathVolume
		if mode == "Run" then
			speed, volume = 0.8, AmbienceController.BreathVolume * 1.6
		elseif mode == "Crouch" or character:GetAttribute("HiddenInSpot") then
			speed, volume = 0.45, AmbienceController.BreathVolume * 0.7 -- contener la respiración
		end
		if oxygen < 30 then
			speed += 0.35 -- jadeo por falta de aire
			volume *= 1.4
		end
		breath.PlaybackSpeed += (speed - breath.PlaybackSpeed) * 0.05
		breath.Volume += (volume - breath.Volume) * 0.05
	end)
end

return AmbienceController
