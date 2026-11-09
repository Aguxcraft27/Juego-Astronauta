--!strict
-- Generador pseudoaleatorio determinista (xorshift32) para ShipGen.
-- No usa Random de Roblox: así los tests headless (CLI `luau`) y el juego producen el MISMO mapa
-- para la misma semilla.

local Rng = {}
Rng.__index = Rng

export type Rng = typeof(setmetatable({} :: { state: number }, Rng))

function Rng.new(seed: number): Rng
	-- Mezcla la semilla (splitmix-like) para que semillas consecutivas no den secuencias parecidas
	local s = bit32.band(math.floor(seed) % 4294967296, 0xFFFFFFFF)
	s = bit32.bxor(s, 0x9E3779B9)
	s = bit32.band(s * 0x85EBCA6B % 4294967296, 0xFFFFFFFF)
	s = bit32.bxor(s, bit32.rshift(s, 13))
	if s == 0 then
		s = 0x6D2B79F5
	end
	local self = setmetatable({ state = s }, Rng)
	for _ = 1, 4 do
		self:NextU32()
	end
	return self
end

function Rng.NextU32(self: Rng): number
	local x = self.state
	x = bit32.bxor(x, bit32.lshift(x, 13))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	x = bit32.bxor(x, bit32.lshift(x, 5))
	self.state = x
	return x
end

-- [0, 1)
function Rng.NextNumber(self: Rng): number
	return self:NextU32() / 4294967296
end

-- Entero en [min, max]
function Rng.NextInt(self: Rng, min: number, max: number): number
	return min + (self:NextU32() % (max - min + 1))
end

function Rng.Chance(self: Rng, p: number): boolean
	return self:NextNumber() < p
end

function Rng.Pick<T>(self: Rng, list: { T }): T
	return list[self:NextInt(1, #list)]
end

function Rng.Shuffle<T>(self: Rng, list: { T }): { T }
	for i = #list, 2, -1 do
		local j = self:NextInt(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

return Rng
