--!nonstrict
-- IA del alien en el servidor (traducción a Luau del AAlienAIController del prototipo C++).
-- Cada Model con tag "Alien" (Humanoid + HumanoidRootPart + Head) recibe un "cerebro" con:
--   Percepción: cono de visión con raycast, linterna, cadáveres, ruido (pasos y otros).
--   Estados: Patrullar -> Investigar -> CorrerHaciaAlarma (corredor único) -> AlertaRoja.
--   Navegación: PathfindingService con waypoints, recálculo si la ruta se bloquea o cambian las puertas.

local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Astronauta")
local Types = require(Shared:WaitForChild("Types"))
local AlienConfig = require(Shared:WaitForChild("AlienConfig"))
local StationAlarmService = require(script.Parent:WaitForChild("StationAlarmService"))
local PlayerStateService = require(script.Parent:WaitForChild("PlayerStateService"))
local HidingSpotService = require(script.Parent:WaitForChild("HidingSpotService"))
local CraftingConfig = require(Shared:WaitForChild("CraftingConfig"))

local State = Types.AlienState
local Cfg = AlienConfig

local AlienAIService = {}

local brains: { [Model]: any } = {}
local capturedRemote: RemoteEvent? = nil

local COS_HALF_CONE = math.cos(math.rad(Cfg.Vision.ConeAngle / 2))

-- Utilidades ---------------------------------------------------------------------
local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function flatDistance(a: Vector3, b: Vector3): number
	return flat(a - b).Magnitude
end

-- R3: ¿el segmento a->b atraviesa alguna nube de humo? (esfera opaca, independiente de CanQuery)
local function isBlockedBySmoke(a: Vector3, b: Vector3): boolean
	local ab = b - a
	local lengthSq = ab:Dot(ab)
	for _, cloud in CollectionService:GetTagged(Types.Tags.SmokeCloud) do
		if cloud:IsA("BasePart") and cloud.Parent then
			local radius = cloud:GetAttribute("Radius") or cloud.Size.X / 2
			local c = cloud.Position
			local t = lengthSq > 0 and math.clamp((c - a):Dot(ab) / lengthSq, 0, 1) or 0
			local closest = a + ab * t
			if (closest - c).Magnitude <= radius then
				return true
			end
		end
	end
	return false
end

-- Un jugador es "perceptible" si está vivo, no escondido y no capturado.
local function isTargetable(character: Model?): boolean
	if not character or character:GetAttribute("HiddenInSpot") or character:GetAttribute("Captured")
		or character:GetAttribute("Escaped") then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

-- Secuencia de captura (R2): congelado + pantalla roja en el cliente, reaparición tras SequenceDuration.
local function capturePlayer(character: Model, alien: Model)
	if character:GetAttribute("Captured") then
		return
	end
	if HidingSpotService.GetSpotOf(character) then
		HidingSpotService.Exit(character)
	end
	character:SetAttribute("Captured", true)
	PlayerStateService.SetFlashlight(character, false)
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.Anchored = true
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 0
	end

	local player = Players:GetPlayerFromCharacter(character)
	print(("[ALIEN] %s capturó a %s"):format(alien.Name, character.Name))
	if player and capturedRemote then
		capturedRemote:FireClient(player, alien.Name, Cfg.Capture.SequenceDuration)
	end
	task.delay(Cfg.Capture.SequenceDuration, function()
		if player and player.Parent and player.Character == character then
			player:LoadCharacter()
		end
	end)
end

local function getPatrolPoints(): { BasePart }
	local points = {}
	for _, inst in CollectionService:GetTagged(Types.Tags.PatrolPoint) do
		local part = StationAlarmService.GetPart(inst)
		if part and part:IsDescendantOf(Workspace) then
			table.insert(points, part)
		end
	end
	table.sort(points, function(a, b)
		local oa, ob = a:GetAttribute("Order"), b:GetAttribute("Order")
		if oa ~= nil and ob ~= nil and oa ~= ob then
			return oa < ob
		end
		return a.Name < b.Name
	end)
	return points
end

-- Cerebro --------------------------------------------------------------------------
local Brain = {}
Brain.__index = Brain

