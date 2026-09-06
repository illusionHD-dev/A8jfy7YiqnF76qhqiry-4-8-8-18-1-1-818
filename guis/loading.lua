-- illusionHD / Vape | CONTOUR loading screen
-- Drop-in replacement: shows immediately, then returns the loader API.
-- ShowLoadingScreen(), WaitForMinimumDisplay(), HideLoadingScreen(immediate).
-- Optional: SetLoadingProgress(0..1, status). Without updates, shows an indeterminate sweep.
-- Shader-style UI lighting + an isolated BlurEffect; no camera/input hooks.
-- API references: https://create.roblox.com/docs/reference/engine/classes/BlurEffect
-- https://create.roblox.com/docs/reference/engine/classes/UIGradient
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local TweenService = game:GetService('TweenService')
local HttpService = game:GetService('HttpService')
local Lighting = game:GetService('Lighting')

local playerGui = Players.LocalPlayer:WaitForChild('PlayerGui')
local previous = playerGui:FindFirstChild('VapeLoadingScreen')
if previous then previous:Destroy() end

local vape = {
	MinimumDisplayTime = 2.25,
	BlurSize = 20
}

local palette = {
	Main = Color3.fromRGB(26, 25, 26),
	Text = Color3.fromRGB(200, 200, 200),
	Font = Font.fromEnum(Enum.Font.Arial),
	FontSemiBold = Font.fromEnum(Enum.Font.Arial, Enum.FontWeight.SemiBold)
}

local accent = Color3.fromRGB(103, 235, 193)
local theme

local TOPOGRAPHY_IMAGE = 'rbxassetid://2151741365'

local function new(class, parent, props)
	local object = Instance.new(class)
	for key, value in pairs(props or {}) do
		object[key] = value
	end
	object.Parent = parent
	return object
end

local function corner(parent, radius)
	return new('UICorner', parent, {
		CornerRadius = radius or UDim.new(0, 6)
	})
end

local function tween(object, duration, props, style, direction)
	local motion = TweenService:Create(
		object,
		TweenInfo.new(
			duration,
			style or Enum.EasingStyle.Quart,
			direction or Enum.EasingDirection.Out
		),
		props
	)
	motion:Play()
	return motion
end

local function asset(path, fallback)
	local register = getcustomasset or getsynasset
	if register then
		local ok, value = pcall(register, path)
		if ok and type(value) == 'string' and value ~= '' then
			return value
		end
	end
	return 'rbxassetid://'..fallback
end

local function light(col, amount)
	local h, s, v = col:ToHSV()
	return Color3.fromHSV(h, s, math.clamp(v + amount, 0, 1))
end

pcall(function()
	local data = HttpService:JSONDecode(readfile('newvape/profiles/color.txt'))
	if data.Main then
		palette.Main = Color3.fromRGB(unpack(data.Main))
	end
	if data.Text then
		palette.Text = Color3.fromRGB(unpack(data.Text))
	end
	if data.Font then
		palette.Font = Font.new(
			data.Font:find('rbxasset')
				and data.Font
				or string.format('rbxasset://fonts/families/%s.json', data.Font)
		)
		palette.FontSemiBold = Font.new(palette.Font.Family, Enum.FontWeight.SemiBold)
	end
end)

pcall(function()
	local data = HttpService:JSONDecode(
		readfile('newvape/profiles/'..game.GameId..'.gui.txt')
	)
	local settings = data.Categories.Main.Settings
	local options = settings.GUI or {}
	local context = {
		Theme = options.Theme or {Value = 'Custom'},
		ThemeSpeed = options['Theme Speed'] or {Value = 1},
		GUIColor = {Hue = 0.46, Sat = 0.96, Value = 0.52}
	}

	for _, pane in pairs(settings) do
		local saved = type(pane) == 'table' and pane['GUI Theme']
		if type(saved) == 'table'
			and type(saved.Hue) == 'number'
			and type(saved.Sat) == 'number'
			and type(saved.Value) == 'number' then
			context.GUIColor = saved
			accent = Color3.fromHSV(saved.Hue, saved.Sat, saved.Value)
		end
	end

	theme = loadstring(
		readfile('newvape/guis/themes.lua'),
		'Loading theme'
	)(context, {Main = palette.Main}, RunService)
end)

