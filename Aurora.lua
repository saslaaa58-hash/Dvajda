--[[
	AURORA GLASS v5  (Roblox / Luau)  —  LocalScript
	Чёрно-белая тема, матовое стекло, нарисованные иконки, кнопка-лаунчер (тап = открыть).

	ESP / WH : боксы 2D / углы / 3D, заливка, скелет, трейсеры, здоровье, имя, дистанция, оружие,
	           линия взгляда, радар, стрелки за экраном, Chams, свечение, проверка видимости,
	           цвет команды, боты (NPC), RGB-радуга, живой предпросмотр
	Бой      : увеличение хитбоксов (режим «скрытый»), Wallbang, убрать коллизию стен, X-Ray
	Пули     : трассеры (луч / лазер / снаряд) + маркер попадания
	Визуал   : FOV, свет, туман, свой прицел
]]

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting         = game:GetService("Lighting")
local Stats            = game:GetService("Stats")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera    = workspace.CurrentCamera

local V2 = Vector2.new
local U = {} -- хранилище UI-объектов (у Luau лимит 200 локальных переменных на файл)
-- M: модули, реестр элементов (для конфигов), список обновлений и очистки
local M = {ctl = {byKey = {}, count = {}}, upd = {}, clean = {}}
function M.reg(text, get, set)
	local c = M.ctl
	c.count[text] = (c.count[text] or 0) + 1
	c.byKey[text .. "#" .. c.count[text]] = {get = get, set = set}
end
function M.setByText(text, value)
	local c = M.ctl.byKey[text .. "#1"]
	if c then pcall(c.set, value) end
end

--------------------------------------------------------------------
-- ОЧИСТКА СТАРОЙ КОПИИ
--------------------------------------------------------------------
local conns = {}
local function bind(sig, fn)
	local c = sig:Connect(fn)
	conns[#conns + 1] = c
	return c
end

-- каждый модуль выполняется в защищённом вызове: ошибка одного не ломает остальные
local errorsLog = {}
local function guard(name, fn, ...)
	local ok, err = pcall(fn, ...)
	if ok then errorsLog[name] = nil else errorsLog[name] = string.sub(tostring(err), 1, 80) end
end

if _G.GlassMenuCleanup then pcall(_G.GlassMenuCleanup) end
local function destroyIf(o) if o then o:Destroy() end end
destroyIf(playerGui:FindFirstChild("GlassMenu"))
destroyIf(playerGui:FindFirstChild("GlassESP"))
destroyIf(Lighting:FindFirstChild("GlassMenuBlur"))
destroyIf(workspace:FindFirstChild("GlassMenuFolder"))
destroyIf(workspace:FindFirstChild("GlassMenuTest"))

--------------------------------------------------------------------
-- ТЕМА / КОНФИГ
--------------------------------------------------------------------
local THEME = {
	Accent  = Color3.fromRGB(240, 240, 240),
	Accent2 = Color3.fromRGB(120, 120, 120),
	Glass   = Color3.fromRGB(10, 10, 10),
	Text    = Color3.fromRGB(245, 245, 245),
	Sub     = Color3.fromRGB(150, 150, 150),
	Good    = Color3.fromRGB(255, 255, 255),
	Warn    = Color3.fromRGB(190, 190, 190),
	Bad     = Color3.fromRGB(110, 110, 110),
}
local WHITE = Color3.new(1, 1, 1)
local DARK  = Color3.fromRGB(22, 22, 22)
local SEL   = Color3.fromRGB(12, 12, 12) -- цвет текста/иконки на выбранной (белой) плашке

local ACCENT_SEQ = ColorSequence.new({
	ColorSequenceKeypoint.new(0, THEME.Accent),
	ColorSequenceKeypoint.new(0.5, THEME.Accent2),
	ColorSequenceKeypoint.new(1, THEME.Accent),
})
local LIGHT_SEQ = ColorSequence.new(WHITE, Color3.fromRGB(205, 205, 205))

local function C(r, g, b) return {C = Color3.fromRGB(r, g, b), Rainbow = false} end

local Config = {
	Rainbow = 0.27, -- циклов радуги в секунду
	ESP = {
		Enabled = false, Target = "Все", NPC = false, TeamColor = false, MaxDistance = 1500,
		VisCheck = false, HiddenColor = C(150, 150, 150),
		Box = {Enabled = true, Style = "2D", Color = C(255, 255, 255), Thickness = 2,
			Fill = false, FillColor = C(255, 255, 255), FillTransparency = 0.8, FillGradient = true},
		HeadDot = {Enabled = false, Color = C(255, 255, 255)},
		Info = {Name = true, DisplayName = true, NameColor = C(255, 255, 255), HealthBar = true, HealthText = true,
			Distance = true, Weapon = true, TextColor = C(200, 200, 200), TextSize = 13},
		Skeleton = {Enabled = false, Color = C(255, 255, 255), Thickness = 2},
		Tracer = {Enabled = false, Origin = "Снизу", Target = "Ноги", Color = C(255, 255, 255), Thickness = 2},
		Look = {Enabled = false, Color = C(255, 255, 255), Length = 8, Thickness = 2},
		Arrows = {Enabled = false, Radius = 220, Size = 14, Color = C(255, 255, 255)},
	},
	Radar = {Enabled = false, Size = 150, Range = 250, Corner = "Лево-верх", Color = C(255, 255, 255)},
	Chams = {Enabled = false, Fill = C(255, 255, 255), FillTransparency = 0.5, Outline = C(255, 255, 255),
		OutlineTransparency = 0, AlwaysOnTop = true, Pulse = false},
	Glow = {Enabled = false, Color = C(255, 255, 255), Brightness = 3, Range = 14},
	Bullets = {Enabled = false, Style = "Луч", Color = C(255, 255, 255), Width = 0.15, Lifetime = 1.2,
		Origin = "Авто", ToolOnly = false, Interval = 0.1, HitMarker = true, HitColor = C(255, 255, 255)},
	Hitbox = {Enabled = false, Part = "HRP", Size = 10, Target = "Все", NPC = false, Hidden = false,
		Color = C(255, 255, 255), Transparency = 0.6},
	Wall = {Bang = false, NoClip = false, KeepFloor = true, Radius = 200, MaxThickness = 0, Xray = 0},
	Crosshair = {Enabled = false, Color = C(255, 255, 255), Size = 8, Gap = 4, Thickness = 2, Dot = true},
	Move = {Fov = false, Walk = false, Jump = false, InfJump = false, Noclip = false},
	TeamMode = "Авто",
	Peek = {Enabled = false, Range = 150, MinSpeed = 4, Approach = 60, OnlyApproach = true,
		Peek = true, Side = "Авто", PeekTime = 0.4, Return = true, Cooldown = 2,
		Shoot = true, Method = "Tool + клик", Delay = 0.05, Interval = 0.12, VisOnly = true, OnlyWhilePeek = false,
		Assist = false, AssistPart = "Голова", Smooth = 10, AssistFov = 30, ShowFov = false},
	Hit = {Enabled = false, Style = "Крест", Color = C(255, 255, 255), KillColor = C(255, 70, 70), Size = 18, Thickness = 2,
		Time = 0.3, Sound = true, HitSound = "Пинг", KillSound = "Оф", Volume = 60, CustomHit = "", CustomKill = "",
		OnlyAfterShot = true, Counter = false},
	Cam = {Third = false, Dist = 12, FreeZoom = true, Offset = 0,
		Zoom = {Enabled = false, FOV = 20, Key = "Z", Smooth = 12, Button = false}},
	Atmo = {Clock = false, Bright = false, Expo = false, AmbientOn = false, Ambient = C(90, 100, 140),
		FogOn = false, FogColor = C(170, 175, 190), FogStart = 0, FogEnd = 800, ShadowsOff = false, SkyOff = false,
		AtmoOn = false, AtmoDensity = 35, AtmoHaze = 20, AtmoGlare = 0, AtmoColor = C(199, 199, 199),
		BloomOn = false, BloomInt = 100, BloomSize = 24, BloomThr = 80,
		CCOn = false, CCBright = 0, CCContrast = 0, CCSat = 0, CCTint = C(255, 255, 255),
		RaysOn = false, RaysInt = 25},
}

local hue = 0
local function col(o)
	if o.Rainbow then return Color3.fromHSV(hue, 0.85, 1) end
	return o.C
end

--------------------------------------------------------------------
-- ХЕЛПЕРЫ
--------------------------------------------------------------------
local function new(class, props, children)
	local inst = Instance.new(class)
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then parent = v else inst[k] = v end
	end
	for _, c in ipairs(children or {}) do c.Parent = inst end
	if parent then inst.Parent = parent end
	return inst
end

local function tween(obj, time, props, style, dir)
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local function corner(inst, r)
	return new("UICorner", {CornerRadius = UDim.new(0, r or 12), Parent = inst})
end

local function stroke(inst, transparency, thickness, color)
	return new("UIStroke", {
		Color = color or WHITE, Transparency = transparency or 0.9, Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = inst,
	})
end

local function accentGradient(inst, rotation)
	return new("UIGradient", {Color = ACCENT_SEQ, Rotation = rotation or 0, Parent = inst})
end

local function lightGradient(inst, rotation)
	return new("UIGradient", {Color = LIGHT_SEQ, Rotation = rotation or 0, Parent = inst})
end

local orderCounter = setmetatable({}, {__mode = "k"})
local function place(parent, inst)
	orderCounter[parent] = (orderCounter[parent] or 0) + 1
	inst.LayoutOrder = orderCounter[parent]
end

local spinners = {}
local function spin(g, speed) table.insert(spinners, {g = g, speed = speed or 45}) end

local function colorForFps(fps)
	if fps >= 55 then return THEME.Good elseif fps >= 30 then return THEME.Warn end
	return THEME.Bad
end

-- линия между двумя точками (Frame с AnchorPoint 0.5)
local function setLine(f, a, b, th)
	local d = b - a
	f.Size = UDim2.fromOffset(d.Magnitude, th)
	f.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
	f.Rotation = math.deg(math.atan2(d.Y, d.X))
end

--------------------------------------------------------------------
-- НАРИСОВАННЫЕ ИКОНКИ (без внешних картинок)
--------------------------------------------------------------------
local function drawIcon(parent, kind, s, color, pos)
	local ic = new("Frame", {
		Size = UDim2.fromOffset(s, s), Position = pos or UDim2.new(), BackgroundTransparency = 1,
		ClipsDescendants = (kind == "user"), Parent = parent,
	})
	local parts, holes = {}, {}
	local function box(cx, cy, w, h, rot, round, hole)
		local f = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(cx, cy), Size = UDim2.fromScale(w, h),
			Rotation = rot or 0, BackgroundColor3 = hole and DARK or color, BorderSizePixel = 0, Parent = ic,
		})
		if round then corner(f, 1000) end
		if hole then holes[#holes + 1] = f else parts[#parts + 1] = {f, "BackgroundColor3"} end
		return f
	end
	local th = math.max(2, s * 0.09)

	if kind == "home" then
		box(0.5, 0.38, 0.5, 0.5, 45)
		box(0.5, 0.7, 0.58, 0.34)
		box(0.5, 0.79, 0.15, 0.2, 0, false, true)
	elseif kind == "user" then
		box(0.5, 0.3, 0.38, 0.38, 0, true)
		box(0.5, 1.0, 0.78, 0.78, 0, true)
	elseif kind == "eye" then
		local e = box(0.5, 0.5, 0.96, 0.56, 0, true)
		e.BackgroundTransparency = 1
		parts[#parts + 1] = {stroke(e, 0, th, color), "Color"}
		box(0.5, 0.5, 0.3, 0.3, 0, true)
		box(0.5, 0.5, 0.12, 0.12, 0, true, true)
	elseif kind == "gear" then
		for _, r in ipairs({0, 45, 90, 135}) do box(0.5, 0.5, 0.15, 0.98, r) end
		box(0.5, 0.5, 0.64, 0.64, 0, true)
		box(0.5, 0.5, 0.28, 0.28, 0, true, true)
	elseif kind == "palette" then
		box(0.5, 0.5, 0.94, 0.94, 0, true)
		box(0.32, 0.4, 0.16, 0.16, 0, true, true)
		box(0.58, 0.28, 0.16, 0.16, 0, true, true)
		box(0.74, 0.52, 0.16, 0.16, 0, true, true)
		box(0.42, 0.74, 0.2, 0.2, 0, true, true)
	elseif kind == "target" then
		local r = box(0.5, 0.5, 0.86, 0.86, 0, true)
		r.BackgroundTransparency = 1
		parts[#parts + 1] = {stroke(r, 0, th, color), "Color"}
		box(0.5, 0.5, 0.1, 1)
		box(0.5, 0.5, 1, 0.1)
		box(0.5, 0.5, 0.44, 0.44, 0, true, true)
		box(0.5, 0.5, 0.18, 0.18, 0, true)
	elseif kind == "zoom" then
		local r = box(0.42, 0.42, 0.62, 0.62, 0, true)
		r.BackgroundTransparency = 1
		parts[#parts + 1] = {stroke(r, 0, th, color), "Color"}
		box(0.8, 0.8, 0.42, 0.12, 45)
	elseif kind == "logo" then
		local o = box(0.5, 0.5, 0.62, 0.62, 45)
		o.BackgroundTransparency = 1
		parts[#parts + 1] = {stroke(o, 0, th, color), "Color"}
		box(0.5, 0.5, 0.26, 0.26, 45)
	end

	local function tint(c, holeColor, animated)
		for _, p in ipairs(parts) do
			if animated then tween(p[1], 0.25, {[p[2]] = c}) else p[1][p[2]] = c end
		end
		for _, h in ipairs(holes) do
			if animated then tween(h, 0.25, {BackgroundColor3 = holeColor}) else h.BackgroundColor3 = holeColor end
		end
	end
	return ic, tint
end

--------------------------------------------------------------------
-- ROOT GUI
--------------------------------------------------------------------
local gui = new("ScreenGui", {
	Name = "GlassMenu", ResetOnSpawn = false, IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 1000, Parent = playerGui,
})
local espGui = new("ScreenGui", {
	Name = "GlassESP", ResetOnSpawn = false, IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 900, Parent = playerGui,
})
local blur = new("BlurEffect", {Name = "GlassMenuBlur", Size = 0, Parent = Lighting})
local blurTarget = 14

local worldFolder = new("Folder", {Name = "GlassMenuFolder", Parent = workspace})
local chamFolder = new("Folder", {Name = "Chams", Parent = worldFolder})
local bulletFolder = new("Folder", {Name = "Bullets", Parent = worldFolder})
local testFolder = new("Folder", {Name = "GlassMenuTest", Parent = workspace})

local isOpen = false
local selectTab, setOpen

local root = new("Frame", {
	Name = "Root", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(660, 410), BackgroundTransparency = 1, Visible = false, Parent = gui,
})
local fit = new("UIScale", {Parent = root})
local function updateFit()
	local v = camera.ViewportSize
	fit.Scale = math.min(1, v.X / 760, v.Y / 520)
end
updateFit()
bind(camera:GetPropertyChangedSignal("ViewportSize"), updateFit)

-- Окно. ВАЖНО: UIGradient НЕ вешаем на CanvasGroup (он красит всё содержимое и делал меню тёмным),
-- поэтому фон — отдельный Frame внутри.
local window = new("CanvasGroup", {
	Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, GroupTransparency = 1, Parent = root,
})
corner(window, 18)
local winScale = new("UIScale", {Scale = 0.85, Parent = window})

U.bg = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 0.3, BorderSizePixel = 0, Parent = window})
new("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(58, 58, 58), Color3.fromRGB(10, 10, 10)), Rotation = 60, Parent = U.bg})

U.winStroke = stroke(window, 0.1, 2)
spin(accentGradient(U.winStroke, 0), 40)

U.shine = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = window})
new("UIGradient", {
	Rotation = 35,
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(0.4, 0.96), NumberSequenceKeypoint.new(1, 1),
	}),
	Parent = U.shine,
})

local function orb(color, startPos, endPos, size, time)
	local o = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = startPos, Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color, BackgroundTransparency = 0.84, BorderSizePixel = 0, Parent = window,
	})
	corner(o, size)
	TweenService:Create(o, TweenInfo.new(time, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Position = endPos}):Play()
end
orb(THEME.Accent,  UDim2.fromScale(0.25, 0.2), UDim2.fromScale(0.55, 0.6), 280, 7)
orb(THEME.Accent2, UDim2.fromScale(0.9, 0.9),  UDim2.fromScale(0.6, 0.35), 240, 9)

--------------------------------------------------------------------
-- САЙДБАР
--------------------------------------------------------------------
U.sidebar = new("Frame", {
	Size = UDim2.new(0, 170, 1, 0), BackgroundColor3 = Color3.fromRGB(8, 10, 22),
	BackgroundTransparency = 0.7, BorderSizePixel = 0, Parent = window,
})
new("Frame", {
	Position = UDim2.new(1, -1, 0, 0), Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = WHITE,
	BackgroundTransparency = 0.9, BorderSizePixel = 0, Parent = U.sidebar,
})

drawIcon(U.sidebar, "logo", 28, WHITE, UDim2.fromOffset(16, 20))
U.logo = new("TextLabel", {
	Position = UDim2.fromOffset(50, 18), Size = UDim2.new(1, -60, 0, 32), BackgroundTransparency = 1,
	Text = "AURORA", Font = Enum.Font.GothamBlack, TextSize = 21, TextColor3 = WHITE,
	TextXAlignment = Enum.TextXAlignment.Left, Parent = U.sidebar,
})
spin(accentGradient(U.logo, 0), 30)

new("TextLabel", {
	AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 20, 1, -14), Size = UDim2.new(1, -30, 0, 16),
	BackgroundTransparency = 1, Text = "v2.0  •  RightShift", Font = Enum.Font.Gotham, TextSize = 12,
	TextColor3 = THEME.Sub, TextXAlignment = Enum.TextXAlignment.Left, Parent = U.sidebar,
})

U.tabArea = new("Frame", {
	Position = UDim2.fromOffset(0, 76), Size = UDim2.new(1, 0, 1, -120), BackgroundTransparency = 1, Parent = U.sidebar,
})
U.indicator = new("Frame", {
	Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 0, 40), BackgroundColor3 = WHITE,
	BackgroundTransparency = 0.04, BorderSizePixel = 0, Parent = U.tabArea,
})
corner(U.indicator, 11)
lightGradient(U.indicator, 0)

--------------------------------------------------------------------
-- ВЕРХНЯЯ ПАНЕЛЬ / СТРАНИЦЫ
--------------------------------------------------------------------
U.topbar = new("Frame", {
	Position = UDim2.fromOffset(170, 0), Size = UDim2.new(1, -170, 0, 56), BackgroundTransparency = 1, Parent = window,
})
U.title = new("TextLabel", {
	Position = UDim2.fromOffset(22, 0), Size = UDim2.new(1, -80, 1, 0), BackgroundTransparency = 1, Text = "",
	Font = Enum.Font.GothamBold, TextSize = 20, TextColor3 = THEME.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = U.topbar,
})
new("Frame", {
	AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 1),
	BackgroundColor3 = WHITE, BackgroundTransparency = 0.9, BorderSizePixel = 0, Parent = U.topbar,
})