function Brain.new(model: Model)
	local self = setmetatable({}, Brain)
	self.model = model
	self.humanoid = model:FindFirstChildOfClass("Humanoid")
	self.root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	self.head = (model:FindFirstChild("Head") or self.root) :: BasePart

	self.state = State.Patrullar
	self.suspicion = 0

	-- Investigación
	self.investigationTarget = nil :: Vector3?
	self.arrived = false
	self.searchUntil = 0
	self.nextLookAround = 0

	-- Percepción
	self.visiblePlayer = nil :: Model?
	self.lastSeenPosition = nil :: Vector3?
	self.seenCorpses = {} :: { [Instance]: boolean }

	-- Alarma
	self.consoleTarget = nil :: BasePart?
	self.consoleTimer = 0

	-- Alerta Roja
	self.lastKnownReachedAt = nil :: number?

	-- Patrulla
	self.patrolIndex = nil :: number?

	-- R5: advertencia / persecución
	self.warningUntil = 0
	self.warningTarget = nil :: Model?
	self.warningResume = State.Investigar
	self.confirmed = false -- ya rugió y confirmó: no vuelve a rugir hasta calmarse
	self.chasing = false -- AlertaRoja: persecución activa (tras el rugido)
	self.lastVisibleTime = 0
	self.searchRoom = false -- inspección tras verlo esconderse (se rinde al terminar)

	self.voice = Instance.new("Sound")
	self.voice.Name = "AlienVoice"
	self.voice.SoundId = Cfg.Warning.RoarSoundId
	self.voice.RollOffMaxDistance = 120
	self.voice.Parent = self.root

	-- R3
	self.stunnedUntil = 0
	self.seenBlood = {} :: { [Instance]: boolean }

	-- Inspección de escondites (R2)
	self.inspectRolled = false
	self.inspectSpot = nil :: Instance?
	self.inspectUntil = nil :: number?
	self.forceOpen = false

	-- Navegación
	self.waypoints = nil :: { PathWaypoint }?
	self.waypointIndex = 1
	self.pathGoal = nil :: Vector3?
	self.lastPathTime = -math.huge
	self.pathRequestId = 0
	self.computing = false
	self.blockedConn = nil :: RBXScriptConnection?

	self.rayParams = RaycastParams.new()
	self.rayParams.FilterType = Enum.RaycastFilterType.Exclude
	self.rayParams.FilterDescendantsInstances = { model }
	self.rayParams.RespectCanCollide = true -- puertas abiertas (CanCollide=false) no tapan la vista
	self.rayParams.IgnoreWater = true

	pcall(function()
		self.root:SetNetworkOwner(nil) -- el servidor mueve al alien
	end)

	self:SetState(State.Patrullar)
	return self
end

function Brain:Destroy()
	if self.blockedConn then
		self.blockedConn:Disconnect()
	end
	StationAlarmService.ReleaseRunner(self.model)
	StationAlarmService.ReportAlien(self.model, nil, nil)
end

function Brain:IsValid(): boolean
	return self.model.Parent ~= nil
		and self.humanoid ~= nil
		and self.humanoid.Health > 0
		and self.root ~= nil
		and self.root.Parent ~= nil
end

-- Estado ----------------------------------------------------------------------------
function Brain:SetState(newState: string)
	local old = self.state
	self.state = newState

	if old == State.CorrerHaciaAlarma and newState ~= State.CorrerHaciaAlarma then
		StationAlarmService.ReleaseRunner(self.model)
	end

	self.humanoid.WalkSpeed = Cfg.Speeds[newState] or Cfg.Speeds.Patrullar
	self.consoleTarget = nil
	self.consoleTimer = 0
	self.lastKnownReachedAt = nil

	if newState == State.Patrullar or newState == State.CorrerHaciaAlarma then
		self:EndInspect()
	end

	if newState == State.Patrullar then
		self.investigationTarget = nil
		self.arrived = false
		self.patrolIndex = nil
		self.confirmed = false
	end
	if newState ~= State.AlertaRoja then
		self.chasing = false
	end
	if old == State.Advertencia and newState ~= State.Advertencia then
		self.model:SetAttribute("Warning", nil)
	end

	self.model:SetAttribute("AlienState", newState)
	self:Report()
	if old ~= newState then
		print(("[ALIEN] %s: %s -> %s (sospecha %.0f)"):format(self.model.Name, old, newState, self.suspicion))
	end
end

function Brain:Report()
	self.model:SetAttribute("Suspicion", math.floor(self.suspicion + 0.5))
	StationAlarmService.ReportAlien(self.model, self.suspicion, self.state)
end

function Brain:AddSuspicion(amount: number)
	self.suspicion = math.clamp(self.suspicion + amount, 0, Cfg.Suspicion.Max)
end

function Brain:SetInvestigationTarget(position: Vector3)
	self.investigationTarget = position
	self.arrived = false
	self.searchUntil = 0
	self.inspectRolled = false
	if self.inspectSpot and not self.searchRoom then
		self:EndInspect() -- un estímulo nuevo cancela la inspección casual (no la búsqueda tras verlo esconderse)
	end
end

-- Escondites ---------------------------------------------------------------------------
function Brain:BeginInspect(spot: Instance, force: boolean)
	self.inspectSpot = spot
	self.inspectUntil = nil
	self.forceOpen = force
end

function Brain:EndInspect()
	self.inspectSpot = nil
	self.inspectUntil = nil
	self.forceOpen = false
	self.searchRoom = false
	if self.model then
		self.model:SetAttribute("Inspecting", nil)
	end
end

function Brain:ForceOpenSpot(spot: Instance)
	local occupant = HidingSpotService.ForceOpen(spot)
	if not occupant then
		return
	end
	print(("[ALIEN] %s abre el escondite y encuentra a %s"):format(self.model.Name, occupant.Name))
	if self.state == State.AlertaRoja then
		capturePlayer(occupant, self.model)
		return
	end
	local root = occupant:FindFirstChild("HumanoidRootPart")
	self.suspicion = Cfg.Suspicion.Max
	if root then
		self.lastSeenPosition = root.Position
		self:SetInvestigationTarget(root.Position)
	end
	self:EvaluateTransitions()
