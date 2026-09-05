-- Local startup overlay, shown before the main GUI or game modules initialize.
local players = game:GetService('Players')
local runService = game:GetService('RunService')
local tweenService = game:GetService('TweenService')
local playerGui = players.LocalPlayer:WaitForChild('PlayerGui')
local previous = playerGui:FindFirstChild('VapeLoadingScreen')
if previous then previous:Destroy() end
local gui = {DisplayOrder = 10000000, Parent = playerGui}
local uipallet = {Font = Font.fromEnum(Enum.Font.Arial)}
local vape = {Clean = function() end}
local minimumDisplayTime = 7
local fadeInTime = 0.45
local entranceAnimations = {}
local logoTheme
-- The loader runs before vape:Load(), so read the same saved GUI settings directly.
pcall(function()
 local data = game:GetService('HttpService'):JSONDecode(readfile('newvape/profiles/'..game.GameId..'.gui.txt'))
 local settings = data.Categories.Main.Settings
 local options = settings.GUI or {}
 local context = {
  Theme = options.Theme or {Value = 'Custom'},
  ThemeSpeed = options['Theme Speed'] or {Value = 1},
  GUIColor = {Hue = 0.46, Sat = 0.96, Value = 0.52}
 }
 for _, pane in settings do
  if type(pane) == 'table' and type(pane['GUI Theme']) == 'table' then
   local saved = pane['GUI Theme']
   if type(saved.Hue) == 'number' and type(saved.Sat) == 'number' and type(saved.Value) == 'number' then
    context.GUIColor = saved
   end
  end
 end
 logoTheme = loadstring(readfile('newvape/guis/themes.lua'), 'Loading theme')()(context, {Main = Color3.fromRGB(23, 26, 33)}, runService)
end)
local function addCorner(parent, radius)
 local corner = Instance.new('UICorner')
 corner.CornerRadius = radius
 corner.Parent = parent
end
local function getvapeasset(path)
 local register = getcustomasset or getsynasset
 if register then
  local ok, asset = pcall(register, path)
  if ok and type(asset) == 'string' and asset ~= '' then return asset end
 end
 -- Full-resolution equivalents for runtimes without local asset registration.
 return path:find('vapelogo.png', 1, true) and 'rbxassetid://126205920310261' or 'rbxassetid://102549752760489'