U.closeBtn = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Size = UDim2.fromOffset(30, 30),
	BackgroundColor3 = THEME.Bad, BackgroundTransparency = 0.6, Text = "×", Font = Enum.Font.GothamBold,
	TextSize = 24, TextColor3 = THEME.Text, AutoButtonColor = false, Parent = U.topbar,
})
corner(U.closeBtn, 15)
U.closeBtn.MouseEnter:Connect(function() tween(U.closeBtn, 0.3, {BackgroundTransparency = 0.1, Rotation = 90}, Enum.EasingStyle.Back) end)
U.closeBtn.MouseLeave:Connect(function() tween(U.closeBtn, 0.3, {BackgroundTransparency = 0.6, Rotation = 0}, Enum.EasingStyle.Back) end)

U.pages = new("Frame", {
	Position = UDim2.fromOffset(170, 56), Size = UDim2.new(1, -170, 1, -56), BackgroundTransparency = 1,
	ClipsDescendants = true, Parent = window,
})

--------------------------------------------------------------------
-- ПЕРЕТАСКИВАНИЕ
--------------------------------------------------------------------
local function makeDraggable(handle, target, getScale)
	local dragging, dragStart, startPos = false, nil, nil
	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging, dragStart, startPos = true, input.Position, target.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end)
	bind(UserInputService.InputChanged, function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - dragStart
			local s = getScale and getScale() or 1
			tween(target, 0.08, {Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + d.X / s, startPos.Y.Scale, startPos.Y.Offset + d.Y / s)}, Enum.EasingStyle.Sine)
		end
	end)
end
makeDraggable(U.topbar, root, function() return fit.Scale end)
makeDraggable(U.sidebar, root, function() return fit.Scale end)

--------------------------------------------------------------------
-- УВЕДОМЛЕНИЯ
--------------------------------------------------------------------
U.toastHolder = new("Frame", {
	AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, -20), Size = UDim2.fromOffset(280, 400),
	BackgroundTransparency = 1, Parent = gui,
})
new("UIListLayout", {
	VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Right,
	Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = U.toastHolder,
})

local function notify(head, text)
	local holder = new("Frame", {Size = UDim2.new(1, 0, 0, 62), BackgroundTransparency = 1, Parent = U.toastHolder})
	place(U.toastHolder, holder)
	local toast = new("CanvasGroup", {
		Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(300, 0), BackgroundColor3 = THEME.Glass,
		BackgroundTransparency = 0.15, GroupTransparency = 1, Parent = holder,
	})
	corner(toast, 14)
	stroke(toast, 0.8, 1)
	local bar = new("Frame", {Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = toast})
	accentGradient(bar, 90)
	new("TextLabel", {
		Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -24, 0, 20), BackgroundTransparency = 1, Text = head,
		Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = THEME.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = toast,
	})
	new("TextLabel", {
		Position = UDim2.fromOffset(16, 28), Size = UDim2.new(1, -24, 0, 24), BackgroundTransparency = 1, Text = text,
		Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = THEME.Sub, TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Parent = toast,
	})
	local prog = new("Frame", {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = toast,
	})
	accentGradient(prog, 0)
	tween(toast, 0.55, {Position = UDim2.new(), GroupTransparency = 0}, Enum.EasingStyle.Back)
	tween(prog, 3, {Size = UDim2.new(0, 0, 0, 2)}, Enum.EasingStyle.Linear)
	task.delay(3.2, function()
		tween(toast, 0.35, {Position = UDim2.fromOffset(300, 0), GroupTransparency = 1}, Enum.EasingStyle.Quint, Enum.EasingDirection.In).Completed:Wait()
		tween(holder, 0.25, {Size = UDim2.new(1, 0, 0, 0)}).Completed:Wait()
		holder:Destroy()
	end)
end

--------------------------------------------------------------------
-- КОМПОНЕНТЫ UI
--------------------------------------------------------------------
local function row(parent, height, canvas)
	local f = new(canvas and "CanvasGroup" or "Frame", {
		Size = UDim2.new(1, 0, 0, height), BackgroundColor3 = WHITE, BackgroundTransparency = 0.92,
		BorderSizePixel = 0, Parent = parent,
	})
	place(parent, f)
	corner(f, 12)
	stroke(f, 0.88, 1)
	return f
end

local function rowLabel(parent, text, pos, size)
	return new("TextLabel", {
		Position = pos or UDim2.fromOffset(16, 0), Size = size or UDim2.new(1, -90, 1, 0), BackgroundTransparency = 1,
		Text = text, Font = Enum.Font.GothamMedium, TextSize = 14, TextColor3 = THEME.Text,
		TextXAlignment = Enum.TextXAlignment.Left, Parent = parent,
	})
end

local function hover(btn, target, base, over)
	btn.MouseEnter:Connect(function() tween(target, 0.2, {BackgroundTransparency = over}) end)
	btn.MouseLeave:Connect(function() tween(target, 0.2, {BackgroundTransparency = base}) end)
end

local function addSection(parent, text)
	local l = new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, Text = string.upper(text),
		Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = THEME.Sub, TextXAlignment = Enum.TextXAlignment.Left, Parent = parent,
	})
	place(parent, l)
	new("UIPadding", {PaddingLeft = UDim.new(0, 4), PaddingTop = UDim.new(0, 8), Parent = l})
end

local function addToggle(parent, text, default, callback, noReg)
	local f = row(parent, 46)
	rowLabel(f, text)
	local OFF, ON = Color3.fromRGB(62, 62, 62), Color3.fromRGB(240, 240, 240)
	local sw = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(44, 24),
		BackgroundColor3 = OFF, BorderSizePixel = 0, Parent = f,
	})
	corner(sw, 12)
	local knob = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0), Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = Color3.fromRGB(200, 200, 200), BorderSizePixel = 0, Parent = sw,
	})
	corner(knob, 9)
	local state = default
	local function render()
		tween(knob, 0.35, {
			Position = state and UDim2.new(1, -21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
			BackgroundColor3 = state and Color3.fromRGB(14, 14, 14) or Color3.fromRGB(200, 200, 200),
		}, Enum.EasingStyle.Back)
		tween(sw, 0.3, {BackgroundColor3 = state and ON or OFF})
	end
	render()
	local btn = new("TextButton", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Parent = f})
	hover(btn, f, 0.92, 0.86)
	local function setState(v, silent)
		state = v and true or false
		render()
		if callback and not silent then callback(state) end
	end
	btn.MouseButton1Click:Connect(function() setState(not state) end)
	if not noReg then M.reg(text, function() return state end, function(v) setState(v) end) end
	return {Set = setState}
end

local function ripple(container, color)
	local m, abs, size = UserInputService:GetMouseLocation(), container.AbsolutePosition, container.AbsoluteSize
	local c = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale((m.X - abs.X) / size.X, (m.Y - abs.Y) / size.Y),
		Size = UDim2.fromOffset(0, 0), BackgroundColor3 = color or WHITE, BackgroundTransparency = 0.75,
		BorderSizePixel = 0, Parent = container,
	})
	corner(c, 1000)
	tween(c, 0.65, {Size = UDim2.fromOffset(800, 800), BackgroundTransparency = 1}).Completed:Connect(function() c:Destroy() end)
end

local function addButton(parent, text, callback)
	local f = row(parent, 44, true)
	f.BackgroundTransparency = 1
	local bgf = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 0.06, BorderSizePixel = 0, Parent = f})
	lightGradient(bgf, 0)
	local sc = new("UIScale", {Parent = f})
	new("TextLabel", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = text, Font = Enum.Font.GothamBold,
		TextSize = 14, TextColor3 = SEL, Parent = f,
	})
	local btn = new("TextButton", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Parent = f})
	hover(btn, bgf, 0.06, 0.22)
	btn.MouseButton1Down:Connect(function() tween(sc, 0.12, {Scale = 0.97}); ripple(f, Color3.new(0, 0, 0)) end)
	local function release() tween(sc, 0.35, {Scale = 1}, Enum.EasingStyle.Back) end
	btn.MouseButton1Up:Connect(release)
	btn.MouseLeave:Connect(release)
	btn.MouseButton1Click:Connect(function() if callback then callback() end end)
end

local function addInput(parent, text, default, callback, placeholder)
	local f = row(parent, 46)
	rowLabel(f, text, nil, UDim2.new(0.4, 0, 1, 0))
	local box = new("TextBox", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.new(0.55, 0, 0, 30),
		BackgroundColor3 = WHITE, BackgroundTransparency = 0.88, Text = default or "", PlaceholderText = placeholder or "введи…",
		PlaceholderColor3 = THEME.Sub, TextColor3 = THEME.Text, Font = Enum.Font.GothamMedium, TextSize = 13,
		ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, Parent = f,
	})
	corner(box, 8)
	new("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = box})
	box.FocusLost:Connect(function() if callback then callback(box.Text) end end)
	return {Set = function(v) box.Text = v end, Get = function() return box.Text end}
end

local function addNote(parent, text)
	local l = new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, Text = text, Font = Enum.Font.Gotham, TextSize = 12,
		TextColor3 = THEME.Sub, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top, Parent = parent,
	})
	place(parent, l)
	new("UIPadding", {PaddingLeft = UDim.new(0, 4), Parent = l})
end

local function addSlider(parent, text, min, max, default, callback, suffix, fillColor, noReg)
	local f = row(parent, 64)
	rowLabel(f, text, UDim2.fromOffset(16, 8), UDim2.new(0.6, 0, 0, 22))
	local valueLabel = new("TextLabel", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 8), Size = UDim2.fromOffset(80, 22),
		BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = fillColor or THEME.Accent,
		TextXAlignment = Enum.TextXAlignment.Right, Text = "", Parent = f,
	})
	local track = new("Frame", {
		Position = UDim2.new(0, 16, 0, 44), Size = UDim2.new(1, -32, 0, 6), BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.85, BorderSizePixel = 0, Parent = f,
	})
	corner(track, 3)
	local fill = new("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = fillColor or WHITE, BorderSizePixel = 0, Parent = track})
	corner(fill, 3)
	if not fillColor then accentGradient(fill, 0) end
	local knob = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = fill,
	})
	corner(knob, 8)
	stroke(knob, 0.4, 2, fillColor or THEME.Accent)

	local cur = default
	local function set(v, silent)
		v = math.clamp(math.floor(v + 0.5), min, max)
		cur = v
		valueLabel.Text = tostring(v) .. (suffix or "")
		tween(fill, 0.12, {Size = UDim2.fromScale((v - min) / (max - min), 1)}, Enum.EasingStyle.Sine)
		if callback and not silent then callback(v) end
	end
	set(default, true)

	local hit = new("TextButton", {
		Position = UDim2.new(0, 10, 0, 30), Size = UDim2.new(1, -20, 0, 32), BackgroundTransparency = 1, Text = "", Parent = f,
	})
	local dragging, scroller = false, nil
	local function fromX(x)
		set(min + (max - min) * math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1))
	end
	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			scroller = f:FindFirstAncestorWhichIsA("ScrollingFrame")
			if scroller then scroller.ScrollingEnabled = false end
			tween(knob, 0.25, {Size = UDim2.fromOffset(22, 22)}, Enum.EasingStyle.Back)
			fromX(input.Position.X)
		end
	end)
	bind(UserInputService.InputChanged, function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			fromX(input.Position.X)
		end
	end)
	bind(UserInputService.InputEnded, function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			if scroller then scroller.ScrollingEnabled = true end
			tween(knob, 0.3, {Size = UDim2.fromOffset(16, 16)}, Enum.EasingStyle.Back)
		end
	end)
	hover(hit, f, 0.92, 0.88)
	if not noReg then M.reg(text, function() return cur end, function(v) set(v) end) end
	return {Set = set}
end

local function addSelector(parent, text, options, default, callback, noReg)
	local f = row(parent, 46)
	rowLabel(f, text, nil, UDim2.new(1, -170, 1, 0))
	local idx = table.find(options, default) or 1
	local pillBg = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(140, 28),
		BackgroundColor3 = WHITE, BackgroundTransparency = 0.06, BorderSizePixel = 0, Parent = f,
	})
	corner(pillBg, 9)
	lightGradient(pillBg, 0)
	local sc = new("UIScale", {Parent = pillBg})
	local pill = new("TextButton", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = options[idx], Font = Enum.Font.GothamBold,
		TextSize = 13, TextColor3 = SEL, AutoButtonColor = false, Parent = pillBg,
	})
	hover(pill, pillBg, 0.06, 0.22)
	pill.MouseButton1Click:Connect(function()
		idx = idx % #options + 1
		pill.Text = options[idx]
		sc.Scale = 0.88
		tween(sc, 0.4, {Scale = 1}, Enum.EasingStyle.Back)
		if callback then callback(options[idx]) end
	end)
	local ctl = {}
	function ctl.Set(opt, silent)
		local i = table.find(options, opt)
		if i then
			idx = i
			pill.Text = options[idx]
			if callback and not silent then callback(options[idx]) end
		end
	end
	function ctl.Refresh()
		if idx > #options then idx = 1 end
		pill.Text = options[idx] or "—"
	end
	if not noReg then M.reg(text, function() return options[idx] end, function(v) ctl.Set(v) end) end
	return ctl
end

-- выбор цвета: пресеты + R/G/B + радуга
local PRESETS = {
	Color3.fromRGB(255, 85, 100), Color3.fromRGB(255, 170, 70), Color3.fromRGB(255, 230, 90), Color3.fromRGB(90, 235, 150),
	Color3.fromRGB(80, 210, 255), Color3.fromRGB(110, 140, 255), Color3.fromRGB(190, 100, 255), Color3.fromRGB(255, 255, 255),
}
local swatches = {}
local function hexOf(c)
	return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

local function addColor(parent, text, obj, onChange)
	local container = new("Frame", {Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1, ClipsDescendants = true, Parent = parent})
	place(parent, container)
	local header = new("Frame", {Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = WHITE, BackgroundTransparency = 0.92, BorderSizePixel = 0, Parent = container})
	corner(header, 12)
	stroke(header, 0.88, 1)
	rowLabel(header, text, nil, UDim2.new(1, -170, 1, 0))
	local sw = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(52, 24),
		BackgroundColor3 = col(obj), BorderSizePixel = 0, Parent = header,
	})
	corner(sw, 8)
	stroke(sw, 0.5, 1)
	local hexL = new("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -74, 0.5, 0), Size = UDim2.fromOffset(70, 20),
		BackgroundTransparency = 1, Text = hexOf(obj.C), Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = THEME.Sub,
		TextXAlignment = Enum.TextXAlignment.Right, Parent = header,
	})
	swatches[#swatches + 1] = {obj = obj, sw = sw}

	local body = new("Frame", {Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 0, 306), BackgroundTransparency = 1, Parent = container})
	new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = body})

	local rv, gv, bv = math.floor(obj.C.R * 255 + 0.5), math.floor(obj.C.G * 255 + 0.5), math.floor(obj.C.B * 255 + 0.5)
	local sR, sG, sB
	local function apply()
		obj.C = Color3.fromRGB(rv, gv, bv)
		hexL.Text = hexOf(obj.C)
		if onChange then onChange(obj) end
	end

	local pr = new("Frame", {Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, Parent = body})
	place(body, pr)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder, Parent = pr,
	})
	for i, pc in ipairs(PRESETS) do
		local b = new("TextButton", {LayoutOrder = i, Size = UDim2.fromOffset(30, 30), BackgroundColor3 = pc, Text = "", AutoButtonColor = false, Parent = pr})
		corner(b, 15)
		stroke(b, 0.5, 1)
		local bs = new("UIScale", {Parent = b})
		b.MouseEnter:Connect(function() tween(bs, 0.25, {Scale = 1.15}, Enum.EasingStyle.Back) end)
		b.MouseLeave:Connect(function() tween(bs, 0.25, {Scale = 1}, Enum.EasingStyle.Back) end)
		b.MouseButton1Click:Connect(function()
			rv, gv, bv = math.floor(pc.R * 255 + 0.5), math.floor(pc.G * 255 + 0.5), math.floor(pc.B * 255 + 0.5)
			sR.Set(rv, true); sG.Set(gv, true); sB.Set(bv, true)
			apply()
		end)
	end
	sR = addSlider(body, "Красный", 0, 255, rv, function(v) rv = v; apply() end, "", Color3.fromRGB(255, 90, 100), true)
	sG = addSlider(body, "Зелёный", 0, 255, gv, function(v) gv = v; apply() end, "", Color3.fromRGB(90, 230, 140), true)
	sB = addSlider(body, "Синий", 0, 255, bv, function(v) bv = v; apply() end, "", Color3.fromRGB(90, 150, 255), true)
	local rbT = addToggle(body, "Радужный режим (RGB)", obj.Rainbow, function(v) obj.Rainbow = v; if onChange then onChange(obj) end end, true)
	M.reg(text, function()
		return {math.floor(obj.C.R * 255 + 0.5), math.floor(obj.C.G * 255 + 0.5), math.floor(obj.C.B * 255 + 0.5), obj.Rainbow}
	end, function(a)
		if type(a) ~= "table" then return end
		rv, gv, bv = a[1] or rv, a[2] or gv, a[3] or bv
		sR.Set(rv, true); sG.Set(gv, true); sB.Set(bv, true)
		obj.Rainbow = a[4] and true or false
		rbT.Set(obj.Rainbow, true)
		apply()
	end)

	local open = false
	local btn = new("TextButton", {Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1, Text = "", Parent = header})
	hover(btn, header, 0.92, 0.86)
	btn.MouseButton1Click:Connect(function()
		open = not open
		tween(container, 0.45, {Size = UDim2.new(1, 0, 0, open and 360 or 46)})
	end)
end

-- подвкладки внутри страницы
local function addSubTabs(parent, names)
	local n = #names
	local bar = new("Frame", {Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = WHITE, BackgroundTransparency = 0.92, BorderSizePixel = 0, Parent = parent})
	place(parent, bar)
	corner(bar, 11)
	stroke(bar, 0.88, 1)
	local pill = new("Frame", {
		Position = UDim2.new(0, 3, 0, 3), Size = UDim2.new(1 / n, -6, 1, -6), BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.04, BorderSizePixel = 0, Parent = bar,
	})
	corner(pill, 9)
	lightGradient(pill, 0)
	local conts, btns, cur = {}, {}, nil
	local function choose(i)
		if cur == i then return end
		local prev = cur
		cur = i
		if prev then
			local pc = conts[prev]
			tween(pc, 0.15, {GroupTransparency = 1})
			task.delay(0.15, function() if cur ~= prev then pc.Visible = false end end)
			tween(btns[prev], 0.2, {TextColor3 = THEME.Sub})
		end
		local c = conts[i]
		c.Visible = true
		c.GroupTransparency = 1
		tween(c, 0.35, {GroupTransparency = 0})
		tween(btns[i], 0.2, {TextColor3 = SEL})
		tween(pill, 0.4, {Position = UDim2.new((i - 1) / n, 3, 0, 3)}, Enum.EasingStyle.Back)
	end
	for i, name in ipairs(names) do
		local b = new("TextButton", {
			Position = UDim2.new((i - 1) / n, 0, 0, 0), Size = UDim2.new(1 / n, 0, 1, 0), BackgroundTransparency = 1,
			Text = name, Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = THEME.Sub, Parent = bar,
		})
		b.MouseButton1Click:Connect(function() choose(i) end)
		btns[i] = b
	end
	for i = 1, n do
		local c = new("CanvasGroup", {
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Visible = false, Parent = parent,
		})
		place(parent, c)
		new("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = c})
		conts[i] = c
	end
	choose(1)
	return conts
end

--------------------------------------------------------------------
-- ВКЛАДКИ
--------------------------------------------------------------------
local tabs, current, tabCount = {}, nil, 0

local function registerTab(name, iconKind)
	tabCount += 1 -- ВАЖНО: tabs индексируется по имени, поэтому #tabs всегда 0; считаем отдельно
	local index = tabCount
	local btn = new("TextButton", {
		Position = UDim2.fromOffset(10, (index - 1) * 46), Size = UDim2.new(1, -20, 0, 40), BackgroundTransparency = 1,
		Text = "", AutoButtonColor = false, Parent = U.tabArea,
	})
	local _, tint = drawIcon(btn, iconKind, 20, THEME.Sub, UDim2.fromOffset(14, 10))
	local lbl = new("TextLabel", {
		Position = UDim2.fromOffset(46, 0), Size = UDim2.new(1, -46, 1, 0), BackgroundTransparency = 1, Text = name,
		Font = Enum.Font.GothamMedium, TextSize = 15, TextColor3 = THEME.Sub, TextXAlignment = Enum.TextXAlignment.Left, Parent = btn,
	})

	local page = new("CanvasGroup", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, GroupTransparency = 1, Visible = false, Parent = U.pages,
	})
	local scroll = new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
		ScrollBarImageColor3 = THEME.Accent, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = page,
	})
	new("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll})
	new("UIPadding", {
		PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18), PaddingTop = UDim.new(0, 14), PaddingBottom = UDim.new(0, 24), Parent = scroll,
	})

	tabs[name] = {name = name, index = index, label = lbl, tint = tint, page = page}
	btn.MouseEnter:Connect(function() if current ~= name then tween(lbl, 0.2, {TextColor3 = THEME.Text}) end end)
	btn.MouseLeave:Connect(function() if current ~= name then tween(lbl, 0.2, {TextColor3 = THEME.Sub}) end end)
	btn.MouseButton1Click:Connect(function() selectTab(name) end)
	return scroll