end

-- Devuelve true mientras la inspección sigue en curso.
function Brain:UpdateInspectSpot(): boolean
	local spot = self.inspectSpot
	if not spot or spot.Parent == nil then
		self:EndInspect()
		return false
	end
	local exitCF = HidingSpotService.GetExitCFrame(spot)
	local stand = exitCF.Position + exitCF.LookVector * (Cfg.HidingSpot.InspectStandDistance - 3)
	local now = os.clock()

	if self.inspectUntil == nil then
		if not self:IsNear(stand, Cfg.Investigation.ArriveRadius) then
			self:MoveTowards(stand)
			return true
		end
		self:StopMoving()
		local spotPos = HidingSpotService.GetHidePosition(spot)
		self.root.CFrame = CFrame.lookAt(self.root.Position, Vector3.new(spotPos.X, self.root.Position.Y, spotPos.Z))
		-- R5: visto entrar -> busca SeenEnterSearchDuration; casual -> olfatea InspectDuration.
		-- En ningún caso abre el armario salvo que el ocupante haga ruido (ver OnNoise).
		self.inspectUntil = now + (self.searchRoom and Cfg.HidingSpot.SeenEnterSearchDuration or Cfg.HidingSpot.InspectDuration)
		self.model:SetAttribute("Inspecting", true)
		return true
	end

	if now < self.inspectUntil then
		return true
	end

	local gaveUp = self.searchRoom
	self:EndInspect()
	self.searchUntil = now -- la inspección cuenta como búsqueda terminada
	if gaveUp then
		-- R5: "suspira", olvida y vuelve a su patrulla fija
		self:PlayVoice(Cfg.Warning.GruntSpeed, Cfg.Warning.GruntVolume)
		self.lastSeenPosition = nil
		self.confirmed = false
		if self.state == State.AlertaRoja then
			self.chasing = false
			self.lastKnownReachedAt = os.clock() - Cfg.Hunt.LastKnownSearchTime -- rastro frío: deambular
		else
			self.suspicion = 0
			self:SetState(State.Patrullar)
		end
		print(("[ALIEN] %s se rinde y vuelve a patrullar"):format(self.model.Name))
	end
	return false
end

-- R5: rugido de advertencia. resume = estado al que vuelve si el jugador escapa de su vista.
function Brain:PlayVoice(speed: number, volume: number)
	self.voice.PlaybackSpeed = speed
	self.voice.Volume = volume
	self.voice.TimePosition = 0
	self.voice:Play()
end

function Brain:BeginWarning(character: Model, resume: string)
	self.warningTarget = character
	self.warningResume = resume
	self.warningUntil = os.clock() + Cfg.Warning.Duration
	self:StopMoving()
	self:SetState(State.Advertencia)
	self.model:SetAttribute("Warning", true)
	self:PlayVoice(Cfg.Warning.RoarSpeed, Cfg.Warning.RoarVolume)
	print(("[ALIEN] %s ruge: ha visto a %s (%.1f s para escapar)"):format(self.model.Name, character.Name, Cfg.Warning.Duration))
end

function Brain:UpdateWarning()
	local target = self.warningTarget
	if not target or self.visiblePlayer ~= target then
		-- Ventana de escape aprovechada: pierde la línea de visión y se queda investigando.
		print(("[ALIEN] %s perdió de vista al jugador durante el rugido"):format(self.model.Name))
		self.warningTarget = nil
		if self.warningResume == State.AlertaRoja or StationAlarmService.IsAlarmActive() then
			self.chasing = false
			self:SetState(State.AlertaRoja)
		else
			self.suspicion = math.min(self.suspicion, Cfg.Warning.CancelSuspicion)
			self:SetInvestigationTarget(self.lastSeenPosition or self.root.Position)
			self:SetState(State.Investigar)
		end
		return
	end

	local root = target:FindFirstChild("HumanoidRootPart")
	if root then
		self.lastSeenPosition = root.Position
		local look = Vector3.new(root.Position.X, self.root.Position.Y, root.Position.Z)
		if (look - self.root.Position).Magnitude > 0.1 then
			self.root.CFrame = CFrame.lookAt(self.root.Position, look)
		end
	end
	if os.clock() < self.warningUntil then
		return
	end

	-- Sigue de pie a la vista tras 2.5 s: confirmado.
	self.warningTarget = nil
	self.confirmed = true
	if self.warningResume == State.AlertaRoja or StationAlarmService.IsAlarmActive() then
		self.chasing = true
		self.lastVisibleTime = os.clock()
		self:SetState(State.AlertaRoja)
	elseif StationAlarmService.TryReserveRunner(self.model) then
		StationAlarmService.ReportIntruder(self.lastSeenPosition or self.root.Position, self.model)
		self:SetState(State.CorrerHaciaAlarma)
	else
		-- Ya hay un corredor: este alien acosa la última posición vista.
		self:SetInvestigationTarget(self.lastSeenPosition or self.root.Position)
		self:SetState(State.Investigar)
	end
end

