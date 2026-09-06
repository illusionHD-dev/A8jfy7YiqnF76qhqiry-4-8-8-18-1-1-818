-- illusionHD / Vape startup overlay
-- Compact GUI-matched boot window with fully procedural animated contour topography.
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local TweenService = game:GetService('TweenService')
local HttpService = game:GetService('HttpService')

local playerGui = Players.LocalPlayer:WaitForChild('PlayerGui')
local previous = playerGui:FindFirstChild('VapeLoadingScreen')
if previous then previous:Destroy() end

local vape = {
	MinimumDisplayTime = 2.2
}

local palette = {
	Main = Color3.fromRGB(26, 25, 26),
	Text = Color3.fromRGB(200, 200, 200),
	Font = Font.fromEnum(Enum.Font.Arial),
	FontSemiBold = Font.fromEnum(Enum.Font.Arial, Enum.FontWeight.SemiBold)
}

local accent = Color3.fromRGB(103, 235, 193)
local theme

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
		CornerRadius = radius or UDim.new(0, 5)
	})
end

local function motion(object, duration, props, style, direction)
	local tween = TweenService:Create(
		object,
		TweenInfo.new(
			duration,
			style or Enum.EasingStyle.Quint,
			direction or Enum.EasingDirection.Out
		),
		props
	)
	tween:Play()
	return tween
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

local function shade(col, amount)
	local h, s, v = col:ToHSV()
	return Color3.fromHSV(h, s, math.clamp(v + amount, 0, 1))
end

-- Load the same saved palette/font the main GUI uses.
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

-- Match the saved GUI accent/theme before the GUI itself loads.
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

local function setLine(frame, a, b, thickness)
	local delta = b - a
	local length = math.max(delta.Magnitude, 0.5)
	frame.Position = UDim2.fromOffset(a.X, a.Y)
	frame.Size = UDim2.fromOffset(length, thickness)
	frame.Rotation = math.deg(math.atan2(delta.Y, delta.X))
end