local WHITE = Color3.fromRGB(240, 248, 246)
local MUTED = Color3.fromRGB(132, 153, 149)
local INK = Color3.fromRGB(9, 15, 17)
local function sequence(points)
	local keys = {}
	for _, point in ipairs(points) do
		keys[#keys + 1] = NumberSequenceKeypoint.new(point[1], point[2])
	end
	return NumberSequence.new(keys)
end
local function frame(parent, name, x, y, w, h, color, transparency, z)
	return new('Frame', parent, {
		Name = name, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = color or WHITE, BackgroundTransparency = transparency or 0,
		BorderSizePixel = 0, ZIndex = z or 1
	})
end
local function label(parent, value, x, y, w, h, size, color, weight)
	return new('TextLabel', parent, {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h), Text = value, TextSize = size,
		FontFace = Font.fromEnum(Enum.Font.Gotham, weight or Enum.FontWeight.Medium),
		TextColor3 = color or WHITE, TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 12
	})
end
local function minimum(self)
	local value = tonumber(self.MinimumDisplayTime)
	return value and value == value and math.clamp(value, 0, 60) or 2.25
end

function vape:ShowLoadingScreen()
	if self.LoadingScreen then self.LoadingScreen:Destroy() end
	local screen = new('ScreenGui', playerGui, {
		Name = 'VapeLoadingScreen', DisplayOrder = 10000001, IgnoreGuiInset = true,
		ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Global
	})
	local root = new('CanvasGroup', screen, {
		Name = 'Atmosphere', Size = UDim2.fromScale(1, 1), BackgroundColor3 = INK,
		BackgroundTransparency = 0.13, GroupTransparency = 1,
		BorderSizePixel = 0, ClipsDescendants = true
	})
	local state = {
		Screen = screen, Root = root, Started = os.clock(), Alive = true, Closing = false,
		Tweens = {}, Connections = {}, Target = nil, Displayed = 0, Ready = false
	}
	self._loading, self.LoadingScreen = state, screen
	self.LoadingStarted, self.LoadingDismissPending = state.Started, nil
	local function connect(signal, callback)
		local connection = signal:Connect(callback)
		state.Connections[#state.Connections + 1] = connection
		return connection
	end
	local function animate(object, duration, properties, style, direction)
		local motion = tween(object, duration, properties, style, direction)
		state.Tweens[#state.Tweens + 1] = motion
		return motion
	end
	-- Register cleanup before constructing effects, including external destruction/re-execution.
	screen.Destroying:Once(function()
		state.Alive = false
		for _, connection in ipairs(state.Connections) do connection:Disconnect() end
		for _, motion in ipairs(state.Tweens) do motion:Cancel() end
		if state.Blur then state.Blur:Destroy() end
		if self._loading == state then
			self._loading, self.LoadingScreen, self.LoadingPanel = nil, nil, nil
			self.LoadingStatus, self.LoadingStarted, self.LoadingDismissPending = nil, nil, nil
		end
	end)
	pcall(function()
		state.Blur = new('BlurEffect', Lighting, {
			Name = 'VapeContourLoadingBlur', Enabled = true, Size = 0
		})
		animate(state.Blur, 0.6, {Size = math.clamp(tonumber(self.BlurSize) or 20, 0, 56)})
	end)

	-- A fixed design canvas keeps the artwork consistent on every aspect ratio.
	local scenery = frame(root, 'BackgroundOnly', 0, 0, 1440, 900, WHITE, 1, 1)
	scenery.AnchorPoint = Vector2.new(0.5, 0.5)
	scenery.Position = UDim2.fromScale(0.5, 0.5)
	local sceneryScale = new('UIScale', scenery, {Scale = 1})
	local ribbons = {}
	for i = 1, 3 do
		local band = frame(scenery, 'LightField'..i, -320, 40 + i * 215, 2000, 260, accent, 0.87, 1)
		band.Rotation = -23 + i * 8
		new('UIGradient', band, {
			Rotation = 90,
			Transparency = sequence({{0, 1}, {0.22, 0.83}, {0.5, 0.05}, {0.78, 0.83}, {1, 1}})
		})
		ribbons[i] = band
	end

	-- Procedural contour geometry: no image permission or texture download required.
	-- Built once; only the parent moves during animation (no per-frame geometry generation).
	local contours = frame(scenery, 'TopographicContours', 745, 390, 0, 0, WHITE, 1, 2)
	local lines = {}
	local samples = 64
	for level = 1, 14 do
		local radius = 76 + level * 31
		local function point(angle)
			local ripple = 1 + 0.115 * math.sin(angle * 3 + level * 0.11)
				+ 0.058 * math.cos(angle * 5 - level * 0.085) + 0.032 * math.sin(angle * 7)
			return Vector2.new(math.cos(angle) * radius * ripple * 1.46,
				math.sin(angle) * radius * ripple * 0.93)
		end
		for sample = 1, samples do
			local a = point((sample - 1) / samples * math.pi * 2)
			local b = point(sample / samples * math.pi * 2)
			local d = b - a
			local center = (a + b) * 0.5
			local major = level % 4 == 0
			local line = frame(contours, 'Contour', center.X, center.Y,
				d.Magnitude + 0.8, major and 1.6 or 1, accent,
				major and 0.51 or (0.73 + level * 0.006), 2)
			line.AnchorPoint = Vector2.new(0.5, 0.5)
			line.Rotation = math.deg(math.atan2(d.Y, d.X))
			lines[#lines + 1] = line
		end
	end
	-- A bright contour texture adds a second depth plane when the original asset loads.
	local texture = new('ImageLabel', scenery, {
		Name = 'DistantContours', BackgroundTransparency = 1, Image = TOPOGRAPHY_IMAGE,
		ImageColor3 = accent, ImageTransparency = 0.86, Position = UDim2.fromOffset(-240, -110),
		Size = UDim2.fromOffset(940, 940), ScaleType = Enum.ScaleType.Fit, Rotation = -18, ZIndex = 1
	})
	local vignette = frame(root, 'VerticalShade', 0, 0, 0, 0, INK, 0, 3)
	vignette.Size = UDim2.fromScale(1, 1)
	new('UIGradient', vignette, {
		Rotation = 90, Transparency = sequence({{0, 0.08}, {0.28, 0.84}, {0.66, 0.9}, {1, 0.05}})
	})

	local stage = frame(root, 'ResponsiveStage', 0, 0, 700, 388, WHITE, 1, 5)
	stage.AnchorPoint = Vector2.new(0.5, 0.5)
	stage.Position = UDim2.fromScale(0.5, 0.5)
	local fitScale = new('UIScale', stage, {Scale = 1})
	local panel = new('CanvasGroup', stage, {
		Name = 'GlassPanel', Position = UDim2.fromOffset(0, 24), Size = UDim2.fromOffset(700, 340),
		BackgroundColor3 = INK, BackgroundTransparency = 0.1, BorderSizePixel = 0,
		GroupTransparency = 1, ClipsDescendants = true, ZIndex = 6
	})
	corner(panel, UDim.new(0, 18))
	local panelScale = new('UIScale', panel, {Scale = 0.96})
	state.Window, state.WindowScale, self.LoadingPanel = panel, panelScale, panel
	local border = new('UIStroke', panel, {Color = WHITE, Thickness = 1, Transparency = 0.75})
	local borderGradient = new('UIGradient', border, {
		Color = ColorSequence.new(accent, Color3.fromRGB(38, 54, 62)), Rotation = -25
	})
	local glass = frame(panel, 'GlassLight', 0, 0, 700, 340, WHITE, 0.95, 7)
	new('UIGradient', glass, {Rotation = 35, Transparency = sequence({{0, 0.1}, {0.45, 0.87}, {1, 1}})})
	local topLine = frame(panel, 'LuminousEdge', 32, 0, 636, 1, accent, 0.15, 9)
	new('UIGradient', topLine, {Transparency = sequence({{0, 1}, {0.35, 0}, {0.65, 0.1}, {1, 1}})})

	label(panel, 'I L L U S I O N H D', 32, 23, 260, 18, 10, MUTED)
	local liveDot = frame(panel, 'StatusDot', 556, 30, 5, 5, accent, 0, 12)
	corner(liveDot, UDim.new(1, 0))
	local liveLabel = label(panel, 'STARTING', 570, 22, 80, 20, 9, accent)
	local close = new('TextButton', panel, {
		Name = 'Dismiss', Position = UDim2.fromOffset(654, 18), Size = UDim2.fromOffset(28, 28),
		BackgroundTransparency = 1, Text = '×', TextSize = 21, TextColor3 = MUTED,
		FontFace = palette.Font, AutoButtonColor = false, ZIndex = 14
	})
	local wordmark = label(panel, 'VAPE', 29, 64, 286, 81, 76, WHITE, Enum.FontWeight.Black)
	local logo = new('ImageLabel', panel, {
		Name = 'Wordmark', BackgroundTransparency = 1,
		Image = asset('newvape/assets/new/vapelogomini.png', '109041903452149'),
		Position = UDim2.fromOffset(34, 82), Size = UDim2.fromOffset(226, 65),
		ImageColor3 = WHITE, ScaleType = Enum.ScaleType.Fit, Visible = false, ZIndex = 12
	})
	local function logoLoaded()
		logo.Visible = logo.IsLoaded
		wordmark.Visible = not logo.IsLoaded
	end
	connect(logo:GetPropertyChangedSignal('IsLoaded'), logoLoaded)
	logoLoaded()
	local version = label(panel, 'V4', 279, 88, 70, 48, 34, accent, Enum.FontWeight.Bold)
	label(panel, 'Welcome back.', 34, 158, 410, 32, 25, WHITE, Enum.FontWeight.Medium)
	local subtitle = label(panel, 'Your next session starts here.', 35, 194, 430, 23, 12, MUTED)

	local number = label(panel, '···', 474, 76, 192, 80, 60, WHITE, Enum.FontWeight.Light)
	number.TextXAlignment = Enum.TextXAlignment.Right
	local numberCaption = label(panel, 'INITIALIZING', 476, 162, 190, 18, 9, MUTED)
	numberCaption.TextXAlignment = Enum.TextXAlignment.Right
	local elapsedLabel = label(panel, '00.0s', 550, 189, 116, 20, 11, MUTED)
	elapsedLabel.TextXAlignment = Enum.TextXAlignment.Right

	frame(panel, 'Divider', 34, 239, 632, 1, WHITE, 0.91, 10)
	local status = label(panel, 'Preparing your interface', 35, 253, 506, 24, 12, WHITE)
	self.LoadingStatus = status
	local detail = label(panel, 'Please wait', 546, 255, 120, 20, 10, MUTED)
	detail.TextXAlignment = Enum.TextXAlignment.Right
	local track = frame(panel, 'ProgressTrack', 34, 291, 632, 4, WHITE, 0.92, 10)
	corner(track, UDim.new(1, 0))
	track.ClipsDescendants = true
	local progress = frame(track, 'Progress', 0, 0, 0, 4, accent, 0, 11)
	corner(progress, UDim.new(1, 0))
	local sweep = frame(track, 'LightSweep', 0, 0, 160, 4, accent, 0, 12)
	new('UIGradient', sweep, {Transparency = sequence({{0, 1}, {0.48, 0}, {0.65, 0}, {1, 1}})})
	local footer = label(stage, 'V A P E   /   E L E V A T E   Y O U R   G A M E', 0, 358, 590, 20, 9, MUTED)
	local dismissHint = label(stage, '×  dismiss', 600, 358, 100, 20, 9, MUTED)
	dismissHint.TextXAlignment = Enum.TextXAlignment.Right
	state.Progress, state.Percent, state.Detail = progress, number, detail
	state.LiveLabel, state.Caption, state.Sweep = liveLabel, numberCaption, sweep
	state.Status = status

	local function fit()
		local size = root.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then return end
		fitScale.Scale = math.max(0.1, math.min(1, (size.X - 36) / 700, (size.Y - 48) / 388))
		sceneryScale.Scale = math.max(size.X / 1440, size.Y / 900)
	end
	connect(root:GetPropertyChangedSignal('AbsoluteSize'), fit)
	fit()
	connect(close.Activated, function() self:HideLoadingScreen(true) end)
	connect(close.MouseEnter, function() close.TextColor3 = WHITE end)
	connect(close.MouseLeave, function() close.TextColor3 = MUTED end)

	animate(root, 0.55, {GroupTransparency = 0})
	animate(panel, 0.65, {GroupTransparency = 0, Position = UDim2.fromOffset(0, 0)})
	animate(panelScale, 0.7, {Scale = 1}, Enum.EasingStyle.Quint)
	local colorClock, lastColor = 0, accent
	connect(RunService.RenderStepped, function(dt)
		if not state.Alive or state.Closing then return end
		local elapsed = os.clock() - state.Started
		colorClock = colorClock + dt
		if theme then
			local ok, value = pcall(function()
				theme:Update(dt)
				return theme:GetColor(0.125)
			end)
			if ok and typeof(value) == 'Color3' then accent = value else theme = nil end
		end
		if colorClock > 0.12 then
			colorClock = 0
			if accent ~= lastColor then
				lastColor = accent
				for _, line in ipairs(lines) do line.BackgroundColor3 = accent end
				for _, band in ipairs(ribbons) do band.BackgroundColor3 = accent end
				texture.ImageColor3 = accent
				version.TextColor3, liveLabel.TextColor3 = accent, accent
				progress.BackgroundColor3, sweep.BackgroundColor3 = accent, accent
				liveDot.BackgroundColor3, topLine.BackgroundColor3 = accent, accent
				borderGradient.Color = ColorSequence.new(accent, Color3.fromRGB(38, 54, 62))
			end
		end
		contours.Position = UDim2.fromOffset(745 + math.sin(elapsed * 0.22) * 24, 390 + math.cos(elapsed * 0.18) * 20)
		contours.Rotation = -12 + math.sin(elapsed * 0.13) * 5
		texture.Position = UDim2.fromOffset(-240 + math.sin(elapsed * 0.15) * 18, -110 + math.cos(elapsed * 0.12) * 20)
		for i, band in ipairs(ribbons) do
			band.Position = UDim2.fromOffset(-320 + math.sin(elapsed * 0.18 + i) * 80,
				40 + i * 215 + math.sin(elapsed * 0.3 + i * 1.7) * 48)
			band.BackgroundTransparency = 0.86 + math.sin(elapsed * 0.5 + i) * 0.025
		end
		borderGradient.Rotation = -25 + math.sin(elapsed * 0.35) * 32
		liveDot.BackgroundTransparency = state.Ready and 0 or 0.15 + (math.sin(elapsed * 4) + 1) * 0.24
		elapsedLabel.Text = string.format('%04.1fs', elapsed)
		if state.Target ~= nil then
			state.Displayed = state.Displayed + (state.Target - state.Displayed) * (1 - math.exp(-dt * 9))
			progress.Size = UDim2.new(state.Displayed, 0, 1, 0)
			number.Text = string.format('%02d', math.floor(state.Displayed * 100 + 0.0001))
			numberCaption.Text = state.Ready and 'READY TO GO' or 'PERCENT LOADED'
			sweep.Visible = not state.Ready
		else
			number.Text = string.rep('·', 1 + math.floor(elapsed * 2) % 3)
		end
		sweep.Position = UDim2.new((elapsed * 0.55) % 1.3 - 0.3, 0, 0, 0)
	end)
	return screen
end

function vape:SetLoadingProgress(value, message)
	local state = self._loading
	if not state or not state.Alive or state.Closing then return end
	if type(value) == 'number' and value == value then
		state.Target = math.max(state.Target or 0, math.clamp(value, 0, 1))
		state.Ready = state.Target >= 1
		state.LiveLabel.Text = state.Ready and 'READY' or 'LOADING'
		state.Detail.Text = state.Ready and 'Complete' or 'Please wait'
		if state.Ready then
			state.Displayed = 1
			state.Progress.Size = UDim2.fromScale(1, 1)
			state.Percent.Text = '100'
			state.Caption.Text = 'READY TO GO'
			state.Sweep.Visible = false
		end
	end
	if message ~= nil then state.Status.Text = tostring(message) end
end

function vape:WaitForMinimumDisplay()
	local state = self._loading
	while state and state.Alive and self._loading == state and not state.Closing
		and os.clock() - state.Started < minimum(self) do
		task.wait(0.05)
	end
end

function vape:HideLoadingScreen(immediate)
	local state = self._loading
	if not state or not state.Alive or state.Closing then return end
	-- The caller indicates readiness; elapsed time alone never claims that modules loaded.
	if not immediate then self:SetLoadingProgress(1, 'Everything is ready.') end
	local remaining = minimum(self) - (os.clock() - state.Started)
	if not immediate and remaining > 0 then
		if not state.Pending then
			state.Pending, self.LoadingDismissPending = true, true
			task.delay(remaining, function()
				if state.Alive and self._loading == state then self:HideLoadingScreen(true) end
			end)
		end
		return
	end
	state.Closing = true
	for _, motion in ipairs(state.Tweens) do motion:Cancel() end
	state.Tweens = {}
	local function fade(object, duration, properties)
		if object then
			state.Tweens[#state.Tweens + 1] = tween(object, duration, properties,
				Enum.EasingStyle.Quart, Enum.EasingDirection.In)
		end
	end
	fade(state.Window, 0.28, {GroupTransparency = 1, Position = UDim2.fromOffset(0, -12)})
	fade(state.WindowScale, 0.3, {Scale = 0.98})
	fade(state.Root, 0.42, {GroupTransparency = 1})
	if state.Blur and state.Blur.Parent then fade(state.Blur, 0.38, {Size = 0}) end
	task.delay(0.44, function()
		if state.Alive then state.Screen:Destroy() end
	end)
end

vape:ShowLoadingScreen()
return vape
