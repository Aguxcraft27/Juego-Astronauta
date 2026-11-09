--!strict
-- PSX / Retro Low-Poly 90s Analog Horror Post-Processing for Astronauta
-- Pure procedural post-processing without external decal dependencies.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

local PSXPostProcessing = {}

function PSXPostProcessing.Start()
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")

    -- 1. Configuracion de Iluminacion Retro en Lighting
    local colorCorrection = Lighting:FindFirstChild("PSX_ColorCorrection") or Instance.new("ColorCorrectionEffect")
    colorCorrection.Name = "PSX_ColorCorrection"
    colorCorrection.Contrast = 0.18
    colorCorrection.Saturation = -0.15 -- Desaturacion clasica noventera
    colorCorrection.TintColor = Color3.fromRGB(240, 245, 252)
    colorCorrection.Parent = Lighting

    local bloom = Lighting:FindFirstChild("PSX_Bloom") or Instance.new("BloomEffect")
    bloom.Name = "PSX_Bloom"
    bloom.Intensity = 0.35
    bloom.Size = 18
    bloom.Threshold = 0.85
    bloom.Parent = Lighting

    -- 2. Filtro CRT Limpio sin texturas externas
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "PSX_AnalogOverlay"
    screenGui.ResetOnSpawn = false
    screenGui.DisplayOrder = 9999
    screenGui.IgnoreGuiInset = true

    -- Marco de borde oscuro sutil tipo CRT (4 barras en los extremos)
    local function makeBorder(name: string, pos: UDim2, size: UDim2)
        local bar = Instance.new("Frame")
        bar.Name = name
        bar.Position = pos
        bar.Size = size
        bar.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        bar.BackgroundTransparency = 0.85
        bar.BorderSizePixel = 0
        bar.Parent = screenGui
    end

    makeBorder("Top", UDim2.fromScale(0, 0), UDim2.new(1, 0, 0, 8))
    makeBorder("Bottom", UDim2.new(0, 0, 1, -8), UDim2.new(1, 0, 0, 8))
    makeBorder("Left", UDim2.fromScale(0, 0), UDim2.new(0, 8, 1, 0))
    makeBorder("Right", UDim2.new(1, -8, 0, 0), UDim2.new(0, 8, 1, 0))

    screenGui.Parent = playerGui
    print("[ASTRONAUTA] Post-procesado PSX limpio activado.")
end

return PSXPostProcessing