end

function selectTab(name)
	if current == name then return end
	local prev = tabs[current]
	current = name
	if prev then
		tween(prev.page, 0.2, {GroupTransparency = 1})
		tween(prev.label, 0.25, {TextColor3 = THEME.Sub})
		prev.tint(THEME.Sub, DARK, true)
		task.delay(0.2, function() if current ~= prev.name then prev.page.Visible = false end end)
	end
	local t = tabs[name]
	t.page.Visible = true
	t.page.Position = UDim2.fromOffset(0, 22)
	tween(t.page, 0.5, {GroupTransparency = 0, Position = UDim2.new()})
	tween(t.label, 0.25, {TextColor3 = SEL})
	t.tint(SEL, WHITE, true)
	tween(U.indicator, 0.45, {Position = UDim2.fromOffset(10, (t.index - 1) * 46)}, Enum.EasingStyle.Back)
	U.title.Text = name
	U.title.TextTransparency = 1
	U.title.Position = UDim2.fromOffset(22, 10)
	tween(U.title, 0.4, {TextTransparency = 0, Position = UDim2.fromOffset(22, 0)})
end

--------------------------------------------------------------------
-- ESP: ОБЩИЙ РЕНДЕР (используется и для предпросмотра, и для игры)
--------------------------------------------------------------------
local BOX_EDGES = {}
for i = 0, 7 do
	for b = 0, 2 do
		local j = bit32.bxor(i, bit32.lshift(1, b))
		if j > i then BOX_EDGES[#BOX_EDGES + 1] = {i + 1, j + 1} end
	end
end

local function mkLine(parent)
	return new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, BackgroundColor3 = WHITE, Visible = false, Parent = parent,
	})
end
local function mkText(parent, anchor)
	return new("TextLabel", {
		AnchorPoint = anchor, Size = UDim2.fromOffset(200, 14), BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
		TextSize = 13, TextColor3 = WHITE, TextStrokeTransparency = 0.4, Visible = false, Parent = parent,
	})
end

local function newElements(parent)
	local e = {all = {}, box = {}, skel = {}, arrow = {}}
	local function reg(i) e.all[#e.all + 1] = i; return i end
	e.fill = reg(new("Frame", {BorderSizePixel = 0, BackgroundColor3 = WHITE, Visible = false, Parent = parent}))
	e.fillGrad = new("UIGradient", {
		Rotation = 90, Enabled = false,
		Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0)}),
		Parent = e.fill,
	})
	for i = 1, 12 do e.box[i] = reg(mkLine(parent)) end
	for i = 1, 14 do e.skel[i] = reg(mkLine(parent)) end
	for i = 1, 3 do e.arrow[i] = reg(mkLine(parent)) end
	e.tracer = reg(mkLine(parent))
	e.look = reg(mkLine(parent))
	e.hbBg = reg(new("Frame", {BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.4, BorderSizePixel = 0, Visible = false, Parent = parent}))
	e.hbFill = reg(new("Frame", {AnchorPoint = Vector2.new(0, 1), BackgroundColor3 = THEME.Good, BorderSizePixel = 0, Visible = false, Parent = parent}))
	e.head = reg(new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Visible = false, Parent = parent}))
	corner(e.head, 1000)
	e.headStroke = stroke(e.head, 0, 2, WHITE)
	e.name = reg(mkText(parent, Vector2.new(0.5, 1)))
	e.hpText = reg(mkText(parent, Vector2.new(1, 0.5)))
	e.hpText.TextXAlignment = Enum.TextXAlignment.Right
	e.dist = reg(mkText(parent, Vector2.new(0.5, 0)))
	e.weapon = reg(mkText(parent, Vector2.new(0.5, 0)))
	return e
end

local function hideElements(e)
	for _, i in ipairs(e.all) do i.Visible = false end
end

-- d = {rect={x,y,w,h}, corners, joints, head, headSize, tracerFrom, tracerTo, arrow={pos,dir},
--      name, health, maxHealth, dist, weapon, override}
local function render(e, d, c)
	local rect, base = d.rect, d.override
	local bx = c.Box

	-- заливка
	local showFill = bx.Fill and rect ~= nil
	e.fill.Visible = showFill
	if showFill then
		e.fill.Position = UDim2.fromOffset(rect.x, rect.y)
		e.fill.Size = UDim2.fromOffset(rect.w, rect.h)
		e.fill.BackgroundColor3 = col(bx.FillColor)
		e.fill.BackgroundTransparency = bx.FillTransparency
		e.fillGrad.Enabled = bx.FillGradient
	end

	-- бокс
	local used = 0
	local boxCol = base or col(bx.Color)
	local function L(a, b)
		used += 1
		local f = e.box[used]
		setLine(f, a, b, bx.Thickness)
		f.BackgroundColor3 = boxCol
	end
	if bx.Enabled and rect then
		local x, y, w, h = rect.x, rect.y, rect.w, rect.h
		local tl, tr, bl, br = V2(x, y), V2(x + w, y), V2(x, y + h), V2(x + w, y + h)
		if bx.Style == "Углы" then
			local cl = math.min(w, h) * 0.28
			L(tl, tl + V2(cl, 0)); L(tl, tl + V2(0, cl))
			L(tr, tr - V2(cl, 0)); L(tr, tr + V2(0, cl))
			L(bl, bl + V2(cl, 0)); L(bl, bl - V2(0, cl))
			L(br, br - V2(cl, 0)); L(br, br - V2(0, cl))
		elseif bx.Style == "3D" and d.corners then
			for _, ed in ipairs(BOX_EDGES) do L(d.corners[ed[1]], d.corners[ed[2]]) end
		else
			L(tl, tr); L(tr, br); L(br, bl); L(bl, tl)
		end
	end
	for i = 1, 12 do e.box[i].Visible = i <= used end

	-- скелет
	local sk, n = c.Skeleton, 0
	if sk.Enabled and d.joints then
		local sc = base or col(sk.Color)
		for _, pr in ipairs(d.joints) do
			n += 1
			local f = e.skel[n]
			if not f then break end
			setLine(f, pr[1], pr[2], sk.Thickness)
			f.BackgroundColor3 = sc
		end
	end
	for i = 1, 14 do e.skel[i].Visible = i <= n end

	-- точка на голове
	local hd = c.HeadDot
	local showHead = hd.Enabled and d.head ~= nil
	e.head.Visible = showHead
	if showHead then
		local s = math.max(5, d.headSize)
		e.head.Position = UDim2.fromOffset(d.head.X, d.head.Y)
		e.head.Size = UDim2.fromOffset(s, s)
		e.headStroke.Color = col(hd.Color)
	end

	-- трейсер
	local tr = c.Tracer
	local showT = tr.Enabled and d.tracerFrom ~= nil and d.tracerTo ~= nil
	e.tracer.Visible = showT
	if showT then
		setLine(e.tracer, d.tracerFrom, d.tracerTo, tr.Thickness)
		e.tracer.BackgroundColor3 = base or col(tr.Color)
	end

	-- линия взгляда
	local lk = c.Look
	local showL = lk.Enabled and d.look ~= nil
	e.look.Visible = showL
	if showL then
		setLine(e.look, d.look[1], d.look[2], lk.Thickness)
		e.look.BackgroundColor3 = base or col(lk.Color)
	end

	-- стрелка за экраном
	local ar = c.Arrows
	local showA = (ar.Enabled and d.arrow ~= nil) and true or false
	if showA then
		local p, dir, s = d.arrow.pos, d.arrow.dir, ar.Size
		local perp = V2(-dir.Y, dir.X)
		local tip = p + dir * s
		local l = p - dir * s * 0.4 + perp * s * 0.7
		local r = p - dir * s * 0.4 - perp * s * 0.7
		setLine(e.arrow[1], tip, l, 2); setLine(e.arrow[2], tip, r, 2); setLine(e.arrow[3], l, r, 2)
		local acol = base or col(ar.Color)
		for i = 1, 3 do e.arrow[i].BackgroundColor3 = acol end
	end
	for i = 1, 3 do e.arrow[i].Visible = showA end

	-- текст и здоровье
	local inf = c.Info
	if rect then
		local x, y, w, h = rect.x, rect.y, rect.w, rect.h
		local ts = inf.TextSize
		local ratio = math.clamp(d.health / math.max(d.maxHealth, 1), 0, 1)
		local hpCol = Color3.fromHSV(ratio * 0.33, 0.85, 1)

		e.name.Visible = inf.Name
		if inf.Name then
			e.name.Text = d.name
			e.name.TextSize = ts
			e.name.TextColor3 = col(inf.NameColor)
			e.name.Position = UDim2.fromOffset(x + w / 2, y - 3)
		end
		e.hbBg.Visible = inf.HealthBar
		e.hbFill.Visible = inf.HealthBar
		if inf.HealthBar then
			e.hbBg.Position = UDim2.fromOffset(x - 7, y - 1)
			e.hbBg.Size = UDim2.fromOffset(4, h + 2)
			e.hbFill.Position = UDim2.fromOffset(x - 6, y + h)
			e.hbFill.Size = UDim2.fromOffset(2, math.max(1, h * ratio))
			e.hbFill.BackgroundColor3 = hpCol
		end
		e.hpText.Visible = inf.HealthText
		if inf.HealthText then
			e.hpText.Text = tostring(math.floor(d.health))
			e.hpText.TextSize = math.max(8, ts - 2)
			e.hpText.TextColor3 = hpCol
			e.hpText.Position = UDim2.fromOffset(x - (inf.HealthBar and 10 or 4), y + h * (1 - ratio))
		end
		local yy = y + h + 2
		e.dist.Visible = inf.Distance
		if inf.Distance then
			e.dist.Text = math.floor(d.dist) .. " m"
			e.dist.TextSize = math.max(8, ts - 1)
			e.dist.TextColor3 = col(inf.TextColor)
			e.dist.Position = UDim2.fromOffset(x + w / 2, yy)
			yy += ts
		end
		e.weapon.Visible = inf.Weapon
		if inf.Weapon then
			e.weapon.Text = d.weapon
			e.weapon.TextSize = math.max(8, ts - 1)
			e.weapon.TextColor3 = col(inf.TextColor)
			e.weapon.Position = UDim2.fromOffset(x + w / 2, yy)
		end
	else
		e.name.Visible, e.hbBg.Visible, e.hbFill.Visible = false, false, false
		e.hpText.Visible, e.dist.Visible, e.weapon.Visible = false, false, false
	end
end

--------------------------------------------------------------------
-- ВКЛАДКА: ГЛАВНАЯ
--------------------------------------------------------------------
U.home = registerTab("Главная", "home")

U.profile = row(U.home, 84)
U.avatar = new("ImageLabel", {
	Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(60, 60), BackgroundColor3 = Color3.fromRGB(50, 54, 80),
	BorderSizePixel = 0, Parent = U.profile,
})
corner(U.avatar, 30)
stroke(U.avatar, 0.1, 2, THEME.Accent)
task.spawn(function()
	local ok, img = pcall(Players.GetUserThumbnailAsync, Players, player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
	if ok then U.avatar.Image = img end
end)
new("TextLabel", {
	Position = UDim2.fromOffset(88, 16), Size = UDim2.new(1, -100, 0, 28), BackgroundTransparency = 1,
	Text = "Привет, " .. player.DisplayName, Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = THEME.Text,
	TextXAlignment = Enum.TextXAlignment.Left, Parent = U.profile,
})
new("TextLabel", {
	Position = UDim2.fromOffset(88, 44), Size = UDim2.new(1, -100, 0, 20), BackgroundTransparency = 1,
	Text = "@" .. player.Name, Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = THEME.Sub,
	TextXAlignment = Enum.TextXAlignment.Left, Parent = U.profile,
})

U.perf = row(U.home, 190)
new("TextLabel", {
	Position = UDim2.fromOffset(16, 10), Size = UDim2.new(0.5, 0, 0, 18), BackgroundTransparency = 1,
	Text = "ПРОИЗВОДИТЕЛЬНОСТЬ", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = THEME.Sub,
	TextXAlignment = Enum.TextXAlignment.Left, Parent = U.perf,
})
U.bigFps = new("TextLabel", {
	Position = UDim2.fromOffset(16, 28), Size = UDim2.fromOffset(160, 46), BackgroundTransparency = 1, RichText = true,
	Text = "--", Font = Enum.Font.GothamBlack, TextSize = 36, TextColor3 = THEME.Good, TextXAlignment = Enum.TextXAlignment.Left, Parent = perf,
})
U.statsLabel = new("TextLabel", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 30), Size = UDim2.fromOffset(160, 44),
	BackgroundTransparency = 1, Text = "", Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = THEME.Sub,
	TextXAlignment = Enum.TextXAlignment.Right, TextYAlignment = Enum.TextYAlignment.Top, Parent = U.perf,
})
local BARS, bars, history = 40, {}, table.create(40, 0)
U.graph = new("Frame", {Position = UDim2.fromOffset(16, 84), Size = UDim2.new(1, -32, 0, 90), BackgroundTransparency = 1, Parent = U.perf})
new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Bottom,
	SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2), Parent = U.graph,
})
for i = 1, BARS do
	local b = new("Frame", {
		LayoutOrder = i, Size = UDim2.new(1 / BARS, -2, 0.05, 0), BackgroundColor3 = THEME.Good,
		BackgroundTransparency = 0.15, BorderSizePixel = 0, Visible = false, Parent = U.graph,
	})
	corner(b, 3)
	bars[i] = b
end

--------------------------------------------------------------------
-- ВКЛАДКА: ESP
--------------------------------------------------------------------
U.espPage = registerTab("ESP", "eye")

-- ПРЕДПРОСМОТР ----------------------------------------------------
local CX = 225
local JOINT = {
	head = {0, 58}, neck = {0, 80}, pelvis = {0, 140},
	lSh = {-22, 86}, lEl = {-35, 118}, lHa = {-38, 148}, rSh = {22, 86}, rEl = {35, 118}, rHa = {38, 148},
	lHi = {-10, 140}, lKn = {-12, 178}, lFo = {-12, 214}, rHi = {10, 140}, rKn = {12, 178}, rFo = {12, 214},
}
local function JP(k) return V2(CX + JOINT[k][1], JOINT[k][2]) end
local PV_BONES = {
	{"head", "neck"}, {"neck", "pelvis"}, {"neck", "lSh"}, {"lSh", "lEl"}, {"lEl", "lHa"},
	{"neck", "rSh"}, {"rSh", "rEl"}, {"rEl", "rHa"}, {"pelvis", "lHi"}, {"lHi", "lKn"}, {"lKn", "lFo"},
	{"pelvis", "rHi"}, {"rHi", "rKn"}, {"rKn", "rFo"},
}
local pvJoints = {}
for _, b in ipairs(PV_BONES) do pvJoints[#pvJoints + 1] = {JP(b[1]), JP(b[2])} end
local PV_RECT = {x = CX - 52, y = 40, w = 104, h = 178}
local pvCorners = {}
for i = 0, 7 do
	local xb, yb, zb = i % 2, math.floor(i / 2) % 2, math.floor(i / 4)
	pvCorners[i + 1] = V2(PV_RECT.x + xb * PV_RECT.w + zb * 16, PV_RECT.y + yb * PV_RECT.h - zb * 14)
end

U.previewCard = row(U.espPage, 290)
U.back = new("Frame", {
	Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 1, -12), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = U.previewCard,
})
corner(U.back, 10)
new("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(34, 38, 64), Color3.fromRGB(12, 13, 24)), Rotation = 90, Parent = U.back})
for i = 1, 11 do
	new("Frame", {
		Position = UDim2.fromScale(i / 12, 0), Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.95, BorderSizePixel = 0, Parent = U.back,
	})
end
for i = 1, 5 do
	new("Frame", {
		Position = UDim2.fromScale(0, i / 6), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.95, BorderSizePixel = 0, Parent = U.back,
	})
end
new("TextLabel", {
	Position = UDim2.fromOffset(16, 12), Size = UDim2.fromOffset(200, 16), BackgroundTransparency = 1, Text = "ПРЕДПРОСМОТР",
	Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = THEME.Sub, TextXAlignment = Enum.TextXAlignment.Left, Parent = U.previewCard,
})
U.liveDot = new("Frame", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 15), Size = UDim2.fromOffset(8, 8),
	BackgroundColor3 = THEME.Good, BorderSizePixel = 0, Parent = U.previewCard,
})
corner(U.liveDot, 4)
TweenService:Create(U.liveDot, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {BackgroundTransparency = 0.7}):Play()

U.stage = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 8), Size = UDim2.fromOffset(340, 250),
	BackgroundTransparency = 1, ClipsDescendants = true, Parent = U.previewCard,
})
U.glowCircle = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(CX, 130), Size = UDim2.fromOffset(200, 200),
	BackgroundColor3 = THEME.Accent, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = U.stage,
})
corner(U.glowCircle, 1000)
U.shadow = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(CX, 218), Size = UDim2.fromOffset(120, 14),
	BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, BorderSizePixel = 0, Parent = U.stage,
})
corner(U.shadow, 1000)

