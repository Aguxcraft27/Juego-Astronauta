--!strict
-- Ajustes de diseño del alien (Balanceado para supervivencia y reacción justa).
-- Distancias en studs, tiempos en segundos.

local AlienConfig = {}

-- Sospecha (0-100) ---------------------------------------------------------
AlienConfig.Suspicion = {
	Max = 100,
	-- Tasas calibradas para dar tiempo de reacción al jugador al ser avistado:
	RunningInSightRate = 25,     -- Correr a la vista (4 segundos para alertar)
	WalkingInSightRate = 12,     -- Caminar/Estar de pie a la vista (8 segundos para alertar)
	CrouchingInSightRate = 4,    -- Agachado a la vista (25 segundos para alertar)
	FlashlightInConeRate = 15,   -- Linterna encendida apuntando hacia el alien
	-- Instantáneos
	CorpseSeenDelta = 30,
	-- Decaimiento: cuando el alien pierde de vista al jugador
	DecayRate = 10,
}

-- Ruido de pasos (lo emite el servidor según el modo de movimiento del jugador)
AlienConfig.Footsteps = {
	Run = { Radius = 50, Delta = 15, Interval = 0.5 },
	Walk = { Radius = 20, Delta = 8, Interval = 0.7 },
	Crouch = { Radius = 0, Delta = 0, Interval = math.huge }, -- 100% silencioso
	MinSpeed = 2, -- por debajo no hay pasos (quieto)
}

-- Umbrales de estado
AlienConfig.Thresholds = {
	Investigate = 30, -- A 30 entra en sospecha e investiga la zona
	Confirm = 100,    -- A 100 confirma presencia humana y corre a dar la alarma
}

-- Velocidades (Humanoid.WalkSpeed)
AlienConfig.Speeds = {
	Patrullar = 12,
	Investigar = 18,
	Advertencia = 0,
	CorrerHaciaAlarma = 32,
	AlertaRoja = 26,
}

-- Percepción
AlienConfig.Vision = {
	Range = 55,       -- Alcance visual
	ConeAngle = 85,   -- Cono de visión frontal; fuera de él el alien NUNCA ve (R5)
	CrouchHiddenDistance = 15, -- R5 "regla de la sombra": agachado a más de esto = invisible
	EyeHeight = 1.5,
	FlashlightRangeMultiplier = 1.3,
}

-- Investigación
AlienConfig.Investigation = {
	ArriveRadius = 5,
	SearchDuration = 4,
}

-- Alarma
AlienConfig.Alarm = {
	InteractionTime = 2.5,
	InteractionRadius = 7,
}

-- Alerta Roja
AlienConfig.Hunt = {
	CaptureRadius = 4,
	LastKnownSearchTime = 6,
}

-- Navegación
AlienConfig.Path = {
	AgentRadius = 2,
	AgentHeight = 6,
	AgentCanJump = false,
	WaypointReachedRadius = 3,
	RepathTargetMoved = 4,
	MinRepathInterval = 0.5,
}

-- Jugador (las aplica el servidor al recibir SetMoveMode)
AlienConfig.Player = {
	WalkSpeed = 16,
	RunSpeed = 22,
	CrouchSpeed = 9,
	CrouchCameraOffset = -1.5,
	FlashlightRange = 40,
	FlashlightAngle = 45,
	FlashlightBrightness = 3,
}

-- Advertencia / rugido (R5): ventana de escape antes de la persecución
AlienConfig.Warning = {
	Duration = 2.5,
	CancelSuspicion = 60, -- si pierde de vista al jugador durante el rugido, investiga con esta sospecha
	ChaseGrace = 1.0, -- (*) s sin verlo antes de dar la persecución por perdida (evita re-rugir por un pilar)
	RoarSoundId = "rbxasset://sounds/impact_explosion_03.mp3", -- marcador: grave y lento suena a rugido
	RoarSpeed = 0.3,
	RoarVolume = 1.5,
	GruntSpeed = 0.5, -- "suspiro" al rendirse buscando
	GruntVolume = 0.5,
}

-- Captura (R2)
AlienConfig.Capture = {
	SequenceDuration = 2.5,
}

-- Escondites (R2)
AlienConfig.HidingSpot = {
	InspectChance = 0.2,
	InspectSearchRadius = 15,
	InspectDuration = 3,
	InspectStandDistance = 3,
	SeenEnterSearchDuration = 4, -- R5: lo vio esconderse -> busca 4 s, se rinde y vuelve a patrullar
}

-- Motion Tracker (R2)
AlienConfig.MotionTracker = {
	Range = 45,
	ConeAngle = 180,
	MinTargetSpeed = 1.5,
	PingIntervalFar = 1.2,
	PingIntervalNear = 0.35,
	DangerDistance = 15,
	DangerSuspicionDelta = 20,
	DangerNoiseRadius = 18,
}

-- Oxígeno / vacío (R2)
AlienConfig.Vacuum = {
	MaxOxygen = 100,
	OxygenDrainRate = 10,
	SuffocationDamageRate = 15,
	OxygenRefillRate = 10,
}

-- Frecuencia del "cerebro" del servidor
AlienConfig.TickRate = 10

return AlienConfig
