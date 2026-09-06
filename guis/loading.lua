-- illusionHD / Vape | CONTOUR / compact loading screen
-- Drop-in replacement: shows immediately, then returns the loader API.
-- ShowLoadingScreen(), WaitForMinimumDisplay(), HideLoadingScreen(immediate).
-- Optional: SetLoadingProgress(0..1, status). Without updates, shows an indeterminate sweep.
-- Shader-style UI lighting + an isolated BlurEffect; no camera/input hooks.
-- Font API: https://create.roblox.com/docs/reference/engine/datatypes/Font
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
	BlurSize = 14
}

local palette = {
	Main = Color3.fromRGB(26, 25, 26),
	Text = Color3.fromRGB(200, 200, 200),
	Font = Font.fromEnum(Enum.Font.Arial),
	FontSemiBold = Font.new(Font.fromEnum(Enum.Font.Arial).Family, Enum.FontWeight.SemiBold)
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
local MUTED = Color3.fromRGB(134, 139, 149)
local INK = Color3.fromRGB(8, 10, 14)
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
		FontFace = Font.new(Font.fromEnum(Enum.Font.Gotham).Family, weight or Enum.FontWeight.Medium),
		TextColor3 = color or WHITE, TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 12
	})
end
local function minimum(self)
	local value = tonumber(self.MinimumDisplayTime)
	return value and value == value and math.clamp(value, 0, 60) or 2.25
end

