--!nonstrict
-- Estado global de la estación: Alerta Roja, corredor único, consolas, puertas, luces y estado del HUD.
-- Equivale a AStationGameState + UStationAlarmSubsystem + AStationLightingDirector del prototipo C++.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Astronauta")
local Types = require(Shared:WaitForChild("Types"))
local AlienConfig = require(Shared:WaitForChild("AlienConfig"))

local StationAlarmService = {}

-- Configuración de atmósfera ------------------------------------------------
StationAlarmService.RedAmbient = Color3.fromRGB(90, 0, 0)
StationAlarmService.RedOutdoorAmbient = Color3.fromRGB(60, 0, 0)
StationAlarmService.AlarmLightColor = Color3.fromRGB(255, 20, 10)
StationAlarmService.BlinkPeriod = 0.66 -- s por ciclo (≈1.5 Hz, como el director de luces C++)
StationAlarmService.SirenSoundId = ""

-- Iluminación base de la estación (estilo DOORS). Fija: no se lee de Lighting, porque un apagón
-- de PowerGridService podría estar activo justo cuando salta o se apaga la alarma.
StationAlarmService.BaseLighting = {
	Ambient = Color3.fromRGB(70, 64, 58),
	OutdoorAmbient = Color3.fromRGB(48, 44, 42),
	Brightness = 1.0,
}
StationAlarmService.RedBrightness = 0.5

-- Valores de Lighting que corresponden al estado de alarma actual (los usa PowerGridService al restaurar).
function StationAlarmService.GetTargetLighting(): { [string]: any }
	if StationAlarmService.IsAlarmActive() then
		return {
			Ambient = StationAlarmService.RedAmbient,
			OutdoorAmbient = StationAlarmService.RedOutdoorAmbient,
			Brightness = StationAlarmService.RedBrightness,
		}
	end
	return table.clone(StationAlarmService.BaseLighting)
end -- poner un rbxassetid://... de sirena en bucle; vacío = sin sonido

-- Estado --------------------------------------------------------------------
local alarmActive = false
local runner: Model? = nil
local lastKnownLocation: Vector3? = nil
local suspicionByAlien: { [Model]: number } = {}
local stateByAlien: { [Model]: string } = {}
local runtimeFolder: Folder
local siren: Sound? = nil

local redAlertEvent = Instance.new("BindableEvent")
local intruderReportedEvent = Instance.new("BindableEvent")
local doorsChangedEvent = Instance.new("BindableEvent")
local alarmDeactivatedEvent = Instance.new("BindableEvent")
local blinkTweens: { Tween } = {}
local savedLights: { [Light]: { Color: Color3, Brightness: number, Enabled: boolean } } = {}
local savedParts: { [BasePart]: { Material: Enum.Material, Color: Color3 } } = {}

StationAlarmService.RedAlert = redAlertEvent.Event -- (instigator: Model?)
StationAlarmService.IntruderReported = intruderReportedEvent.Event -- (location: Vector3, reporter: Model?)
StationAlarmService.DoorsChanged = doorsChangedEvent.Event -- () las rutas deben recalcularse
StationAlarmService.AlarmDeactivated = alarmDeactivatedEvent.Event -- () R5: consola de seguridad

-- Utilidades ------------------------------------------------------------------
local function getPart(inst: Instance): BasePart?
	if inst:IsA("BasePart") then
		return inst
	elseif inst:IsA("Model") then
		return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end
StationAlarmService.GetPart = getPart

local function updateHudStatus()
	local maxSuspicion = 0
	for _, value in suspicionByAlien do
		maxSuspicion = math.max(maxSuspicion, value)
	end

	local anyWarning = false
	for _, state in stateByAlien do
		if state == Types.AlienState.Advertencia then
			anyWarning = true
		end
	end

	local status = Types.StationStatus.Desapercibido
	if alarmActive then
		status = Types.StationStatus.AlertaRoja
	elseif runner ~= nil then
		status = Types.StationStatus.CorriendoAlarma
	elseif anyWarning then
		status = Types.StationStatus.Advertencia -- R5: "¡TE HA VISTO!" durante el rugido
	elseif maxSuspicion >= AlienConfig.Thresholds.Investigate then
		status = Types.StationStatus.Sospecha
	end

	-- Redondeo para no replicar cada décima
	runtimeFolder:SetAttribute("MaxSuspicion", math.floor(maxSuspicion + 0.5))
	runtimeFolder:SetAttribute("StationStatus", status)
