--!nonstrict
-- Inventario y crafteo (Milestone R3).
--   I / Tab  -> abrir / cerrar el menú de fabricación
--   1 / 2 / 3 -> usar Mina PEM / Bomba de Humo / Botiquín
-- El inventario vive en atributos del Player ("Res_*", "Gadget_*") que pone el servidor (CraftingService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Astronauta")
local Types = require(Shared:WaitForChild("Types"))
local CraftingConfig = require(Shared:WaitForChild("CraftingConfig"))

local InventoryUI = {}

local player = Players.LocalPlayer
local remotes = {}
local ui = {}
local menuOpen = false
local craftEndTime: number? = nil
local craftDuration = 0

local GREEN = Color3.fromRGB(120, 220, 140)
local GREY = Color3.fromRGB(110, 115, 125)
local TEXT = Color3.fromRGB(215, 225, 235)

local function label(parent: Instance, text: string, size: UDim2, pos: UDim2, props: { [string]: any }?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.Gotham
	l.TextSize = 14
	l.TextColor3 = TEXT
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = text
	l.Size = size
	l.Position = pos
	if props then
		for k, v in props do
			(l :: any)[k] = v
		end
	end
	l.Parent = parent
	return l
end

local function recipeText(gadget: string): string
	local parts = {}
	for _, resource in CraftingConfig.Resources do
		local amount = CraftingConfig.Recipes[gadget][resource]
		if amount then
			table.insert(parts, ("%d %s"):format(amount, CraftingConfig.ResourceNames[resource]))
		end
	end
	return table.concat(parts, " + ")
end

local function canCraft(gadget: string): boolean
	if (player:GetAttribute("Gadget_" .. gadget) or 0) >= CraftingConfig.Craft.MaxStack then
		return false
	end
	for resource, amount in CraftingConfig.Recipes[gadget] do
		if (player:GetAttribute("Res_" .. resource) or 0) < amount then
			return false
		end
	end
	return true
end

local function refresh()
	for _, resource in CraftingConfig.Resources do
		local l = ui.resources[resource]
		l.Text = ("%s: %d"):format(CraftingConfig.ResourceNames[resource], player:GetAttribute("Res_" .. resource) or 0)
	end
	for i, gadget in CraftingConfig.Gadgets do
		local count = player:GetAttribute("Gadget_" .. gadget) or 0
		local row = ui.rows[gadget]
		row.count.Text = ("x%d"):format(count)
		local ok = canCraft(gadget)
		row.button.BackgroundColor3 = ok and Color3.fromRGB(40, 110, 70) or Color3.fromRGB(50, 52, 58)
		row.button.TextColor3 = ok and Color3.new(1, 1, 1) or GREY
		-- Barra rápida
		local slot = ui.hotbar[gadget]
		slot.Text = ("[%d] %s  x%d"):format(i, CraftingConfig.GadgetNames[gadget], count)
		slot.TextColor3 = count > 0 and GREEN or GREY
	end
end

local function setMenu(open: boolean)
	menuOpen = open
	ui.panel.Visible = open
end

local function buildGui()
	local gui = Instance.new("ScreenGui")
	gui.Name = "InventoryHUD"
	gui.ResetOnSpawn = false

	-- Panel de fabricación
	local panel = Instance.new("Frame")
	panel.Name = "CraftPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(420, 300)
	panel.BackgroundColor3 = Color3.fromRGB(14, 16, 22)
	panel.BackgroundTransparency = 0.1
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(70, 90, 110)
	stroke.Parent = panel

	label(panel, "FABRICACIÓN", UDim2.new(1, -24, 0, 24), UDim2.fromOffset(12, 10), {
		Font = Enum.Font.GothamBold,
		TextSize = 18,
	})
	label(panel, "[I] cerrar · no te muevas ni recibas daño mientras fabricas", UDim2.new(1, -24, 0, 16),
		UDim2.fromOffset(12, 34), { TextSize = 12, TextColor3 = GREY })

	ui.resources = {}
	for i, resource in CraftingConfig.Resources do
		ui.resources[resource] = label(panel, "", UDim2.fromOffset(95, 20),
			UDim2.fromOffset(12 + (i - 1) * 100, 58), { TextSize = 13, TextColor3 = Color3.fromRGB(230, 200, 120) })
	end

	ui.rows = {}
	for i, gadget in CraftingConfig.Gadgets do
		local y = 92 + (i - 1) * 56
		label(panel, CraftingConfig.GadgetNames[gadget], UDim2.fromOffset(200, 20), UDim2.fromOffset(12, y),
			{ Font = Enum.Font.GothamBold, TextSize = 15 })
		label(panel, recipeText(gadget), UDim2.fromOffset(260, 18), UDim2.fromOffset(12, y + 20),
			{ TextSize = 12, TextColor3 = GREY })
		local count = label(panel, "x0", UDim2.fromOffset(40, 20), UDim2.fromOffset(270, y + 8), { TextSize = 14 })
		local button = Instance.new("TextButton")
		button.Size = UDim2.fromOffset(90, 32)
		button.Position = UDim2.fromOffset(318, y + 2)
		button.Font = Enum.Font.GothamBold
		button.TextSize = 14
		button.Text = "Fabricar"
		button.AutoButtonColor = true
		button.BorderSizePixel = 0
		button.Parent = panel
		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(0, 6)
		bc.Parent = button
		button.Activated:Connect(function()
			remotes.RequestCraft:FireServer(gadget)
		end)
		ui.rows[gadget] = { count = count, button = button }
	end

	-- Barra de progreso de fabricación
	local progressBack = Instance.new("Frame")
	progressBack.Name = "CraftProgress"
	progressBack.AnchorPoint = Vector2.new(0.5, 1)
	progressBack.Position = UDim2.new(0.5, 0, 1, -110)
	progressBack.Size = UDim2.fromOffset(260, 12)
	progressBack.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	progressBack.BorderSizePixel = 0
	progressBack.Visible = false
	progressBack.Parent = gui
	local progressFill = Instance.new("Frame")
	progressFill.Size = UDim2.fromScale(0, 1)
	progressFill.BackgroundColor3 = GREEN
	progressFill.BorderSizePixel = 0
	progressFill.Parent = progressBack
	local progressText = label(progressBack, "", UDim2.new(1, 0, 0, 18), UDim2.new(0, 0, 0, -20), {
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Enum.Font.GothamBold,
		TextStrokeTransparency = 0.5,
	})

	-- Mensajes cortos (completado / cancelado)
	local toast = label(gui, "", UDim2.fromOffset(400, 24), UDim2.new(0.5, -200, 1, -150), {
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextStrokeTransparency = 0.4,
		TextTransparency = 1,
	})

	-- Barra rápida de gadgets (abajo a la izquierda, encima de la línea de controles)
	ui.hotbar = {}
	for i, gadget in CraftingConfig.Gadgets do
		ui.hotbar[gadget] = label(gui, "", UDim2.fromOffset(220, 18), UDim2.new(0, 20, 1, -110 + (i - 1) * 20), {
			TextSize = 13,
			TextStrokeTransparency = 0.5,
		})
	end

	gui.Parent = player:WaitForChild("PlayerGui")
	ui.panel = panel
	ui.progressBack = progressBack
	ui.progressFill = progressFill
	ui.progressText = progressText
	ui.toast = toast
end

local function showToast(text: string, color: Color3)
	ui.toast.Text = text
	ui.toast.TextColor3 = color
	ui.toast.TextTransparency = 0
	TweenService:Create(ui.toast, TweenInfo.new(1.5, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 1), {
		TextTransparency = 1,
	}):Play()
end

local function onCraftState(event: string, gadget: string, extra: any)
	local name = CraftingConfig.GadgetNames[gadget] or gadget
	if event == "started" then
		craftDuration = typeof(extra) == "number" and extra or CraftingConfig.Craft.Duration
		craftEndTime = os.clock() + craftDuration
		ui.progressBack.Visible = true
		ui.progressText.Text = "Fabricando " .. name .. "..."
	elseif event == "completed" then
		craftEndTime = nil
		ui.progressBack.Visible = false
		showToast(name .. " fabricado", GREEN)
	elseif event == "cancelled" then
		craftEndTime = nil
		ui.progressBack.Visible = false
		showToast(("%s: cancelado (%s)"):format(name, tostring(extra or "")), Color3.fromRGB(255, 120, 90))
	end
end

function InventoryUI.Start()
	local runtime = ReplicatedStorage:WaitForChild(Types.RuntimeFolderName)
	remotes.RequestCraft = runtime:WaitForChild(Types.Remotes.RequestCraft)
	remotes.UseGadget = runtime:WaitForChild(Types.Remotes.UseGadget)
	remotes.CraftState = runtime:WaitForChild(Types.Remotes.CraftState)

	buildGui()
	refresh()
	player.AttributeChanged:Connect(function(name)
		if string.sub(name, 1, 4) == "Res_" or string.sub(name, 1, 7) == "Gadget_" then
			refresh()
		end
	end)
	remotes.CraftState.OnClientEvent:Connect(onCraftState)

	local hotkeyToGadget = {}
	for gadget, key in CraftingConfig.Hotkeys do
		hotkeyToGadget[key] = gadget
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		-- Tab suele estar libre aunque "processed" sea false; I también.
		if input.KeyCode == Enum.KeyCode.I or input.KeyCode == Enum.KeyCode.Tab then
			if not processed or input.KeyCode == Enum.KeyCode.Tab then
				setMenu(not menuOpen)
			end
			return
		end
		if processed then
			return
		end
		local gadget = hotkeyToGadget[input.KeyCode]
		if gadget then
			remotes.UseGadget:FireServer(gadget)
		end
	end)

	RunService.RenderStepped:Connect(function()
		if craftEndTime then
			local alpha = 1 - math.clamp((craftEndTime - os.clock()) / craftDuration, 0, 1)
			ui.progressFill.Size = UDim2.fromScale(alpha, 1)
		end
	end)

	player.CharacterAdded:Connect(function()
		craftEndTime = nil
		ui.progressBack.Visible = false
	end)
end

return InventoryUI