function Brain:EvaluateTransitions()
	if self.state == State.Advertencia then
		return -- la advertencia se resuelve sola en UpdateWarning
	end

	if StationAlarmService.IsAlarmActive() then
		if self.state ~= State.AlertaRoja then
			self:SetState(State.AlertaRoja)
		end
		return
	end

	if self.state == State.CorrerHaciaAlarma or self.state == State.AlertaRoja then
		return
	end

	if self.suspicion < Cfg.Thresholds.Investigate then
		self.confirmed = false
	end

	if self.suspicion >= Cfg.Thresholds.Confirm and not self.confirmed then
		if self.visiblePlayer then
			self:BeginWarning(self.visiblePlayer, State.Investigar)
			return
		end
		-- R5: solo se confirma VIENDO al jugador. Ruidos, pistas, etc. no pasan de 99.
		self.suspicion = Cfg.Thresholds.Confirm - 1
	end

	if self.state == State.Patrullar and self.suspicion >= Cfg.Thresholds.Investigate then
		if not self.investigationTarget then
			self:SetInvestigationTarget(self.lastSeenPosition or self.root.Position)
		end
		self:SetState(State.Investigar)
	elseif self.state == State.Investigar then
		local searchDone = self.arrived and os.clock() >= self.searchUntil
		if searchDone and self.suspicion <= 0 and self.visiblePlayer == nil then
			self:SetState(State.Patrullar)
		end
	end
end

-- Percepción --------------------------------------------------------------------------
function Brain:EyePosition(): Vector3
	return self.head.Position + Vector3.new(0, Cfg.Vision.EyeHeight * 0.25, 0)
end

-- ¿Está "point" dentro del cono y del alcance, sin oclusores? (owner = modelo al que pertenece el punto)
function Brain:CanSeePoint(point: Vector3, owner: Instance?, range: number): boolean
	local eye = self:EyePosition()
	local toPoint = point - eye
	local distance = toPoint.Magnitude
	if distance > range or distance < 0.01 then
		return distance < 0.01
	end

	local forward = flat(self.root.CFrame.LookVector)
	local dirFlat = flat(toPoint)
	if forward.Magnitude > 0 and dirFlat.Magnitude > 0 then
		if forward.Unit:Dot(dirFlat.Unit) < COS_HALF_CONE then
			return false
		end
	end

	if isBlockedBySmoke(eye, point) then
		return false
	end

	local result = Workspace:Raycast(eye, toPoint, self.rayParams)
	if not result then
		return true
	end
	-- IsDescendantOf(x) es false para x mismo: un cadáver de una sola Part se compara directamente.
	return owner ~= nil and (result.Instance == owner or result.Instance:IsDescendantOf(owner))
end

-- R5: reglas de visión del jugador, en este orden (todas deterministas):
--   1. escondido / capturado / escapado -> no
--   2. agachado a más de CrouchHiddenDistance -> no (regla de la sombra)
--   3. fuera del cono frontal de 85° o del alcance -> no
--   4. humo u obstáculo entre los ojos y el jugador -> no
function Brain:CanSeeCharacter(character: Model): boolean
	if not isTargetable(character) then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	if PlayerStateService.GetMoveMode(character) == Types.MoveMode.Crouch
		and (root.Position - self.root.Position).Magnitude > Cfg.Vision.CrouchHiddenDistance then
		return false
	end
	return self:CanSeePoint(root.Position, character, Cfg.Vision.Range)
end

function Brain:FindVisiblePlayer(): (Model?, number)
	local best, bestDistance = nil, math.huge
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			local d = (root.Position - self.root.Position).Magnitude
			if d < bestDistance and self:CanSeeCharacter(character) then
				best, bestDistance = character, d
			end
		end
	end
	return best, bestDistance
end

-- Linterna encendida dentro del cono visual (el haz se ve desde más lejos que el cuerpo).
function Brain:SeesFlashlight(): (boolean, Vector3?)
	local range = Cfg.Vision.Range * Cfg.Vision.FlashlightRangeMultiplier
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if isTargetable(character) and PlayerStateService.IsFlashlightOn(character) then
			local head = character:FindFirstChild("Head")
			if head and self:CanSeePoint(head.Position, character, range) then
				return true, head.Position
			end
		end
	end
	return false, nil
end

function Brain:CheckCorpses()
	for _, inst in CollectionService:GetTagged(Types.Tags.Corpse) do
		if not self.seenCorpses[inst] then
			local part = StationAlarmService.GetPart(inst)
			if part and part:IsDescendantOf(Workspace) and self:CanSeePoint(part.Position, inst, Cfg.Vision.Range) then
				self.seenCorpses[inst] = true
				if self.state == State.Patrullar or self.state == State.Investigar then
					self:AddSuspicion(Cfg.Suspicion.CorpseSeenDelta)
					self:SetInvestigationTarget(part.Position)
					if self.state == State.Patrullar then
						self:SetState(State.Investigar)
					end
				end
			end
		end
	end
end