end

-- API -------------------------------------------------------------------------
function StationAlarmService.Init(folder: Folder)
	runtimeFolder = folder
	runtimeFolder:SetAttribute("AlarmActive", false)
	updateHudStatus()
end

function StationAlarmService.IsAlarmActive(): boolean
	return alarmActive
end

-- Sospecha por alien -> máximo para el HUD. value = nil retira al alien.
function StationAlarmService.ReportAlien(alien: Model, suspicion: number?, state: string?)
	suspicionByAlien[alien] = suspicion
	stateByAlien[alien] = state
	updateHudStatus()
end

-- Corredor único
function StationAlarmService.TryReserveRunner(alien: Model): boolean
	if alarmActive then
		return false
	end
	if runner == nil or runner == alien or runner.Parent == nil then
		runner = alien
		updateHudStatus()
		return true
	end
	return false
end

function StationAlarmService.ReleaseRunner(alien: Model)
	if runner == alien then
		runner = nil
		updateHudStatus()
	end
end

function StationAlarmService.GetRunner(): Model?
	return runner
end

function StationAlarmService.ReportIntruder(location: Vector3, reporter: Model?)
	lastKnownLocation = location
	intruderReportedEvent:Fire(location, reporter)
end

function StationAlarmService.UpdateLastKnownLocation(location: Vector3)
	lastKnownLocation = location
end

function StationAlarmService.GetLastKnownLocation(): Vector3?
	return lastKnownLocation
end

function StationAlarmService.FindNearestConsole(from: Vector3): BasePart?
	local best: BasePart? = nil
	local bestDist = math.huge
	for _, inst in CollectionService:GetTagged(Types.Tags.AlarmConsole) do
		local part = getPart(inst)
		if part and part:IsDescendantOf(Workspace) then
			local d = (part.Position - from).Magnitude
			if d < bestDist then
				best, bestDist = part, d
			end
		end
	end
	return best
end

-- Puertas ------------------------------------------------------------------------
local function setDoorLocked(inst: Instance, locked: boolean)
	inst:SetAttribute("Locked", locked)
	local parts = {}
	if inst:IsA("BasePart") then
		table.insert(parts, inst)
	else
		for _, d in inst:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(parts, d)
			end
		end
	end
	for _, part in parts do
		-- Una puerta abierta es "fantasma" (atravesable) y semitransparente; cerrada es sólida.
		if part:GetAttribute("OpenTransparency") == nil then
			part:SetAttribute("OpenTransparency", part.Transparency)
		end
		part.CanCollide = locked -- la vista del alien usa RespectCanCollide: puerta abierta no tapa
		part.Transparency = locked and 0 or part:GetAttribute("OpenTransparency")
		if part:GetAttribute("OpenColor") == nil then
			part:SetAttribute("OpenColor", part.Color)
		end
		part.Color = locked and Color3.fromRGB(150, 20, 20) or part:GetAttribute("OpenColor")
	end
end

function StationAlarmService.SetAllDoorsLocked(locked: boolean)
	for _, door in CollectionService:GetTagged(Types.Tags.StationDoor) do
		setDoorLocked(door, locked)
	end
	doorsChangedEvent:Fire()
end

-- Luces y sirena ------------------------------------------------------------------
local startRedLightsOnly -- definida abajo (balizas y sirena, sin tocar Lighting)