-- Real procedural contour map: each line is geometry, not an image.
local function createTopology(parent, config)
	config = config or {}

	local holder = new('Frame', parent, {
		Name = 'LiveTopology',
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Size = UDim2.fromScale(1, 1),
		ZIndex = config.ZIndex or 1
	})

	if config.Round then
		corner(holder, config.Round)
	end

	local topology = {
		Holder = holder,
		Seed = math.random() * 256,
		Contours = {},
		Color = accent,
		Transparency = config.Transparency or 0.9,
		Speed = config.Speed or 1,
		Strength = config.Strength or 1,
		Offset = config.Offset or Vector2.new(0.66, 0.52),
		Thickness = config.Thickness or 1
	}

	local contourCount = config.Contours or 7
	local points = config.Points or 24

	for ring = 1, contourCount do
		local contour = {
			Ring = ring,
			Segments = {},
			Points = points
		}

		for point = 1, points do
			local segment = new('Frame', holder, {
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = accent,
				BackgroundTransparency = topology.Transparency,
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(1, topology.Thickness),
				ZIndex = holder.ZIndex
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
	if size.X < 10 or size.Y < 10 then return end

	local short = math.min(size.X, size.Y)
	local t = now * topology.Speed
	local driftX = math.noise(topology.Seed, t * 0.055, 2) * size.X * 0.11
	local driftY = math.noise(4, topology.Seed, t * 0.05) * size.Y * 0.12

	for _, contour in ipairs(topology.Contours) do
		local ring = contour.Ring
		local count = contour.Points
		local phase = ring * 0.73

		-- Two nearby moving terrain "peaks" pull the rings asymmetrically.
		local center = Vector2.new(
			size.X * topology.Offset.X + driftX + math.sin(t * 0.12 + phase) * size.X * 0.018,
			size.Y * topology.Offset.Y + driftY + math.cos(t * 0.10 + phase) * size.Y * 0.024
		)

		local radius = short * (0.10 + ring * 0.062)
		local generated = table.create(count)

		for point = 1, count do
			local angle = ((point - 1) / count) * math.pi * 2
			local nx = math.cos(angle)
			local ny = math.sin(angle)

			local broad = math.noise(
				nx * 0.72 + topology.Seed,
				ny * 0.72 + ring * 0.22,
				t * 0.055
			)

			local detail = math.noise(
				nx * 2.1 - topology.Seed * 0.14,
				ny * 2.1 + ring * 0.41,
				t * 0.095 + 8
			)

			local pinch = math.sin(angle * 3 + t * 0.22 + phase) * 0.035
			local breathe = math.sin(t * 0.42 + phase) * 0.032
			local warpedRadius = radius * (
				1
				+ broad * 0.24 * topology.Strength
				+ detail * 0.09 * topology.Strength
				+ pinch
				+ breathe
			)

			local shearX = math.noise(
				ring * 0.31,
				angle + topology.Seed,
				t * 0.082
			) * short * 0.055 * topology.Strength

			local shearY = math.noise(
				angle - topology.Seed,
				ring * 0.36,
				t * 0.074
			) * short * 0.065 * topology.Strength

			local squash = 0.56 + math.sin(t * 0.17 + ring * 0.4) * 0.05

			generated[point] = center + Vector2.new(
				nx * warpedRadius + shearX,
				ny * warpedRadius * squash + shearY
			)
		end

		for point, segment in ipairs(contour.Segments) do
			local nextPoint = point == count and 1 or point + 1
			local wave = (math.sin(t * 0.9 + ring * 0.65 + point * 0.15) + 1) * 0.5

			segment.BackgroundColor3 = topology.Color
			segment.BackgroundTransparency = math.clamp(
				topology.Transparency + ring * 0.006 + wave * 0.025,
				0,
				1
			)

			setLine(
				segment,
				generated[point],
				generated[nextPoint],
				topology.Thickness
			)
		end
	end
end

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
		BackgroundTransparency = 0.42,
		GroupTransparency = 0,
		ClipsDescendants = true
	})

	-- Very faint full-screen contours give depth without taking over the screen.
	local backgroundTopology = createTopology(root, {
		Contours = 6,
		Points = 22,
		Transparency = 0.985,
		Speed = 0.72,
		Strength = 1.25,
		Offset = Vector2.new(0.72, 0.48),
		Thickness = 1,
		ZIndex = 0
	})

	local blocker = new('TextButton', root, {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = '',
		Modal = true,
		AutoButtonColor = false,
		ZIndex = 0
	})

	local window = new('CanvasGroup', root, {
		Name = 'BootWindow',
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 18),
		Size = UDim2.fromOffset(548, 248),
		BackgroundColor3 = palette.Main,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		ClipsDescendants = true,
		ZIndex = 2
	})
	corner(window, UDim.new(0, 6))

	local windowScale = new('UIScale', window, {
		Scale = 1
	})

	new('UIStroke', window, {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = shade(palette.Main, 0.11),
		Transparency = 0.35,
		Thickness = 1
	})

	-- Header ---------------------------------------------------------------
	local header = new('Frame', window, {
		BackgroundColor3 = shade(palette.Main, 0.012),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 42),
		ZIndex = 5
	})

	local logo = new('ImageLabel', header, {
		BackgroundTransparency = 1,
		Image = asset('newvape/assets/new/vapelogomini.png', '109041903452149'),
		ImageColor3 = palette.Text,
		Position = UDim2.fromOffset(15, 13),
		Size = UDim2.fromOffset(52, 15),
		ZIndex = 6
	})

	local version = new('ImageLabel', header, {
		BackgroundTransparency = 1,
		Image = asset('newvape/assets/new/v4mini.png', '115213099001611'),
		ImageColor3 = accent,
		Position = UDim2.fromOffset(71, 13),
		Size = UDim2.fromOffset(21, 15),
		ZIndex = 6
	})

	local headerDivider = new('Frame', header, {
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = shade(palette.Main, 0.11),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(109, 21),
		Size = UDim2.fromOffset(1, 16),
		ZIndex = 6
	})

	new('TextLabel', header, {
		BackgroundTransparency = 1,
		FontFace = palette.Font,
		Position = UDim2.fromOffset(121, 0),
		Size = UDim2.fromOffset(175, 42),
		Text = 'Starting interface',
		TextColor3 = shade(palette.Text, -0.1),
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 6
	})

	local bootChip = new('Frame', header, {
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = shade(palette.Main, 0.035),
		Position = UDim2.new(1, -47, 0.5, 0),
		Size = UDim2.fromOffset(67, 22),
		ZIndex = 6
	})
	corner(bootChip, UDim.new(0, 4))

	local bootDot = new('Frame', bootChip, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(10, 11),
		Size = UDim2.fromOffset(5, 5),
		ZIndex = 7
	})
	corner(bootDot, UDim.new(1, 0))
	local bootDotScale = new('UIScale', bootDot, {Scale = 1})

	local bootText = new('TextLabel', bootChip, {
		BackgroundTransparency = 1,
		FontFace = palette.FontSemiBold,
		Position = UDim2.fromOffset(18, 0),
		Size = UDim2.new(1, -19, 1, 0),
		Text = 'BOOT',
		TextColor3 = shade(palette.Text, -0.08),
		TextSize = 9,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 7
	})

	local close = new('TextButton', header, {
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(22, 22),
		Text = '×',
		FontFace = palette.Font,
		TextColor3 = shade(palette.Text, -0.22),
		TextSize = 18,
		AutoButtonColor = false,
		ZIndex = 7
	})

	new('Frame', header, {
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = shade(palette.Main, 0.09),
		BackgroundTransparency = 0.62,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 1),
		ZIndex = 6
	})

	-- Tiny category rail ---------------------------------------------------
	local rail = new('Frame', window, {
		BackgroundColor3 = shade(palette.Main, -0.014),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(0, 126, 1, -42),
		ZIndex = 3
	})

	new('Frame', rail, {
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = shade(palette.Main, 0.09),
		BackgroundTransparency = 0.58,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 1, 1, 0),
		ZIndex = 4
	})

	new('TextLabel', rail, {
		BackgroundTransparency = 1,
		FontFace = palette.FontSemiBold,
		Position = UDim2.fromOffset(14, 12),
		Size = UDim2.fromOffset(90, 18),
		Text = 'CLIENT',
		TextColor3 = shade(palette.Text, -0.27),
		TextSize = 9,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 5
	})

	local railEntries = {
		{'Combat', 'rbxassetid://94762732349053'},
		{'Blatant', 'rbxassetid://126929923309265'},
		{'Render', 'rbxassetid://125472576898654'},
		{'Utility', 'rbxassetid://108303206513893'}
	}

	local railRows = {}
	for index, entry in ipairs(railEntries) do
		local row = new('Frame', rail, {
			BackgroundColor3 = palette.Main,
			BackgroundTransparency = index == 1 and 0.72 or 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(8, 36 + (index - 1) * 35),
			Size = UDim2.fromOffset(110, 29),
			ZIndex = 5
		})
		corner(row, UDim.new(0, 4))

		local indicator = new('Frame', row, {
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = accent,
			BackgroundTransparency = index == 1 and 0 or 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, 14.5),
			Size = UDim2.fromOffset(2, 13),
			ZIndex = 6
		})
		corner(indicator, UDim.new(1, 0))

		local icon = new('ImageLabel', row, {
			BackgroundTransparency = 1,
			Image = entry[2],
			ImageColor3 = index == 1 and palette.Text or shade(palette.Text, -0.22),
			ImageTransparency = index == 1 and 0 or 0.18,
			Position = UDim2.fromOffset(10, 8),
			Size = UDim2.fromOffset(13, 13),
			ZIndex = 6
		})

		local label = new('TextLabel', row, {
			BackgroundTransparency = 1,
			FontFace = palette.Font,
			Position = UDim2.fromOffset(31, 0),
			Size = UDim2.new(1, -34, 1, 0),
			Text = entry[1],
			TextColor3 = index == 1 and palette.Text or shade(palette.Text, -0.2),
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 6
		})

		railRows[index] = {
			Row = row,
			Indicator = indicator,
			Icon = icon,
			Label = label
		}
	end

	-- Main boot area -------------------------------------------------------
	local content = new('Frame', window, {
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(126, 42),
		Size = UDim2.new(1, -126, 1, -42),
		ZIndex = 3
	})

	local contentTopology = createTopology(content, {
		Contours = 8,
		Points = 28,
		Transparency = 0.955,
		Speed = 1,
		Strength = 1.4,
		Offset = Vector2.new(0.80, 0.47),
		Thickness = 1,
		ZIndex = 3
	})

	local glow = new('Frame', content, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = accent,
		BackgroundTransparency = 0.965,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.82, 0.48),
		Size = UDim2.fromOffset(230, 230),
		ZIndex = 3
	})
	corner(glow, UDim.new(1, 0))

	local accentBar = new('Frame', content, {
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(18, 22),
		Size = UDim2.fromOffset(2, 50),
		ZIndex = 5
	})
	corner(accentBar, UDim.new(1, 0))

	local title = new('TextLabel', content, {
		BackgroundTransparency = 1,
		FontFace = palette.FontSemiBold,
		Position = UDim2.fromOffset(31, 18),
		Size = UDim2.fromOffset(260, 24),
		Text = 'Loading Vape',
		TextColor3 = palette.Text,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 5
	})

	local status = new('TextLabel', content, {
		BackgroundTransparency = 1,
		FontFace = palette.Font,
		Position = UDim2.fromOffset(31, 43),
		Size = UDim2.fromOffset(310, 36),
		Text = 'Preparing game modules',
		TextColor3 = shade(palette.Text, -0.18),
		TextSize = 11,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 5
	})

	local moduleHolder = new('Frame', content, {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(18, 92),
		Size = UDim2.fromOffset(374, 78),
		ZIndex = 5
	})

	local fakeModules = {
		{'Interface', 'GUI'},
		{'Universal', 'CORE'},
		{'Game modules', 'PLACE'}
	}

	local moduleRows = {}
	for index, data in ipairs(fakeModules) do
		local row = new('CanvasGroup', moduleHolder, {
			BackgroundColor3 = shade(palette.Main, 0.018),
			BackgroundTransparency = 0.12,
			BorderSizePixel = 0,
			GroupTransparency = 1,
			Position = UDim2.fromOffset(0, (index - 1) * 25 + 5),
			Size = UDim2.fromOffset(346, 21),
			ZIndex = 5
		})
		corner(row, UDim.new(0, 4))

		local dot = new('Frame', row, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = shade(palette.Text, -0.33),
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(11, 10.5),
			Size = UDim2.fromOffset(4, 4),
			ZIndex = 6
		})
		corner(dot, UDim.new(1, 0))

		new('TextLabel', row, {
			BackgroundTransparency = 1,
			FontFace = palette.Font,
			Position = UDim2.fromOffset(21, 0),
			Size = UDim2.fromOffset(190, 21),
			Text = data[1],
			TextColor3 = shade(palette.Text, -0.08),
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 6
		})

		local tag = new('TextLabel', row, {
			AnchorPoint = Vector2.new(1, 0),
			BackgroundTransparency = 1,
			FontFace = palette.FontSemiBold,
			Position = UDim2.new(1, -8, 0, 0),
			Size = UDim2.fromOffset(54, 21),
			Text = data[2],
			TextColor3 = shade(palette.Text, -0.32),
			TextSize = 8,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 6
		})

		moduleRows[index] = {
			Row = row,
			Dot = dot,
			Tag = tag
		}
	end

	local progressTrack = new('Frame', content, {
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = shade(palette.Main, 0.09),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 18, 1, -17),
		Size = UDim2.fromOffset(374, 2),
		ZIndex = 5
	})
	corner(progressTrack, UDim.new(1, 0))

	local progress = new('Frame', progressTrack, {
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		ZIndex = 6
	})
	corner(progress, UDim.new(1, 0))

	local percent = new('TextLabel', content, {
		AnchorPoint = Vector2.new(1, 1),
		BackgroundTransparency = 1,
		FontFace = palette.Font,
		Position = UDim2.new(1, -18, 1, -21),
		Size = UDim2.fromOffset(40, 16),
		Text = '0%',
		TextColor3 = shade(palette.Text, -0.28),
		TextSize = 9,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 5
	})

	-- Responsive size for smaller resolutions. The same UIScale is also used
	-- by the entrance animation so there are no stacked scale modifiers.
	local fitScale = 1
	local entered = false
	local function fit()
		local viewport = root.AbsoluteSize
		fitScale = math.clamp(
			math.min(viewport.X / 680, viewport.Y / 380),
			0.68,
			1
		)
		if entered then
			windowScale.Scale = fitScale
		else
			windowScale.Scale = fitScale * 0.955
		end
	end
	fit()

	local state = {
		Screen = screen,
		Root = root,
		Window = window,
		WindowScale = windowScale,
		Started = os.clock(),
		Alive = true,
		Tweens = {},
		Topologies = {backgroundTopology, contentTopology},
		TopologyAccumulator = 0,
		Close = close,
		Progress = progress,
		Percent = percent,
		BootDot = bootDot,
		BootText = bootText,
		ModuleRows = moduleRows,
		RailRows = railRows
	}

	self._loading = state
	self.LoadingScreen = screen
	self.LoadingPanel = window
	self.LoadingStatus = status
	self.LoadingStarted = state.Started
	self.LoadingDismissPending = nil

	state.Resize = root:GetPropertyChangedSignal('AbsoluteSize'):Connect(fit)

	local pulseScale = TweenService:Create(
		bootDotScale,
		TweenInfo.new(1.05, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{Scale = 1.55}
	)
	local pulseFade = TweenService:Create(
		bootDot,
		TweenInfo.new(1.05, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{BackgroundTransparency = 0.58}
	)
	pulseScale:Play()
	pulseFade:Play()
	state.PulseScale = pulseScale
	state.PulseFade = pulseFade

	local function animate(object, duration, props, style, direction)
		local tween = motion(object, duration, props, style, direction)
		table.insert(state.Tweens, tween)
		return tween
	end

	-- Entrance feels like the real GUI opening, not a splash screen.
	animate(window, 0.32, {
		GroupTransparency = 0,
		Position = UDim2.fromScale(0.5, 0.5)
	}, Enum.EasingStyle.Quart)

	animate(windowScale, 0.42, {
		Scale = fitScale
	}, Enum.EasingStyle.Back)
	task.delay(0.43, function()
		if state.Alive and not state.Closing then
			entered = true
			windowScale.Scale = fitScale
		end
	end)

	for index, module in ipairs(moduleRows) do
		task.delay(0.10 + index * 0.09, function()
			if state.Alive and not state.Closing then
				animate(module.Row, 0.24, {
					GroupTransparency = 0,
					Position = UDim2.fromOffset(0, (index - 1) * 25)
				}, Enum.EasingStyle.Quart)
			end
		end)
	end

	local hoverTween
	close.MouseEnter:Connect(function()
		if hoverTween then hoverTween:Cancel() end
		hoverTween = motion(close, 0.13, {
			TextColor3 = accent
		}, Enum.EasingStyle.Quart)
	end)

	close.MouseLeave:Connect(function()
		if hoverTween then hoverTween:Cancel() end
		hoverTween = motion(close, 0.13, {
			TextColor3 = shade(palette.Text, -0.22)
		}, Enum.EasingStyle.Quart)
	end)

	close.Activated:Connect(function()
		self:HideLoadingScreen(true)
	end)

	state.Connection = RunService.RenderStepped:Connect(function(dt)
		if not state.Alive or state.Closing then return end

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

		state.TopologyAccumulator += dt
		if state.TopologyAccumulator >= 1 / 30 then
			state.TopologyAccumulator = 0

			for _, topology in ipairs(state.Topologies) do
				topology.Color = accent
				updateTopology(topology, now)
			end
		end

		version.ImageColor3 = accent
		bootDot.BackgroundColor3 = accent
		accentBar.BackgroundColor3 = accent
		progress.BackgroundColor3 = accent
		glow.BackgroundColor3 = accent

		progress.Size = UDim2.fromScale(ratio, 1)
		percent.Text = tostring(math.floor(ratio * 100 + 0.5))..'%'

		local phase = math.clamp(math.floor(ratio * #moduleRows) + 1, 1, #moduleRows)

		for index, module in ipairs(moduleRows) do
			local complete = index < phase or ratio >= 0.995
			local active = index == phase and not complete

			if complete then
				module.Dot.BackgroundColor3 = accent
				module.Dot.BackgroundTransparency = 0
				module.Tag.TextColor3 = shade(palette.Text, -0.22)
			elseif active then
				local blink = (math.sin(elapsed * 6) + 1) * 0.5
				module.Dot.BackgroundColor3 = accent
				module.Dot.BackgroundTransparency = 0.18 + blink * 0.52
				module.Tag.TextColor3 = accent:Lerp(shade(palette.Text, -0.1), blink * 0.42)
			else
				module.Dot.BackgroundColor3 = shade(palette.Text, -0.33)
				module.Dot.BackgroundTransparency = 0.15
				module.Tag.TextColor3 = shade(palette.Text, -0.32)
			end
		end

		-- Category rail wakes up sequentially like the GUI is being populated.
		local railProgress = ratio * #railRows
		for index, row in ipairs(railRows) do
			local awake = railProgress >= index - 0.3
			if awake then
				row.Icon.ImageColor3 = index == 1 and palette.Text or shade(palette.Text, -0.12)
				row.Label.TextColor3 = index == 1 and palette.Text or shade(palette.Text, -0.12)
			end
			row.Indicator.BackgroundColor3 = accent
		end

		if ratio >= 0.995 then
			bootText.Text = 'READY'
		else
			bootText.Text = 'BOOT'
		end
	end)

	screen.Destroying:Once(function()
		state.Alive = false

		if state.Connection then
			state.Connection:Disconnect()
		end
		if state.Resize then
			state.Resize:Disconnect()
		end

		pulseScale:Cancel()
		pulseFade:Cancel()

		for _, tween in ipairs(state.Tweens) do
			tween:Cancel()
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

	state.PulseScale:Cancel()
	state.PulseFade:Cancel()

	for _, tween in ipairs(state.Tweens) do
		tween:Cancel()
	end

	-- Collapse toward the window header instead of generic fade-to-black.
	state.Tweens = {
		motion(state.WindowScale, 0.24, {
			Scale = fitScale * 0.975
		}, Enum.EasingStyle.Quart, Enum.EasingDirection.In),

		motion(state.Window, 0.24, {
			GroupTransparency = 1,
			Position = UDim2.new(0.5, 0, 0.5, -9)
		}, Enum.EasingStyle.Quart, Enum.EasingDirection.In),

		motion(state.Root, 0.30, {
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