local BODY = Color3.fromRGB(78, 78, 78)
local figure = {}
local function fpart(cx, cy, w, h, round)
	local f = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(CX + cx, cy), Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = BODY, BorderSizePixel = 0, Parent = U.stage,
	})
	corner(f, round and 100 or 7)
	local st = stroke(f, 1, 2, WHITE)
	figure[#figure + 1] = {f, st}
end
fpart(0, 58, 30, 30, true)
fpart(0, 112, 52, 64)
fpart(-37, 117, 14, 62)
fpart(37, 117, 14, 62)
fpart(-12, 178, 22, 74)
fpart(12, 178, 22, 74)

local pe = newElements(U.stage)

local function refreshPreview(t)
	local ch, gl, c = Config.Chams, Config.Glow, Config.ESP
	for _, p in ipairs(figure) do
		if ch.Enabled then
			local ft = ch.FillTransparency
			if ch.Pulse then ft = ft + (1 - ft) * 0.6 * (math.sin(t * 3) * 0.5 + 0.5) end
			p[1].BackgroundColor3 = col(ch.Fill)
			p[1].BackgroundTransparency = ft
			p[2].Color = col(ch.Outline)
			p[2].Transparency = ch.OutlineTransparency
		else
			p[1].BackgroundColor3 = BODY
			p[1].BackgroundTransparency = 0
			p[2].Transparency = 1
		end
	end
	if gl.Enabled then
		U.glowCircle.BackgroundColor3 = col(gl.Color)
		U.glowCircle.BackgroundTransparency = 1 - math.clamp(gl.Brightness / 14, 0.08, 0.7)
		local s = gl.Range * 11
		U.glowCircle.Size = UDim2.fromOffset(s, s)
	else
		U.glowCircle.BackgroundTransparency = 1
	end

	local o = c.Tracer.Origin
	local from = o == "Снизу" and V2(170, 250) or o == "Сверху" and V2(170, 0) or o == "Центр" and V2(170, 125) or V2(60, 70)
	local to = c.Tracer.Target == "Ноги" and V2(CX, 218) or V2(CX, 130)
	render(pe, {
		rect = PV_RECT, corners = pvCorners, joints = pvJoints, head = JP("head"), headSize = 24,
		tracerFrom = from, tracerTo = to, arrow = {pos = V2(46, 110), dir = V2(-1, 0)},
		look = {JP("head"), JP("head") + V2(34, -8)},
		name = "Enemy", health = 55 + 45 * math.sin(t * 1.2), maxHealth = 100, dist = 42, weapon = "Rifle",
	}, c)
end

-- РАДАР (рисуется поверх экрана) ------------------------------------
local RD = Config.Radar
U.radarFrame = new("Frame", {
	Name = "Radar", Active = true, Size = UDim2.fromOffset(RD.Size, RD.Size), BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.4, BorderSizePixel = 0, Visible = false, Parent = espGui,
})
corner(U.radarFrame, 1000)
stroke(U.radarFrame, 0.45, 2)
for _, sz in ipairs({UDim2.new(1, -16, 0, 1), UDim2.new(0, 1, 1, -16)}) do
	new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = sz,
		BackgroundColor3 = WHITE, BackgroundTransparency = 0.8, BorderSizePixel = 0, Parent = U.radarFrame,
	})
end
U.radarRing = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.5, 0.5),
	BackgroundTransparency = 1, Parent = U.radarFrame,
})
corner(U.radarRing, 1000)
stroke(U.radarRing, 0.8, 1)
U.radarSelf = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(8, 8),
	BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = U.radarFrame,
})
corner(U.radarSelf, 4)
local function placeRadar()
	local sz = RD.Size
	U.radarFrame.Size = UDim2.fromOffset(sz, sz)
	local left = RD.Corner == "Лево-верх" or RD.Corner == "Лево-низ"
	local top = RD.Corner == "Лево-верх" or RD.Corner == "Право-верх"
	U.radarFrame.Position = UDim2.new(left and 0 or 1, left and 90 or -(sz + 16), top and 0 or 1, top and 16 or -(sz + 16))
end
placeRadar()
makeDraggable(U.radarFrame, U.radarFrame)

-- НАСТРОЙКИ ESP ---------------------------------------------------
local E = Config.ESP
local spawnTest, clearTest
local espStatus, hbStatus, wallStatus
local function addStatus(parent)
	local l = new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1, Text = "", Font = Enum.Font.GothamMedium, TextSize = 12,
		TextColor3 = THEME.Sub, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top, Parent = parent,
	})
	place(parent, l)
	new("UIPadding", {PaddingLeft = UDim.new(0, 4), Parent = l})
	return l
end

addToggle(U.espPage, "Включить ESP", false, function(v)
	E.Enabled = v
	if v then
		local n = 0
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= player then n += 1 end
		end
		notify("ESP включён", n > 0 and ("Других игроков: " .. n) or "Игроков нет — нажми «Создать тест-цель»")
	end
end)
espStatus = addStatus(U.espPage)
addButton(U.espPage, "Создать тест-цель и стену", function() spawnTest() end)
addButton(U.espPage, "Удалить тесты", function() clearTest() end)
U.sub = addSubTabs(U.espPage, {"Общее", "Бокс", "Инфо", "Chams", "Линии", "Радар", "Пули"})

-- Общее
addSelector(U.sub[1], "Цели", {"Все", "Враги", "Союзники"}, "Все", function(v) E.Target = v end)
addSelector(U.sub[1], "Определение команд", {"Авто", "Roblox Team", "TeamColor", "Атрибут/Value"}, "Авто", function(v) Config.TeamMode = v; table.clear(M.teamCache) end)
addToggle(U.sub[1], "Показывать ботов (NPC)", false, function(v) E.NPC = v end)
addToggle(U.sub[1], "Цвет команды", false, function(v) E.TeamColor = v end)
addSlider(U.sub[1], "Макс. дистанция", 100, 5000, 1500, function(v) E.MaxDistance = v end, " m")
addToggle(U.sub[1], "Проверка видимости (за стеной)", false, function(v) E.VisCheck = v end)
addColor(U.sub[1], "Цвет скрытых игроков", E.HiddenColor)
addSlider(U.sub[1], "Скорость радуги", 1, 30, 8, function(v) Config.Rainbow = v / 30 end)
addSection(U.sub[1], "Стрелки за экраном")
addToggle(U.sub[1], "Показывать стрелки", false, function(v) E.Arrows.Enabled = v end)
addSlider(U.sub[1], "Радиус", 80, 500, 220, function(v) E.Arrows.Radius = v end)
addSlider(U.sub[1], "Размер", 8, 40, 14, function(v) E.Arrows.Size = v end)
addColor(U.sub[1], "Цвет стрелок", E.Arrows.Color)

-- Бокс
addToggle(U.sub[2], "Бокс", true, function(v) E.Box.Enabled = v end)
addSelector(U.sub[2], "Стиль", {"2D", "Углы", "3D"}, "2D", function(v) E.Box.Style = v end)
addColor(U.sub[2], "Цвет бокса", E.Box.Color)
addSlider(U.sub[2], "Толщина", 1, 6, 2, function(v) E.Box.Thickness = v end)
addSection(U.sub[2], "Заливка")
addToggle(U.sub[2], "Заливка бокса", false, function(v) E.Box.Fill = v end)
addColor(U.sub[2], "Цвет заливки", E.Box.FillColor)
addSlider(U.sub[2], "Прозрачность заливки", 0, 100, 80, function(v) E.Box.FillTransparency = v / 100 end, "%")
addToggle(U.sub[2], "Градиентная заливка", true, function(v) E.Box.FillGradient = v end)
addSection(U.sub[2], "Голова")
addToggle(U.sub[2], "Круг на голове", false, function(v) E.HeadDot.Enabled = v end)
addColor(U.sub[2], "Цвет круга", E.HeadDot.Color)

-- Инфо
addToggle(U.sub[3], "Имя", true, function(v) E.Info.Name = v end)
addToggle(U.sub[3], "Показывать DisplayName", true, function(v) E.Info.DisplayName = v end)
addColor(U.sub[3], "Цвет имени", E.Info.NameColor)
addToggle(U.sub[3], "Полоска здоровья", true, function(v) E.Info.HealthBar = v end)
addToggle(U.sub[3], "Число здоровья", true, function(v) E.Info.HealthText = v end)
addToggle(U.sub[3], "Дистанция", true, function(v) E.Info.Distance = v end)
addToggle(U.sub[3], "Оружие в руках", true, function(v) E.Info.Weapon = v end)
addColor(U.sub[3], "Цвет текста", E.Info.TextColor)
addSlider(U.sub[3], "Размер текста", 9, 22, 13, function(v) E.Info.TextSize = v end)
addSection(U.sub[3], "Скелет")
addToggle(U.sub[3], "Скелет", false, function(v) E.Skeleton.Enabled = v end)
addColor(U.sub[3], "Цвет скелета", E.Skeleton.Color)
addSlider(U.sub[3], "Толщина линий", 1, 5, 2, function(v) E.Skeleton.Thickness = v end)

-- Chams + свечение
local CH, GL = Config.Chams, Config.Glow
addToggle(U.sub[4], "Chams (подсветка тела)", false, function(v) CH.Enabled = v end)
addColor(U.sub[4], "Цвет заливки", CH.Fill)
addSlider(U.sub[4], "Прозрачность заливки", 0, 100, 50, function(v) CH.FillTransparency = v / 100 end, "%")
addColor(U.sub[4], "Цвет контура", CH.Outline)
addSlider(U.sub[4], "Прозрачность контура", 0, 100, 0, function(v) CH.OutlineTransparency = v / 100 end, "%")
addToggle(U.sub[4], "Видно сквозь стены", true, function(v) CH.AlwaysOnTop = v end)
addToggle(U.sub[4], "Пульсация", false, function(v) CH.Pulse = v end)
addNote(U.sub[4], "Roblox рисует не больше ~31 Highlight одновременно.")
addSection(U.sub[4], "Свечение")
addToggle(U.sub[4], "Свечение вокруг игрока", false, function(v) GL.Enabled = v end)
addColor(U.sub[4], "Цвет свечения", GL.Color)
addSlider(U.sub[4], "Яркость", 1, 10, 3, function(v) GL.Brightness = v end)
addSlider(U.sub[4], "Радиус", 4, 40, 14, function(v) GL.Range = v end)

-- Линии
addToggle(U.sub[5], "Трейсеры", false, function(v) E.Tracer.Enabled = v end)
addSelector(U.sub[5], "Начало линии", {"Снизу", "Центр", "Сверху", "Курсор"}, "Снизу", function(v) E.Tracer.Origin = v end)
addSelector(U.sub[5], "Конец линии", {"Ноги", "Центр"}, "Ноги", function(v) E.Tracer.Target = v end)
addColor(U.sub[5], "Цвет линии", E.Tracer.Color)
addSlider(U.sub[5], "Толщина", 1, 6, 2, function(v) E.Tracer.Thickness = v end)
addSection(U.sub[5], "Линия взгляда")
addToggle(U.sub[5], "Показывать, куда смотрит", false, function(v) E.Look.Enabled = v end)
addColor(U.sub[5], "Цвет", E.Look.Color)
addSlider(U.sub[5], "Длина", 2, 30, 8, function(v) E.Look.Length = v end, " st")
addSlider(U.sub[5], "Толщина линии", 1, 6, 2, function(v) E.Look.Thickness = v end)

-- Радар
addToggle(U.sub[6], "Радар", false, function(v) RD.Enabled = v end)
addSelector(U.sub[6], "Положение", {"Лево-верх", "Право-верх", "Лево-низ", "Право-низ"}, RD.Corner, function(v) RD.Corner = v; placeRadar() end)
addSlider(U.sub[6], "Размер", 100, 260, RD.Size, function(v) RD.Size = v; placeRadar() end, " px")
addSlider(U.sub[6], "Дальность", 50, 800, RD.Range, function(v) RD.Range = v end, " st")
addColor(U.sub[6], "Цвет точек", RD.Color)
addNote(U.sub[6], "Радар можно перетащить пальцем или мышью.")

-- Пули
local BU = Config.Bullets
local spawnTracer
addToggle(U.sub[7], "Трассеры пуль", false, function(v) BU.Enabled = v end)
addSelector(U.sub[7], "Стиль", {"Луч", "Лазер", "Снаряд"}, "Луч", function(v) BU.Style = v end)
addColor(U.sub[7], "Цвет трассера", BU.Color)
addSlider(U.sub[7], "Толщина", 1, 40, 15, function(v) BU.Width = v / 100 end)
addSlider(U.sub[7], "Время жизни", 2, 40, 12, function(v) BU.Lifetime = v / 10 end, " /10с")
addSelector(U.sub[7], "Начало трассера", {"Авто", "Камера", "Персонаж"}, "Авто", function(v) BU.Origin = v end)
addToggle(U.sub[7], "Только с оружием (Tool)", false, function(v) BU.ToolOnly = v end)
addSlider(U.sub[7], "Интервал при зажатии", 3, 50, 10, function(v) BU.Interval = v / 100 end, " /100с")
addToggle(U.sub[7], "Маркер попадания", true, function(v) BU.HitMarker = v end)
addColor(U.sub[7], "Цвет маркера", BU.HitColor)
addButton(U.sub[7], "Тест трассера", function()
	local cf = camera.CFrame
	spawnTracer(cf:PointToWorldSpace(Vector3.new(0.9, -0.8, -1.5)), cf:PointToWorldSpace(Vector3.new(0, 0, -70)), true)
end)

--------------------------------------------------------------------
-- ВКЛАДКА: БОЙ (хитбоксы + wallbang)
--------------------------------------------------------------------
local HBc, WL = Config.Hitbox, Config.Wall
U.combat = registerTab("Бой", "target")
U.cs = addSubTabs(U.combat, {"Хитбоксы", "Wallbang", "Авто-пик", "Хитмаркер"})
do
	local c1, c2, c3, c4 = U.cs[1], U.cs[2], U.cs[3], U.cs[4]
	local PK, HT = Config.Peek, Config.Hit

	-- Хитбоксы
	addToggle(c1, "Увеличить хитбоксы", false, function(v) HBc.Enabled = v end)
	hbStatus = addStatus(c1)
	addSelector(c1, "Часть тела", {"HRP", "Голова", "Торс"}, "HRP", function(v) HBc.Part = v end)
	addSlider(c1, "Размер хитбокса", 2, 60, 10, function(v) HBc.Size = v end, " st")
	addSelector(c1, "Цели хитбокса", {"Все", "Враги", "Союзники"}, "Все", function(v) HBc.Target = v end)
	addToggle(c1, "Включая ботов (NPC)", false, function(v) HBc.NPC = v end)
	addToggle(c1, "Скрыть хитбокс (невидимый)", false, function(v) HBc.Hidden = v end)
	addColor(c1, "Цвет хитбокса", HBc.Color)
	addSlider(c1, "Прозрачность хитбокса", 0, 100, 60, function(v) HBc.Transparency = v / 100 end, "%")
	addNote(c1, "HRP — лучший выбор: он и так невидим. У головы и торса «скрыть» делает саму часть тела невидимой.")
	addButton(c1, "Создать тест-цель и стену", function() spawnTest() end)

	-- Wallbang
	addToggle(c2, "Wallbang: пули сквозь стены", false, function(v) WL.Bang = v end)
	addToggle(c2, "Убрать коллизию стен", false, function(v) WL.NoClip = v end)
	addToggle(c2, "Сохранять пол", true, function(v) WL.KeepFloor = v end)
	addSlider(c2, "Радиус действия", 30, 500, 200, function(v) WL.Radius = v end, " st")
	addSlider(c2, "Макс. толщина стены (0 = любая)", 0, 50, 0, function(v) WL.MaxThickness = v end, " st")
	addSlider(c2, "X-Ray: прозрачность стен", 0, 90, 0, function(v) WL.Xray = v end, "%")
	wallStatus = addStatus(c2)
	addNote(c2, "Всё меняется только на твоём клиенте. Работает, если игра считает попадания на клиенте; серверную проверку это не обойдёт.")

	-- Авто-пик
	addToggle(c3, "Авто-пик", false, function(v) PK.Enabled = v end)
	U.peekLabel = addStatus(c3)
	addSection(c3, "Обнаружение")
	addSlider(c3, "Дальность обнаружения", 20, 500, 150, function(v) PK.Range = v end, " st")
	addSlider(c3, "Мин. скорость цели", 1, 30, 4, function(v) PK.MinSpeed = v end, " st/s")
	addSlider(c3, "Точность «идёт на меня»", 10, 100, 60, function(v) PK.Approach = v end, "%")
	addToggle(c3, "Реагировать только на приближающихся", true, function(v) PK.OnlyApproach = v end)
	addSection(c3, "Выход из укрытия (пик)")
	addToggle(c3, "Авто-выход (пик)", true, function(v) PK.Peek = v end)
	addSelector(c3, "Сторона выхода", {"Авто", "Влево", "Вправо"}, "Авто", function(v) PK.Side = v end)
	addSlider(c3, "Время выхода (×0.1 с)", 1, 20, 4, function(v) PK.PeekTime = v / 10 end)
	addToggle(c3, "Возвращаться в укрытие", true, function(v) PK.Return = v end)
	addSlider(c3, "Пауза между пиками (×0.1 с)", 5, 100, 20, function(v) PK.Cooldown = v / 10 end)
	addSection(c3, "Авто-стрельба")
	addToggle(c3, "Стрелять по цели в прицеле", true, function(v) PK.Shoot = v end)
	addSelector(c3, "Способ выстрела", {"Tool + клик", "Tool:Activate", "Клик (exploit)"}, "Tool + клик", function(v) PK.Method = v end)
	addSlider(c3, "Задержка выстрела (×0.01 с)", 0, 50, 5, function(v) PK.Delay = v / 100 end)
	addSlider(c3, "Интервал выстрелов (×0.01 с)", 3, 60, 12, function(v) PK.Interval = v / 100 end)
	addToggle(c3, "Только если цель видна", true, function(v) PK.VisOnly = v end)
	addToggle(c3, "Стрелять только во время пика", false, function(v) PK.OnlyWhilePeek = v end)
	addSection(c3, "Подвод прицела")
	addToggle(c3, "Подводить прицел к цели", false, function(v) PK.Assist = v end)
	addSelector(c3, "Куда целиться", {"Голова", "Торс", "HRP"}, "Голова", function(v) PK.AssistPart = v end)
	addSlider(c3, "Скорость подвода", 1, 40, 10, function(v) PK.Smooth = v end)
	addSlider(c3, "Угол захвата", 5, 90, 30, function(v) PK.AssistFov = v end, "°")
	addToggle(c3, "Показывать круг захвата", false, function(v) PK.ShowFov = v end)
	addNote(c3, "«Выход» = шаг из-за укрытия в сторону цели и обратно. Работает по врагам (см. «Определение команд» в ESP). Эффект зависит от игры.")

	-- Хитмаркер
	addToggle(c4, "Хитмаркер и звук", false, function(v) HT.Enabled = v end)
	addSelector(c4, "Стиль маркера", {"Крест", "Плюс", "Точка", "Круг"}, "Крест", function(v) HT.Style = v end)
	addColor(c4, "Цвет попадания", HT.Color)
	addColor(c4, "Цвет убийства", HT.KillColor)
	addSlider(c4, "Размер маркера", 8, 60, 18, function(v) HT.Size = v end)
	addSlider(c4, "Толщина маркера", 1, 6, 2, function(v) HT.Thickness = v end)
	addSlider(c4, "Длительность (×0.01 с)", 10, 100, 30, function(v) HT.Time = v / 100 end)
	addSection(c4, "Звук")
	addToggle(c4, "Звук попадания", true, function(v) HT.Sound = v end)
	addSelector(c4, "Звук попадания: тип", {"Пинг", "Щелчок", "Оф", "Свой ID"}, "Пинг", function(v) HT.HitSound = v end)
	addSelector(c4, "Звук убийства: тип", {"Оф", "Пинг", "Щелчок", "Свой ID"}, "Оф", function(v) HT.KillSound = v end)
	addInput(c4, "ID звука попадания", "", function(v) HT.CustomHit = v end, "rbxassetid")
	addInput(c4, "ID звука убийства", "", function(v) HT.CustomKill = v end, "rbxassetid")
	addSlider(c4, "Громкость", 0, 100, 60, function(v) HT.Volume = v end, "%")
	addSection(c4, "Логика")
	addToggle(c4, "Только после моего выстрела", not UserInputService.TouchEnabled, function(v) HT.OnlyAfterShot = v end)
	addToggle(c4, "Счётчик убийств на экране", false, function(v) HT.Counter = v end)
	addButton(c4, "Тест хитмаркера", function() M.hitTest() end)
	addButton(c4, "Сбросить счётчик убийств", function() M.kills = 0 end)
	addNote(c4, "Хитмаркер срабатывает, когда у врага падает здоровье сразу после твоего выстрела. Если игра не использует Humanoid.Health — не сработает.")