-- R3: sangre fresca a la vista -> +30 e investigar la gota MÁS RECIENTE que ve (sigue el rastro).
function Brain:CheckBlood()
	if self.state ~= State.Patrullar and self.state ~= State.Investigar then
		return
	end
	local newest, newestTime = nil, -math.huge
	for _, drop in CollectionService:GetTagged(Types.Tags.BloodDrop) do
		if not self.seenBlood[drop] and drop:IsA("BasePart") and drop.Parent then
			local t = drop:GetAttribute("SpawnTime") or 0
			if t > newestTime and self:CanSeePoint(drop.Position, drop, Cfg.Vision.Range) then
				newest, newestTime = drop, t
			end
		end
	end
	if not newest then
		return
	end
	-- Marca como vistas esta y todas las anteriores visibles: no retrocede por el rastro.
	for _, drop in CollectionService:GetTagged(Types.Tags.BloodDrop) do
		if (drop:GetAttribute("SpawnTime") or 0) <= newestTime then
			self.seenBlood[drop] = true
		end
	end
	self:AddSuspicion(CraftingConfig.Blood.SuspicionDelta)
	self:SetInvestigationTarget(newest.Position)
	self:EvaluateTransitions()
	if self.state == State.Patrullar then
		self:SetState(State.Investigar)
	end
end

-- R3: aturdimiento por mina PEM
function Brain:Stun(duration: number)
	self.stunnedUntil = math.max(self.stunnedUntil, os.clock() + duration)
	self:StopMoving()
	self.humanoid.WalkSpeed = 0
	self.model:SetAttribute("Stunned", true)
	print(("[ALIEN] %s aturdido %.1f s"):format(self.model.Name, duration))
end

function Brain:IsStunned(): boolean
	return os.clock() < self.stunnedUntil
end

-- Ruido (pasos u otros): llamado por AlienAIService.ReportNoise
function Brain:OnNoise(position: Vector3, delta: number, source: Instance?)
	if self:IsStunned() then
		return
	end
	-- Ruido del ocupante del armario que estoy olfateando: lo abro.
	if self.inspectSpot and self.inspectUntil and source and HidingSpotService.GetOccupant(self.inspectSpot) == source then
		local spot = self.inspectSpot
		self:EndInspect()
		self:ForceOpenSpot(spot)
		return
	end
	if self.state == State.CorrerHaciaAlarma then
		return -- el corredor no se distrae
	end
	if self.state == State.AlertaRoja then
		if self.visiblePlayer == nil then
			self.lastSeenPosition = position
			self.lastKnownReachedAt = nil
		end
		return
	end
	self:AddSuspicion(delta)
	self:SetInvestigationTarget(position)
	self:EvaluateTransitions()
end

-- Navegación ----------------------------------------------------------------------------
function Brain:InvalidatePath()
	self.pathGoal = nil
	self.waypoints = nil
end

function Brain:StopMoving()
	self:InvalidatePath()
	self.pathRequestId += 1
	self.humanoid:MoveTo(self.root.Position)
end

