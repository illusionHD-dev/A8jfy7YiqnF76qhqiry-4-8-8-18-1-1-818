-- GUI-matched startup overlay with fully procedural animated topography.
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local TweenService = game:GetService('TweenService')
local HttpService = game:GetService('HttpService')
local playerGui = Players.LocalPlayer:WaitForChild('PlayerGui')
local previous = playerGui:FindFirstChild('VapeLoadingScreen')
if previous then previous:Destroy() end

local vape = {MinimumDisplayTime = 2.2}
local palette = {
	Main = Color3.fromRGB(26, 25, 26),
	Text = Color3.fromRGB(200, 200, 200),
	Font = Font.fromEnum(Enum.Font.Arial),
	FontSemiBold = Font.fromEnum(Enum.Font.Arial, Enum.FontWeight.SemiBold)
}
local accent, theme = Color3.fromRGB(103, 235, 193), nil

local function new(class, parent, properties)
	local object = Instance.new(class)
	for key, value in pairs(properties or {}) do object[key] = value end
	object.Parent = parent
	return object
end

local function tween(object, duration, properties, style, direction)
	local motion = TweenService:Create(object, TweenInfo.new(
		duration,
		style or Enum.EasingStyle.Quart,
		direction or Enum.EasingDirection.Out
	), properties)
	motion:Play()
	return motion
end

local function asset(path, fallback)
	local register = getcustomasset or getsynasset
	if register then
		local ok, result = pcall(register, path)
		if ok and type(result) == 'string' and result ~= '' then return result end
	end
	return 'rbxassetid://'..fallback
end

local function addCorner(parent, radius)
	return new('UICorner', parent, {CornerRadius = radius or UDim.new(0, 5)})
end

local function setLine(segment, a, b, thickness)
	local delta = b - a
	segment.Position = UDim2.fromOffset(a.X, a.Y)
	segment.Size = UDim2.fromOffset(math.max(delta.Magnitude, 0.5), thickness)
	segment.Rotation = math.deg(math.atan2(delta.Y, delta.X))
end

-- Same palette/font source as the main GUI when those saved values are available.
pcall(function()
	local data = HttpService:JSONDecode(readfile('newvape/profiles/color.txt'))
	if data.Main then palette.Main = Color3.fromRGB(unpack(data.Main)) end
	if data.Text then palette.Text = Color3.fromRGB(unpack(data.Text)) end
	if data.Font then
		palette.Font = Font.new(data.Font:find('rbxasset') and data.Font or string.format('rbxasset://fonts/families/%s.json', data.Font))
		palette.FontSemiBold = Font.new(palette.Font.Family, Enum.FontWeight.SemiBold)
	end
end)

-- Match the saved GUI accent/theme before the main client initializes.
pcall(function()
	local data = HttpService:JSONDecode(readfile('newvape/profiles/'..game.GameId..'.gui.txt'))
	local settings = data.Categories.Main.Settings
	local options = settings.GUI or {}
	local context = {
		Theme = options.Theme or {Value = 'Custom'},
		ThemeSpeed = options['Theme Speed'] or {Value = 1},
		GUIColor = {Hue = 0.46, Sat = 0.96, Value = 0.52}
	}
	for _, pane in pairs(settings) do
		local saved = type(pane) == 'table' and pane['GUI Theme']
		if type(saved) == 'table' and type(saved.Hue) == 'number' and type(saved.Sat) == 'number' and type(saved.Value) == 'number' then
			context.GUIColor = saved
			accent = Color3.fromHSV(saved.Hue, saved.Sat, saved.Value)
		end
	end
	theme = loadstring(readfile('newvape/guis/themes.lua'), 'Loading theme')()(context, {Main = palette.Main}, RunService)
end)