local function buildLoadingScreen(self)
	if self.LoadingScreen then self.LoadingScreen:Destroy() end
	local screen = new('ScreenGui', playerGui, {
		Name = 'VapeLoadingScreen', DisplayOrder = 10000001, IgnoreGuiInset = true,
		ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Global
	})
	self.LoadingScreen = screen
	local root = new('CanvasGroup', screen, {
		Name = 'Atmosphere', Size = UDim2.fromScale(1, 1), BackgroundColor3 = INK,
		BackgroundTransparency = 0.52, GroupTransparency = 1,
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

	local stage = frame(root, 'ResponsiveStage', 0, 0, 560, 300, WHITE, 1, 4)
	stage.AnchorPoint = Vector2.new(0.5, 0.5)
	stage.Position = UDim2.fromScale(0.5, 0.5)
	local fitScale = new('UIScale', stage, {Scale = 1})
	-- Quiet, close shadow. All artwork stays inside the card.
	for i = 5, 1, -1 do
		local shadow = frame(stage, 'Shadow', -i * 3, 5 - i * 2,
			560 + i * 6, 300 + i * 4, Color3.new(), 0.94, 4)
		corner(shadow, UDim.new(0, 14 + i * 3))
	end
	local panel = new('CanvasGroup', stage, {
		Name = 'LoadingCard', Position = UDim2.fromOffset(0, 12), Size = UDim2.fromOffset(560, 300),
		BackgroundColor3 = Color3.fromRGB(17, 19, 23), BackgroundTransparency = 0,
		BorderSizePixel = 0, GroupTransparency = 1, ClipsDescendants = true, ZIndex = 6
	})
	corner(panel, UDim.new(0, 14))
	local panelScale = new('UIScale', panel, {Scale = 0.985})
	state.Window, state.WindowScale, self.LoadingPanel = panel, panelScale, panel
	local border = new('UIStroke', panel, {Color = WHITE, Thickness = 1, Transparency = 0.86})
	local edgeGradient = new('UIGradient', border, {
		Color = ColorSequence.new(WHITE, accent), Rotation = 25,
		Transparency = sequence({{0, 0.12}, {0.45, 0.65}, {1, 0.25}})
	})

	local artwork = frame(panel, 'Artwork', 288, 0, 272, 250, WHITE, 1, 7)
	artwork.ClipsDescendants = true
	local lightField = frame(artwork, 'LightField', 34, -60, 295, 320, accent, 0.93, 7)
	corner(lightField, UDim.new(1, 0))
	new('UIGradient', lightField, {
		Rotation = -24, Transparency = sequence({{0, 1}, {0.48, 0.5}, {0.7, 0.06}, {1, 1}})
	})
	local texture = new('ImageLabel', artwork, {
		Name = 'FineTopography', BackgroundTransparency = 1, Image = TOPOGRAPHY_IMAGE,
		ImageColor3 = accent, ImageTransparency = 0.57,
		Position = UDim2.fromOffset(-60, -105), Size = UDim2.fromOffset(395, 395),
		ScaleType = Enum.ScaleType.Fit, Rotation = -8, ZIndex = 8
	})
	-- The fade belongs to the ImageLabel, rather than its container.
	local topoFade = new('UIGradient', texture, {
		Rotation = 8, Transparency = sequence({{0, 1}, {0.26, 1}, {0.6, 0.26}, {1, 0.06}})
	})
	local bottomShade = frame(artwork, 'ArtworkFade', 0, 116, 272, 134, Color3.fromRGB(17, 19, 23), 0, 9)
	new('UIGradient', bottomShade, {Rotation = 90, Transparency = sequence({{0, 1}, {1, 0}})})

	local wordmark = label(panel, 'VAPE', 30, 24, 127, 42, 36, WHITE, Enum.FontWeight.Bold)
	local logo = new('ImageLabel', panel, {
		Name = 'Wordmark', BackgroundTransparency = 1,
		Image = asset('newvape/assets/new/vapelogomini.png', '109041903452149'),
		Position = UDim2.fromOffset(32, 30), Size = UDim2.fromOffset(119, 34),
		ImageColor3 = WHITE, ScaleType = Enum.ScaleType.Fit, Visible = false, ZIndex = 12
	})
	local function logoLoaded()
		logo.Visible, wordmark.Visible = logo.IsLoaded, not logo.IsLoaded
	end
	connect(logo:GetPropertyChangedSignal('IsLoaded'), logoLoaded)
	logoLoaded()
	local badge = frame(panel, 'VersionBadge', 164, 34, 34, 23, accent, 0.89, 12)
	corner(badge, UDim.new(0, 5))
	local version = label(badge, 'V4', 8, 0, 25, 23, 10, accent, Enum.FontWeight.Bold)
	local close = new('TextButton', panel, {
		Name = 'Dismiss', Position = UDim2.fromOffset(506, 22), Size = UDim2.fromOffset(30, 30),
		BackgroundTransparency = 1, Text = '×', TextSize = 20, TextColor3 = MUTED,
		FontFace = palette.Font, AutoButtonColor = false, ZIndex = 14
	})
	label(panel, 'Loading your session.', 32, 108, 400, 33, 25, WHITE, Enum.FontWeight.Bold)
	local status = label(panel, 'Preparing your interface', 33, 148, 448, 26, 12, MUTED)
	self.LoadingStatus, state.Status = status, status
	local liveDot = frame(panel, 'StatusDot', 33, 211, 5, 5, accent, 0, 12)
	corner(liveDot, UDim.new(1, 0))
	local detail = label(panel, 'Please wait', 47, 201, 350, 24, 11, MUTED)
	local number = label(panel, '', 447, 201, 80, 24, 11, WHITE)
	number.TextXAlignment = Enum.TextXAlignment.Right
	local track = frame(panel, 'ProgressTrack', 32, 235, 496, 4, WHITE, 0.92, 12)
	corner(track, UDim.new(1, 0))
	track.ClipsDescendants = true
	local progress = frame(track, 'Progress', 0, 0, 0, 4, accent, 0, 13)
	corner(progress, UDim.new(1, 0))
	local sweep = frame(track, 'LightSweep', 0, 0, 145, 4, accent, 0, 14)
	new('UIGradient', sweep, {Transparency = sequence({{0, 1}, {0.55, 0.08}, {0.85, 0}, {1, 1}})})
	label(panel, 'illusionHD', 33, 259, 220, 18, 10, MUTED)
	local liveLabel = label(panel, 'INITIALIZING', 371, 259, 156, 18, 9, MUTED)
	liveLabel.TextXAlignment = Enum.TextXAlignment.Right
	state.Progress, state.Percent, state.Detail = progress, number, detail
	state.LiveLabel, state.Sweep = liveLabel, sweep

	local function fit()
		local size = root.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then return end
		fitScale.Scale = math.max(0.1, math.min(1, (size.X - 40) / 560, (size.Y - 48) / 300))
	end
	connect(root:GetPropertyChangedSignal('AbsoluteSize'), fit)
	fit()
	connect(close.Activated, function() self:HideLoadingScreen(true) end)
	connect(close.MouseEnter, function() close.TextColor3 = WHITE end)
	connect(close.MouseLeave, function() close.TextColor3 = MUTED end)
	animate(root, 0.32, {GroupTransparency = 0})
	animate(panel, 0.42, {GroupTransparency = 0, Position = UDim2.fromOffset(0, 0)})
	animate(panelScale, 0.48, {Scale = 1}, Enum.EasingStyle.Quint)
	local colorClock = 0
	connect(RunService.RenderStepped, function(dt)
		if not state.Alive or state.Closing then return end
		local elapsed = os.clock() - state.Started
		if theme then
			local ok, value = pcall(function()
				theme:Update(dt)
				return theme:GetColor(0.125)
			end)
			if ok and typeof(value) == 'Color3' then accent = value else theme = nil end
		end
		colorClock = colorClock + dt
		if colorClock >= 0.12 then
			colorClock = 0
			texture.ImageColor3, lightField.BackgroundColor3 = accent, accent
			badge.BackgroundColor3, version.TextColor3 = accent, accent
			liveDot.BackgroundColor3, progress.BackgroundColor3 = accent, accent
			sweep.BackgroundColor3 = accent
			edgeGradient.Color = ColorSequence.new(WHITE, accent)
		end
		texture.Position = UDim2.fromOffset(-60 + math.sin(elapsed * 0.23) * 5, -105 + math.sin(elapsed * 0.18) * 7)
		topoFade.Offset = Vector2.new(math.sin(elapsed * 0.35) * 0.065, 0)
		lightField.BackgroundTransparency = 0.935 + math.sin(elapsed * 0.7) * 0.014
		edgeGradient.Offset = Vector2.new(math.sin(elapsed * 0.32) * 0.22, 0)
		liveDot.BackgroundTransparency = state.Ready and 0 or 0.2 + (math.sin(elapsed * 4) + 1) * 0.2
		if state.Target ~= nil then
			state.Displayed = state.Displayed + (state.Target - state.Displayed) * (1 - math.exp(-dt * 9))
			progress.Size = UDim2.new(state.Displayed, 0, 1, 0)
			number.Text = string.format('%d%%', math.floor(state.Displayed * 100 + 0.0001))
			sweep.Visible = not state.Ready
		else
			number.Text = string.format('%.1fs', elapsed)
		end
		sweep.Position = UDim2.new((elapsed * 0.65) % 1.3 - 0.3, 0, 0, 0)
	end)
	return screen
end

-- Fail closed visually: a partially built loader must never strand its blur or UI.
function vape:ShowLoadingScreen()
	local ok, result = pcall(buildLoadingScreen, self)
	if ok then return result end
	local screen = self.LoadingScreen
	if screen then screen:Destroy() end
	self._loading, self.LoadingScreen, self.LoadingPanel = nil, nil, nil
	self.LoadingStatus, self.LoadingStarted, self.LoadingDismissPending = nil, nil, nil
	warn('[illusionHD] Loading screen could not initialize: '..tostring(result))
	return nil
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
			state.Percent.Text = '100%'
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
