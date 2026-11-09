--!strict
-- Recursos, recetas y gadgets (Milestone R3). Valores marcados con (*) son míos, no del spec.

local CraftingConfig = {}

CraftingConfig.Resources = { "Chatarra", "Quimicos", "Bateria", "Circuito" }

CraftingConfig.ResourceNames = {
	Chatarra = "Chatarra",
	Quimicos = "Químicos",
	Bateria = "Batería",
	Circuito = "Circuito",
}

CraftingConfig.Gadgets = { "EMPMine", "SmokeBomb", "Medkit" }

CraftingConfig.GadgetNames = {
	EMPMine = "Mina PEM",
	SmokeBomb = "Bomba de Humo",
	Medkit = "Botiquín",
}

-- Tecla rápida de uso (1/2/3)
CraftingConfig.Hotkeys = {
	EMPMine = Enum.KeyCode.One,
	SmokeBomb = Enum.KeyCode.Two,
	Medkit = Enum.KeyCode.Three,
}

CraftingConfig.Recipes = {
	EMPMine = { Chatarra = 1, Bateria = 1, Circuito = 1 },
	SmokeBomb = { Chatarra = 1, Quimicos = 2 },
	Medkit = { Quimicos = 2, Chatarra = 1 },
}

CraftingConfig.Craft = {
	Duration = 2.5,
	MaxMoveDistance = 2, -- studs desde donde empezó
	MaxStack = 3, -- (*) por gadget
}

CraftingConfig.Gadget = {
	EMP = {
		TriggerRadius = 5,
		StunDuration = 5,
		ArmDelay = 1, -- (*) para que el jugador se aleje
		LightColor = Color3.fromRGB(80, 160, 255),
		SoundId = "", -- rbxassetid de descarga eléctrica (vacío = sin sonido)
	},
	Smoke = {
		Radius = 10,
		Duration = 8,
		ThrowSpeed = 55, -- (*) studs/s
		ThrowUpAngle = 12, -- (*) grados sobre la horizontal
		FuseMax = 3, -- (*) explota al tocar algo o a los 3 s
	},
	Medkit = {
		Heal = 50,
	},
}

CraftingConfig.Blood = {
	HealthThreshold = 40,
	IntervalMoving = 2,
	IntervalStill = 4,
	Lifetime = 60,
	FadeTime = 5, -- (*) últimos segundos desvaneciéndose
	SuspicionDelta = 30,
	MinMoveSpeed = 2,
}

CraftingConfig.Pickup = {
	DefaultAmount = 1,
}

return CraftingConfig