end

--------------------------------------------------------------------
-- ВКЛАДКА: ИГРОК
--------------------------------------------------------------------
local function humanoid()
	local c = player.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

local MV = Config.Move
U.h0 = humanoid()
local origWalk, origJump = U.h0 and U.h0.WalkSpeed or 16, U.h0 and U.h0.JumpPower or 50

U.playerTab = registerTab("Игрок", "user")
addSection(U.playerTab, "Движение (удерживается каждый кадр)")
addSlider(U.playerTab, "Скорость ходьбы", 8, 150, math.floor(origWalk + 0.5), function(v) MV.Walk = v end)
addSlider(U.playerTab, "Сила прыжка", 25, 300, math.floor(origJump + 0.5), function(v) MV.Jump = v end)
addToggle(U.playerTab, "Бесконечный прыжок", false, function(v) MV.InfJump = v end)
addToggle(U.playerTab, "Noclip (проходить сквозь всё)", false, function(v) MV.Noclip = v end)
addSection(U.playerTab, "Действия")
addButton(U.playerTab, "Вернуть скорость и прыжок", function()
	MV.Walk, MV.Jump = false, false
	local h = humanoid()
	if h then h.WalkSpeed = origWalk; h.JumpPower = origJump end
	notify("Игрок", "Значения возвращены")
end)
addButton(U.playerTab, "Сбросить персонажа", function()
	local h = humanoid(); if h then h.Health = 0 end
	notify("Персонаж", "Респавн выполнен")
end)

--------------------------------------------------------------------
-- ВКЛАДКА: ВИЗУАЛ
--------------------------------------------------------------------
U.visual = registerTab("Визуал", "palette")
U.vs = addSubTabs(U.visual, {"Камера", "Атмосфера", "Эффекты", "Прицел"})
local CRH = Config.Crosshair
do
	local v1, v2, v3, v4 = U.vs[1], U.vs[2], U.vs[3], U.vs[4]
	local AT, CM, ZM = Config.Atmo, Config.Cam, Config.Cam.Zoom

	-- Камера
	U.origFov = camera.FieldOfView
	addSection(v1, "Поле зрения")
	addSlider(v1, "Поле зрения (FOV)", 30, 120, math.floor(camera.FieldOfView + 0.5), function(v)
		Config.Move.Fov = v -- применяется каждый кадр, игра не сможет сбросить
	end, "°")
	addButton(v1, "Вернуть FOV по умолчанию", function()
		Config.Move.Fov = false
		camera.FieldOfView = U.origFov
	end)
	addSection(v1, "Третье лицо")
	addToggle(v1, "Принудительное 3-е лицо", false, function(v) CM.Third = v end)
	addSlider(v1, "Дистанция камеры", 4, 80, 12, function(v) CM.Dist = v end, " st")
	addToggle(v1, "Свободный зум колесом", true, function(v) CM.FreeZoom = v end)
	addSlider(v1, "Смещение камеры (плечо)", -10, 10, 0, function(v) CM.Offset = v end, " st")
	addSection(v1, "Зум")
	addToggle(v1, "Зум на клавишу", false, function(v) ZM.Enabled = v end)
	addSelector(v1, "Клавиша зума", {"Z", "X", "C", "V", "B", "Q", "E", "LeftAlt"}, "Z", function(v) ZM.Key = v end)
	addSlider(v1, "FOV при зуме", 5, 70, 20, function(v) ZM.FOV = v end, "°")
	addSlider(v1, "Плавность зума", 2, 30, 12, function(v) ZM.Smooth = v end)
	addToggle(v1, "Кнопка зума на экране (для телефона)", false, function(v) ZM.Button = v end)

	-- Атмосфера
	addSection(v2, "Пресеты")
	addButton(v2, "Ночь", function() M.atmoPreset("Ночь") end)
	addButton(v2, "Закат", function() M.atmoPreset("Закат") end)
	addButton(v2, "Яркий день", function() M.atmoPreset("День") end)
	addButton(v2, "Чёрно-белый мир", function() M.atmoPreset("ЧБ") end)
	addButton(v2, "Туман и мрак", function() M.atmoPreset("Туман") end)
	addButton(v2, "Сбросить всё", function() M.atmoReset() end)
	addSection(v2, "Свет")
	addSlider(v2, "Время суток (140 = 14:00)", 0, 240, 140, function(v) AT.Clock = v / 10 end)
	addButton(v2, "Отпустить время (игра управляет)", function() AT.Clock = false end)
	addSlider(v2, "Яркость (×10)", 0, 100, 20, function(v) AT.Bright = v / 10 end)
	addSlider(v2, "Экспозиция (×10)", -30, 30, 0, function(v) AT.Expo = v / 10 end)
	addToggle(v2, "Свой Ambient", false, function(v) AT.AmbientOn = v end)
	addColor(v2, "Цвет Ambient", AT.Ambient)
	addToggle(v2, "Убрать тени", false, function(v) AT.ShadowsOff = v end)
	addToggle(v2, "Убрать небо", false, function(v) AT.SkyOff = v end)
	addSection(v2, "Туман")
	addToggle(v2, "Свой туман", false, function(v) AT.FogOn = v end)
	addColor(v2, "Цвет тумана", AT.FogColor)
	addSlider(v2, "Начало тумана", 0, 2000, 0, function(v) AT.FogStart = v end, " st")
	addSlider(v2, "Конец тумана", 50, 5000, 800, function(v) AT.FogEnd = v end, " st")

	-- Эффекты
	addToggle(v3, "Atmosphere (атмосфера)", false, function(v) AT.AtmoOn = v end)
	addSlider(v3, "Плотность", 0, 100, 35, function(v) AT.AtmoDensity = v end, "%")
	addSlider(v3, "Дымка", 0, 100, 20, function(v) AT.AtmoHaze = v end)
	addSlider(v3, "Блики", 0, 100, 0, function(v) AT.AtmoGlare = v end)
	addColor(v3, "Цвет атмосферы", AT.AtmoColor)
	addSection(v3, "Bloom")
	addToggle(v3, "Bloom (свечение)", false, function(v) AT.BloomOn = v end)
	addSlider(v3, "Интенсивность Bloom", 0, 300, 100, function(v) AT.BloomInt = v end, "%")
	addSlider(v3, "Размер Bloom", 0, 56, 24, function(v) AT.BloomSize = v end)
	addSlider(v3, "Порог Bloom", 0, 300, 80, function(v) AT.BloomThr = v end, "%")
	addSection(v3, "Цветокоррекция")
	addToggle(v3, "Цветокоррекция", false, function(v) AT.CCOn = v end)
	addSlider(v3, "Яркость цвета", -50, 50, 0, function(v) AT.CCBright = v end)
	addSlider(v3, "Контраст", -50, 100, 0, function(v) AT.CCContrast = v end)
	addSlider(v3, "Насыщенность", -100, 100, 0, function(v) AT.CCSat = v end)
	addColor(v3, "Оттенок", AT.CCTint)
	addSection(v3, "Солнце")
	addToggle(v3, "Солнечные лучи", false, function(v) AT.RaysOn = v end)
	addSlider(v3, "Сила лучей", 0, 100, 25, function(v) AT.RaysInt = v end, "%")

	-- Прицел
	addToggle(v4, "Свой прицел", false, function(v) CRH.Enabled = v end)
	addColor(v4, "Цвет прицела", CRH.Color)
	addSlider(v4, "Длина линий", 2, 30, 8, function(v) CRH.Size = v end)
	addSlider(v4, "Зазор в центре", 0, 20, 4, function(v) CRH.Gap = v end)
	addSlider(v4, "Толщина прицела", 1, 5, 2, function(v) CRH.Thickness = v end)
	addToggle(v4, "Точка в центре", true, function(v) CRH.Dot = v end)
end

