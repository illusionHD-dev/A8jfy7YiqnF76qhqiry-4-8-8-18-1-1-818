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
	local backdrop = new('TextButton', screen, {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(7, 8, 12),
		BackgroundTransparency = 1, BorderSizePixel = 0, Text = '', AutoButtonColor = false, Modal = true
	})
	local card = new('CanvasGroup', backdrop, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.new(0.86, 0, 0, 166), BackgroundColor3 = Color3.fromRGB(18, 20, 26),
		BorderSizePixel = 0, GroupTransparency = 1
	})
	new('UISizeConstraint', card, {MaxSize = Vector2.new(340, 166)})
	new('UICorner', card, {CornerRadius = UDim.new(0, 18)})
	new('UIStroke', card, {Color = Color3.fromRGB(65, 71, 84), Transparency = 0.55, Thickness = 1})
	local scale = new('UIScale', card, {Scale = 0.94})
	local brand = new('Frame', card, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 34),
		Size = UDim2.fromOffset(158, 32), BackgroundTransparency = 1
	})
	local logo = new('ImageLabel', brand, {
		Size = UDim2.fromOffset(112, 32), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit,
		Image = asset('newvape/assets/new/vapelogo.png', '126205920310261')
	})
	local version = new('ImageLabel', brand, {
		Position = UDim2.fromOffset(112, 0), Size = UDim2.fromOffset(46, 32),
		BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, ImageColor3 = accent,
		Image = asset('newvape/assets/new/v4.png', '102549752760489')
	})
	local status = new('TextLabel', card, {
		Position = UDim2.new(0, 20, 0, 81), Size = UDim2.new(1, -40, 0, 22),
		BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12,
		TextColor3 = Color3.fromRGB(151, 157, 170), Text = 'Preparing your interface', TextTruncate = Enum.TextTruncate.AtEnd
	})
	local track = new('Frame', card, {
		Position = UDim2.new(0, 38, 0, 127), Size = UDim2.new(1, -76, 0, 2),
		BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(37, 41, 51), ClipsDescendants = true
	})
	local sweep = new('Frame', track, {
		Size = UDim2.fromScale(0.45, 1), BorderSizePixel = 0, BackgroundColor3 = accent
	})
	new('UIGradient', sweep, {Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1)
	})})
	local close = new('TextButton', card, {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(28, 28),
		BackgroundTransparency = 1, Text = '×', TextSize = 20, Font = Enum.Font.Gotham,
		TextColor3 = Color3.fromRGB(110, 117, 133), AutoButtonColor = false
	})
	local state = {Screen = screen, Card = card, Backdrop = backdrop, Scale = scale, Started = os.clock(), Tweens = {}}
	self._loading = state
	self.LoadingScreen, self.LoadingPanel, self.LoadingStatus = screen, card, status
	self.LoadingStarted = state.Started
	state.Connection = RunService.RenderStepped:Connect(function(dt)
		sweep.Position = UDim2.fromScale(((os.clock() - state.Started) / 1.3 % 1) * 1.45 - 0.45, 0)
		if theme then
			local ok = pcall(function()
				theme:Update(dt)
				logo.ImageColor3 = theme:GetColor()
				version.ImageColor3 = theme:GetColor(0.125)
				sweep.BackgroundColor3 = version.ImageColor3
			end)
			if not ok then theme = nil end
		end
	end)
	screen.Destroying:Once(function()
		state.Connection:Disconnect()
		for _, motion in ipairs(state.Tweens) do motion:Cancel() end
		if self._loading == state then
			self._loading = nil
			self.LoadingScreen, self.LoadingPanel, self.LoadingStatus = nil, nil, nil
			self.LoadingDismissPending = nil
		end
	end)
	close.Activated:Connect(function() self:HideLoadingScreen(true) end)
	close.MouseEnter:Connect(function() tween(close, 0.15, {TextColor3 = accent}) end)
	close.MouseLeave:Connect(function() tween(close, 0.15, {TextColor3 = Color3.fromRGB(110, 117, 133)}) end)
	state.Tweens = {
		tween(backdrop, 0.35, {BackgroundTransparency = 0.16}),
		tween(card, 0.45, {GroupTransparency = 0, Position = UDim2.fromScale(0.5, 0.5)}),
		tween(scale, 0.45, {Scale = 1})
	}
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
		tween(state.Backdrop, 0.25, {BackgroundTransparency = 1}),
		tween(state.Card, 0.25, {GroupTransparency = 1, Position = UDim2.fromScale(0.5, 0.49)}),
		tween(state.Scale, 0.25, {Scale = 0.97})
	}
	task.delay(0.26, function() state.Screen:Destroy() end)
end

vape:ShowLoadingScreen()
return vape