local function createTopology(parent, options)
	options = options or {}
	local holder = new('Frame', parent, {
		Name = 'ProceduralTopography',
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Size = UDim2.fromScale(1, 1)
	})
	if options.Round then addCorner(holder, UDim.new(0, 5)) end

	local topology = {
		Holder = holder,
		Seed = math.random() * 100,
		Contours = {},
		Transparency = options.Transparency or 0.91,
		Color = accent,
		Rich = options.Rich == true
	}
	local contourCount = options.Contours or (topology.Rich and 8 or 5)
	local points = options.Points or (topology.Rich and 20 or 14)
	for ring = 1, contourCount do
		local contour = {Ring = ring, Points = points, Segments = {}}
		for point = 1, points do
			local segment = new('Frame', holder, {
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = accent,
				BackgroundTransparency = topology.Transparency,
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(1, topology.Rich and 1 or 0.8)
			})
			contour.Segments[point] = segment
		end
		topology.Contours[ring] = contour
	end
	return topology
end

local function updateTopology(topology, now)
	local holder = topology.Holder
	if not holder or not holder.Parent then return end
	local size = holder.AbsoluteSize
	if size.X < 4 or size.Y < 4 then return end
	local minAxis = math.min(size.X, size.Y)
	local drift = Vector2.new(
		math.sin(now * 0.13 + topology.Seed) * size.X * 0.028,
		math.cos(now * 0.11 + topology.Seed * 0.7) * size.Y * 0.04
	)

	for _, contour in topology.Contours do
		local ring = contour.Ring
		local pointCount = contour.Points
		local side = ring % 2 == 0 and 1 or -1
		local center = Vector2.new(
			size.X * (0.56 + side * (topology.Rich and 0.12 or 0.07)),
			size.Y * (0.51 - side * (topology.Rich and 0.08 or 0.04))
		) + drift
		local radius = minAxis * ((topology.Rich and 0.12 or 0.14) + ring * (topology.Rich and 0.047 or 0.06))
		local squash = 0.58 + math.sin(now * 0.18 + ring) * 0.07
		local generated = table.create(pointCount)

		for point = 1, pointCount do
			local angle = ((point - 1) / pointCount) * math.pi * 2
			local nx, ny = math.cos(angle), math.sin(angle)
			local n1 = math.noise(nx * 0.95 + topology.Seed, ny * 0.95 + ring * 0.27, now * 0.078)
			local n2 = math.noise(nx * 1.8 - topology.Seed * 0.25, ny * 1.8 + ring, now * 0.045 + 6)
			local breathing = math.sin(now * 0.32 + ring * 0.7 + angle * 3) * 0.04
			local r = radius * (1 + n1 * 0.18 + n2 * 0.08 + breathing)
			local warpX = math.noise(ring * 0.44, angle * 0.9 + topology.Seed, now * 0.1) * minAxis * 0.038
			local warpY = math.noise(angle * 0.9 - topology.Seed, ring * 0.51, now * 0.09) * minAxis * 0.05
			generated[point] = center + Vector2.new(nx * r + warpX, ny * r * squash + warpY)
		end

		for point, segment in contour.Segments do
			segment.BackgroundColor3 = topology.Color
			segment.BackgroundTransparency = math.clamp(topology.Transparency + ring * 0.007, 0, 1)
			setLine(segment, generated[point], generated[point == pointCount and 1 or point + 1], topology.Rich and 1 or 0.8)
		end
	end
end