--------------------------------------------------------------------
-- ВКЛАДКА: НАСТРОЙКИ
--------------------------------------------------------------------
U.settings = registerTab("Настройки", "gear")
U.ss = addSubTabs(U.settings, {"Интерфейс", "Конфиги", "Диагностика"})
do
	local s1, s2, s3 = U.ss[1], U.ss[2], U.ss[3]

	-- Интерфейс
	addSlider(s1, "Сила размытия фона", 0, 40, blurTarget, function(v)
		blurTarget = v
		if isOpen then tween(blur, 0.3, {Size = v}) end
	end)
	addSlider(s1, "Прозрачность стекла", 0, 100, 35, function(v)
		tween(U.bg, 0.2, {BackgroundTransparency = 0.05 + v / 100 * 0.6})
	end, "%")
	if typeof(setfpscap) == "function" then
		addSlider(s1, "Лимит FPS (0 = без лимита)", 0, 240, 0, function(v) pcall(setfpscap, v) end)
	end
	addButton(s1, "Тест уведомления", function() notify("Aurora Glass", "Всё работает отлично!") end)
	addButton(s1, "Закрыть меню", function() setOpen(false) end)
	addButton(s1, "Выгрузить скрипт (выключить всё)", function()
		if _G.GlassMenuCleanup then _G.GlassMenuCleanup() end
	end)

	-- Диагностика
	U.diagCard = row(s3, 150)
	U.diagLabel = new("TextLabel", {
		Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -28, 1, -20), BackgroundTransparency = 1, Text = "Диагностика…",
		Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = THEME.Text, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = U.diagCard,
	})

	-- Конфиги: сохраняется состояние ВСЕХ элементов меню
	local HttpService = game:GetService("HttpService")
	local DIR = "GlassMenu"
	local fs = typeof(writefile) == "function" and typeof(readfile) == "function" and typeof(isfolder) == "function"
		and typeof(makefolder) == "function" and typeof(isfile) == "function"
	_G.GlassMenuMem = _G.GlassMenuMem or {}
	local mem = _G.GlassMenuMem
	local cfgName = "default"
	local nameBox, ioBox, picker
	local list = {"—"}

	local function path(n) return DIR .. "/" .. n .. ".json" end
	local function encode()
		local data = {}
		for key, c in pairs(M.ctl.byKey) do
			local ok, v = pcall(c.get)
			if ok then data[key] = v end
		end
		return HttpService:JSONEncode({v = 5, data = data})
	end
	local function decode(text)
		local ok, obj = pcall(function() return HttpService:JSONDecode(text) end)
		if ok and type(obj) == "table" and type(obj.data) == "table" then return obj.data end
		return nil
	end
	local function applyData(data)
		local n = 0
		for key, v in pairs(data) do
			local c = M.ctl.byKey[key]
			if c and pcall(c.set, v) then n += 1 end
		end
		return n
	end
	local function listNames()
		local out = {}
		if fs and typeof(listfiles) == "function" and isfolder(DIR) then
			for _, f in ipairs(listfiles(DIR)) do
				local n = string.match(f, "([^/\\]+)%.json$")
				if n then out[#out + 1] = n end
			end
		else
			for n in pairs(mem) do out[#out + 1] = n end
		end
		table.sort(out)
		return out
	end
	local function refreshList()
		local names = listNames()
		table.clear(list)
		if #names == 0 then list[1] = "—" else for _, n in ipairs(names) do list[#list + 1] = n end end
		picker.Refresh()
	end
	local function saveCfg()
		local n = cfgName ~= "" and cfgName or "default"
		local text = encode()
		if fs then
			if not isfolder(DIR) then makefolder(DIR) end
			writefile(path(n), text)
		else
			mem[n] = text
		end
		refreshList()
		notify("Конфиг", "Сохранён: " .. n .. (fs and "" or " (память сессии)"))
	end
	local function loadCfg()
		local n = cfgName
		local text
		if fs and isfile(path(n)) then text = readfile(path(n)) else text = mem[n] end
		if not text then notify("Конфиг", "Не найден: " .. n); return end
		local data = decode(text)
		if not data then notify("Конфиг", "Файл повреждён"); return end
		notify("Конфиг", "Загружен: " .. n .. " (параметров: " .. applyData(data) .. ")")
	end

	nameBox = addInput(s2, "Имя конфига", cfgName, function(v) cfgName = v end, "default")
	picker = addSelector(s2, "Сохранённые конфиги", list, list[1], function(v)
		if v ~= "—" then cfgName = v; nameBox.Set(v) end
	end, true)
	addButton(s2, "Сохранить", saveCfg)
	addButton(s2, "Загрузить", loadCfg)
	addButton(s2, "Удалить", function()
		if fs and typeof(delfile) == "function" then pcall(delfile, path(cfgName)) end
		mem[cfgName] = nil
		refreshList()
		notify("Конфиг", "Удалён: " .. cfgName)
	end)
	addButton(s2, "Обновить список", refreshList)
	addToggle(s2, "Автозагрузка выбранного конфига при запуске", false, function(v)
		if not fs then notify("Автозагрузка", "Нужен writefile (эксплойтер)"); return end
		if not isfolder(DIR) then makefolder(DIR) end
		if v then
			writefile(DIR .. "/_autoload.txt", cfgName)
		elseif typeof(delfile) == "function" then
			pcall(delfile, DIR .. "/_autoload.txt")
		end
	end, true)
	addSection(s2, "Экспорт / импорт текстом")
	ioBox = addInput(s2, "JSON конфига", "", nil, "вставь сюда")
	addButton(s2, "Экспорт (в поле и в буфер)", function()
		local text = encode()
		ioBox.Set(text)
		if typeof(setclipboard) == "function" then
			pcall(setclipboard, text)
			notify("Экспорт", "Скопировано в буфер обмена")
		else
			notify("Экспорт", "Текст в поле — скопируй вручную")
		end
	end)
	addButton(s2, "Импорт из поля", function()
		local data = decode(ioBox.Get())
		if not data then notify("Импорт", "Неверный JSON"); return end
		notify("Импорт", "Применено параметров: " .. applyData(data))
	end)
	addNote(s2, fs and "Файлы лежат в папке GlassMenu вашего эксплойтера." or "writefile недоступен: конфиги живут только пока открыта игра. Используй экспорт текстом.")

	M.autoload = function()
		if fs and isfile(DIR .. "/_autoload.txt") then
			cfgName = readfile(DIR .. "/_autoload.txt")
			nameBox.Set(cfgName)
			loadCfg()
		end
	end
	refreshList()
end

--------------------------------------------------------------------
-- ESP: РЕАЛЬНЫЙ РЕНДЕР ПО ИГРОКАМ
--------------------------------------------------------------------
local R15_BONES = {
	{"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
	{"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
	{"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
	{"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
	{"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"},
}
local R6_BONES = {
	{"Head", "Torso"}, {"Torso", "Left Arm"}, {"Torso", "Right Arm"}, {"Torso", "Left Leg"}, {"Torso", "Right Leg"},
}

-- боты (NPC): модели с Humanoid, которые не являются персонажами игроков
local npcs = {}
local function registerHumanoid(h)
	local m = h.Parent
	if m and m:IsA("Model") and m ~= player.Character and not Players:GetPlayerFromCharacter(m) then npcs[m] = true end
end
task.spawn(function()
	local n = 0
	for _, inst in ipairs(workspace:GetDescendants()) do
		if inst:IsA("Humanoid") then registerHumanoid(inst) end
		n += 1
		if n % 800 == 0 then task.wait() end
	end
end)
bind(workspace.DescendantAdded, function(inst) if inst:IsA("Humanoid") then registerHumanoid(inst) end end)
bind(workspace.DescendantRemoving, function(inst) if inst:IsA("Humanoid") and inst.Parent then npcs[inst.Parent] = nil end end)

local espObjs = {}
local espWasOn = false
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function getObj(key)
	local o = espObjs[key]
	if not o then
		o = {e = newElements(espGui), hidden = false}
		espObjs[key] = o
	end
	return o
end

local function hideObj(o)
	if o.hidden then return end
	o.hidden = true
	hideElements(o.e)
	if o.hl then o.hl.Enabled = false end
	if o.light then o.light.Enabled = false end
	if o.dot then o.dot.Visible = false end
end

local function destroyObj(o)
	if not o then return end
	for _, i in ipairs(o.e.all) do i:Destroy() end
	if o.hl then o.hl:Destroy() end
	if o.light then o.light:Destroy() end
	if o.dot then o.dot:Destroy() end
end

bind(Players.PlayerRemoving, function(plr)
	destroyObj(espObjs[plr])
	espObjs[plr] = nil
end)

local function project(pos)
	local v = camera:WorldToViewportPoint(pos)
	return V2(v.X, v.Y), v.Z
end

local function updateRadarDot(o, pos, color)
	if not (RD.Enabled and E.Enabled) then
		if o.dot then o.dot.Visible = false end
		return
	end
	local dot = o.dot
	if not dot then
		dot = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(7, 7), BorderSizePixel = 0, Parent = U.radarFrame})
		corner(dot, 4)
		o.dot = dot
	end
	local rel = camera.CFrame:PointToObjectSpace(pos)
	local v = V2(rel.X, rel.Z) / RD.Range
	if v.Magnitude > 1 then v = v.Unit end
	local r = RD.Size / 2 * 0.92
	dot.Position = UDim2.new(0.5, v.X * r, 0.5, v.Y * r)
	dot.BackgroundColor3 = color
	dot.Visible = true
end

local espDrawn = 0
local charCache = {}
-- в некоторых играх персонаж лежит не в Player.Character — ищем модель по имени игрока
local function getCharacter(plr)
	local c = plr.Character
	if c then return c end
	local cache = charCache[plr]
	local now = os.clock()
	if cache and now - cache.t < 1 then return cache.m end
	local m = workspace:FindFirstChild(plr.Name, true)
	if m and not m:IsA("Model") then m = nil end
	charCache[plr] = {m = m, t = now}
	return m
end

-- КОМАНДЫ: Roblox Team, TeamColor, атрибуты и Value-объекты (многие игры не используют стандартные Team)
M.TEAM_KEYS = {"Team", "TeamName", "team", "TeamColor", "Side"}
M.teamCache = setmetatable({}, {__mode = "k"})
function M.teamRead(plr, char)
	local mode = Config.TeamMode
	if plr and (mode == "Авто" or mode == "Roblox Team") and plr.Team then return "T:" .. plr.Team.Name end
	if plr and (mode == "TeamColor" or (mode == "Авто" and plr.Team == nil and plr.TeamColor.Name ~= "White")) then
		return "C:" .. plr.TeamColor.Name
	end
	if mode == "Авто" or mode == "Атрибут/Value" then
		for _, inst in ipairs({plr or char, plr and char or char}) do
			if inst then
				for _, k in ipairs(M.TEAM_KEYS) do
					local a = inst:GetAttribute(k)
					if a ~= nil then return "A:" .. tostring(a) end
					local v = inst:FindFirstChild(k)
					if v and v:IsA("ValueBase") then return "V:" .. tostring(v.Value) end
				end
			end
		end
	end
	return nil
end
function M.teamOf(plr, char)
	local key = char or plr
	if not key then return nil end
	local c = M.teamCache[key]
	local now = os.clock()
	if c and now - c.t < 0.4 then return c.v end
	local v = M.teamRead(plr, char)
	M.teamCache[key] = {v = v, t = now}
	return v
end
function M.isAlly(plr, char)
	local mine = M.teamOf(player, player.Character)
	local theirs = M.teamOf(plr, char)
	return mine ~= nil and theirs ~= nil and mine == theirs
end
-- «Все / Враги / Союзники»; если команду определить нельзя — цель считается врагом
function M.passes(mode, plr, char)
	if mode == "Все" then return true end
	local ally = M.isAlly(plr, char)
	if mode == "Враги" then return not ally end
	return ally
end

-- ЖИВ ЛИ ПЕРСОНАЖ: Humanoid, событие Died, устаревшая модель, атрибуты Dead/Alive
M.dead = setmetatable({}, {__mode = "k"})
M.hooked = setmetatable({}, {__mode = "k"})
function M.isAlive(plr, char, hum)
	if M.dead[char] then return false end
	if not char:IsDescendantOf(workspace) then return false end
	if plr and plr.Character ~= nil and plr.Character ~= char then return false end -- старая модель / труп
	if hum then
		if not M.hooked[hum] then
			M.hooked[hum] = true
			hum.Died:Connect(function() M.dead[char] = true end)
		end
		if hum.Health <= 0 or hum:GetState() == Enum.HumanoidStateType.Dead then return false end
	end
	for _, k in ipairs({"Dead", "IsDead", "Eliminated"}) do
		if char:GetAttribute(k) == true or (plr and plr:GetAttribute(k) == true) then return false end
	end
	if char:GetAttribute("Alive") == false or (plr and plr:GetAttribute("Alive") == false) then return false end
	return true
end

local function drawPlayer(o, plr, char, hum, hrp, dist, vp, t)
	local cfg = E
	o.hidden = false

	-- Chams
	if CH.Enabled then
		local hl = o.hl
		if not hl then
			hl = Instance.new("Highlight")
			hl.Parent = chamFolder
			o.hl = hl
		end
		if hl.Adornee ~= char then hl.Adornee = char end
		local ft = CH.FillTransparency
		if CH.Pulse then ft = ft + (1 - ft) * 0.6 * (math.sin(t * 3) * 0.5 + 0.5) end
		hl.FillColor = col(CH.Fill)
		hl.FillTransparency = ft
		hl.OutlineColor = col(CH.Outline)
		hl.OutlineTransparency = CH.OutlineTransparency
		hl.DepthMode = CH.AlwaysOnTop and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
		hl.Enabled = true
	elseif o.hl then
		o.hl.Enabled = false
	end

	-- Свечение
	if GL.Enabled then
		local l = o.light
		if not l or l.Parent ~= hrp then
			if l then l:Destroy() end
			l = Instance.new("PointLight")
			l.Name = "GlassGlow"
			l.Shadows = false
			l.Parent = hrp
			o.light = l
		end
		l.Color = col(GL.Color)
		l.Brightness = GL.Brightness
		l.Range = GL.Range
		l.Enabled = true
	elseif o.light then
		o.light.Enabled = false
	end

	-- проекция бокса
	local cf, bsz = char:GetBoundingBox()
	local boxCF = CFrame.new(hrp.Position.X, cf.Position.Y, hrp.Position.Z) * hrp.CFrame.Rotation
	local half = Vector3.new(4.2, math.max(bsz.Y, 1), 2.4) / 2
	local corners = {}
	local minX, minY, maxX, maxY, allFront = math.huge, math.huge, -math.huge, -math.huge, true
	for i = 0, 7 do
		local sx = (i % 2) * 2 - 1
		local sy = 1 - (math.floor(i / 2) % 2) * 2
		local sz = math.floor(i / 4) * 2 - 1
		local p, depth = project(boxCF:PointToWorldSpace(half * Vector3.new(sx, sy, sz)))
		if depth <= 0 then allFront = false end
		corners[i + 1] = p
		minX, minY = math.min(minX, p.X), math.min(minY, p.Y)
		maxX, maxY = math.max(maxX, p.X), math.max(maxY, p.Y)
	end
	local onScreen = allFront and maxX > 0 and minX < vp.X and maxY > 0 and minY < vp.Y

	-- цвет-переопределение
	local override
	if cfg.TeamColor and plr and plr.Team then override = plr.TeamColor.Color end
	if cfg.VisCheck then
		local head = char:FindFirstChild("Head") or hrp
		rayParams.FilterDescendantsInstances = {player.Character, char, bulletFolder}
		local origin = camera.CFrame.Position
		if workspace:Raycast(origin, head.Position - origin, rayParams) then override = col(cfg.HiddenColor) end
	end

	updateRadarDot(o, hrp.Position, override or col(RD.Color))

	local d = {
		name = (plr and (cfg.Info.DisplayName and plr.DisplayName or plr.Name)) or char.Name,
		health = hum and hum.Health or 100, maxHealth = hum and hum.MaxHealth or 100, dist = dist, override = override,
	}
	local tool = char:FindFirstChildOfClass("Tool")
	d.weapon = tool and tool.Name or "—"

	if onScreen then
		local x, y, w, h = minX, minY, maxX - minX, maxY - minY
		d.rect = {x = x, y = y, w = w, h = h}
		d.corners = corners

		local head = char:FindFirstChild("Head")
		if head then
			local hp, hd = project(head.Position)
			if hd > 0 then d.head = hp; d.headSize = h * 0.14 end
			if cfg.Look.Enabled then
				local a, da = project(head.Position)
				local b, db = project(head.Position + head.CFrame.LookVector * cfg.Look.Length)
				if da > 0 and db > 0 then d.look = {a, b} end
			end
		end

		if cfg.Skeleton.Enabled then
			local joints = {}
			local bones = char:FindFirstChild("UpperTorso") and R15_BONES or R6_BONES
			for _, b in ipairs(bones) do
				local p1, p2 = char:FindFirstChild(b[1]), char:FindFirstChild(b[2])
				if p1 and p2 then
					local a, da = project(p1.Position)
					local c2, dc = project(p2.Position)
					if da > 0 and dc > 0 then joints[#joints + 1] = {a, c2} end
				end
			end
			d.joints = joints
		end

		if cfg.Tracer.Enabled then
			local org = cfg.Tracer.Origin
			d.tracerFrom = org == "Снизу" and V2(vp.X / 2, vp.Y) or org == "Сверху" and V2(vp.X / 2, 0)
				or org == "Центр" and vp / 2 or UserInputService:GetMouseLocation()
			d.tracerTo = cfg.Tracer.Target == "Ноги" and V2(x + w / 2, y + h) or V2(x + w / 2, y + h / 2)
		end
	elseif cfg.Arrows.Enabled then
		local rel = camera.CFrame:PointToObjectSpace(hrp.Position)
		local dir = V2(rel.X, rel.Z)
		dir = dir.Magnitude > 0.001 and dir.Unit or V2(0, 1)
		local radius = math.min(cfg.Arrows.Radius, vp.Y / 2 - 30)
		d.arrow = {pos = vp / 2 + dir * radius, dir = dir}
	end

	render(o.e, d, cfg)
end

local function processEntity(key, plr, char, vp, camPos, t)
	local o = getObj(key)
	o.seen = true
	if not char:IsA("Model") then hideObj(o); return false end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart or char:FindFirstChildWhichIsA("BasePart")
	local show = hrp ~= nil and M.isAlive(plr, char, hum)
	local dist = 0
	if show then
		show = M.passes(E.Target, plr, char)
		dist = (hrp.Position - camPos).Magnitude
		if dist > E.MaxDistance then show = false end
	end
	if show then drawPlayer(o, plr, char, hum, hrp, dist, vp, t) else hideObj(o) end
	return show
end

-- ошибка в одной цели не должна оставлять «застрявшие» линии и ломать остальные
function M.safeProcess(key, plr, char, vp, camPos, t)
	local ok, res = pcall(processEntity, key, plr, char, vp, camPos, t)
	if ok then return res end
	errorsLog["esp:entity"] = string.sub(tostring(res), 1, 80)
	local o = espObjs[key]
	if o then
		o.hidden = false
		hideObj(o)
	end
	return false
end

local function updateESP(t)
	U.radarFrame.Visible = E.Enabled and RD.Enabled
	espDrawn = 0
	errorsLog["esp:entity"] = nil
	if not E.Enabled then
		if espWasOn then
			for _, o in pairs(espObjs) do hideObj(o) end
			espWasOn = false
		end
		return
	end
	espWasOn = true
	for _, o in pairs(espObjs) do o.seen = false end
	local vp, camPos = camera.ViewportSize, camera.CFrame.Position
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= player then
			local char = getCharacter(plr)
			if char and M.safeProcess(plr, plr, char, vp, camPos, t) then espDrawn += 1 end
		end
	end
	for m in pairs(npcs) do
		if m.Parent and m ~= player.Character then
			if Players:GetPlayerFromCharacter(m) then
				npcs[m] = nil
			elseif E.NPC or m:GetAttribute("GlassTest") then
				if M.safeProcess(m, nil, m, vp, camPos, t) then espDrawn += 1 end
			end
		else
			npcs[m] = nil
		end
	end
	for k, o in pairs(espObjs) do
		if not o.seen then
			hideObj(o)
			if typeof(k) == "Instance" and not k:IsDescendantOf(workspace) then
				destroyObj(o)
				espObjs[k] = nil
			end
		end
	end
end

local function countTargets()
	local p = 0
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= player and getCharacter(plr) then p += 1 end
	end
	local n = 0
	for m in pairs(npcs) do
		if m.Parent then n += 1 end
	end
	return p, n
end

--------------------------------------------------------------------
-- ТРАССЕРЫ ПУЛЬ
--------------------------------------------------------------------
local function anchorPart(pos)
	return new("Part", {
		Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
		Transparency = 1, Size = Vector3.new(0.1, 0.1, 0.1), Position = pos, Parent = bulletFolder,
	})
end

local function hitMarker(pos)
	if not BU.HitMarker then return end
	local ball = new("Part", {
		Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Shape = Enum.PartType.Ball,
		Material = Enum.Material.Neon, Color = col(BU.HitColor), Size = Vector3.new(0.3, 0.3, 0.3), Transparency = 0.15,
		Position = pos, Parent = bulletFolder,
	})
	tween(ball, 0.5, {Size = Vector3.new(1.6, 1.6, 1.6), Transparency = 1})
	task.delay(0.6, function() ball:Destroy() end)
end

function spawnTracer(a, b, hasHit)
	local life = BU.Lifetime
	local color = col(BU.Color)
	local dist = (b - a).Magnitude
	if dist < 0.5 then return end

	if BU.Style == "Луч" then
		local seq
		if BU.Color.Rainbow then
			local kps = {}
			for i = 0, 6 do kps[#kps + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV((hue + i / 6) % 1, 0.85, 1)) end
			seq = ColorSequence.new(kps)
		else
			seq = ColorSequence.new(color, color:Lerp(WHITE, 0.55))
		end
		local p0, p1 = anchorPart(a), anchorPart(b)
		local a0, a1 = Instance.new("Attachment", p0), Instance.new("Attachment", p1)
		local beam = new("Beam", {
			Attachment0 = a0, Attachment1 = a1, Color = seq, Width0 = BU.Width, Width1 = BU.Width * 0.4,
			LightEmission = 1, LightInfluence = 0, FaceCamera = true, Segments = 1, Parent = p0,
		})
		local nv = Instance.new("NumberValue")
		nv.Changed:Connect(function(v) beam.Transparency = NumberSequence.new(v) end)
		TweenService:Create(nv, TweenInfo.new(life, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {Value = 1}):Play()
		tween(beam, life, {Width0 = 0, Width1 = 0}, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
		task.delay(life + 0.1, function() p0:Destroy(); p1:Destroy(); nv:Destroy() end)
		if hasHit then hitMarker(b) end

	elseif BU.Style == "Лазер" then
		local w = math.max(0.03, BU.Width)
		local part = new("Part", {
			Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
			Material = Enum.Material.Neon, Color = color, Size = Vector3.new(w, w, dist),
			CFrame = CFrame.lookAt(a, b) * CFrame.new(0, 0, -dist / 2), Parent = bulletFolder,
		})
		tween(part, life, {Transparency = 1, Size = Vector3.new(0.01, 0.01, dist)}, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
		task.delay(life + 0.1, function() part:Destroy() end)
		if hasHit then hitMarker(b) end

	else -- "Снаряд": быстрый светящийся отрезок летит от стрелка к цели
		local seg = math.min(dist, 7)
		local w = math.max(0.03, BU.Width)
		local base = CFrame.lookAt(a, b)
		local part = new("Part", {
			Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
			Material = Enum.Material.Neon, Color = color, Size = Vector3.new(w, w, seg),
			CFrame = base * CFrame.new(0, 0, -seg / 2), Parent = bulletFolder,
		})
		local flight = math.max(0.05, (dist - seg) / 450)
		tween(part, flight, {CFrame = base * CFrame.new(0, 0, -(dist - seg / 2))}, Enum.EasingStyle.Linear)
		task.delay(flight, function()
			if hasHit then hitMarker(b) end
			tween(part, 0.2, {Transparency = 1})
			task.delay(0.25, function() part:Destroy() end)
		end)
	end
end

local lastShot = 0
local function shoot()
	if not BU.Enabled then return end
	local now = os.clock()
	if now - lastShot < 0.04 then return end
	lastShot = now

	local char = player.Character
	local tool = char and char:FindFirstChildOfClass("Tool")
	if BU.ToolOnly and not tool then return end

	local origin
	if BU.Origin == "Авто" and tool then
		local m = tool:FindFirstChild("Muzzle", true) or tool:FindFirstChild("Barrel", true) or tool:FindFirstChild("FirePoint", true)
		if m and m:IsA("Attachment") then origin = m.WorldPosition
		elseif m and m:IsA("BasePart") then origin = m.Position
		else
			local h = tool:FindFirstChild("Handle")
			if h then origin = h.Position end
		end
	elseif BU.Origin == "Персонаж" and char then
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp then origin = hrp.Position + Vector3.new(0, 1.5, 0) end
	end
	origin = origin or camera.CFrame:PointToWorldSpace(Vector3.new(0.9, -0.8, -1.5))

	local vp = camera.ViewportSize
	local pos = (UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter or UserInputService.TouchEnabled)
		and vp / 2 or UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(pos.X, pos.Y)
	rayParams.FilterDescendantsInstances = {char, bulletFolder}
	local res = workspace:Raycast(ray.Origin, ray.Direction * 1000, rayParams)
	spawnTracer(origin, res and res.Position or (ray.Origin + ray.Direction * 1000), res ~= nil)
end

local holding = false
bind(UserInputService.InputBegan, function(input, processed)
	if processed or isOpen then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		holding = true
		shoot()
		task.spawn(function()
			while holding do
				task.wait(BU.Interval)
				if holding then shoot() end
			end
		end)
	end
end)
bind(UserInputService.InputEnded, function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then holding = false end
end)

local hooked = setmetatable({}, {__mode = "k"})
local function hookTool(tool)
	if hooked[tool] then return end
	hooked[tool] = true
	tool.Activated:Connect(function() M.lastFire = os.clock(); shoot() end)
end
local function hookChar(char)
	for _, c in ipairs(char:GetChildren()) do if c:IsA("Tool") then hookTool(c) end end
	char.ChildAdded:Connect(function(c) if c:IsA("Tool") then hookTool(c) end end)
end
if player.Character then hookChar(player.Character) end
bind(player.CharacterAdded, hookChar)

--------------------------------------------------------------------
-- ХИТБОКСЫ / WALLBANG / ПРИЦЕЛ
--------------------------------------------------------------------
local hbOrig = {}
local function restoreHitbox(p, o)
	if p.Parent then
		p.Size, p.Transparency, p.Color = o.Size, o.Transparency, o.Color
		p.Material, p.CanCollide, p.Massless = o.Material, o.CanCollide, o.Massless
	end
end
local function restoreAllHitboxes()
	for p, o in pairs(hbOrig) do
		restoreHitbox(p, o)
		hbOrig[p] = nil
	end
end

local function hitboxPart(char)
	if HBc.Part == "Голова" then return char:FindFirstChild("Head") end
	if HBc.Part == "Торс" then return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") end
	return char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
end

local function updateHitboxes()
	if not HBc.Enabled then
		if next(hbOrig) then restoreAllHitboxes() end
		return
	end
	local touched = {}
	local size = Vector3.new(HBc.Size, HBc.Size, HBc.Size)
	local function handle(char, plr)
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not M.isAlive(plr, char, hum) then return end
		if not M.passes(HBc.Target, plr, char) then return end
		local part = hitboxPart(char)
		if not part then return end
		touched[part] = true
		local o = hbOrig[part]
		if not o then
			o = {Size = part.Size, Transparency = part.Transparency, Color = part.Color, Material = part.Material,
				CanCollide = part.CanCollide, Massless = part.Massless}
			hbOrig[part] = o
		end
		if part.Size ~= size then part.Size = size end
		part.CanCollide = false
		part.Massless = true
		if HBc.Hidden then
			part.Transparency = 1
			part.Material, part.Color = o.Material, o.Color
		else
			part.Transparency = HBc.Transparency
			part.Color = col(HBc.Color)
			part.Material = Enum.Material.Neon
		end
	end
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= player then
			local c = getCharacter(plr)
			if c then handle(c, plr) end
		end
	end
	for m in pairs(npcs) do
		if m.Parent and m ~= player.Character and (HBc.NPC or m:GetAttribute("GlassTest")) then handle(m, nil) end
	end
	for p, o in pairs(hbOrig) do
		if not touched[p] then
			restoreHitbox(p, o)
			hbOrig[p] = nil
		end
	end
end

-- Wallbang: стены вокруг тебя получают CanQuery=false (лучи проходят), CanCollide=false (можно пройти)
local wallState = {}
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Exclude

local function restoreWall(p, st)
	if p.Parent then
		p.CanQuery, p.CanCollide, p.LocalTransparencyModifier = st.Q, st.C, 0
	end
end
local function restoreAllWalls()
	for p, st in pairs(wallState) do
		restoreWall(p, st)
		wallState[p] = nil
	end
end

local function isWallPart(p, feetY)
	if not p:IsA("BasePart") or p:IsA("Terrain") then return false end
	local s, cf = p.Size, p.CFrame
	if WL.MaxThickness > 0 and math.min(s.X, s.Y, s.Z) > WL.MaxThickness then return false end
	if WL.KeepFloor then
		local hy = (math.abs(cf.RightVector.Y) * s.X + math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.LookVector.Y) * s.Z) / 2
		if cf.Position.Y + hy <= feetY + 1.2 then return false end -- пол / всё ниже колен
	end
	return true
end

local function wallPass()
	local active = WL.Bang or WL.NoClip or WL.Xray > 0
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not active or not hrp then
		if next(wallState) then restoreAllWalls() end
		return
	end
	local excl = {worldFolder}
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then excl[#excl + 1] = plr.Character end
	end
	for m in pairs(npcs) do
		if m.Parent then excl[#excl + 1] = m end
	end
	overlap.FilterDescendantsInstances = excl

	-- уже изменённые части с CanQuery=false не попадают в пространственный запрос — добавляем вручную
	local cand = {}
	for _, p in ipairs(workspace:GetPartBoundsInRadius(hrp.Position, WL.Radius, overlap)) do cand[p] = true end
	for p in pairs(wallState) do
		if p.Parent and (p.Position - hrp.Position).Magnitude <= WL.Radius then cand[p] = true end
	end

	local feetY = hrp.Position.Y - 3
	local x = WL.Xray / 100
	local touched = {}
	for p in pairs(cand) do
		if isWallPart(p, feetY) then
			touched[p] = true
			local st = wallState[p]
			if not st then
				st = {Q = p.CanQuery, C = p.CanCollide}
				wallState[p] = st
			end
			local q = (not WL.Bang) and st.Q
			local c = (not WL.NoClip) and st.C
			if p.CanQuery ~= q then p.CanQuery = q end
			if p.CanCollide ~= c then p.CanCollide = c end
			if p.LocalTransparencyModifier ~= x then p.LocalTransparencyModifier = x end
		end
	end
	for p, st in pairs(wallState) do
		if not touched[p] then
			restoreWall(p, st)
			wallState[p] = nil
		end
	end
end

-- свой прицел
U.chLines = {}
for i = 1, 4 do U.chLines[i] = mkLine(espGui) end
U.chDot = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(4, 4), BorderSizePixel = 0, Visible = false, Parent = espGui,
})
corner(U.chDot, 3)
local function updateCrosshair(vp)
	if not CRH.Enabled then
		if U.chLines[1].Visible then
			for _, l in ipairs(U.chLines) do l.Visible = false end
			U.chDot.Visible = false
		end
		return
	end
	local c, color = vp / 2, col(CRH.Color)
	local g, sz, th = CRH.Gap, CRH.Size, CRH.Thickness
	setLine(U.chLines[1], c + V2(-g - sz, 0), c + V2(-g, 0), th)
	setLine(U.chLines[2], c + V2(g, 0), c + V2(g + sz, 0), th)
	setLine(U.chLines[3], c + V2(0, -g - sz), c + V2(0, -g), th)
	setLine(U.chLines[4], c + V2(0, g), c + V2(0, g + sz), th)
	for _, l in ipairs(U.chLines) do
		l.BackgroundColor3 = color
		l.Visible = true
	end
	U.chDot.Size = UDim2.fromOffset(th + 2, th + 2)
	U.chDot.Position = UDim2.fromOffset(c.X, c.Y)
	U.chDot.BackgroundColor3 = color
	U.chDot.Visible = CRH.Dot
end

local wallAcc = 0

-- ПРИНУДИТЕЛЬНЫЕ ЗНАЧЕНИЯ: FOV / скорость / прыжок / noclip (игры любят их сбрасывать)
local ncOrig = {}
local function enforceMovement()
	local h = humanoid()
	if h then
		if MV.Walk and h.WalkSpeed ~= MV.Walk then h.WalkSpeed = MV.Walk end
		if MV.Jump then
			if h.UseJumpPower ~= true then h.UseJumpPower = true end
			if h.JumpPower ~= MV.Jump then h.JumpPower = MV.Jump end
		end
	end
	local char = player.Character
	if MV.Noclip and char then
		for _, p in ipairs(char:GetDescendants()) do
			if p:IsA("BasePart") then
				if ncOrig[p] == nil then ncOrig[p] = p.CanCollide end
				if p.CanCollide then p.CanCollide = false end
			end
		end
	elseif next(ncOrig) then
		for p, v in pairs(ncOrig) do
			if p.Parent then p.CanCollide = v end
			ncOrig[p] = nil
		end
	end
end

bind(UserInputService.JumpRequest, function()
	if MV.InfJump then
		local h = humanoid()
		if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
	end
end)

-- FOV ставится ПОСЛЕ скрипта камеры игры, поэтому игра не успевает его перезаписать
pcall(function() RunService:UnbindFromRenderStep("GlassFov") end)
RunService:BindToRenderStep("GlassFov", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if M.camStep then guard("camera", M.camStep, dt) end
end)

-- ТЕСТ-ЦЕЛЬ: манекен за стеной, чтобы проверить ESP / хитбоксы / Wallbang без других игроков
local testState
function clearTest()
	testState = nil
	testFolder:ClearAllChildren()
end

function spawnTest()
	clearTest()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local pos = hrp and hrp.Position or (camera.CFrame.Position - Vector3.new(0, 3, 0))
	local look = hrp and hrp.CFrame.LookVector or camera.CFrame.LookVector
	local fwd = Vector3.new(look.X, 0, look.Z)
	fwd = fwd.Magnitude > 0.1 and fwd.Unit or Vector3.new(0, 0, -1)

	new("Part", {
		Name = "TestWall", Anchored = true, Size = Vector3.new(16, 12, 1), Material = Enum.Material.Concrete,
		Color = Color3.fromRGB(70, 70, 70), Transparency = 0.1,
		CFrame = CFrame.lookAt(pos + fwd * 12 + Vector3.new(0, 3, 0), pos + fwd * 13 + Vector3.new(0, 3, 0)),
		Parent = testFolder,
	})

	local base = CFrame.lookAt(pos + fwd * 26, pos + fwd * 25)
	local m = Instance.new("Model")
	m.Name = "GlassDummy"
	m:SetAttribute("GlassTest", true)
	local function limb(name, size, offset, color)
		return new("Part", {
			Name = name, Size = size, Anchored = true, CanCollide = false, Color = color, Material = Enum.Material.SmoothPlastic,
			CFrame = base * CFrame.new(offset), Parent = m,
		})
	end
	local skin, shirt = Color3.fromRGB(235, 235, 235), Color3.fromRGB(60, 60, 60)
	local root = limb("HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 0, 0), shirt)
	root.Transparency = 1
	limb("Torso", Vector3.new(2, 2, 1), Vector3.new(0, 0, 0), shirt)
	limb("Head", Vector3.new(1.4, 1.2, 1.2), Vector3.new(0, 1.6, 0), skin)
	limb("Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 0, 0), skin)
	limb("Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 0, 0), skin)
	limb("Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, -2, 0), shirt)
	limb("Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, -2, 0), shirt)
	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R6
	hum.RequiresNeck = false
	hum.BreakJointsOnDeath = false
	hum.MaxHealth, hum.Health = 100, 100
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.Parent = m
	local tool = Instance.new("Tool")
	tool.Name = "Test Rifle"
	tool.RequiresHandle = false
	tool.Parent = m
	m.PrimaryPart = root
	m.Parent = testFolder

	testState = {model = m, hum = hum, base = base}
	notify("Тест-цель", "Манекен стоит за стеной перед тобой. Включи ESP / хитбоксы / Wallbang")
end

local function animateTest(t)
	local st = testState
	if not st or not st.model.Parent then return end
	st.model:PivotTo(st.base * CFrame.new(math.sin(t * 0.8) * 6, 0, 0))
	st.hum.Health = 55 + 40 * math.sin(t * 0.7)
end

--------------------------------------------------------------------
-- МОДУЛЬ: КАМЕРА (3-е лицо, плечо, зум)
--------------------------------------------------------------------
do
	local CM, ZM = Config.Cam, Config.Cam.Zoom
	local orig = {mode = player.CameraMode, min = player.CameraMinZoomDistance, max = player.CameraMaxZoomDistance}
	local held, btnHeld, thirdT = false, false, 0
	local function key() return Enum.KeyCode[ZM.Key] end

	bind(UserInputService.InputBegan, function(input, processed)
		if not processed and ZM.Enabled and input.KeyCode == key() then held = true end
	end)
	bind(UserInputService.InputEnded, function(input)
		if input.KeyCode == key() then held = false end
	end)

	local zb = new("Frame", {
		Name = "ZoomButton", Active = true, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(54, 54), BackgroundColor3 = THEME.Glass, BackgroundTransparency = 0.15, Visible = false, Parent = gui,
	})
	corner(zb, 27)
	stroke(zb, 0.2, 2)
	drawIcon(zb, "zoom", 28, WHITE, UDim2.fromOffset(13, 13))
	zb.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then btnHeld = true end
	end)
	zb.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then btnHeld = false end
	end)

	function M.camStep(dt)
		local cam = workspace.CurrentCamera
		if not cam then return end
		zb.Visible = ZM.Enabled and ZM.Button

		-- третье лицо
		if CM.Third then
			if not M.thirdOn then thirdT = os.clock() end
			M.thirdOn = true
			if player.CameraMode ~= Enum.CameraMode.Classic then player.CameraMode = Enum.CameraMode.Classic end
			-- первые 0.4 с жёстко ставим дистанцию, чтобы камера «выехала» из первого лица
			local mn = (CM.FreeZoom and os.clock() - thirdT > 0.4) and 0.5 or CM.Dist
			if player.CameraMinZoomDistance ~= mn then player.CameraMinZoomDistance = mn end
			if player.CameraMaxZoomDistance ~= CM.Dist then player.CameraMaxZoomDistance = CM.Dist end
		elseif M.thirdOn then
			M.thirdOn = false
			player.CameraMode, player.CameraMinZoomDistance, player.CameraMaxZoomDistance = orig.mode, orig.min, orig.max
		end

		local h = humanoid()
		if h and (CM.Offset ~= 0 or M.offOn) then
			local want = Vector3.new(CM.Offset, 0, 0)
			if h.CameraOffset ~= want then h.CameraOffset = want end
			M.offOn = CM.Offset ~= 0
		end

		-- FOV: свой + зум (своё значение хранится отдельно, игра не может его сбросить)
		local zooming = ZM.Enabled and (held or btnHeld)
		local want
		if zooming then want = ZM.FOV elseif M.fov then want = MV.Fov or M.base end
		if want then
			if not M.fov then
				M.base = MV.Fov or cam.FieldOfView
				M.fov = cam.FieldOfView
			end
			M.fov = M.fov + (want - M.fov) * (1 - math.exp(-dt * ZM.Smooth))
			if not zooming and math.abs(M.fov - want) < 0.2 then
				M.fov = nil
				if MV.Fov then cam.FieldOfView = MV.Fov end
			else
				cam.FieldOfView = M.fov
			end
		elseif MV.Fov and cam.FieldOfView ~= MV.Fov then
			cam.FieldOfView = MV.Fov
		end
	end

	M.clean[#M.clean + 1] = function()
		player.CameraMode, player.CameraMinZoomDistance, player.CameraMaxZoomDistance = orig.mode, orig.min, orig.max
		local h = humanoid()
		if h then h.CameraOffset = Vector3.new(0, 0, 0) end
	end
end

--------------------------------------------------------------------
-- МОДУЛЬ: АТМОСФЕРА
--------------------------------------------------------------------
do
	local AT, L = Config.Atmo, Lighting
	local orig = {Clock = L.ClockTime, Bright = L.Brightness, Expo = L.ExposureCompensation, Amb = L.Ambient,
		Out = L.OutdoorAmbient, FogC = L.FogColor, FogS = L.FogStart, FogE = L.FogEnd, Shadows = L.GlobalShadows}
	local fx, hidden, was = {}, {}, {}

	local function effect(class, name)
		local o = fx[name]
		if not o or not o.Parent then
			o = Instance.new(class)
			o.Name = name
			o.Parent = L
			fx[name] = o
		end
		return o
	end
	local function drop(name)
		if fx[name] then
			fx[name]:Destroy()
			fx[name] = nil
		end
	end
	local function setHidden(class, on, keep)
		if on then
			for _, o in ipairs(L:GetChildren()) do
				if o:IsA(class) and o ~= keep then
					hidden[o] = true
					o.Parent = nil
				end
			end
		elseif next(hidden) then
			for o in pairs(hidden) do
				if o:IsA(class) then
					o.Parent = L
					hidden[o] = nil
				end
			end
		end
	end

	function M.atmoStep()
		if AT.Clock and L.ClockTime ~= AT.Clock then L.ClockTime = AT.Clock end
		if AT.Bright and L.Brightness ~= AT.Bright then L.Brightness = AT.Bright end
		if AT.Expo and L.ExposureCompensation ~= AT.Expo then L.ExposureCompensation = AT.Expo end

		if AT.AmbientOn then
			was.amb = true
			local c = col(AT.Ambient)
			if L.Ambient ~= c then L.Ambient = c end
			if L.OutdoorAmbient ~= c then L.OutdoorAmbient = c end
		elseif was.amb then
			was.amb = false
			L.Ambient, L.OutdoorAmbient = orig.Amb, orig.Out
		end

		if AT.FogOn then
			was.fog = true
			L.FogColor, L.FogStart, L.FogEnd = col(AT.FogColor), AT.FogStart, AT.FogEnd
		elseif was.fog then
			was.fog = false
			L.FogColor, L.FogStart, L.FogEnd = orig.FogC, orig.FogS, orig.FogE
		end

		if AT.ShadowsOff then
			was.sh = true
			if L.GlobalShadows then L.GlobalShadows = false end
		elseif was.sh then
			was.sh = false
			L.GlobalShadows = orig.Shadows
		end

		if AT.AtmoOn then
			local a = effect("Atmosphere", "GlassAtmosphere")
			setHidden("Atmosphere", true, a)
			a.Density, a.Haze, a.Glare, a.Offset = AT.AtmoDensity / 100, AT.AtmoHaze / 10, AT.AtmoGlare / 10, 0
			a.Color, a.Decay = col(AT.AtmoColor), col(AT.AtmoColor)
		else
			drop("GlassAtmosphere")
			setHidden("Atmosphere", false)
		end
		setHidden("Sky", AT.SkyOff)

		if AT.BloomOn then
			local b = effect("BloomEffect", "GlassBloom")
			b.Intensity, b.Size, b.Threshold = AT.BloomInt / 100, AT.BloomSize, AT.BloomThr / 100
		else
			drop("GlassBloom")
		end
		if AT.CCOn then
			local c = effect("ColorCorrectionEffect", "GlassCC")
			c.Brightness, c.Contrast, c.Saturation, c.TintColor = AT.CCBright / 100, AT.CCContrast / 100, AT.CCSat / 100, col(AT.CCTint)
		else
			drop("GlassCC")
		end
		if AT.RaysOn then
			local r = effect("SunRaysEffect", "GlassRays")
			r.Intensity, r.Spread = AT.RaysInt / 100, 0.6
		else
			drop("GlassRays")
		end
	end

	local TOGGLES = {"Свой Ambient", "Свой туман", "Убрать тени", "Убрать небо", "Atmosphere (атмосфера)",
		"Bloom (свечение)", "Цветокоррекция", "Солнечные лучи"}

	function M.atmoReset()
		AT.Clock, AT.Bright, AT.Expo = false, false, false
		for _, name in ipairs(TOGGLES) do M.setByText(name, false) end
		L.ClockTime, L.Brightness, L.ExposureCompensation = orig.Clock, orig.Bright, orig.Expo
		M.atmoStep()
	end

	local PRESET = {
		["Ночь"] = {["Время суток (140 = 14:00)"] = 0, ["Яркость (×10)"] = 6, ["Свой Ambient"] = true,
			["Цвет Ambient"] = {25, 32, 70, false}, ["Bloom (свечение)"] = true, ["Цветокоррекция"] = true,
			["Оттенок"] = {170, 190, 255, false}, ["Насыщенность"] = -20, ["Яркость цвета"] = -8},
		["Закат"] = {["Время суток (140 = 14:00)"] = 180, ["Свой Ambient"] = true, ["Цвет Ambient"] = {255, 150, 90, false},
			["Bloom (свечение)"] = true, ["Интенсивность Bloom"] = 150, ["Цветокоррекция"] = true,
			["Оттенок"] = {255, 190, 150, false}, ["Насыщенность"] = 25, ["Контраст"] = 10, ["Солнечные лучи"] = true},
		["День"] = {["Время суток (140 = 14:00)"] = 130, ["Яркость (×10)"] = 40, ["Bloom (свечение)"] = true,
			["Интенсивность Bloom"] = 80, ["Цветокоррекция"] = true, ["Контраст"] = 10, ["Насыщенность"] = 20},
		["ЧБ"] = {["Цветокоррекция"] = true, ["Насыщенность"] = -100, ["Контраст"] = 25},
		["Туман"] = {["Свой туман"] = true, ["Цвет тумана"] = {60, 62, 70, false}, ["Конец тумана"] = 180,
			["Atmosphere (атмосфера)"] = true, ["Плотность"] = 60, ["Дымка"] = 40, ["Яркость (×10)"] = 8},
	}
	function M.atmoPreset(name)
		M.atmoReset()
		for text, value in pairs(PRESET[name] or {}) do M.setByText(text, value) end
		notify("Атмосфера", "Пресет: " .. name)
	end

	M.upd.atmo = function() M.atmoStep() end
	M.clean[#M.clean + 1] = function()
		AT.Clock, AT.Bright, AT.Expo = false, false, false
		for _, name in ipairs(TOGGLES) do M.setByText(name, false) end
		L.ClockTime, L.Brightness, L.ExposureCompensation = orig.Clock, orig.Bright, orig.Expo
		M.atmoStep()
		for name in pairs(fx) do drop(name) end
	end
end

--------------------------------------------------------------------
-- МОДУЛЬ: ХИТМАРКЕР / ЗВУК / СЧЁТЧИК УБИЙСТВ
--------------------------------------------------------------------
do
	local HT = Config.Hit
	M.kills, M.lastFire, M.firing = 0, 0, false
	local SOUNDS = {
		["Пинг"] = "rbxasset://sounds/electronicpingshort.wav",
		["Щелчок"] = "rbxasset://sounds/button.wav",
		["Оф"] = "rbxasset://sounds/uuhhh.mp3",
	}

	local function play(kind)
		if not HT.Sound then return end
		local choice = kind == "kill" and HT.KillSound or HT.HitSound
		local id = SOUNDS[choice]
		if choice == "Свой ID" then
			local c = kind == "kill" and HT.CustomKill or HT.CustomHit
			c = string.gsub(c, "%D", "")
			if c ~= "" then id = "rbxassetid://" .. c end
		end
		if not id then return end
		local snd = new("Sound", {SoundId = id, Volume = HT.Volume / 50, Parent = gui})
		snd:Play()
		task.delay(4, function() snd:Destroy() end)
	end

	local function marker(kill)
		local color = col(kill and HT.KillColor or HT.Color)
		local c = camera.ViewportSize / 2
		local sz, th, life = HT.Size * (kill and 1.45 or 1), HT.Thickness, HT.Time
		local style = HT.Style
		local objs = {}
		local function line(a, b)
			local f = mkLine(espGui)
			setLine(f, a, b, th)
			f.BackgroundColor3 = color
			f.Visible = true
			objs[#objs + 1] = f
		end
		if style == "Крест" then
			for _, sg in ipairs({{1, 1}, {1, -1}, {-1, 1}, {-1, -1}}) do
				line(c + V2(sg[1] * sz * 0.18, sg[2] * sz * 0.18), c + V2(sg[1] * sz * 0.6, sg[2] * sz * 0.6))
			end
		elseif style == "Плюс" then
			line(c + V2(-sz * 0.6, 0), c + V2(-sz * 0.18, 0)); line(c + V2(sz * 0.18, 0), c + V2(sz * 0.6, 0))
			line(c + V2(0, -sz * 0.6), c + V2(0, -sz * 0.18)); line(c + V2(0, sz * 0.18), c + V2(0, sz * 0.6))
		else
			local f = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(c.X, c.Y), Size = UDim2.fromOffset(sz * 0.5, sz * 0.5),
				BackgroundColor3 = color, BackgroundTransparency = style == "Точка" and 0 or 1, BorderSizePixel = 0, Parent = espGui,
			})
			corner(f, 1000)
			objs[1] = f
			tween(f, life, {Size = UDim2.fromOffset(sz * 1.1, sz * 1.1)})
			if style == "Круг" then tween(stroke(f, 0, th, color), life, {Transparency = 1}) end
		end
		for _, f in ipairs(objs) do
			tween(f, life, {BackgroundTransparency = 1})
			task.delay(life + 0.05, function() f:Destroy() end)
		end
	end

	local counter = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.62), Size = UDim2.fromOffset(220, 22),
		BackgroundTransparency = 1, Text = "", Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = WHITE,
		TextStrokeTransparency = 0.4, Visible = false, Parent = espGui,
	})
	local function onHit(kill)
		if kill then
			M.kills += 1
			counter.Text = "УБИЙСТВ: " .. M.kills
		end
		marker(kill)
		play(kill and "kill" or "hit")
	end

	local last = setmetatable({}, {__mode = "k"})
	local hooked = setmetatable({}, {__mode = "k"})
	local function hook(hum, char, plr)
		if hooked[hum] then return end
		hooked[hum] = true
		last[hum] = hum.Health
		hum.HealthChanged:Connect(function(h)
			local prev = last[hum]
			last[hum] = h
			if not HT.Enabled or not prev or h >= prev - 0.01 then return end
			if M.isAlly(plr, char) then return end
			if HT.OnlyAfterShot and not M.firing and os.clock() - M.lastFire > 0.6 then return end
			onHit(h <= 0)
		end)
	end

	bind(UserInputService.InputBegan, function(input)
		local ut = input.UserInputType
		if ut == Enum.UserInputType.MouseButton1 or ut == Enum.UserInputType.Touch then
			M.lastFire = os.clock()
			if ut == Enum.UserInputType.MouseButton1 then M.firing = true end
		end
	end)
	bind(UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then M.firing = false end
	end)

	M.upd.hit = function(t)
		counter.Visible = HT.Enabled and HT.Counter
		if not HT.Enabled or t - (M.hitScanT or 0) < 0.5 then return end
		M.hitScanT = t
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= player then
				local c = getCharacter(plr)
				local h = c and c:FindFirstChildOfClass("Humanoid")
				if h and not c:GetAttribute("GlassTest") then hook(h, c, plr) end
			end
		end
		for m in pairs(npcs) do
			if m.Parent and m ~= player.Character and not m:GetAttribute("GlassTest") then
				local h = m:FindFirstChildOfClass("Humanoid")
				if h then hook(h, m, nil) end
			end
		end
	end

	function M.hitTest()
		marker(false)
		play("hit")
		task.delay(0.45, function()
			marker(true)
			play("kill")
		end)
	end
end

--------------------------------------------------------------------
-- МОДУЛЬ: АВТО-ПИК (выход из-за укрытия к приближающемуся врагу + авто-стрельба по цели в прицеле)
--------------------------------------------------------------------
do
	local PK = Config.Peek
	local st = {state = "idle", t0 = 0, lastPeek = -99, lastShot = 0, side = 1, aimSince = nil, move = nil, assist = nil,
		lt = 0, prev = setmetatable({}, {__mode = "k"})}
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude

	local ring = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, Visible = false, Parent = espGui,
	})
	corner(ring, 1000)
	stroke(ring, 0.3, 1.5)

	local function targets()
		local list = {}
		local function add(char, plr)
			local hum = char:FindFirstChildOfClass("Humanoid")
			local hrp = char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
			if hrp and M.isAlive(plr, char, hum) and not M.isAlly(plr, char) then
				list[#list + 1] = {char = char, plr = plr, hrp = hrp}
			end
		end
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= player then
				local c = getCharacter(plr)
				if c and c:IsA("Model") then add(c, plr) end
			end
		end
		for m in pairs(npcs) do
			if m.Parent and m ~= player.Character and (E.NPC or m:GetAttribute("GlassTest")) then add(m, nil) end
		end
		return list
	end

	local function aimPart(e)
		if PK.AssistPart == "Голова" then return e.char:FindFirstChild("Head") or e.hrp end
		if PK.AssistPart == "Торс" then return e.char:FindFirstChild("UpperTorso") or e.char:FindFirstChild("Torso") or e.hrp end
		return e.hrp
	end

	local function visible(e, part)
		rp.FilterDescendantsInstances = {player.Character, bulletFolder}
		local o = camera.CFrame.Position
		local res = workspace:Raycast(o, part.Position - o, rp)
		return res == nil or res.Instance:IsDescendantOf(e.char)
	end

	local function fire()
		M.lastFire = os.clock()
		local m = PK.Method
		local char = player.Character
		local tool = char and char:FindFirstChildOfClass("Tool")
		if tool and (m == "Tool:Activate" or m == "Tool + клик") then pcall(function() tool:Activate() end) end
		if (m == "Клик (exploit)" or m == "Tool + клик") and typeof(mouse1click) == "function" then pcall(mouse1click) end
	end

	function M.peekStep(t)
		ring.Visible = false
		if not PK.Enabled then
			st.state, st.move, st.assist = "idle", nil, nil
			return
		end
		local char = player.Character
		local myHrp = char and char:FindFirstChild("HumanoidRootPart")
		if not myHrp then st.move = nil; return end
		local myPos, cam = myHrp.Position, camera
		local list = targets()

		local threat, threatD = nil, math.huge
		for _, e in ipairs(list) do
			local pos = e.hrp.Position
			e.dist = (pos - myPos).Magnitude
			local pv = st.prev[e.char]
			local vel = Vector3.new(0, 0, 0)
			if pv and t > pv.t then vel = (pos - pv.pos) / (t - pv.t) end
			st.prev[e.char] = {pos = pos, t = t}
			local av = e.hrp.AssemblyLinearVelocity
			if av.Magnitude > vel.Magnitude then vel = av end
			local flat = Vector3.new(vel.X, 0, vel.Z)
			local to = Vector3.new(myPos.X - pos.X, 0, myPos.Z - pos.Z)
			e.approaching = flat.Magnitude >= PK.MinSpeed and to.Magnitude > 0.1 and flat.Unit:Dot(to.Unit) >= PK.Approach / 100
			e.part = aimPart(e)
			e.vis = e.part ~= nil and visible(e, e.part) or false
			if e.dist <= PK.Range and (e.approaching or not PK.OnlyApproach) and e.dist < threatD then
				threat, threatD = e, e.dist
			end
		end

		-- выход из укрытия
		if st.state == "idle" then
			st.move = nil
			if PK.Peek and threat and t - st.lastPeek >= PK.Cooldown then
				local rel = cam.CFrame:VectorToObjectSpace(threat.hrp.Position - myPos)
				st.side = PK.Side == "Влево" and -1 or PK.Side == "Вправо" and 1 or (rel.X >= 0 and 1 or -1)
				st.state, st.t0 = "out", t
			end
		elseif st.state == "out" then
			st.move = cam.CFrame.RightVector * st.side
			if t - st.t0 >= PK.PeekTime then
				if PK.Return then
					st.state, st.t0 = "back", t
				else
					st.state, st.lastPeek, st.move = "idle", t, nil
				end
			end
		elseif st.state == "back" then
			st.move = cam.CFrame.RightVector * -st.side
			if t - st.t0 >= PK.PeekTime then st.state, st.lastPeek, st.move = "idle", t, nil end
		end

		-- цель для подвода прицела: ближайшая к центру экрана внутри угла захвата
		st.assist = nil
		local bestAng = math.rad(PK.AssistFov)
		local look = cam.CFrame.LookVector
		for _, e in ipairs(list) do
			if e.part and e.dist <= PK.Range * 1.5 and (e.approaching or not PK.OnlyApproach) and (e.vis or not PK.VisOnly) then
				local dir = (e.part.Position - cam.CFrame.Position)
				if dir.Magnitude > 0.1 then
					local ang = math.acos(math.clamp(look:Dot(dir.Unit), -1, 1))
					if ang < bestAng then bestAng, st.assist = ang, e end
				end
			end
		end

		-- авто-стрельба: стреляем, когда в прицеле враг
		if PK.Shoot and (st.state == "out" or not PK.OnlyWhilePeek) then
			rp.FilterDescendantsInstances = {char, bulletFolder}
			local res = workspace:Raycast(cam.CFrame.Position, look * (PK.Range * 1.5), rp)
			local hitE
			if res then
				for _, e in ipairs(list) do
					if res.Instance:IsDescendantOf(e.char) and (e.approaching or not PK.OnlyApproach) then hitE = e; break end
				end
			end
			if hitE then
				st.aimSince = st.aimSince or t
				if t - st.aimSince >= PK.Delay and t - st.lastShot >= PK.Interval then
					st.lastShot = t
					fire()
				end
			else
				st.aimSince = nil
			end
		end

		-- круг захвата
		if PK.Assist and PK.ShowFov then
			local vp = camera.ViewportSize
			local r = math.tan(math.rad(PK.AssistFov)) / math.tan(math.rad(camera.FieldOfView / 2)) * vp.Y / 2
			ring.Size = UDim2.fromOffset(r * 2, r * 2)
			ring.Visible = true
		end

		if t - st.lt > 0.25 and U.peekLabel then
			st.lt = t
			U.peekLabel.Text = string.format("Состояние: %s  •  целей: %d  •  угроза: %s", st.state, #list,
				threat and (math.floor(threat.dist) .. " st") or "нет")
		end
	end

	function M.peekMove()
		local m = st.move
		if m and PK.Enabled then
			local flat = Vector3.new(m.X, 0, m.Z)
			local h = humanoid()
			if h and flat.Magnitude > 0.01 then h:Move(flat.Unit, false) end
		end
	end

	function M.assistStep(dt)
		local e = st.assist
		if not (PK.Enabled and PK.Assist and e and e.part and e.part.Parent) then return end
		local cam = workspace.CurrentCamera
		local goal = CFrame.lookAt(cam.CFrame.Position, e.part.Position)
		cam.CFrame = cam.CFrame:Lerp(goal, 1 - math.exp(-dt * PK.Smooth))
	end

	pcall(function() RunService:UnbindFromRenderStep("GlassPeekMove") end)
	pcall(function() RunService:UnbindFromRenderStep("GlassAssist") end)
	RunService:BindToRenderStep("GlassPeekMove", Enum.RenderPriority.Input.Value + 1, function() guard("peekmove", M.peekMove) end)
	RunService:BindToRenderStep("GlassAssist", Enum.RenderPriority.Camera.Value + 2, function(dt) guard("assist", M.assistStep, dt) end)

	M.upd.peek = function(t) M.peekStep(t) end
	M.clean[#M.clean + 1] = function()
		pcall(function() RunService:UnbindFromRenderStep("GlassPeekMove") end)
		pcall(function() RunService:UnbindFromRenderStep("GlassAssist") end)
		st.move = nil
	end
end

--------------------------------------------------------------------
-- ОТКРЫТИЕ / ЗАКРЫТИЕ
--------------------------------------------------------------------
local token
function setOpen(state)
	if state == isOpen then return end
	isOpen = state
	local my = {}
	token = my
	if state then
		root.Visible = true
		winScale.Scale = 0.8
		window.GroupTransparency = 1
		window.Position = UDim2.new(0.5, 0, 0.5, 30)
		tween(window, 0.5, {GroupTransparency = 0, Position = UDim2.fromScale(0.5, 0.5)})
		tween(winScale, 0.65, {Scale = 1}, Enum.EasingStyle.Back)
		tween(blur, 0.5, {Size = blurTarget})
	else
		tween(window, 0.3, {GroupTransparency = 1, Position = UDim2.new(0.5, 0, 0.5, 20)}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tween(winScale, 0.3, {Scale = 0.88}, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		tween(blur, 0.35, {Size = 0})
		task.delay(0.32, function() if token == my then root.Visible = false end end)
	end
end

U.closeBtn.MouseButton1Click:Connect(function() setOpen(false) end)

bind(UserInputService.InputBegan, function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.RightShift then
		setOpen(not isOpen)
	elseif input.KeyCode == Enum.KeyCode.End then
		if _G.GlassMenuCleanup then _G.GlassMenuCleanup() end -- аварийная выгрузка
	end
end)

-- кнопка-лаунчер: нажми — меню откроется; потяни — переместишь
U.launcher = new("Frame", {
	Name = "Launcher", Active = true, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 0),
	Size = UDim2.fromOffset(54, 54), BackgroundColor3 = THEME.Glass, BackgroundTransparency = 0.15, Parent = gui,
})
corner(U.launcher, 27)
spin(accentGradient(stroke(U.launcher, 0, 2.5), 0), 90)
drawIcon(U.launcher, "logo", 30, WHITE, UDim2.fromOffset(12, 12))
U.lScale = new("UIScale", {Parent = U.launcher})

local ldrag, lmoved, lstart, lpos = false, false, nil, nil
U.launcher.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		ldrag, lmoved, lstart, lpos = true, false, input.Position, U.launcher.Position
		tween(U.lScale, 0.1, {Scale = 0.88})
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				ldrag = false
				tween(U.lScale, 0.35, {Scale = 1}, Enum.EasingStyle.Back)
				if not lmoved then setOpen(not isOpen) end
			end
		end)
	end
end)
bind(UserInputService.InputChanged, function(input)
	if ldrag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local d = input.Position - lstart
		if d.Magnitude > 8 then lmoved = true end
		if lmoved then
			U.launcher.Position = UDim2.new(lpos.X.Scale, lpos.X.Offset + d.X, lpos.Y.Scale, lpos.Y.Offset + d.Y)
		end
	end
end)
U.launcher.MouseEnter:Connect(function() tween(U.lScale, 0.35, {Scale = 1.1}, Enum.EasingStyle.Back) end)
U.launcher.MouseLeave:Connect(function() if not ldrag then tween(U.lScale, 0.35, {Scale = 1}, Enum.EasingStyle.Back) end end)

--------------------------------------------------------------------
-- ГЛАВНЫЙ ЦИКЛ
--------------------------------------------------------------------
local frames, acc, smooth = 0, 0, 60
local function updateStats(fps)
	local c = colorForFps(fps)
	local ping = 0
	pcall(function() ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue() + 0.5) end)
	local mem = math.floor(Stats:GetTotalMemoryUsageMb() + 0.5)
	U.bigFps.Text = string.format('%d <font size="15" color="rgb(160,166,200)">FPS</font>', fps)
	tween(U.bigFps, 0.3, {TextColor3 = c})
	U.statsLabel.Text = string.format("Пинг  %d ms\nПамять  %d MB", ping, mem)
	table.remove(history, 1)
	table.insert(history, fps)
	for i, b in ipairs(bars) do
		local v = history[i]
		b.Visible = v > 0
		tween(b, 0.25, {Size = UDim2.new(1 / BARS, -2, math.clamp(v / 144, 0.05, 1), 0), BackgroundColor3 = colorForFps(v)})
	end
end

local function countKeys(tbl)
	local n = 0
	for _ in pairs(tbl) do n += 1 end
	return n
end

local function updateStatuses(fps)
	local p, n = countTargets()
	espStatus.Text = string.format("Игроков рядом: %d  •  ботов: %d  •  отрисовано: %d", p, n, espDrawn)
		.. "\nМоя команда: " .. tostring(M.teamOf(player, player.Character) or "не определена (все = враги)")
		.. ((p + n == 0) and "\nЦелей нет — нажми «Создать тест-цель»" or "")
	hbStatus.Text = "Изменено частей тела: " .. countKeys(hbOrig)
	wallStatus.Text = "Изменено объектов стен: " .. countKeys(wallState)

	if current == "Настройки" then
		local lines = {
			string.format("FPS %d  •  игроков рядом: %d  •  ботов: %d", fps, p, n),
			string.format("ESP: %s  •  отрисовано: %d", E.Enabled and "ВКЛ" or "выкл", espDrawn),
			string.format("Хитбоксы: %s  •  изменено: %d", HBc.Enabled and "ВКЛ" or "выкл", countKeys(hbOrig)),
			string.format("Wallbang / NoClip / X-Ray: %s  •  объектов: %d",
				(WL.Bang or WL.NoClip or WL.Xray > 0) and "ВКЛ" or "выкл", countKeys(wallState)),
			string.format("FOV камеры: %d  (свой: %s)", math.floor(camera.FieldOfView + 0.5), MV.Fov and tostring(MV.Fov) or "нет"),
		}
		local errs = {}
		for k, v in pairs(errorsLog) do errs[#errs + 1] = k .. ": " .. v end
		lines[#lines + 1] = #errs > 0 and ("ОШИБКИ: " .. table.concat(errs, " | ")) or "Ошибки: нет"
		U.diagLabel.Text = table.concat(lines, "\n")
	end
end

bind(RunService.RenderStepped, function(dt)
	local t = os.clock()
	local cam = workspace.CurrentCamera
	if cam and cam ~= camera then camera = cam end -- игра могла подменить камеру
	hue = (hue + dt * Config.Rainbow) % 1
	for _, sp in ipairs(spinners) do sp.g.Rotation = (sp.g.Rotation + dt * sp.speed) % 360 end

	frames += 1
	acc += dt
	if acc >= 0.25 then
		smooth += (frames / acc - smooth) * 0.5
		frames, acc = 0, 0
		local fps = math.floor(smooth + 0.5)
		if isOpen then
			if current == "Главная" then guard("stats", updateStats, fps) end
			guard("status", updateStatuses, fps)
		end
	end

	if isOpen then
		for _, sw in ipairs(swatches) do sw.sw.BackgroundColor3 = col(sw.obj) end
		if current == "ESP" then guard("preview", refreshPreview, t) end
	end

	guard("esp", updateESP, t)
	guard("crosshair", updateCrosshair, camera.ViewportSize)
	guard("hitbox", updateHitboxes)
	wallAcc += dt
	if wallAcc >= 0.6 then
		wallAcc = 0
		guard("wall", wallPass)
	end
	guard("move", enforceMovement)
	guard("test", animateTest, t)
	for name, fn in pairs(M.upd) do guard(name, fn, t, dt) end
end)

--------------------------------------------------------------------
-- ОЧИСТКА / СТАРТ
--------------------------------------------------------------------
_G.GlassMenuCleanup = function()
	for _, c in ipairs(conns) do c:Disconnect() end
	for _, o in pairs(espObjs) do destroyObj(o) end
	pcall(restoreAllHitboxes)
	pcall(restoreAllWalls)
	pcall(function() RunService:UnbindFromRenderStep("GlassFov") end)
	pcall(function()
		local hadFov, hadWalk, hadJump = MV.Fov, MV.Walk, MV.Jump
		MV.Fov, MV.Walk, MV.Jump, MV.Noclip, MV.InfJump = false, false, false, false, false
		enforceMovement() -- вернёт коллизии после Noclip
		if hadFov then camera.FieldOfView = U.origFov end
		local h = humanoid()
		if h then
			if hadWalk then h.WalkSpeed = origWalk end
			if hadJump then h.JumpPower = origJump end
		end
	end)
	for _, f in ipairs(M.clean) do pcall(f) end
	destroyIf(gui); destroyIf(espGui); destroyIf(blur); destroyIf(worldFolder); destroyIf(testFolder)
	holding = false
end

if M.autoload then pcall(M.autoload) end
selectTab("Главная")
task.delay(0.6, function() notify("Aurora Glass", "Нажми на кнопку-логотип слева, чтобы открыть меню") end)
