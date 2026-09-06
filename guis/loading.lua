-- Replace the original startup overlay with this file.
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local TweenService = game:GetService('TweenService')
local playerGui = Players.LocalPlayer:WaitForChild('PlayerGui')
local previous = playerGui:FindFirstChild('VapeLoadingScreen')
if previous then previous:Destroy() end

local vape = {MinimumDisplayTime = 2.2}
local accent, theme = Color3.fromRGB(103, 235, 193), nil
local function new(class, parent, properties)
	local object = Instance.new(class)
	for key, value in pairs(properties or {}) do object[key] = value end
	object.Parent = parent
	return object
end
local function tween(object, duration, properties)
	local motion = TweenService:Create(object, TweenInfo.new(duration, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), properties)
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

-- Match the saved GUI theme before the main client initializes.
pcall(function()
	local data = game:GetService('HttpService'):JSONDecode(readfile('newvape/profiles/'..game.GameId..'.gui.txt'))
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
		end
	end
	theme = loadstring(readfile('newvape/guis/themes.lua'), 'Loading theme')()(context, {Main = Color3.fromRGB(16, 18, 23)}, RunService)
end)

function vape:ShowLoadingScreen()
	if self.LoadingScreen then self.LoadingScreen:Destroy() end
	local screen = new('ScreenGui', playerGui, {
		Name = 'VapeLoadingScreen', DisplayOrder = 10000001, IgnoreGuiInset = true,
		ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	})
	pcall(function() screen.OnTopOfCoreBlur = true end)
	local root = new('Frame', screen, {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true
	})
	local state = {Screen = screen, Started = os.clock(), Tweens = {}, Alive = true}
	local function animate(object, duration, properties)
		local motion = tween(object, duration, properties)
		table.insert(state.Tweens, motion)
	end
	local function later(delay, callback)
		task.delay(delay, function()
			if state.Alive and not state.Closing then callback() end
		end)
	end
	local shutters = {}
	for index = 1, 2 do
		shutters[index] = new('Frame', root, {
			Position = UDim2.fromScale(0, (index - 1) * 0.5), Size = UDim2.new(1, 0, 0.5, 1),
			BackgroundColor3 = Color3.fromRGB(9, 11, 15), BorderSizePixel = 0
		})
	end
	local ghost = new('ImageLabel', root, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.79, 0.5),
		Size = UDim2.fromScale(0.64, 0.9), Rotation = -12, BackgroundTransparency = 1,
		Image = asset('newvape/assets/new/v4.png', '102549752760489'),
		ImageColor3 = accent, ImageTransparency = 1, ScaleType = Enum.ScaleType.Fit
	})
	local hero = new('CanvasGroup', root, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.48),
		Size = UDim2.fromOffset(480, 220), BackgroundTransparency = 1, GroupTransparency = 0
	})
	local scale = new('UIScale', hero)
	local function fit()
		scale.Scale = math.clamp(math.min(root.AbsoluteSize.X / 560, root.AbsoluteSize.Y / 340), 0.25, 1.15)
	end
	fit()
	state.Resize = root:GetPropertyChangedSignal('AbsoluteSize'):Connect(fit)
	local function label(parent, text, position, size, color)
		return new('TextLabel', parent, {
			Position = position, Size = size, BackgroundTransparency = 1,
			Text = text, Font = Enum.Font.GothamMedium, TextSize = 11,
			TextColor3 = color, TextTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left
		})
	end
	local eyebrow = label(hero, 'W E L C O M E   B A C K', UDim2.fromOffset(40, 26), UDim2.fromOffset(400, 20), accent)
	local mask = new('Frame', hero, {
		Position = UDim2.fromOffset(40, 60), Size = UDim2.fromOffset(400, 90),
		BackgroundTransparency = 1, ClipsDescendants = true
	})
	local logo = new('ImageLabel', mask, {
		Position = UDim2.fromOffset(0, 100), Size = UDim2.fromOffset(280, 80),
		BackgroundTransparency = 1, Image = asset('newvape/assets/new/vapelogo.png', '126205920310261'),
		ScaleType = Enum.ScaleType.Fit, ImageColor3 = Color3.fromRGB(242, 245, 248)
	})
	local version = new('ImageLabel', mask, {
		Position = UDim2.fromOffset(410, 0), Size = UDim2.fromOffset(115, 80),
		BackgroundTransparency = 1, Image = ghost.Image, ImageColor3 = accent, ScaleType = Enum.ScaleType.Fit
	})
	local slash = new('Frame', hero, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(18, 100),
		Size = UDim2.fromOffset(3, 0), Rotation = 12, BackgroundColor3 = accent, BorderSizePixel = 0
	})
	local status = label(hero, 'Preparing your interface', UDim2.fromOffset(40, 175), UDim2.fromOffset(340, 24), Color3.fromRGB(139, 147, 163))
	status.TextSize = 13
	status.TextTruncate = Enum.TextTruncate.AtEnd
	local dots = {}
	for index = 1, 3 do
		dots[index] = new('Frame', hero, {
			Position = UDim2.fromOffset(402 + index * 10, 177), Size = UDim2.fromOffset(3, 3),
			BackgroundColor3 = accent, BackgroundTransparency = 1, BorderSizePixel = 0
		})
		new('UICorner', dots[index], {CornerRadius = UDim.new(1, 0)})
	end
	local close = new('TextButton', root, {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -24, 0, 20),
		Size = UDim2.fromOffset(58, 32), BackgroundTransparency = 1, Text = 'S K I P',
		Font = Enum.Font.GothamMedium, TextSize = 10, TextColor3 = Color3.fromRGB(133, 142, 157),
		TextTransparency = 1, AutoButtonColor = false
	})
	local blocker = new('TextButton', root, {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = '',
		AutoButtonColor = false, Modal = true, ZIndex = 0
	})
	state.Hero, state.Ghost, state.Close, state.Shutters = hero, ghost, close, shutters
	self._loading = state
	self.LoadingScreen, self.LoadingPanel, self.LoadingStatus = screen, root, status
	self.LoadingStarted, self.LoadingDismissPending = state.Started, nil
	state.Connection = RunService.RenderStepped:Connect(function(dt)
		local elapsed = os.clock() - state.Started
		ghost.Position = UDim2.fromScale(0.79 + math.sin(elapsed * 0.45) * 0.012, 0.5)
		for index, dot in ipairs(dots) do
			local wave = (math.sin(elapsed * 5 - index * 0.9) + 1) * 0.5
			dot.BackgroundTransparency = elapsed < 0.5 and 1 or 0.2 + wave * 0.65
			dot.Position = UDim2.fromOffset(402 + index * 10, 177 - wave * 3)
		end
		if theme then
			local ok = pcall(function()
				theme:Update(dt)
				accent = theme:GetColor(0.125)
			end)
			if not ok then theme = nil end
		end
		version.ImageColor3, ghost.ImageColor3 = accent, accent
		slash.BackgroundColor3, eyebrow.TextColor3 = accent, accent
		for _, dot in ipairs(dots) do dot.BackgroundColor3 = accent end
	end)
	screen.Destroying:Once(function()
		state.Alive = false
		state.Connection:Disconnect()
		state.Resize:Disconnect()
		for _, motion in ipairs(state.Tweens) do motion:Cancel() end
		if self._loading == state then
			self._loading = nil
			self.LoadingScreen, self.LoadingPanel, self.LoadingStatus = nil, nil, nil
			self.LoadingDismissPending = nil
		end
	end)
	close.Activated:Connect(function() self:HideLoadingScreen(true) end)
	local hover
	local function hoverColor(color)
		if state.Closing then return end
		if hover then hover:Cancel() end
		hover = tween(close, 0.15, {TextColor3 = color})
	end
	close.MouseEnter:Connect(function() hoverColor(accent) end)
	close.MouseLeave:Connect(function() hoverColor(Color3.fromRGB(133, 142, 157)) end)
	animate(slash, 0.5, {Size = UDim2.fromOffset(3, 70)})
	animate(ghost, 1.1, {ImageTransparency = 0.95})
	later(0.08, function() animate(logo, 0.7, {Position = UDim2.fromOffset(0, 0)}) end)
	later(0.2, function() animate(version, 0.65, {Position = UDim2.fromOffset(285, 0)}) end)
	later(0.3, function() animate(eyebrow, 0.45, {TextTransparency = 0.2}) end)
	later(0.45, function()
		animate(status, 0.4, {TextTransparency = 0, Position = UDim2.fromOffset(40, 165)})
		animate(close, 0.4, {TextTransparency = 0})
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
	state.Connection:Disconnect()
	for _, motion in ipairs(state.Tweens) do motion:Cancel() end
	state.Tweens = {
		tween(state.Hero, 0.25, {GroupTransparency = 1, Position = UDim2.fromScale(0.5, 0.44)}),
		tween(state.Ghost, 0.2, {ImageTransparency = 1}),
		tween(state.Close, 0.15, {TextTransparency = 1}),
		tween(state.Shutters[1], 0.55, {Position = UDim2.new(0, 0, -0.5, -2)}),
		tween(state.Shutters[2], 0.55, {Position = UDim2.fromScale(0, 1)})
	}
	task.delay(0.56, function() state.Screen:Destroy() end)
end

vape:ShowLoadingScreen()
return vape