function Brain:RequestPath(goal: Vector3)
	self.pathRequestId += 1
	local requestId = self.pathRequestId
	self.pathGoal = goal
	self.lastPathTime = os.clock()
	self.computing = true

	task.spawn(function()
		local path = PathfindingService:CreatePath({
			AgentRadius = Cfg.Path.AgentRadius,
			AgentHeight = Cfg.Path.AgentHeight,
			AgentCanJump = Cfg.Path.AgentCanJump,
		})
		local ok = pcall(function()
			path:ComputeAsync(self.root.Position, goal)
		end)
		if requestId ~= self.pathRequestId then
			return -- llegó una petición más nueva mientras calculábamos
		end
		self.computing = false

		if self.blockedConn then
			self.blockedConn:Disconnect()
			self.blockedConn = nil
		end

		if ok and path.Status == Enum.PathStatus.Success then
			self.waypoints = path:GetWaypoints()
			self.waypointIndex = math.min(2, #self.waypoints)
			self.blockedConn = path.Blocked:Connect(function(blockedIndex)
				if requestId == self.pathRequestId and blockedIndex >= self.waypointIndex then
					self:InvalidatePath()
				end
			end)
		else
			-- Sin ruta (destino fuera del navmesh): intento directo.
			self.waypoints = nil
			self.humanoid:MoveTo(goal)
		end
	end)
end

-- Llamar en cada tick con el destino deseado. direct = perseguir sin pathfinding (LOS a corta distancia).
function Brain:MoveTowards(goal: Vector3, direct: boolean?)
	if direct then
		self:InvalidatePath()
		self.humanoid:MoveTo(goal)
		return
	end

	local now = os.clock()
	local needsPath = self.pathGoal == nil or (self.pathGoal - goal).Magnitude > Cfg.Path.RepathTargetMoved
	if needsPath and not self.computing and now - self.lastPathTime >= Cfg.Path.MinRepathInterval then
		self:RequestPath(goal)
	end

	local waypoints = self.waypoints
	if not waypoints then
		return
	end
	local wp = waypoints[self.waypointIndex]
	while wp and flatDistance(self.root.Position, wp.Position) <= Cfg.Path.WaypointReachedRadius do
		self.waypointIndex += 1
		wp = waypoints[self.waypointIndex]
	end
	if wp then
		self.humanoid:MoveTo(wp.Position)
		if wp.Action == Enum.PathWaypointAction.Jump then
			self.humanoid.Jump = true
		end
	else
		self.humanoid:MoveTo(goal) -- último tramo
	end
end

function Brain:IsNear(position: Vector3, radius: number): boolean
	return flatDistance(self.root.Position, position) <= radius
end

-- Comportamiento por estado --------------------------------------------------------------
function Brain:UpdatePatrol()
	local points = getPatrolPoints()
	if #points == 0 then
		self:StopMoving()
		return
	end
	if self.patrolIndex == nil or self.patrolIndex > #points then
		-- Empieza por el punto más cercano
		local bestIndex, bestDist = 1, math.huge
		for i, p in points do
			local d = (p.Position - self.root.Position).Magnitude
			if d < bestDist then
				bestIndex, bestDist = i, d
			end
		end
		self.patrolIndex = bestIndex
	end
	local target = points[self.patrolIndex].Position
	if self:IsNear(target, Cfg.Investigation.ArriveRadius) then
		self.patrolIndex = (self.patrolIndex % #points) + 1
		target = points[self.patrolIndex].Position
	end
	self:MoveTowards(target)
end

function Brain:UpdateInvestigate()
	if self.inspectSpot and self:UpdateInspectSpot() then
		return
	end
	local target = self.investigationTarget
	if not target then
		self.arrived = true
		return
	end
	if not self.arrived then
		if self:IsNear(target, Cfg.Investigation.ArriveRadius) then
			self.arrived = true
			self.searchUntil = os.clock() + Cfg.Investigation.SearchDuration
			self:StopMoving()
			-- R2: 20 % de inspeccionar un armario cercano
			if not self.inspectRolled then
				self.inspectRolled = true
				local spot = HidingSpotService.FindNearest(target, Cfg.HidingSpot.InspectSearchRadius)
				if spot and math.random() < Cfg.HidingSpot.InspectChance then
					self:BeginInspect(spot, false)
				end
			end
		else
			self:MoveTowards(target)
		end
		return
	end
	-- Búsqueda: pequeños desplazamientos aleatorios alrededor del punto
	local now = os.clock()
	if now < self.searchUntil and now >= self.nextLookAround then
		self.nextLookAround = now + 1.3
		local angle = math.random() * math.pi * 2
		self:MoveTowards(target + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 6, true)
	end
end

function Brain:UpdateRunToAlarm(dt: number)
	if not self.consoleTarget or self.consoleTarget.Parent == nil then
		self.consoleTarget = StationAlarmService.FindNearestConsole(self.root.Position)
		if not self.consoleTarget then
			warn("[ALIEN] No hay AlarmConsole en el nivel: Alerta Roja directa")
			StationAlarmService.TriggerRedAlert(self.model)
			return
		end
	end

	local consolePos = self.consoleTarget.Position
	if self:IsNear(consolePos, Cfg.Alarm.InteractionRadius) then
		if self.consoleTimer == 0 then
			self:StopMoving()
		end
		self.consoleTimer += dt
		self.model:SetAttribute("AlarmProgress", math.clamp(self.consoleTimer / Cfg.Alarm.InteractionTime, 0, 1))
		if self.consoleTimer >= Cfg.Alarm.InteractionTime then
			self.model:SetAttribute("AlarmProgress", nil)
			StationAlarmService.TriggerRedAlert(self.model)
		end
	else
		self.consoleTimer = 0
		self:MoveTowards(consolePos)
	end
end

function Brain:Capture(character: Model)
	if character:GetAttribute("HiddenInSpot") then
		return -- R5: el armario es refugio 100 % seguro
	end
	capturePlayer(character, self.model)
	self:StopMoving()
	self.visiblePlayer = nil
	self.lastSeenPosition = nil
end

function Brain:UpdateHunt()
	local character = self.visiblePlayer
	local now = os.clock()
	if character then
		self.lastVisibleTime = now
		if not self.chasing then
			-- R5: también en Alerta Roja, cada nuevo avistamiento empieza con el rugido.
			self:BeginWarning(character, State.AlertaRoja)
			return
		end
	elseif self.chasing and now - self.lastVisibleTime > Cfg.Warning.ChaseGrace then
		self.chasing = false -- lo perdió: el próximo avistamiento volverá a rugir
	end

	if character then
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then
			local pos = root.Position
			self.lastSeenPosition = pos
			self.lastKnownReachedAt = nil
			StationAlarmService.UpdateLastKnownLocation(pos)

			local distance = (pos - self.root.Position).Magnitude
			if distance <= Cfg.Hunt.CaptureRadius then
				self:Capture(character)
				return
			end
			-- A la vista y cerca: persecución directa; lejos: ruta
			self:MoveTowards(pos, distance < 20)
			return
		end
	end

	if self.inspectSpot and self:UpdateInspectSpot() then
		return
	end

	local lastKnown = self.lastSeenPosition or StationAlarmService.GetLastKnownLocation()
	if lastKnown then
		if self.lastKnownReachedAt == nil then
			if self:IsNear(lastKnown, Cfg.Investigation.ArriveRadius) then
				self.lastKnownReachedAt = os.clock()
				self:StopMoving()
			else
				self:MoveTowards(lastKnown)
			end
			return
		elseif os.clock() - self.lastKnownReachedAt < Cfg.Hunt.LastKnownSearchTime then
			return
		end
		-- Rastro frío: deambular por la patrulla a velocidad de caza
		self.lastSeenPosition = nil
	end
	self:UpdatePatrol()
end

-- Tick principal -------------------------------------------------------------------------
function Brain:Tick(dt: number)
	-- Aturdido: ni percibe, ni se mueve, ni ataca. La sospecha se congela.
	if self.stunnedUntil > 0 then
		if self:IsStunned() then
			self.visiblePlayer = nil
			self.humanoid.WalkSpeed = 0
			self:Report()
			return
		end
		self.stunnedUntil = 0
		self.model:SetAttribute("Stunned", nil)
		self.humanoid.WalkSpeed = Cfg.Speeds[self.state] or Cfg.Speeds.Patrullar
		self:InvalidatePath()
	end

	local visible, _ = self:FindVisiblePlayer()
	self.visiblePlayer = visible
	self:CheckCorpses()
	self:CheckBlood()

	if self.state == State.Patrullar or self.state == State.Investigar then
		local rate = 0
		if visible then
			local mode = PlayerStateService.GetMoveMode(visible)
			if mode == Types.MoveMode.Run then
				rate += Cfg.Suspicion.RunningInSightRate
			elseif mode == Types.MoveMode.Crouch then
				rate += Cfg.Suspicion.CrouchingInSightRate
			else
				rate += Cfg.Suspicion.WalkingInSightRate
			end
			local root = visible:FindFirstChild("HumanoidRootPart")
			if root then
				self.lastSeenPosition = root.Position
				self:SetInvestigationTarget(root.Position)
			end
		end

		local seesLight, lightPos = self:SeesFlashlight()
		if seesLight then
			rate += Cfg.Suspicion.FlashlightInConeRate
			if not visible and lightPos then
				self:SetInvestigationTarget(lightPos)
			end
		end

		if rate > 0 then
			self:AddSuspicion(rate * dt)
		else
			local canDecay = self.state == State.Patrullar or self.arrived
			if canDecay then
				self:AddSuspicion(-Cfg.Suspicion.DecayRate * dt)
			end
		end
		self:EvaluateTransitions()
	elseif StationAlarmService.IsAlarmActive() and self.state ~= State.AlertaRoja and self.state ~= State.Advertencia then
		self:SetState(State.AlertaRoja)
	end

	if self.state == State.Advertencia then
		self.humanoid.WalkSpeed = 0
		self:UpdateWarning()
	elseif self.state == State.Patrullar then
		self:UpdatePatrol()
	elseif self.state == State.Investigar then
		self:UpdateInvestigate()
	elseif self.state == State.CorrerHaciaAlarma then
		self:UpdateRunToAlarm(dt)
	elseif self.state == State.AlertaRoja then
		self.suspicion = Cfg.Suspicion.Max
		self:UpdateHunt()
	end

	self:Report()
end

-- Servicio ---------------------------------------------------------------------------------
local function registerAlien(inst: Instance)
	if not inst:IsA("Model") or brains[inst] then
		return
	end
	local humanoid = inst:FindFirstChildOfClass("Humanoid") or inst:WaitForChild("Humanoid", 5)
	local root = inst:FindFirstChild("HumanoidRootPart") or inst:WaitForChild("HumanoidRootPart", 5)
	if not humanoid or not root then
		warn(("[ALIEN] %s tiene el tag Alien pero le falta Humanoid o HumanoidRootPart"):format(inst:GetFullName()))
		return
	end
	brains[inst] = Brain.new(inst)
end

local function unregisterAlien(inst: Instance)
	local brain = brains[inst]
	if brain then
		brain:Destroy()
		brains[inst] = nil
	end
end

-- Ruido en el mundo: todo alien dentro del radio lo oye (sin oclusión, como el Hearing de UE).
function AlienAIService.ReportNoise(position: Vector3, radius: number, delta: number, source: Instance?)
	for _, brain in brains do
		if brain:IsValid() and (brain.root.Position - position).Magnitude <= radius then
			brain:OnNoise(position, delta, source)
		end
	end
end

-- Motion Tracker (R2): pitido audible si un alien en movimiento está a <= DangerDistance
-- dentro del cono frontal de 180° del jugador. Calculado en el servidor (no se fía del cliente).
local lastTrackerPing: { [Player]: number } = {}
local function updateTrackerDanger()
	local tracker = Cfg.MotionTracker
	local cosHalf = math.cos(math.rad(tracker.ConeAngle / 2))
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and PlayerStateService.IsTrackerActive(character) and not character:GetAttribute("Captured") then
			local forward = flat(root.CFrame.LookVector)
			local nearest = math.huge
			for _, brain in brains do
				if brain:IsValid() and flat(brain.root.AssemblyLinearVelocity).Magnitude >= tracker.MinTargetSpeed then
					local offset = brain.root.Position - root.Position
					local d = offset.Magnitude
					local dirFlat = flat(offset)
					local inCone = d < 0.01 or forward.Magnitude == 0 or dirFlat.Magnitude == 0
						or forward.Unit:Dot(dirFlat.Unit) >= cosHalf - 1e-3
					if d <= tracker.Range and inCone then
						nearest = math.min(nearest, d)
					end
				end
			end
			if nearest <= tracker.Range then
				local alpha = math.clamp(nearest / tracker.Range, 0, 1)
				local interval = tracker.PingIntervalNear + (tracker.PingIntervalFar - tracker.PingIntervalNear) * alpha
				if now - (lastTrackerPing[player] or 0) >= interval then
					lastTrackerPing[player] = now
					if nearest <= tracker.DangerDistance then
						AlienAIService.ReportNoise(root.Position, tracker.DangerNoiseRadius, tracker.DangerSuspicionDelta, character)
					end
				end
			end
		end
	end
end

function AlienAIService.Stun(model: Model, duration: number)
	local brain = brains[model]
	if brain and brain:IsValid() then
		brain:Stun(duration)
	end
end

function AlienAIService.GetBrains()
	return brains
end

function AlienAIService.Init(runtimeFolder: Folder)
	local remote = Instance.new("RemoteEvent")
	remote.Name = Types.Remotes.PlayerCaptured
	remote.Parent = runtimeFolder
	capturedRemote = remote

	StationAlarmService.RedAlert:Connect(function()
		for _, brain in brains do
			if brain:IsValid() then
				brain.lastSeenPosition = brain.lastSeenPosition or StationAlarmService.GetLastKnownLocation()
				if brain.state == State.Advertencia then
					brain.warningResume = State.AlertaRoja -- termina de rugir y pasa a cazar
				else
					brain:SetState(State.AlertaRoja)
				end
			end
		end
	end)

	StationAlarmService.IntruderReported:Connect(function(location: Vector3, reporter: Model?)
		-- Los demás aliens en patrulla acuden a la zona del avistamiento.
		for model, brain in brains do
			if model ~= reporter and brain:IsValid() and brain.state == State.Patrullar then
				brain.suspicion = math.max(brain.suspicion, Cfg.Thresholds.Investigate)
				brain:SetInvestigationTarget(location)
				brain:SetState(State.Investigar)
			end
		end
	end)

	-- R5: si un alien ve al jugador meterse en un armario, busca en la zona 4 s y se rinde.
	-- NUNCA abre el armario por haberlo visto entrar (solo por ruido del ocupante: OnNoise).
	HidingSpotService.PlayerEntering:Connect(function(character: Model, spot: Instance)
		local root = character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		for _, brain in brains do
			if brain:IsValid() and brain.state ~= State.CorrerHaciaAlarma and not brain:IsStunned()
				and brain:CanSeeCharacter(character) then
				brain.lastSeenPosition = root.Position
				brain.warningTarget = nil
				brain.chasing = false
				if brain.state == State.Advertencia then
					brain:SetState(brain.warningResume == State.AlertaRoja and State.AlertaRoja or State.Investigar)
				end
				if brain.state ~= State.AlertaRoja then
					brain.suspicion = math.clamp(brain.suspicion, Cfg.Thresholds.Investigate, Cfg.Thresholds.Confirm - 1)
					brain:SetInvestigationTarget(HidingSpotService.GetHidePosition(spot))
					if brain.state == State.Patrullar then
						brain:SetState(State.Investigar)
					end
				end
				brain:BeginInspect(spot, false)
				brain.searchRoom = true
				print(("[ALIEN] %s vio a %s esconderse: buscará %d s"):format(
					brain.model.Name, character.Name, Cfg.HidingSpot.SeenEnterSearchDuration))
			end
		end
	end)

	-- R5: la consola de seguridad desactiva la alarma -> todos vuelven a patrullar en calma.
	StationAlarmService.AlarmDeactivated:Connect(function()
		for _, brain in brains do
			if brain:IsValid() then
				brain.warningTarget = nil
				brain.chasing = false
				brain.confirmed = false
				brain.suspicion = 0
				brain.lastSeenPosition = nil
				brain:EndInspect()
				brain:SetState(State.Patrullar)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastTrackerPing[player] = nil
	end)

	StationAlarmService.DoorsChanged:Connect(function()
		for _, brain in brains do
			brain:InvalidatePath()
		end
	end)

	CollectionService:GetInstanceAddedSignal(Types.Tags.Alien):Connect(function(inst)
		task.spawn(registerAlien, inst)
	end)
	CollectionService:GetInstanceRemovedSignal(Types.Tags.Alien):Connect(unregisterAlien)
	for _, inst in CollectionService:GetTagged(Types.Tags.Alien) do
		task.spawn(registerAlien, inst)
	end

	local interval = 1 / Cfg.TickRate
	local accumulator = 0
	RunService.Heartbeat:Connect(function(step)
		accumulator += step
		if accumulator < interval then
			return
		end
		local dt = accumulator
		accumulator = 0
		updateTrackerDanger()
		for model, brain in brains do
			if model.Parent == nil then
				unregisterAlien(model)
			elseif brain:IsValid() then
				local ok, err = pcall(brain.Tick, brain, dt)
				if not ok then
					warn(("[ALIEN] Error en %s: %s"):format(model.Name, tostring(err)))
				end
			end
		end
	end)
end

return AlienAIService