local function startRedLighting()
	-- Durante un apagón no se toca Lighting: PowerGridService aplicará el rojo al restaurar la energía.
	if Lighting:GetAttribute("Blackout") then
		return startRedLightsOnly()
	end
	TweenService:Create(Lighting, TweenInfo.new(1.5), {
		Ambient = StationAlarmService.RedAmbient,
		OutdoorAmbient = StationAlarmService.RedOutdoorAmbient,
		Brightness = StationAlarmService.RedBrightness,
	}):Play()
	startRedLightsOnly()
end

startRedLightsOnly = function()
	local blinkInfo = TweenInfo.new(
		StationAlarmService.BlinkPeriod / 2,
		Enum.EasingStyle.Sine,
		Enum.EasingDirection.InOut,
		-1, -- infinito
		true -- ida y vuelta
	)
	for _, inst in CollectionService:GetTagged(Types.Tags.AlarmLight) do
		for _, d in inst:GetDescendants() do
			if d:IsA("Light") then
				savedLights[d] = { Color = d.Color, Brightness = d.Brightness, Enabled = d.Enabled }
				d.Color = StationAlarmService.AlarmLightColor
				d.Enabled = true
				local base = math.max(d.Brightness, 2)
				d.Brightness = 0
				local tween = TweenService:Create(d, blinkInfo, { Brightness = base })
				tween:Play()
				table.insert(blinkTweens, tween)
			end
		end
		local part = getPart(inst)
		if part then
			savedParts[part] = { Material = part.Material, Color = part.Color }
			part.Material = Enum.Material.Neon
			part.Color = StationAlarmService.AlarmLightColor
		end
	end

	if StationAlarmService.SirenSoundId ~= "" then
		local sound = Instance.new("Sound")
		sound.Name = "Siren"
		sound.SoundId = StationAlarmService.SirenSoundId
		sound.Looped = true
		sound.Volume = 0.6
		sound.Parent = Workspace
		sound:Play()
		siren = sound
	end
end

-- Alerta Roja ----------------------------------------------------------------------
function StationAlarmService.TriggerRedAlert(instigator: Model?)
	if alarmActive then
		return
	end
	alarmActive = true
	runner = nil
	runtimeFolder:SetAttribute("AlarmActive", true)
	updateHudStatus()

	startRedLighting()
	StationAlarmService.SetAllDoorsLocked(true)

	print(("[ALARMA] Alerta Roja activada por %s"):format(instigator and instigator.Name or "desconocido"))
	redAlertEvent:Fire(instigator)
end

-- R5: la consola de seguridad apaga la alarma: luces, sirena y puertas vuelven a la normalidad.
function StationAlarmService.DeactivateAlarm()
	if not alarmActive then
		return
	end
	alarmActive = false
	runner = nil
	lastKnownLocation = nil
	runtimeFolder:SetAttribute("AlarmActive", false)

	for _, tween in blinkTweens do
		tween:Cancel()
	end
	table.clear(blinkTweens)
	for light, data in savedLights do
		if light.Parent then
			light.Color = data.Color
			light.Brightness = data.Brightness
			light.Enabled = data.Enabled
		end
	end
	table.clear(savedLights)
	for part, data in savedParts do
		if part.Parent then
			part.Material = data.Material
			part.Color = data.Color
		end
	end
	table.clear(savedParts)
	-- Vuelve a la base fija (salvo en pleno apagón: PowerGridService restaurará la base al terminar).
	if not Lighting:GetAttribute("Blackout") then
		TweenService:Create(Lighting, TweenInfo.new(2), StationAlarmService.BaseLighting):Play()
	end
	if siren then
		siren:Stop()
		siren:Destroy()
		siren = nil
	end

	StationAlarmService.SetAllDoorsLocked(false)
	updateHudStatus()
	print("[ALARMA] Alerta Roja desactivada desde la consola de seguridad")
	alarmDeactivatedEvent:Fire()
end

-- Puertas: al arrancar, todas desbloqueadas (abiertas)
function StationAlarmService.Start()
	StationAlarmService.SetAllDoorsLocked(false)
	CollectionService:GetInstanceAddedSignal(Types.Tags.StationDoor):Connect(function(door)
		setDoorLocked(door, alarmActive)
	end)
end

return StationAlarmService