end
function vape:ShowLoadingScreen()
	local screen = Instance.new('ScreenGui')
	screen.Name = 'VapeLoadingScreen'
	screen.Enabled = false
	screen.DisplayOrder = gui.DisplayOrder + 1
	screen.IgnoreGuiInset = true
	screen.ScreenInsets = Enum.ScreenInsets.None
	screen.ResetOnSpawn = false
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	pcall(function() screen.OnTopOfCoreBlur = true end)
	screen.Parent = gui.Parent
	self:Clean(screen)

	local panel = Instance.new('Frame')
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	panel.BorderSizePixel = 0
	panel.ClipsDescendants = true
	panel.Parent = screen
	self.LoadingScreen = screen
	self.LoadingPanel = panel
	self.LoadingStarted = os.clock()

	-- Oversized, rounded diagonal shapes reproduce the reference's quiet corner pattern.
	local cornerAnimations = {}
	for index, position in {Vector2.new(0, -0.06), Vector2.new(1, 1.06)} do
		local curve = Instance.new('Frame')
		curve.Name = 'CornerPattern'
		curve.AnchorPoint = Vector2.new(0.5, 0.5)
		curve.Position = UDim2.fromScale(position.X, position.Y)
		curve.Size = UDim2.fromScale(0.24, 0.85)
		curve.Rotation = 30
		curve.BackgroundColor3 = Color3.fromRGB(19, 19, 19)
		curve.BorderSizePixel = 0
		curve.Parent = panel
		addCorner(curve, UDim.new(0.5, 0))
		local direction = index == 1 and 1 or -1
		local motion = tweenService:Create(curve, TweenInfo.new(4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			Position = UDim2.fromScale(position.X + 0.035 * direction, position.Y + 0.045 * direction),
			Rotation = 30 + 7 * direction
		})
		table.insert(cornerAnimations, motion)
		motion:Play()
	end
	screen.Destroying:Once(function()
		for _, animation in entranceAnimations do animation:Cancel() end
		table.clear(entranceAnimations)
		for _, motion in cornerAnimations do
			motion:Cancel()
		end
		table.clear(cornerAnimations)
	end)

	local blocker = Instance.new('TextButton')
	blocker.Name = 'InputBlocker'
	blocker.Size = UDim2.fromScale(1, 1)
	blocker.BackgroundTransparency = 1
	blocker.Text = ''
	blocker.AutoButtonColor = false
	blocker.Modal = true
	blocker.Parent = panel
	local status = Instance.new('TextLabel')
	status.AnchorPoint = Vector2.new(0.5, 0.5)
	status.Position = UDim2.fromScale(0.5, 0.53)
	status.Size = UDim2.new(0.8, 0, 0, 42)
	status.BackgroundTransparency = 1
	status.FontFace = uipallet.Font
	status.TextColor3 = Color3.fromRGB(125, 125, 125)
	status.TextSize = 14
	status.Text = 'Loading Vape\nPreparing your interface'
	status.Parent = panel
	self.LoadingStatus = status

	local close = Instance.new('TextButton')
	close.Name = 'DismissLoading'
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -20, 0, 20)
	close.Size = UDim2.fromOffset(32, 28)
	close.BackgroundColor3 = Color3.fromRGB(29, 29, 29)
	close.TextColor3 = Color3.fromRGB(120, 120, 120)
	close.FontFace = uipallet.Font
	close.TextSize = 18
	close.Text = '×'
	close.Parent = panel
	addCorner(close, UDim.new(0.5, 0))
	close.MouseButton1Click:Connect(function()
		self:HideLoadingScreen(true)
	end)

	local logo = Instance.new('ImageLabel')
	logo.Name = 'VapeLogo'
	logo.AnchorPoint = Vector2.new(1, 0.5)
	logo.Position = UDim2.new(0.5, 28, 0.4, 0)
	logo.Size = UDim2.fromOffset(112, 32)
	logo.BackgroundTransparency = 1
	logo.ScaleType = Enum.ScaleType.Fit
	logo.Parent = panel
	local version = Instance.new('ImageLabel')
	version.Name = 'Version'
	version.AnchorPoint = Vector2.new(0, 0.5)
	version.Position = UDim2.new(0.5, 28, 0.4, 0)
	version.Size = UDim2.fromOffset(46, 32)
	version.BackgroundTransparency = 1
	version.ImageColor3 = Color3.fromRGB(73, 211, 173)
	version.ScaleType = Enum.ScaleType.Fit
	version.Parent = panel
	logo.Image = getvapeasset('newvape/assets/new/vapelogo.png')
	version.Image = getvapeasset('newvape/assets/new/v4.png')
	local themeConnection
	if logoTheme then
		local function updateLogo(dt)
			logoTheme:Update(dt)
			logo.ImageColor3 = logoTheme:GetColor()
			version.ImageColor3 = logoTheme:GetColor(0.125)
		end
		updateLogo(0)
		themeConnection = runService.RenderStepped:Connect(updateLogo)
		screen.Destroying:Once(function() themeConnection:Disconnect() end)
	end
	local objects = panel:GetDescendants()
	table.insert(objects, panel)
	for _, object in objects do
		if object:IsA('GuiObject') then
			local goal = {BackgroundTransparency = object.BackgroundTransparency}
			if object:IsA('ImageLabel') then
				goal.ImageTransparency = object.ImageTransparency
			elseif object:IsA('TextLabel') or object:IsA('TextButton') then
				goal.TextTransparency = object.TextTransparency
			end
			for property in goal do object[property] = 1 end
			table.insert(entranceAnimations, tweenService:Create(object,
				TweenInfo.new(fadeInTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal))
		end
	end
	screen.Enabled = true
	-- Let the overlay render even when the rest of initialization is fully cached.
	runService.RenderStepped:Wait()
	if self.LoadingScreen ~= screen or not screen.Parent then return end
	for _, animation in entranceAnimations do animation:Play() end
	-- Keep the full seven-second hold after the entrance animation finishes.
	self.LoadingStarted = os.clock() + fadeInTime
end

function vape:WaitForMinimumDisplay()
	-- Complete the visible hold before Frontlines can uninject for its actor handoff.
	while self.LoadingScreen and self.LoadingScreen.Parent do
		local remaining = minimumDisplayTime - (os.clock() - self.LoadingStarted)
		if remaining <= 0 then return end
		task.wait(math.min(remaining, 0.1))
	end
end

function vape:HideLoadingScreen(immediate)
	local screen, panel = self.LoadingScreen, self.LoadingPanel
	if not screen or not panel then return end
	local remaining = minimumDisplayTime - (os.clock() - self.LoadingStarted)
	if not immediate and remaining > 0 then
		if not self.LoadingDismissPending then
			self.LoadingDismissPending = true
			task.delay(remaining, function()
				if self.LoadingScreen == screen and screen.Parent then
					self:HideLoadingScreen(true)
				end
			end)
		end
		return
	end
	self.LoadingScreen, self.LoadingPanel, self.LoadingStatus = nil, nil, nil
	self.LoadingDismissPending = nil
	for _, animation in entranceAnimations do animation:Cancel() end
	table.clear(entranceAnimations)
	if not screen.Parent then return end
	local info = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, object in panel:GetDescendants() do
		if object:IsA('GuiObject') then
			local goal = {BackgroundTransparency = 1}
			if object:IsA('ImageLabel') then
				goal.ImageTransparency = 1
			elseif object:IsA('TextLabel') or object:IsA('TextButton') then
				goal.TextTransparency = 1
			end
			tweenService:Create(object, info, goal):Play()
		end
	end
	local fade = tweenService:Create(panel, info, {BackgroundTransparency = 1})
	fade.Completed:Once(function()
		screen:Destroy()
	end)
	fade:Play()
end


vape:ShowLoadingScreen()
return vape
