--!strict
-- Cámara en primera persona (rediseño de infiltración).
-- StarterPlayer.CameraMode = LockFirstPerson se fija en default.project.json; este módulo:
--   * oculta localmente el cuerpo y las piezas del traje/casco (si no, el casco tapa la cámara),
--   * añade un balanceo de cabeza muy sutil al caminar/correr (se aplica después de la cámara
--     de Roblox, así que no pisa el CameraOffset del agachado que usa AstronautController).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local FirstPersonController = {}

local player = Players.LocalPlayer

local BOB = {
	Walk = { Freq = 7.5, Amp = 0.06 },
	Run = { Freq = 11, Amp = 0.12 },
	Crouch = { Freq = 5, Amp = 0.03 },
}

local bobTime = 0
local bobWeight = 0

local function hideCharacter(character: Model)
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = 1
		elseif d:IsA("Decal") then
			d.LocalTransparencyModifier = 1
		end
	end
end

function FirstPersonController.Start()
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	player.CameraMaxZoomDistance = 0.5
	player.CameraMinZoomDistance = 0.5

	RunService:BindToRenderStep("AstronautaFirstPerson", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		local character = player.Character
		local camera = Workspace.CurrentCamera
		if not character or not camera or camera.CameraType ~= Enum.CameraType.Custom then
			return
		end
		hideCharacter(character)

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not humanoid or not root then
			return
		end

		local v = root.AssemblyLinearVelocity
		local speed = Vector3.new(v.X, 0, v.Z).Magnitude
		local moving = speed > 1 and humanoid.FloorMaterial ~= Enum.Material.Air
		local mode = character:GetAttribute("MoveMode") or "Walk"
		local cfg = BOB[mode] or BOB.Walk

		bobWeight += ((moving and 1 or 0) - bobWeight) * math.min(dt * 8, 1)
		if moving then
			bobTime += dt * cfg.Freq
		end
		local x = math.sin(bobTime) * cfg.Amp * bobWeight
		local y = math.abs(math.cos(bobTime)) * cfg.Amp * bobWeight
		camera.CFrame = camera.CFrame * CFrame.new(x, y, 0)
	end)
end

return FirstPersonController
