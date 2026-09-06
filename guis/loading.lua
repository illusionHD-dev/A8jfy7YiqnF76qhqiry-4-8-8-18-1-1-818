-- illusionHD / Vape loading screen
-- Rewritten loader using the real topography image asset (2151741365).
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local TweenService = game:GetService('TweenService')
local HttpService = game:GetService('HttpService')

local playerGui = Players.LocalPlayer:WaitForChild('PlayerGui')
local previous = playerGui:FindFirstChild('VapeLoadingScreen')
if previous then previous:Destroy() end

local vape = {
	MinimumDisplayTime = 2.25
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

function vape:ShowLoadingScreen()
	if self.LoadingScreen then
		self.LoadingScreen:Destroy()
	end

	local screen = new('ScreenGui', playerGui, {
		Name = 'VapeLoadingScreen',
		DisplayOrder = 10000001,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Global
	})
	pcall(function()
		screen.OnTopOfCoreBlur = true
	end)

	local root = new('CanvasGroup', screen, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(),
		BackgroundTransparency = 0.44,
		GroupTransparency = 0,
		ClipsDescendants = true
	})

	new('TextButton', root, {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = '',
		Modal = true,
		AutoButtonColor = false,
		ZIndex = 0
	})

	-- Fullscreen atmospheric topography layer.
	local ambient = new('ImageLabel', root, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = TOPOGRAPHY_IMAGE,
		ImageColor3 = accent,
		ImageTransparency = 0.975,
		Position = UDim2.fromScale(0.72, 0.53),
		Rotation = -6,
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromScale(1.15, 1.15),
		ZIndex = 0
	})

	local window = new('CanvasGroup', root, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = palette.Main,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		GroupTransparency = 1,
		Position = UDim2.new(0.5, 0, 0.5, 18),
		Size = UDim2.fromOffset(540, 246),
		ZIndex = 2
	})
	corner(window, UDim.new(0, 7))

	local windowScale = new('UIScale', window, {Scale = 0.965})
	new('UIStroke', window, {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = light(palette.Main, 0.09),
		Transparency = 0.42,
		Thickness = 1
	})

	-- Topography artwork lives inside the window.
	local topoHolder = new('Frame', window, {
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(132, 42),
		Size = UDim2.new(1, -132, 1, -42),
		ZIndex = 2
	})

	local topoBack = new('ImageLabel', topoHolder, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = TOPOGRAPHY_IMAGE,
		ImageColor3 = accent,
		ImageTransparency = 0.91,
		Position = UDim2.fromScale(0.68, 0.50),
		Rotation = -4,
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromScale(1.28, 1.28),
		ZIndex = 2
	})

	local topoFront = new('ImageLabel', topoHolder, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = TOPOGRAPHY_IMAGE,
		ImageColor3 = accent,
		ImageTransparency = 0.965,
		Position = UDim2.fromScale(0.76, 0.48),
		Rotation = 5,
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromScale(0.88, 0.88),
		ZIndex = 3
	})

	local fade = new('UIGradient', topoHolder, {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.18),
			NumberSequenceKeypoint.new(0.35, 0.35),
			NumberSequenceKeypoint.new(1, 0.82)
		})
	})
	fade.Rotation = 0

	-- Header
	local header = new('Frame', window, {
		BackgroundColor3 = light(palette.Main, 0.012),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 42),
		ZIndex = 6
	})

	new('Frame', header, {
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = light(palette.Main, 0.08),
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 1),
		ZIndex = 7
	})

	local logo = new('ImageLabel', header, {
		BackgroundTransparency = 1,
		Image = asset('newvape/assets/new/vapelogomini.png', '109041903452149'),
		ImageColor3 = palette.Text,
		Position = UDim2.fromOffset(15, 13),
		Size = UDim2.fromOffset(52, 15),
		ZIndex = 7
	})

	local version = new('ImageLabel', header, {
		BackgroundTransparency = 1,
		Image = asset('newvape/assets/new/v4mini.png', '115213099001611'),
		ImageColor3 = accent,
		Position = UDim2.fromOffset(71, 13),
		Size = UDim2.fromOffset(21, 15),
		ZIndex = 7
	})

	new('TextLabel', header, {
		BackgroundTransparency = 1,
		FontFace = palette.Font,
		Position = UDim2.fromOffset(116, 0),
		Size = UDim2.fromOffset(185, 42),
		Text = 'Preparing interface',
		TextColor3 = light(palette.Text, -0.1),
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 7
	})

	local chip = new('Frame', header, {
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = light(palette.Main, 0.032),
		Position = UDim2.new(1, -45, 0.5, 0),
		Size = UDim2.fromOffset(72, 22),
		ZIndex = 7
	})
	corner(chip, UDim.new(0, 4))

	local chipDot = new('Frame', chip, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(10, 11),
		Size = UDim2.fromOffset(5, 5),
		ZIndex = 8
	})
	corner(chipDot, UDim.new(1, 0))

	local chipText = new('TextLabel', chip, {
		BackgroundTransparency = 1,
		FontFace = palette.FontSemiBold,
		Position = UDim2.fromOffset(19, 0),
		Size = UDim2.new(1, -21, 1, 0),
		Text = 'LOADING',
		TextColor3 = light(palette.Text, -0.08),
		TextSize = 8,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 8
	})

	local close = new('TextButton', header, {
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(22, 22),
		Text = '×',
		FontFace = palette.Font,
		TextColor3 = light(palette.Text, -0.22),
		TextSize = 18,
		AutoButtonColor = false,
		ZIndex = 8
	})

	-- Sidebar
	local rail = new('Frame', window, {
		BackgroundColor3 = light(palette.Main, -0.01),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(0, 132, 1, -42),
		ZIndex = 4
	})

	new('Frame', rail, {
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = light(palette.Main, 0.08),
		BackgroundTransparency = 0.58,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 1, 1, 0),
		ZIndex = 5
	})

	new('TextLabel', rail, {
		BackgroundTransparency = 1,
		FontFace = palette.FontSemiBold,
		Position = UDim2.fromOffset(14, 12),
		Size = UDim2.fromOffset(95, 18),
		Text = 'STARTUP',
		TextColor3 = light(palette.Text, -0.27),
		TextSize = 9,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 6
	})

	local stages = {
		{'Interface', 'GUI'},
		{'Universal', 'CORE'},
		{'Game', 'PLACE'},
		{'Profile', 'CONFIG'}
	}

	local stageRows = {}

	for index, data in ipairs(stages) do
		local row = new('Frame', rail, {
			BackgroundColor3 = palette.Main,
			BackgroundTransparency = index == 1 and 0.73 or 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(8, 37 + (index - 1) * 35),
			Size = UDim2.fromOffset(116, 29),
			ZIndex = 6
		})
		corner(row, UDim.new(0, 4))

		local indicator = new('Frame', row, {
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = accent,
			BackgroundTransparency = index == 1 and 0 or 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, 14.5),
			Size = UDim2.fromOffset(2, 13),
			ZIndex = 7
		})
		corner(indicator, UDim.new(1, 0))

		local label = new('TextLabel', row, {
			BackgroundTransparency = 1,
			FontFace = palette.Font,
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(1, -16, 1, 0),
			Text = data[1],
			TextColor3 = index == 1 and palette.Text or light(palette.Text, -0.2),
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 7
		})

		stageRows[index] = {
			Row = row,
			Indicator = indicator,
			Label = label
		}
	end

	-- Content
	local content = new('Frame', window, {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(132, 42),
		Size = UDim2.new(1, -132, 1, -42),
		ZIndex = 5
	})

	local accentBar = new('Frame', content, {
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(18, 23),
		Size = UDim2.fromOffset(2, 48),
		ZIndex = 7
	})
	corner(accentBar, UDim.new(1, 0))

	local title = new('TextLabel', content, {
		BackgroundTransparency = 1,
		FontFace = palette.FontSemiBold,
		Position = UDim2.fromOffset(31, 18),
		Size = UDim2.fromOffset(290, 25),
		Text = 'Loading Vape',
		TextColor3 = palette.Text,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 7
	})

	local status = new('TextLabel', content, {
		BackgroundTransparency = 1,
		FontFace = palette.Font,
		Position = UDim2.fromOffset(31, 44),
		Size = UDim2.fromOffset(320, 36),
		Text = 'Preparing game modules',
		TextColor3 = light(palette.Text, -0.18),
		TextSize = 11,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 7
	})

	local detail = new('TextLabel', content, {
		BackgroundTransparency = 1,
		FontFace = palette.Font,
		Position = UDim2.fromOffset(18, 112),
		Size = UDim2.fromOffset(305, 18),
		Text = 'Initializing interface...',
		TextColor3 = light(palette.Text, -0.26),
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 7
	})

	local progressTrack = new('Frame', content, {
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = light(palette.Main, 0.08),
		BackgroundTransparency = 0.32,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 18, 1, -18),
		Size = UDim2.fromOffset(350, 3),
		ZIndex = 7
	})
	corner(progressTrack, UDim.new(1, 0))

	local progress = new('Frame', progressTrack, {
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		ZIndex = 8
	})
	corner(progress, UDim.new(1, 0))

	local percent = new('TextLabel', content, {
		AnchorPoint = Vector2.new(1, 1),
		BackgroundTransparency = 1,
		FontFace = palette.Font,
		Position = UDim2.new(1, -18, 1, -24),
		Size = UDim2.fromOffset(45, 16),
		Text = '0%',
		TextColor3 = light(palette.Text, -0.28),
		TextSize = 9,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 7
	})

	local uiScale = new('UIScale', window, {Scale = 1})
	local function fit()
		local viewport = root.AbsoluteSize
		uiScale.Scale = math.clamp(
			math.min(viewport.X / 680, viewport.Y / 380),
			0.68,
			1
		)
	end
	fit()

	local state = {
		Screen = screen,
		Root = root,
		Window = window,
		WindowScale = windowScale,
		Started = os.clock(),
		Alive = true,
		Closing = false,
		Tweens = {},
		Ambient = ambient,
		TopoBack = topoBack,
		TopoFront = topoFront,
		Version = version,
		ChipDot = chipDot,
		ChipText = chipText,
		AccentBar = accentBar,
		Progress = progress,
		Percent = percent,
		Detail = detail,
		StageRows = stageRows
	}

	self._loading = state
	self.LoadingScreen = screen
	self.LoadingPanel = window
	self.LoadingStatus = status
	self.LoadingStarted = state.Started
	self.LoadingDismissPending = nil

	state.Resize = root:GetPropertyChangedSignal('AbsoluteSize'):Connect(fit)

	local function animate(object, duration, props, style, direction)
		local m = tween(object, duration, props, style, direction)
		table.insert(state.Tweens, m)
		return m
	end

	animate(window, 0.34, {
		GroupTransparency = 0,
		Position = UDim2.fromScale(0.5, 0.5)
	}, Enum.EasingStyle.Quart)

	animate(windowScale, 0.42, {
		Scale = 1
	}, Enum.EasingStyle.Back)

	local pulse = TweenService:Create(
		chipDot,
		TweenInfo.new(0.85, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{BackgroundTransparency = 0.62}
	)
	pulse:Play()
	state.Pulse = pulse

	close.MouseEnter:Connect(function()
		tween(close, 0.13, {TextColor3 = accent})
	end)

	close.MouseLeave:Connect(function()
		tween(close, 0.13, {TextColor3 = light(palette.Text, -0.22)})
	end)

	close.Activated:Connect(function()
		self:HideLoadingScreen(true)
	end)

	state.Connection = RunService.RenderStepped:Connect(function(dt)
		if state.Closing then return end

		if theme then
			local ok = pcall(function()
				theme:Update(dt)
				accent = theme:GetColor(0.125)
			end)
			if not ok then
				theme = nil
			end
		end

		local now = os.clock()
		local elapsed = now - state.Started
		local ratio = math.clamp(elapsed / self.MinimumDisplayTime, 0, 1)

		-- Image-based topography animation only.
		ambient.Position = UDim2.fromScale(
			0.72 + math.sin(elapsed * 0.18) * 0.018,
			0.53 + math.cos(elapsed * 0.15) * 0.016
		)
		ambient.Rotation = -6 + math.sin(elapsed * 0.11) * 2
		ambient.Size = UDim2.fromScale(
			1.15 + math.sin(elapsed * 0.13) * 0.025,
			1.15 + math.sin(elapsed * 0.13) * 0.025
		)

		topoBack.Position = UDim2.fromScale(
			0.68 + math.sin(elapsed * 0.31) * 0.035,
			0.50 + math.cos(elapsed * 0.27) * 0.03
		)
		topoBack.Rotation = -4 + math.sin(elapsed * 0.17) * 3
		topoBack.Size = UDim2.fromScale(
			1.28 + math.sin(elapsed * 0.21) * 0.055,
			1.28 + math.sin(elapsed * 0.21) * 0.055
		)

		topoFront.Position = UDim2.fromScale(
			0.76 + math.cos(elapsed * 0.39) * 0.045,
			0.48 + math.sin(elapsed * 0.33) * 0.035
		)
		topoFront.Rotation = 5 + math.cos(elapsed * 0.16) * 4
		topoFront.Size = UDim2.fromScale(
			0.88 + math.cos(elapsed * 0.24) * 0.04,
			0.88 + math.cos(elapsed * 0.24) * 0.04
		)

		ambient.ImageColor3 = accent
		topoBack.ImageColor3 = accent
		topoFront.ImageColor3 = accent
		state.Version.ImageColor3 = accent
		state.ChipDot.BackgroundColor3 = accent
		state.AccentBar.BackgroundColor3 = accent
		state.Progress.BackgroundColor3 = accent

		state.Progress.Size = UDim2.fromScale(ratio, 1)
		state.Percent.Text = tostring(math.floor(ratio * 100 + 0.5))..'%'

		local stageIndex = math.clamp(math.floor(ratio * #state.StageRows) + 1, 1, #state.StageRows)
		local stageNames = {
			'Initializing interface...',
			'Loading universal modules...',
			'Loading game modules...',
			'Applying profile...'
		}
		state.Detail.Text = ratio >= 0.995 and 'Ready.' or stageNames[stageIndex]

		for index, row in ipairs(state.StageRows) do
			local complete = index < stageIndex or ratio >= 0.995
			local active = index == stageIndex and not complete

			if complete then
				row.Indicator.BackgroundTransparency = 0
				row.Indicator.BackgroundColor3 = accent
				row.Row.BackgroundTransparency = 0.84
				row.Label.TextColor3 = palette.Text
			elseif active then
				local wave = (math.sin(elapsed * 6) + 1) * 0.5
				row.Indicator.BackgroundTransparency = 0.18 + wave * 0.45
				row.Indicator.BackgroundColor3 = accent
				row.Row.BackgroundTransparency = 0.76
				row.Label.TextColor3 = palette.Text
			else
				row.Indicator.BackgroundTransparency = 1
				row.Row.BackgroundTransparency = 1
				row.Label.TextColor3 = light(palette.Text, -0.2)
			end
		end

		state.ChipText.Text = ratio >= 0.995 and 'READY' or 'LOADING'
	end)

	screen.Destroying:Once(function()
		state.Alive = false

		if state.Connection then
			state.Connection:Disconnect()
		end
		if state.Resize then
			state.Resize:Disconnect()
		end

		if state.Pulse then
			state.Pulse:Cancel()
		end

		for _, m in ipairs(state.Tweens) do
			m:Cancel()
		end

		if self._loading == state then
			self._loading = nil
			self.LoadingScreen = nil
			self.LoadingPanel = nil
			self.LoadingStatus = nil
			self.LoadingDismissPending = nil
		end
	end)

	RunService.RenderStepped:Wait()
end

function vape:WaitForMinimumDisplay()
	local state = self._loading
	while state
		and self._loading == state
		and not state.Closing
		and os.clock() - state.Started < self.MinimumDisplayTime do
		task.wait(0.05)
	end
end

function vape:HideLoadingScreen(immediate)
	local state = self._loading
	if not state or state.Closing then return end

	local remaining = self.MinimumDisplayTime - (os.clock() - state.Started)
	if not immediate and remaining > 0 then
		if not state.Pending then
			state.Pending = true
			self.LoadingDismissPending = true

			task.delay(remaining, function()
				if self._loading == state then
					self:HideLoadingScreen(true)
				end
			end)
		end
		return
	end

	state.Closing = true

	if state.Connection then
		state.Connection:Disconnect()
		state.Connection = nil
	end

	if state.Pulse then
		state.Pulse:Cancel()
	end

	for _, m in ipairs(state.Tweens) do
		m:Cancel()
	end

	state.Tweens = {
		tween(state.WindowScale, 0.22, {
			Scale = 0.975
		}, Enum.EasingStyle.Quart, Enum.EasingDirection.In),

		tween(state.Window, 0.24, {
			GroupTransparency = 1,
			Position = UDim2.new(0.5, 0, 0.5, -9)
		}, Enum.EasingStyle.Quart, Enum.EasingDirection.In),

		tween(state.Root, 0.3, {
			GroupTransparency = 1,
			BackgroundTransparency = 1
		}, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
	}

	task.delay(0.31, function()
		if state.Screen and state.Screen.Parent then
			state.Screen:Destroy()
		end
	end)
end

vape:ShowLoadingScreen()
return vape