function vape:ShowLoadingScreen()
	if self.LoadingScreen then self.LoadingScreen:Destroy() end

	local screen = new('ScreenGui', playerGui, {
		Name = 'VapeLoadingScreen',
		DisplayOrder = 10000001,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	})
	pcall(function() screen.OnTopOfCoreBlur = true end)

	local root = new('CanvasGroup', screen, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(),
		BackgroundTransparency = 0.28,
		GroupTransparency = 0,
		ClipsDescendants = true
	})
	local rootTopology = createTopology(root, {Rich = true, Contours = 8, Points = 20, Transparency = 0.972})
	local blocker = new('TextButton', root, {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = '',
		AutoButtonColor = false,
		Modal = true
	})

	local panel = new('CanvasGroup', root, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 12),
		Size = UDim2.fromOffset(430, 170),
		BackgroundColor3 = palette.Main,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		ClipsDescendants = true
	})
	addCorner(panel, UDim.new(0, 6))
	new('UIStroke', panel, {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(85, 85, 85),
		Transparency = 0.75
	})
	local panelScale = new('UIScale', panel, {Scale = 0.965})
	local panelTopology = createTopology(panel, {Contours = 5, Points = 14, Transparency = 0.92, Round = true})

	local logo = new('ImageLabel', panel, {
		BackgroundTransparency = 1,
		Image = asset('newvape/assets/new/vapelogomini.png', '109041903452149'),
		ImageColor3 = select(3, palette.Main:ToHSV()) > 0.5 and palette.Text or Color3.new(1, 1, 1),
		Position = UDim2.fromOffset(18, 15),
		Size = UDim2.fromOffset(55, 16)
	})
	local version = new('ImageLabel', logo, {
		BackgroundTransparency = 1,
		Image = asset('newvape/assets/new/v4mini.png', '115213099001611'),
		ImageColor3 = accent,
		Position = UDim2.new(1, -1, 0, 0),
		Size = UDim2.fromOffset(23, 16)
	})

	local readyPill = new('Frame', panel, {
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = palette.Main:Lerp(Color3.new(1, 1, 1), 0.025),
		BackgroundTransparency = 0.12,
		Position = UDim2.new(1, -18, 0, 13),
		Size = UDim2.fromOffset(86, 22)
	})
	addCorner(readyPill, UDim.new(0, 4))
	new('UIStroke', readyPill, {
		Color = palette.Main:Lerp(Color3.new(1, 1, 1), 0.09),
		Transparency = 0.42
	})
	local statusDot = new('Frame', readyPill, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(10, 11),
		Size = UDim2.fromOffset(4, 4)
	})
	addCorner(statusDot, UDim.new(1, 0))
	local statusDotScale = new('UIScale', statusDot, {Scale = 1})
	new('TextLabel', readyPill, {
		BackgroundTransparency = 1,
		FontFace = palette.FontSemiBold,
		Position = UDim2.fromOffset(18, 0),
		Size = UDim2.new(1, -20, 1, 0),
		Text = 'INITIALIZING',
		TextColor3 = palette.Text,
		TextSize = 8,
		TextXAlignment = Enum.TextXAlignment.Left
	})

	new('Frame', panel, {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.93,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 45),
		Size = UDim2.new(1, 0, 0, 1)
	})
	local accentLine = new('Frame', panel, {
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(18, 65),
		Size = UDim2.fromOffset(2, 45)
	})
	addCorner(accentLine, UDim.new(1, 0))

	local title = new('TextLabel', panel, {
		BackgroundTransparency = 1,
		FontFace = palette.FontSemiBold,
		Position = UDim2.fromOffset(31, 61),
		Size = UDim2.fromOffset(260, 25),
		Text = 'WELCOME BACK',
		TextColor3 = palette.Text,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left
	})
	local status = new('TextLabel', panel, {
		BackgroundTransparency = 1,
		FontFace = palette.Font,
		Position = UDim2.fromOffset(31, 88),
		Size = UDim2.fromOffset(330, 20),
		Text = 'Preparing your interface',
		TextColor3 = palette.Text:Lerp(palette.Main, 0.33),
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left
	})

	local track = new('Frame', panel, {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.91,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(18, 137),
		Size = UDim2.new(1, -36, 0, 2)
	})
	addCorner(track, UDim.new(1, 0))
	local progress = new('Frame', track, {
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1)
	})
	addCorner(progress, UDim.new(1, 0))

	local close = new('TextButton', panel, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -17, 1, -10),
		Size = UDim2.fromOffset(52, 18),
		BackgroundTransparency = 1,
		Text = 'SKIP',
		FontFace = palette.Font,
		TextSize = 9,
		TextColor3 = palette.Text:Lerp(palette.Main, 0.35),
		AutoButtonColor = false
	})
	local state = {
		Screen = screen,
		Root = root,
		Panel = panel,
		PanelScale = panelScale,
		Started = os.clock(),
		Alive = true,
		Tweens = {},
		Topologies = {rootTopology, panelTopology},
		StatusDot = statusDot,
		Progress = progress,
		Close = close,
		TopoAccumulator = 0
	}
	self._loading = state
	self.LoadingScreen, self.LoadingPanel, self.LoadingStatus = screen, panel, status
	self.LoadingStarted, self.LoadingDismissPending = state.Started, nil

	local pulseScale = TweenService:Create(statusDotScale, TweenInfo.new(1.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Scale = 1.6})
	local pulseFade = TweenService:Create(statusDot, TweenInfo.new(1.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {BackgroundTransparency = 0.58})
	pulseScale:Play()
	pulseFade:Play()
	state.PulseScale, state.PulseFade = pulseScale, pulseFade

	local function animate(object, duration, properties, style)
		local motion = tween(object, duration, properties, style)
		table.insert(state.Tweens, motion)
		return motion
	end

	state.Connection = RunService.RenderStepped:Connect(function(dt)
		if theme then
			local ok = pcall(function()
				theme:Update(dt)
				accent = theme:GetColor(0.125)
			end)
			if not ok then theme = nil end
		end

		local now = os.clock()
		state.TopoAccumulator += dt
		if state.TopoAccumulator >= (1 / 30) then
			state.TopoAccumulator = 0
			for _, topology in state.Topologies do
				topology.Color = accent
				updateTopology(topology, now)
			end
		end
		version.ImageColor3 = accent
		accentLine.BackgroundColor3 = accent
		statusDot.BackgroundColor3 = accent
		progress.BackgroundColor3 = accent
		local elapsed = now - state.Started
		progress.Size = UDim2.fromScale(math.clamp(elapsed / self.MinimumDisplayTime, 0, 1), 1)
	end)

	local hover
	close.MouseEnter:Connect(function()
		if hover then hover:Cancel() end
		hover = tween(close, 0.14, {TextColor3 = accent})
	end)
	close.MouseLeave:Connect(function()
		if hover then hover:Cancel() end
		hover = tween(close, 0.14, {TextColor3 = palette.Text:Lerp(palette.Main, 0.35)})
	end)
	close.Activated:Connect(function() self:HideLoadingScreen(true) end)

	animate(panel, 0.42, {GroupTransparency = 0, Position = UDim2.fromScale(0.5, 0.5)}, Enum.EasingStyle.Quart)
	animate(panelScale, 0.46, {Scale = 1}, Enum.EasingStyle.Back)

	screen.Destroying:Once(function()
		state.Alive = false
		if state.Connection then state.Connection:Disconnect() end
		pulseScale:Cancel()
		pulseFade:Cancel()
		for _, motion in ipairs(state.Tweens) do motion:Cancel() end
		if self._loading == state then
			self._loading = nil
			self.LoadingScreen, self.LoadingPanel, self.LoadingStatus = nil, nil, nil
			self.LoadingDismissPending = nil
		end
	end)

	RunService.RenderStepped:Wait()
end

function vape:WaitForMinimumDisplay()
	local state = self._loading
	while state and self._loading == state and not state.Closing and os.clock() - state.Started < self.MinimumDisplayTime do
		task.wait(0.05)
	end
end

function vape:HideLoadingScreen(immediate)
	local state = self._loading
	if not state or state.Closing then return end
	local remaining = self.MinimumDisplayTime - (os.clock() - state.Started)
	if not immediate and remaining > 0 then
		if not state.Pending then
			state.Pending, self.LoadingDismissPending = true, true
			task.delay(remaining, function()
				if self._loading == state then self:HideLoadingScreen(true) end
			end)
		end
		return
	end

	state.Closing = true
	if state.Connection then
		state.Connection:Disconnect()
		state.Connection = nil
	end
	state.PulseScale:Cancel()
	state.PulseFade:Cancel()
	for _, motion in ipairs(state.Tweens) do motion:Cancel() end
	state.Tweens = {
		tween(state.Panel, 0.22, {GroupTransparency = 1, Position = UDim2.new(0.5, 0, 0.5, -10)}),
		tween(state.PanelScale, 0.24, {Scale = 0.975}),
		tween(state.Root, 0.32, {GroupTransparency = 1, BackgroundTransparency = 1})
	}
	task.delay(0.34, function()
		if state.Screen and state.Screen.Parent then state.Screen:Destroy() end
	end)
end

vape:ShowLoadingScreen()
return vape
