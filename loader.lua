-- Robust GitHub bootstrap for illusionHD.
-- Syncs the repository from the real main branch and repairs known bad cached files.

local httpService = game:GetService('HttpService')

local OWNER = 'illusionhd-dev'
local REPO = 'A8jfy7YiqnF76qhqiry-4-8-8-18-1-1-818'
local BRANCH = 'main'
local RAW = 'https://raw.githubusercontent.com/'..OWNER..'/'..REPO..'/'..BRANCH..'/'
local API_TREE = 'https://api.github.com/repos/'..OWNER..'/'..REPO..'/git/trees/'..BRANCH..'?recursive=1'

local isfile = isfile or function(path)
	local ok, value = pcall(readfile, path)
	return ok and value ~= nil and value ~= ''
end

local function ensureFolder(path)
	local current = ''
	for piece in path:gmatch('[^/]+') do
		current = current == '' and piece or (current..'/'..piece)
		if not isfolder(current) then
			pcall(makefolder, current)
		end
	end
end

local function ensureParent(path)
	local parent = path:match('^(.*)/[^/]+$')
	if parent and parent ~= '' then
		ensureFolder(parent)
	end
end

for _, folder in {'newvape', 'newvape/games', 'newvape/profiles', 'newvape/assets', 'newvape/libraries', 'newvape/guis'} do
	ensureFolder(folder)
end

local function invalidDownload(data, path)
	if type(data) ~= 'string' or data == '' then return true end
	local head = data:sub(1, 512):lower()
	if head:find('404: not found', 1, true)
		or head:find('<!doctype html', 1, true)
		or head:find('<html', 1, true)
		or head:find('<svg', 1, true)
		or head:find('repository not found', 1, true) then
		return true
	end
	if path and path:match('%.lua$') and head:match('^%s*<') then
		return true
	end
	return false
end

local function httpGet(url, path)
	local ok, body = pcall(function()
		return game:HttpGet(url, true)
	end)
	if ok and not invalidDownload(body, path) then
		return body
	end
	return nil
end

-- This fork's commit.txt contains a stale hash from another history.
-- Runtime downloads intentionally track this repository's main branch.
writefile('newvape/profiles/commit.txt', BRANCH)
writefile('newvape/profiles/asset.txt', '1')

local function getRemote(remotePath)
	return httpGet(RAW..remotePath, remotePath)
end

local function repairFrontlines(data)
	if type(data) ~= 'string' then return data end
	data = data:gsub('%-%-%[%[run%(function%(%)', 'run(function()', 1)
	data = data:gsub('\tend%)\nend%)%]%]\nif vape%.Loaded == nil then return end',
		'\tend)\nend)\nif vape.Loaded == nil then return end', 1)
	return data
end


local function applyHitEffectsPatch(data)
	if type(data) ~= 'string' then return data end

	local startMarker = '-- ILLUSIONHD_HITEFFECTS_V1'
	local endMarker = '-- ILLUSIONHD_HITEFFECTS_END'
	local startPos = data:find(startMarker, 1, true)
	if startPos then
		local endPos = data:find(endMarker, startPos, true)
		if endPos then
			endPos += #endMarker
			data = data:sub(1, startPos - 1)..data:sub(endPos)
		end
	end

	local marker = '\nrun(function()\n\tlocal KillEffects'
	local insertPos = data:find(marker, 1, true)
	if not insertPos then
		return data
	end

	local patch = [====[
-- ILLUSIONHD_HITEFFECTS_V1
run(function()
	local HitEffects
	local Mode
	local ColorMode
	local PrimaryColor
	local SecondaryColor
	local EffectSize
	local Lifetime
	local Quality
	local HeadshotsOnly
	local ConfirmedHits

	local Folder = Instance.new('Folder')
	Folder.Name = 'IllusionHDHitEffects'
	Folder.Parent = workspace

	local pending = {}
	local healthCache = {}

	local modes = {
		'Sparks', 'Burst', 'Pulse', 'Ring', 'Slash', 'Cross', 'Lightning',
		'Stars', 'Hearts', 'Crit', 'Smoke', 'Shards', 'Pixels', 'Spiral',
		'Orbit', 'Bubble', 'Shockwave', 'Rainbow', 'Headshot', 'Random'
	}

	local randomModes = {
		'Sparks', 'Burst', 'Pulse', 'Ring', 'Slash', 'Cross', 'Lightning',
		'Stars', 'Hearts', 'Crit', 'Smoke', 'Shards', 'Pixels', 'Spiral',
		'Orbit', 'Bubble', 'Shockwave', 'Rainbow'
	}

	local function amount(base)
		local mul = Quality.Value == 'Low' and 0.85 or Quality.Value == 'High' and 2.35 or 1.45
		return math.max(1, math.floor(base * mul + 0.5))
	end

	local function getColors(ent)
		if ColorMode.Value == 'Target' and ent then
			local c = entitylib.getEntityColor(ent)
			if c then
				return c, c:Lerp(Color3.new(1, 1, 1), 0.55)
			end
		elseif ColorMode.Value == 'Rainbow' then
			local hue = (tick() * 0.2) % 1
			return Color3.fromHSV(hue, 0.85, 1), Color3.fromHSV((hue + 0.5) % 1, 0.85, 1)
		end

		return Color3.fromHSV(PrimaryColor.Hue, PrimaryColor.Sat, PrimaryColor.Value),
			Color3.fromHSV(SecondaryColor.Hue, SecondaryColor.Sat, SecondaryColor.Value)
	end

	local function cleanup(obj, life)
		debrisService:AddItem(obj, math.max(life or Lifetime.Value, 0.05) + 0.15)
		return obj
	end

	local function makePart(size, cf, color, transparency, material, shape)
		local obj = Instance.new('Part')
		obj.Size = size
		obj.CFrame = cf
		obj.Anchored = true
		obj.CanCollide = false
		obj.CanTouch = false
		obj.CanQuery = false
		obj.CastShadow = false
		obj.Color = color
		obj.Transparency = transparency or 0
		obj.Material = material or Enum.Material.Neon
		if shape then
			obj.Shape = shape
		end
		obj.Parent = Folder
		return obj
	end

	local function tween(obj, life, props, style)
		local tw = tweenService:Create(obj, TweenInfo.new(
			math.max(life, 0.03),
			style or Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		), props)
		tw:Play()
		tw.Completed:Connect(function()
			pcall(function()
				tw:Destroy()
			end)
		end)
		return tw
	end

	local function sphere(pos, startSize, endSize, color, life, transparency)
		local obj = makePart(
			Vector3.one * math.max(startSize, 0.03),
			CFrame.new(pos),
			color,
			transparency or 0,
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
		tween(obj, life, {
			Size = Vector3.one * math.max(endSize, 0.03),
			Transparency = 1
		}, Enum.EasingStyle.Quart)
		cleanup(obj, life)
	end

	local function line(a, b, width, color, life)
		local dist = (b - a).Magnitude
		if dist <= 0.01 then return end

		local obj = makePart(
			Vector3.new(width, width, dist),
			CFrame.lookAt((a + b) / 2, b),
			color,
			0,
			Enum.Material.Neon
		)

		tween(obj, life, {
			Transparency = 1,
			Size = Vector3.new(math.max(width * 0.1, 0.015), math.max(width * 0.1, 0.015), dist)
		}, Enum.EasingStyle.Quart)

		cleanup(obj, life)
	end

	local function burst(pos, count, radius, size, a, b, life, cubes, rainbow)
		local total = amount(count)
		for i = 1, total do
			local dir = Vector3.new(
				math.random(-100, 100) / 100,
				math.random(-100, 100) / 100,
				math.random(-100, 100) / 100
			)
			if dir.Magnitude < 0.05 then
				dir = Vector3.yAxis
			end
			dir = dir.Unit

			local color
			if rainbow then
				color = Color3.fromHSV(i / math.max(total, 1), 0.85, 1)
			else
				color = i % 2 == 0 and a or b
			end

			local obj = makePart(
				Vector3.one * size,
				CFrame.new(pos) * CFrame.Angles(math.random(), math.random(), math.random()),
				color,
				0,
				Enum.Material.Neon,
				cubes and nil or Enum.PartType.Ball
			)

			local endPos = pos + dir * radius * (0.6 + math.random() * 0.5)
			tween(obj, life, {
				CFrame = CFrame.new(endPos) * CFrame.Angles(math.random() * 5, math.random() * 5, math.random() * 5),
				Size = Vector3.one * math.max(size * 0.1, 0.02),
				Transparency = 1
			}, Enum.EasingStyle.Quart)
			cleanup(obj, life)
		end
	end

	local function ring(pos, radius, count, size, a, b, life)
		local total = amount(count)
		for i = 1, total do
			local angle = (i / total) * math.pi * 2
			local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local start = pos + dir * radius * 0.15
			local finish = pos + dir * radius
			local obj = makePart(
				Vector3.one * size,
				CFrame.new(start),
				i % 2 == 0 and a or b,
				0,
				Enum.Material.Neon,
				Enum.PartType.Ball
			)
			tween(obj, life, {
				CFrame = CFrame.new(finish),
				Size = Vector3.one * math.max(size * 0.12, 0.02),
				Transparency = 1
			}, Enum.EasingStyle.Quart)
			cleanup(obj, life)
		end
	end

	local function symbol(pos, text, color, life, count, scale)
		for _ = 1, amount(count or 1) do
			local anchor = makePart(Vector3.one * 0.03, CFrame.new(
				pos + Vector3.new(math.random(-5, 5) / 10, math.random(-3, 5) / 10, math.random(-5, 5) / 10)
			), color, 1, Enum.Material.SmoothPlastic)

			local gui = Instance.new('BillboardGui')
			gui.Size = UDim2.fromOffset(48 * (scale or 1), 48 * (scale or 1))
			gui.AlwaysOnTop = true
			gui.Adornee = anchor
			gui.Parent = anchor

			local label = Instance.new('TextLabel')
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Text = text
			label.TextScaled = true
			label.TextColor3 = color
			label.TextStrokeTransparency = 0.3
			label.Font = Enum.Font.GothamBold
			label.Parent = gui

			tween(anchor, life, {
				CFrame = anchor.CFrame + Vector3.new(math.random(-8, 8) / 10, 2 + math.random(), math.random(-8, 8) / 10)
			}, Enum.EasingStyle.Sine)
			tween(label, life, {
				TextTransparency = 1,
				TextStrokeTransparency = 1
			}, Enum.EasingStyle.Quad)
			cleanup(anchor, life)
		end
	end

	local function lightning(pos, a, b, scale, life)
		local segments = amount(5)
		local start = pos + Vector3.new(
			math.random(-10, 10) / 10,
			1.2 * scale,
			math.random(-10, 10) / 10
		)
		for i = 1, segments do
			local finish = pos + Vector3.new(
				math.random(-15, 15) / 10 * scale,
				(1.2 - i / segments * 2.4) * scale,
				math.random(-15, 15) / 10 * scale
			)
			line(start, finish, 0.055 * scale, i % 2 == 0 and a or b, life)
			start = finish
		end
	end

	local function runEffect(hit)
		if not HitEffects.Enabled or not hit or not hit.Position then return end
		if HeadshotsOnly.Enabled and not hit.Headshot then return end

		local mode = Mode.Value
		if mode == 'Random' then
			mode = randomModes[math.random(1, #randomModes)]
		elseif mode == 'Headshot' and not hit.Headshot then
			mode = 'Sparks'
		end

		local scale = EffectSize.Value * (hit.Headshot and 1.18 or 1)
		local life = math.max(Lifetime.Value, 0.12)
		local a, b = getColors(hit.Entity)
		local pos = hit.Position
		local white = Color3.new(1, 1, 1)

		local function flashLight(color, brightness, radius, duration)
			local anchor = makePart(Vector3.one * 0.04, CFrame.new(pos), color, 1, Enum.Material.Neon)
			local light = Instance.new('PointLight')
			light.Color = color
			light.Brightness = brightness
			light.Range = radius
			light.Shadows = false
			light.Parent = anchor
			tween(light, duration, {
				Brightness = 0,
				Range = radius * 1.35
			}, Enum.EasingStyle.Quart)
			cleanup(anchor, duration)
		end

		local function radialLines(count, radius, width, c1, c2, duration, tilt)
			local total = amount(count)
			for i = 1, total do
				local ang = (i / total) * math.pi * 2
				local y = math.sin(ang * 2) * (tilt or 0)
				local dir = Vector3.new(math.cos(ang), y, math.sin(ang)).Unit
				line(
					pos + dir * 0.08 * scale,
					pos + dir * radius * scale,
					width * scale,
					i % 2 == 0 and c1 or c2,
					duration
				)
			end
		end

		local function layeredRing(layers, baseRadius, points, dotSize, duration)
			for layer = 1, layers do
				task.delay((layer - 1) * duration * 0.08, function()
					if not HitEffects.Enabled then return end
					ring(
						pos + Vector3.new(0, (layer - 1) * 0.08 * scale, 0),
						(baseRadius + (layer - 1) * 0.55) * scale,
						points + layer * 2,
						dotSize * scale,
						layer % 2 == 0 and b or a,
						layer % 2 == 0 and a or b,
						duration * (0.8 + layer * 0.06)
					)
				end)
			end
		end

		local function rainbowRays(count, radius, duration)
			local total = amount(count)
			for i = 1, total do
				local ang = (i / total) * math.pi * 2
				local color = Color3.fromHSV(i / total, 0.95, 1)
				local dir = Vector3.new(math.cos(ang), math.sin(ang * 3) * 0.22, math.sin(ang)).Unit
				line(pos, pos + dir * radius * scale, 0.045 * scale, color, duration)
			end
		end

		-- Every confirmed hit gets a bright layered core so even the "small" modes pop.
		flashLight(hit.Headshot and white or a, hit.Headshot and 5.5 or 3.5, (hit.Headshot and 9 or 6) * scale, life * 0.42)
		sphere(pos, 0.035 * scale, (hit.Headshot and 0.95 or 0.62) * scale, white, life * 0.26, 0.02)
		sphere(pos, 0.05 * scale, (hit.Headshot and 1.35 or 0.9) * scale, a, life * 0.34, 0.32)
		burst(pos, hit.Headshot and 12 or 7, (hit.Headshot and 2.0 or 1.25) * scale, 0.045 * scale, a, b, life * 0.42, false, false)

		if hit.Headshot then
			symbol(pos + Vector3.new(0, 0.15 * scale, 0), '✦', white, life * 0.55, 3, scale * 0.58)
		end

		if mode == 'Sparks' then
			burst(pos, 22, 2.6 * scale, 0.075 * scale, a, b, life, false, false)
			radialLines(10, 2.15, 0.035, a, b, life * 0.62, 0.22)

		elseif mode == 'Burst' then
			sphere(pos, 0.08 * scale, 1.65 * scale, a, life * 0.52, 0.12)
			sphere(pos, 0.04 * scale, 1.15 * scale, b, life * 0.38, 0.18)
			burst(pos, 30, 3.45 * scale, 0.095 * scale, a, b, life, false, false)
			radialLines(12, 2.9, 0.045, white, a, life * 0.6, 0.12)

		elseif mode == 'Pulse' then
			for i = 1, 4 do
				task.delay((i - 1) * life * 0.08, function()
					if HitEffects.Enabled then
						sphere(
							pos,
							0.04 * scale,
							(0.9 + i * 0.65) * scale,
							i % 2 == 0 and a or b,
							life * 0.55,
							0.58
						)
					end
				end)
			end
			layeredRing(2, 1.3, 15, 0.055, life * 0.72)

		elseif mode == 'Ring' then
			layeredRing(4, 1.2, 18, 0.065, life)
			sphere(pos, 0.04 * scale, 1.2 * scale, white, life * 0.34, 0.45)
			radialLines(8, 2.0, 0.03, a, b, life * 0.55, 0)

		elseif mode == 'Slash' then
			for i = 1, amount(8) do
				local yaw = (i / amount(8)) * math.pi * 2
				local pitch = ((i % 3) - 1) * 0.38
				local dir = Vector3.new(math.cos(yaw), pitch, math.sin(yaw)).Unit * (1.5 + (i % 2) * 0.6) * scale
				line(pos - dir, pos + dir, (i % 3 == 0 and 0.075 or 0.045) * scale, i % 2 == 0 and a or b, life * (0.55 + (i % 3) * 0.08))
			end
			burst(pos, 14, 2.1 * scale, 0.055 * scale, a, b, life * 0.7, false, false)

		elseif mode == 'Cross' then
			for _, axis in {
				Vector3.xAxis, Vector3.yAxis, Vector3.zAxis,
				Vector3.new(1, 1, 0).Unit, Vector3.new(1, -1, 0).Unit,
				Vector3.new(0, 1, 1).Unit, Vector3.new(0, 1, -1).Unit
			} do
				line(pos - axis * 1.55 * scale, pos + axis * 1.55 * scale, 0.045 * scale, math.random() > 0.5 and a or b, life * 0.65)
			end
			sphere(pos, 0.04 * scale, 1.45 * scale, white, life * 0.35, 0.35)

		elseif mode == 'Lightning' then
			for strike = 1, amount(4) do
				local last = pos + Vector3.new(math.random(-10, 10) / 10, 2.4 + math.random(), math.random(-10, 10) / 10) * scale
				for step = 1, 5 do
					local finish = pos + Vector3.new(
						math.random(-15, 15) / 10 * scale,
						(2.2 - step * 0.55) * scale,
						math.random(-15, 15) / 10 * scale
					)
					line(last, finish, (step == 5 and 0.065 or 0.04) * scale, strike % 2 == 0 and a or b, life * 0.55)
					last = finish
				end
			end
			sphere(pos, 0.05 * scale, 1.6 * scale, white, life * 0.32, 0.38)
			burst(pos, 16, 2.4 * scale, 0.055 * scale, a, b, life * 0.65, false, false)

		elseif mode == 'Stars' then
			symbol(pos, '★', a, life, 7, scale * 0.95)
			symbol(pos, '✦', b, life * 0.88, 7, scale * 0.72)
			symbol(pos, '✧', white, life * 0.7, 4, scale * 0.55)
			burst(pos, 12, 2.0 * scale, 0.045 * scale, a, b, life * 0.65, false, false)

		elseif mode == 'Hearts' then
			symbol(pos, '♥', a, life, 9, scale * 0.95)
			symbol(pos, '♡', b, life * 0.9, 6, scale * 0.72)
			burst(pos, 10, 1.8 * scale, 0.05 * scale, a, b, life * 0.6, false, false)

		elseif mode == 'Crit' then
			symbol(pos, '✦', white, life * 0.7, 7, scale * 0.75)
			symbol(pos, '✧', a, life, 6, scale)
			burst(pos, 24, 3.0 * scale, 0.07 * scale, a, b, life, false, false)
			radialLines(10, 2.65, 0.04, white, b, life * 0.62, 0.25)

		elseif mode == 'Smoke' then
			for i = 1, amount(17) do
				local offset = Vector3.new(
					math.random(-10, 10) / 10,
					math.random(-7, 9) / 10,
					math.random(-10, 10) / 10
				) * scale
				sphere(
					pos + offset,
					0.12 * scale,
					(0.45 + math.random() * 0.55) * scale,
					i % 2 == 0 and a or b,
					life * (0.75 + math.random() * 0.3),
					0.4
				)
			end
			burst(pos, 10, 1.7 * scale, 0.05 * scale, white, a, life * 0.5, false, false)

		elseif mode == 'Shards' then
			burst(pos, 30, 3.2 * scale, 0.12 * scale, a, b, life, true, false)
			radialLines(12, 2.8, 0.04, a, white, life * 0.6, 0.35)
			sphere(pos, 0.04 * scale, 1.0 * scale, b, life * 0.32, 0.4)

		elseif mode == 'Pixels' then
			for i = 1, amount(28) do
				local obj = makePart(
					Vector3.one * (0.08 + math.random() * 0.08) * scale,
					CFrame.new(pos),
					i % 3 == 0 and white or (i % 2 == 0 and a or b),
					0,
					Enum.Material.Neon
				)
				local finish = pos + Vector3.new(
					math.random(-28, 28) / 10,
					math.random(-24, 24) / 10,
					math.random(-28, 28) / 10
				) * scale
				tween(obj, life, {
					CFrame = CFrame.new(finish) * CFrame.Angles(math.random() * 4, math.random() * 4, math.random() * 4),
					Transparency = 1,
					Size = Vector3.one * 0.02
				}, Enum.EasingStyle.Quart)
				cleanup(obj, life)
			end

		elseif mode == 'Spiral' then
			local total = amount(34)
			for i = 1, total do
				local alpha = i / total
				local theta = alpha * math.pi * 7
				local radius = (0.15 + alpha * 1.9) * scale
				local finish = pos + Vector3.new(
					math.cos(theta) * radius,
					(alpha - 0.5) * 3.0 * scale,
					math.sin(theta) * radius
				)
				local obj = makePart(
					Vector3.one * (0.05 + alpha * 0.04) * scale,
					CFrame.new(pos),
					i % 2 == 0 and a or b,
					0,
					Enum.Material.Neon,
					Enum.PartType.Ball
				)
				tween(obj, life, {
					CFrame = CFrame.new(finish),
					Transparency = 1,
					Size = Vector3.one * 0.018
				}, Enum.EasingStyle.Sine)
				cleanup(obj, life)
			end
			sphere(pos, 0.04 * scale, 1.2 * scale, white, life * 0.36, 0.35)

		elseif mode == 'Orbit' then
			layeredRing(4, 0.95, 18, 0.07, life)
			for i = 1, amount(12) do
				local ang = i / amount(12) * math.pi * 2
				local p1 = pos + Vector3.new(math.cos(ang), math.sin(ang) * 0.7, math.sin(ang)) * 0.5 * scale
				local p2 = pos + Vector3.new(math.cos(ang + 1.7), math.sin(ang + 1.7) * 1.25, math.sin(ang + 1.7)) * 2.2 * scale
				line(p1, p2, 0.03 * scale, i % 2 == 0 and a or b, life * 0.75)
			end

		elseif mode == 'Bubble' then
			for i = 1, amount(19) do
				local offset = Vector3.new(
					math.random(-14, 14) / 10,
					math.random(-10, 12) / 10,
					math.random(-14, 14) / 10
				) * scale
				sphere(
					pos + offset,
					0.055 * scale,
					(0.22 + math.random() * 0.48) * scale,
					i % 2 == 0 and a or b,
					life * (0.7 + math.random() * 0.3),
					0.22
				)
			end
			layeredRing(2, 1.0, 12, 0.04, life * 0.65)

		elseif mode == 'Shockwave' then
			for i = 1, 4 do
				task.delay((i - 1) * life * 0.06, function()
					if HitEffects.Enabled then
						sphere(pos, 0.04 * scale, (1.15 + i * 0.7) * scale, i % 2 == 0 and a or b, life * 0.55, 0.62)
					end
				end)
			end
			radialLines(18, 3.2, 0.038, white, a, life * 0.65, 0.18)
			burst(pos, 16, 2.5 * scale, 0.055 * scale, a, b, life * 0.65, false, false)

		elseif mode == 'Rainbow' then
			burst(pos, 34, 3.2 * scale, 0.075 * scale, a, b, life, false, true)
			rainbowRays(18, 2.8, life * 0.72)
			for i = 1, 3 do
				local color = Color3.fromHSV((tick() * 0.3 + i / 3) % 1, 0.95, 1)
				sphere(pos, 0.04 * scale, (0.75 + i * 0.5) * scale, color, life * 0.45, 0.55)
			end

		elseif mode == 'Headshot' then
			flashLight(white, 8, 12 * scale, life * 0.45)
			sphere(pos, 0.04 * scale, 2.0 * scale, white, life * 0.34, 0.18)
			sphere(pos, 0.05 * scale, 2.65 * scale, a, life * 0.48, 0.58)
			symbol(pos + Vector3.new(0, 0.2 * scale, 0), '✦', white, life, 8, scale * 0.9)
			symbol(pos + Vector3.new(0, 0.35 * scale, 0), '★', a, life * 0.85, 5, scale * 0.72)
			burst(pos, 38, 4.1 * scale, 0.085 * scale, a, b, life, false, false)
			radialLines(20, 3.65, 0.05, white, b, life * 0.7, 0.28)
			layeredRing(3, 1.35, 18, 0.055, life * 0.75)
		end
	end
	local function trimPending()
		local now = tick()
		for i = #pending, 1, -1 do
			if now - pending[i].Time > 0.8 then
				table.remove(pending, i)
			end
		end
	end

	HitEffects = vape.Categories.Render:CreateModule({
		Name = 'HitEffects',
		Function = function(callback)
			if callback then
				table.clear(pending)
				table.clear(healthCache)

				for _, ent in entitylib.List do
					if ent and ent.Id then
						healthCache[ent.Id] = ent.Health or 100
					end
				end

				HitEffects:Clean(frontlines.LocalHitEvent.Event:Connect(function(ent, pos, headshot)
					if not ent or not ent.Id or not pos then return end
					if HeadshotsOnly.Enabled and not headshot then return end

					if not ConfirmedHits.Enabled then
						runEffect({
							Entity = ent,
							Position = pos,
							Headshot = headshot,
							Time = tick()
						})
						return
					end

					trimPending()
					table.insert(pending, {
						Id = ent.Id,
						Entity = ent,
						Position = pos,
						Headshot = headshot,
						Health = ent.Health or healthCache[ent.Id] or 100,
						Time = tick()
					})
				end))

				HitEffects:Clean(entitylib.Events.EntityUpdated:Connect(function(ent)
					if not ent or not ent.Id then return end

					local current = ent.Health or 0
					local previous = healthCache[ent.Id]
					healthCache[ent.Id] = current

					trimPending()
					for i = #pending, 1, -1 do
						local hit = pending[i]
						if hit.Id == ent.Id then
							if current < hit.Health or (previous and current < previous) then
								table.remove(pending, i)
								runEffect(hit)
								break
							elseif tick() - hit.Time > 0.65 then
								table.remove(pending, i)
							end
						end
					end
				end))

				HitEffects:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
					if ent and ent.Id then
						healthCache[ent.Id] = ent.Health or 100
					end
				end))

				HitEffects:Clean(entitylib.Events.EntityRemoved:Connect(function(ent)
					if ent and ent.Id then
						healthCache[ent.Id] = nil
					end
				end))
			else
				Folder:ClearAllChildren()
				table.clear(pending)
				table.clear(healthCache)
			end
		end,
		Tooltip = 'Displays a visual effect at the exact impact point when you damage a target.'
	})

	Mode = HitEffects:CreateDropdown({
		Name = 'Mode',
		List = modes,
		Default = 'Sparks'
	})

	ColorMode = HitEffects:CreateDropdown({
		Name = 'Color Mode',
		List = {'Custom', 'Target', 'Rainbow'},
		Default = 'Custom'
	})

	PrimaryColor = HitEffects:CreateColorSlider({
		Name = 'Primary Color',
		DefaultHue = 0.78,
		DefaultSat = 0.8,
		DefaultValue = 1
	})

	SecondaryColor = HitEffects:CreateColorSlider({
		Name = 'Secondary Color',
		DefaultHue = 0.58,
		DefaultSat = 0.75,
		DefaultValue = 1
	})

	EffectSize = HitEffects:CreateSlider({
		Name = 'Size',
		Min = 0.25,
		Max = 2.5,
		Default = 1,
		Decimal = 100
	})

	Lifetime = HitEffects:CreateSlider({
		Name = 'Lifetime',
		Min = 0.08,
		Max = 2,
		Default = 0.35,
		Decimal = 100,
		Suffix = 's'
	})

	Quality = HitEffects:CreateDropdown({
		Name = 'Quality',
		List = {'Low', 'Normal', 'High'},
		Default = 'Normal'
	})

	HeadshotsOnly = HitEffects:CreateToggle({
		Name = 'Headshots only'
	})

	ConfirmedHits = HitEffects:CreateToggle({
		Name = 'Confirmed hits',
		Default = true
	})

	vape:Clean(function()
		if Folder then
			Folder:Destroy()
		end
	end)
end)
-- ILLUSIONHD_HITEFFECTS_END
]====]
	return data:sub(1, insertPos - 1)..'\n'..patch..data:sub(insertPos)
end

local function applyKillEffectsVisualPatch(data)
	if type(data) ~= 'string' then return data end

	data = data:gsub(
		"local multiplier = Quality.Value == 'Low' and 0%.6 or Quality.Value == 'High' and 1%.45 or 1",
		"local multiplier = Quality.Value == 'Low' and 0.8 or Quality.Value == 'High' and 2.25 or 1.4",
		1
	)

	local killStart = data:find('\nrun(function()\n\tlocal KillEffects', 1, true)
	if not killStart then return data end

	local runStart = data:find('\tlocal function runEffect(death)', killStart, true)
	local runEnd = runStart and data:find('\n\tlocal function rememberDeath(ent)', runStart, true)
	if not runStart or not runEnd then return data end

	local replacement = [====[
	local function runEffect(death)
		if not death or not death.Position then return end

		local pos = death.Position
		local scale = EffectSize.Value
		local life = math.max(Lifetime.Value, 0.18)
		local a, b = colors(death)
		local white = Color3.new(1, 1, 1)
		local mode = Mode.Value

		if mode == 'Random' then
			local pool = {
				'Nova', 'Lightning', 'Soul', 'Rings', 'Spiral', 'Firework', 'Tornado',
				'Shatter', 'Slash', 'Beam', 'Pulse', 'Confetti', 'Galaxy', 'Freeze',
				'Void', 'Ghost', 'Hearts', 'Skull', 'Black Hole', 'Disintegrate',
				'Crystal', 'Orbit'
			}
			mode = pool[math.random(1, #pool)]
		end

		local center = pos + Vector3.new(0, 1.35 * scale, 0)

		local function flashLight(where, color, brightness, radius, duration)
			local anchor = part(Vector3.one * 0.05, CFrame.new(where), color, 1, Enum.Material.Neon)
			local light = Instance.new('PointLight')
			light.Color = color
			light.Brightness = brightness
			light.Range = radius
			light.Shadows = false
			light.Parent = anchor
			tween(light, duration, {
				Brightness = 0,
				Range = radius * 1.35
			}, Enum.EasingStyle.Quart)
			cleanup(anchor, duration)
		end

		local function radialLines(where, count, radius, width, c1, c2, duration, vertical)
			local total = amount(count)
			for i = 1, total do
				local ang = (i / total) * math.pi * 2
				local y = math.sin(ang * 2) * (vertical or 0)
				local dir = Vector3.new(math.cos(ang), y, math.sin(ang)).Unit
				line(
					where + dir * 0.15 * scale,
					where + dir * radius * scale,
					width * scale,
					i % 2 == 0 and c1 or c2,
					duration
				)
			end
		end

		local function orbitLayer(where, rings, points, radius, height, duration, reverse)
			for ringIndex = 1, rings do
				local total = amount(points)
				for i = 1, total do
					local alpha = i / total
					local dir = reverse and -1 or 1
					local ang = alpha * math.pi * 2 * dir + ringIndex * 0.7
					local y = ((ringIndex - (rings + 1) / 2) * height) * scale
					local start = where + Vector3.new(math.cos(ang) * radius * scale, y, math.sin(ang) * radius * scale)
					local finish = where + Vector3.new(
						math.cos(ang + dir * 2.4) * (radius + 2.1) * scale,
						y + math.sin(ang * 2) * 1.2 * scale,
						math.sin(ang + dir * 2.4) * (radius + 2.1) * scale
					)
					local orb = part(
						Vector3.one * (0.09 + ringIndex * 0.018) * scale,
						CFrame.new(start),
						(i + ringIndex) % 2 == 0 and a or b,
						0,
						Enum.Material.Neon,
						Enum.PartType.Ball
					)
					tween(orb, duration, {
						CFrame = CFrame.new(finish),
						Transparency = 1,
						Size = Vector3.one * 0.025
					}, Enum.EasingStyle.Sine)
					cleanup(orb, duration)
				end
			end
		end

		local function sparkleCloud(where, count, radius, duration, rainbow)
			local total = amount(count)
			for i = 1, total do
				local offset = Vector3.new(
					math.random(-100, 100) / 100,
					math.random(-100, 100) / 100,
					math.random(-100, 100) / 100
				)
				if offset.Magnitude < 0.05 then offset = Vector3.yAxis end
				offset = offset.Unit * radius * (0.3 + math.random() * 0.7) * scale
				local c = rainbow and Color3.fromHSV(i / total, 0.95, 1) or (i % 3 == 0 and white or (i % 2 == 0 and a or b))
				local obj = part(
					Vector3.one * (0.055 + math.random() * 0.085) * scale,
					CFrame.new(where),
					c,
					0,
					Enum.Material.Neon,
					Enum.PartType.Ball
				)
				tween(obj, duration, {
					CFrame = CFrame.new(where + offset),
					Transparency = 1,
					Size = Vector3.one * 0.018
				}, Enum.EasingStyle.Quart)
				cleanup(obj, duration)
			end
		end

		local function pulseStack(where, layers, maxRadius, duration)
			for i = 1, layers do
				task.delay((i - 1) * duration * 0.065, function()
					if KillEffects.Enabled then
						sphere(
							where,
							0.08 * scale,
							(maxRadius * (0.45 + i / layers * 0.55)) * scale,
							i % 3 == 0 and white or (i % 2 == 0 and a or b),
							duration * (0.65 + i * 0.04),
							0.58
						)
					end
				end)
			end
		end

		playKillSound()

		-- Universal cinematic base: white-hot core + colored bloom + debris.
		flashLight(center, white, 8.5, 18 * scale, life * 0.42)
		flashLight(center, a, 5.5, 13 * scale, life * 0.62)
		sphere(center, 0.08 * scale, 1.6 * scale, white, life * 0.28, 0.06)
		sphere(center, 0.12 * scale, 2.65 * scale, a, life * 0.4, 0.38)
		burst(center, 16, 3.7 * scale, 0.075 * scale, a, b, life * 0.55, false, 0.18)
		sparkleCloud(center, 10, 2.8, life * 0.48, false)

		if mode == 'Nova' or mode == 'Explosion' then
			pulseStack(center, 5, 8.5, life * 0.8)
			sphere(center, 0.25 * scale, 8.5 * scale, a, life * 0.82, 0.5)
			sphere(center, 0.18 * scale, 5.2 * scale, b, life * 0.62, 0.5)
			burst(center, 46, 10 * scale, 0.21 * scale, a, b, life, false, 0.2)
			radialLines(center, 24, 9.4, 0.07, white, a, life * 0.72, 0.22)
			sparkleCloud(center, 28, 8.0, life * 0.9, false)

		elseif mode == 'Lightning' then
			local top = center + Vector3.new(0, 16 * scale, 0)
			for strike = 1, amount(6) do
				local last = top + Vector3.new(math.random(-25, 25) / 10 * scale, 0, math.random(-25, 25) / 10 * scale)
				for step = 1, 9 do
					local nextp = top:Lerp(center, step / 9) + Vector3.new(
						math.random(-18, 18) / 10 * scale,
						0,
						math.random(-18, 18) / 10 * scale
					)
					line(last, nextp, (step > 6 and 0.12 or 0.075) * scale, strike % 3 == 0 and white or (strike % 2 == 0 and b or a), life * 0.62)
					if step % 3 == 0 then
						local branch = nextp + Vector3.new(
							math.random(-35, 35) / 10,
							math.random(-8, 20) / 10,
							math.random(-35, 35) / 10
						) * scale
						line(nextp, branch, 0.045 * scale, b, life * 0.48)
					end
					last = nextp
				end
			end
			pulseStack(center, 3, 5.5, life * 0.6)
			burst(center, 34, 7.2 * scale, 0.11 * scale, white, a, life * 0.75, false, 0.15)
			radialLines(center, 18, 7.5, 0.055, white, b, life * 0.62, 0.3)

		elseif mode == 'Soul' then
			sphere(center, 0.3 * scale, 5.1 * scale, a, life, 0.5)
			sphere(center, 0.2 * scale, 3.3 * scale, b, life * 0.72, 0.55)
			for i = 1, amount(34) do
				local start = center + Vector3.new(
					math.random(-26, 26) / 10,
					math.random(-12, 22) / 10,
					math.random(-26, 26) / 10
				) * scale
				local orb = part(Vector3.one * (0.11 + math.random() * 0.16) * scale, CFrame.new(start), i % 3 == 0 and white or (i % 2 == 0 and a or b), 0.08, Enum.Material.Neon, Enum.PartType.Ball)
				tween(orb, life * (0.72 + math.random() * 0.28), {
					CFrame = CFrame.new(start + Vector3.new(
						math.random(-18, 18) / 10,
						9 + math.random() * 6,
						math.random(-18, 18) / 10
					) * scale),
					Transparency = 1,
					Size = Vector3.one * 0.025
				}, Enum.EasingStyle.Sine)
				cleanup(orb, life * 1.1)
			end
			orbitLayer(center, 2, 18, 2.2, 0.6, life * 0.9, false)
			symbol(center + Vector3.new(0, 2 * scale, 0), '✦', white, life, 7, scale * 0.85)

		elseif mode == 'Rings' or mode == 'Orbit' then
			orbitLayer(center, 5, 22, 1.4, 0.48, life, mode == 'Orbit')
			orbitLayer(center, 3, 16, 2.4, 0.7, life * 0.82, not (mode == 'Orbit'))
			pulseStack(center, 3, 4.3, life * 0.62)
			radialLines(center, 16, 5.5, 0.045, white, a, life * 0.6, 0.18)

		elseif mode == 'Spiral' or mode == 'Tornado' then
			local total = amount(mode == 'Tornado' and 62 or 48)
			for i = 1, total do
				local alpha = i / total
				local turns = mode == 'Tornado' and 11 or 7
				local ang = alpha * math.pi * turns
				local radius = mode == 'Tornado' and (0.6 + alpha * 4.8) or (1.15 + math.sin(alpha * math.pi) * 2.8)
				local start = center + Vector3.new(
					math.cos(ang) * radius * scale,
					(alpha * (mode == 'Tornado' and 10 or 7) - 1.5) * scale,
					math.sin(ang) * radius * scale
				)
				local orb = part(
					Vector3.one * (0.08 + alpha * 0.12) * scale,
					CFrame.new(start),
					i % 4 == 0 and white or (i % 2 == 0 and a or b),
					0,
					Enum.Material.Neon,
					Enum.PartType.Ball
				)
				tween(orb, life, {
					CFrame = CFrame.new(start + Vector3.new(
						math.cos(ang + 2.6) * 3.3,
						3.6 + alpha * 2.2,
						math.sin(ang + 2.6) * 3.3
					) * scale),
					Transparency = 1,
					Size = Vector3.one * 0.025
				}, Enum.EasingStyle.Sine)
				cleanup(orb, life)
			end
			burst(center, 30, 6 * scale, 0.09 * scale, a, b, life * 0.72, false, 0.7)

		elseif mode == 'Firework' then
			local sky = center + Vector3.new(0, 10 * scale, 0)
			line(center, sky, 0.15 * scale, white, life * 0.36)
			for i = 1, amount(9) do
				local trailPos = center:Lerp(sky, i / amount(9))
				sphere(trailPos, 0.04 * scale, 0.35 * scale, i % 2 == 0 and a or b, life * 0.3, 0.2)
			end
			task.delay(life * 0.23, function()
				if KillEffects.Enabled then
					flashLight(sky, white, 9, 20 * scale, life * 0.45)
					pulseStack(sky, 4, 6.0, life * 0.65)
					burst(sky, 72, 10 * scale, 0.17 * scale, a, b, life * 0.9, false, 0.12)
					radialLines(sky, 30, 8.8, 0.055, white, a, life * 0.72, 0.35)
					sparkleCloud(sky, 46, 8.5, life, false)
				end
			end)

		elseif mode == 'Shatter' or mode == 'Disintegrate' or mode == 'Pixel Burst' then
			local count = mode == 'Disintegrate' and 68 or 50
			burst(center, count, 9 * scale, 0.27 * scale, a, b, life, true, mode == 'Disintegrate' and 0.9 or 0.25)
			burst(center, 34, 6.5 * scale, 0.11 * scale, white, b, life * 0.75, true, 0.5)
			radialLines(center, 22, 7.5, 0.05, white, a, life * 0.62, 0.4)
			pulseStack(center, 2, 4.7, life * 0.55)

		elseif mode == 'Slash' then
			for i = 1, amount(10) do
				local yaw = (i / amount(10)) * math.pi * 2
				local pitch = ((i % 4) - 1.5) * 0.24
				local dir = Vector3.new(math.cos(yaw), pitch, math.sin(yaw)).Unit * (5.5 + (i % 3)) * scale
				line(center - dir, center + dir, (i % 3 == 0 and 0.17 or 0.095) * scale, i % 3 == 0 and white or (i % 2 == 0 and a or b), life * (0.6 + (i % 4) * 0.05))
			end
			pulseStack(center, 3, 5.1, life * 0.55)
			burst(center, 34, 6.5 * scale, 0.11 * scale, a, b, life * 0.72, false, 0.12)

		elseif mode == 'Beam' then
			for i = 1, 4 do
				local offset = Vector3.new((i - 2.5) * 0.38 * scale, 0, ((i % 2) - 0.5) * 0.42 * scale)
				line(center - Vector3.new(0, 4 * scale, 0) + offset, center + Vector3.new(0, 18 * scale, 0) + offset, (i == 2 and 0.36 or 0.13) * scale, i == 2 and white or (i % 2 == 0 and a or b), life)
			end
			pulseStack(center, 5, 6.5, life * 0.72)
			orbitLayer(center, 3, 18, 2.0, 0.55, life * 0.85, false)
			burst(center, 28, 6.2 * scale, 0.09 * scale, a, b, life * 0.65, false, 0.25)

		elseif mode == 'Pulse' or mode == 'Shockwave' then
			pulseStack(center, 7, 9.0, life)
			radialLines(center, 34, 10, 0.055, white, a, life * 0.68, 0.18)
			burst(center, 42, 8.0 * scale, 0.11 * scale, a, b, life * 0.82, false, 0.2)
			sparkleCloud(center, 30, 6.7, life * 0.86, false)

		elseif mode == 'Confetti' or mode == 'Rainbow' then
			burst(center, 80, 10 * scale, 0.18 * scale, a, b, life, true, 1.0, mode == 'Rainbow')
			sparkleCloud(center, 54, 8.5, life * 0.95, mode == 'Rainbow')
			if mode == 'Rainbow' then
				local total = amount(26)
				for i = 1, total do
					local ang = i / total * math.pi * 2
					local c = Color3.fromHSV(i / total, 0.95, 1)
					line(center, center + Vector3.new(math.cos(ang), math.sin(ang * 3) * 0.28, math.sin(ang)).Unit * 8 * scale, 0.055 * scale, c, life * 0.72)
				end
				pulseStack(center, 4, 6.0, life * 0.65)
			end

		elseif mode == 'Galaxy' then
			sphere(center, 0.25 * scale, 4.8 * scale, b, life, 0.52)
			sphere(center, 0.14 * scale, 3.2 * scale, Color3.new(0.02, 0.02, 0.05), life * 0.9, 0.1)
			for arm = 1, 4 do
				local total = amount(26)
				for i = 1, total do
					local alpha = i / total
					local ang = alpha * math.pi * 3.5 + arm * math.pi / 2
					local rad = (0.6 + alpha * 5.5) * scale
					local start = center + Vector3.new(
						math.cos(ang) * rad,
						math.sin(ang * 0.65) * 1.3 * scale,
						math.sin(ang) * rad
					)
					local orb = part(Vector3.one * (0.06 + alpha * 0.08) * scale, CFrame.new(start), (i + arm) % 3 == 0 and white or ((i + arm) % 2 == 0 and a or b), 0, Enum.Material.Neon, Enum.PartType.Ball)
					tween(orb, life, {
						CFrame = CFrame.new(center + Vector3.new(
							math.cos(ang + 2.8) * (rad + 2.5 * scale),
							math.sin(ang + 1) * 2.4 * scale,
							math.sin(ang + 2.8) * (rad + 2.5 * scale)
						)),
						Transparency = 1,
						Size = Vector3.one * 0.025
					}, Enum.EasingStyle.Sine)
					cleanup(orb, life)
				end
			end
			flashLight(center, b, 7, 18 * scale, life * 0.8)
			sparkleCloud(center, 36, 7.5, life, false)

		elseif mode == 'Freeze' or mode == 'Crystal' then
			for i = 1, amount(34) do
				local ang = (i / amount(34)) * math.pi * 2
				local endpoint = center + Vector3.new(
					math.cos(ang) * (3.5 + math.random() * 5.5) * scale,
					(math.random(-2, 8) + math.random()) * scale,
					math.sin(ang) * (3.5 + math.random() * 5.5) * scale
				)
				local shard = line(center, endpoint, (0.075 + math.random() * 0.16) * scale, i % 4 == 0 and white or (i % 2 == 0 and a or b), life)
				if shard then shard.Material = Enum.Material.Ice end
			end
			pulseStack(center, 4, 6.5, life * 0.76)
			burst(center, 48, 8.0 * scale, 0.15 * scale, white, a, life * 0.82, true, 0.3)
			sparkleCloud(center, 28, 6.0, life * 0.75, false)

		elseif mode == 'Void' or mode == 'Black Hole' then
			sphere(center, 0.3 * scale, 5.1 * scale, Color3.new(0.005, 0.005, 0.012), life, 0.02)
			sphere(center, 0.2 * scale, 6.6 * scale, a, life * 0.78, 0.7)
			for ringIndex = 1, 4 do
				local total = amount(24)
				for i = 1, total do
					local ang = (i / total) * math.pi * 2 + ringIndex * 0.5
					local rad = (4.5 + ringIndex * 1.4) * scale
					local start = center + Vector3.new(
						math.cos(ang) * rad,
						math.sin(ang * 2) * 2.3 * scale,
						math.sin(ang) * rad
					)
					local orb = part(Vector3.one * (0.08 + ringIndex * 0.025) * scale, CFrame.new(start), (i + ringIndex) % 3 == 0 and white or ((i + ringIndex) % 2 == 0 and a or b), 0, Enum.Material.Neon, Enum.PartType.Ball)
					tween(orb, life * (0.7 + ringIndex * 0.07), {
						CFrame = CFrame.new(center),
						Transparency = 1,
						Size = Vector3.one * 0.02
					}, Enum.EasingStyle.Quint)
					cleanup(orb, life)
				end
			end
			radialLines(center, 22, 7.5, 0.045, a, b, life * 0.62, 0.28)
			flashLight(center, a, 6.5, 16 * scale, life * 0.75)

		elseif mode == 'Ghost' then
			ghostEffect(death, a, scale, life)
			for i = 1, 3 do
				task.delay(i * life * 0.07, function()
					if KillEffects.Enabled then
						sphere(center + Vector3.new(0, i * 0.7 * scale, 0), 0.1 * scale, (3.3 + i) * scale, i % 2 == 0 and a or b, life * 0.7, 0.72)
					end
				end)
			end
			symbol(center + Vector3.new(0, 2.4 * scale, 0), '✦', white, life, 10, scale * 0.8)
			sparkleCloud(center, 34, 6.5, life, false)

		elseif mode == 'Hearts' then
			symbol(center, '♥', a, life, 18, scale)
			symbol(center + Vector3.new(0, 1.0 * scale, 0), '♡', b, life * 0.9, 12, scale * 0.78)
			symbol(center + Vector3.new(0, 0.4 * scale, 0), '✦', white, life * 0.72, 8, scale * 0.62)
			pulseStack(center, 4, 5.5, life * 0.68)
			burst(center, 34, 7.0 * scale, 0.1 * scale, a, b, life * 0.78, false, 0.65)

		elseif mode == 'Skull' then
			symbol(center + Vector3.new(0, 3.0 * scale, 0), '☠', white, life, 1, 2.0 * scale)
			symbol(center + Vector3.new(0, 2.7 * scale, 0), '☠', a, life * 0.92, 2, 1.45 * scale)
			pulseStack(center, 4, 6.5, life * 0.72)
			radialLines(center, 28, 8.5, 0.06, white, b, life * 0.72, 0.35)
			burst(center, 50, 8.5 * scale, 0.12 * scale, a, b, life * 0.85, false, 0.25)
			sparkleCloud(center, 30, 6.0, life * 0.75, false)
		end
	end
]====]
	return data:sub(1, runStart - 1)..replacement..data:sub(runEnd)
end

local function applyLeaveSoundPatch(data)
	if type(data) ~= 'string' then return data end
	if data:find('-- ILLUSIONHD_LEAVE_SOUND_V1', 1, true) then
		return data
	end

	local marker = 'shared.vape = vape\n'
	local pos = data:find(marker, 1, true)
	if not pos then
		return data
	end

	local patch = [====[
-- ILLUSIONHD_LEAVE_SOUND_V1
do
	local leaveSoundService = cloneref(game:GetService('SoundService'))
	local leaveContentProvider = cloneref(game:GetService('ContentProvider'))
	local leaveSound = Instance.new('Sound')
	leaveSound.Name = 'IllusionHDLeaveSound'
	leaveSound.SoundId = 'rbxassetid://104269922408932'
	leaveSound.Volume = 1
	leaveSound.PlayOnRemove = false
	leaveSound.Parent = leaveSoundService

	-- Load the audio while Vape is running so it can start instantly when leaving.
	task.spawn(function()
		pcall(function()
			leaveContentProvider:PreloadAsync({leaveSound})
		end)
	end)

	local leaving = false
	local function playLeaveSound(blockShutdown)
		-- If Vape was uninjected first, do nothing.
		if leaving or shared.vape ~= vape then return end
		leaving = true

		pcall(function()
			leaveSound.TimePosition = 0
			leaveSound:Play()
		end)

		-- A Shutdown hook can briefly hold the close call so the sound is actually audible.
		if blockShutdown then
			local duration = 0.9
			pcall(function()
				if leaveSound.TimeLength > 0 then
					duration = math.clamp(leaveSound.TimeLength, 0.35, 1.5)
				end
			end)
			task.wait(duration)
		end
	end

	-- Covers the LocalPlayer being removed from the current server.
	vape:Clean(playersService.PlayerRemoving:Connect(function(plr)
		if plr == playersService.LocalPlayer then
			playLeaveSound(false)
		end
	end))

	-- Teleports also leave the current game/server.
	vape:Clean(playersService.LocalPlayer.OnTeleport:Connect(function(state)
		if state == Enum.TeleportState.Started
			or state == Enum.TeleportState.InProgress then
			playLeaveSound(false)
		end
	end))

	-- Some environments expose BindToClose to the injected context.
	pcall(function()
		game:BindToClose(function()
			playLeaveSound(true)
		end)
	end)

	-- Roblox's Leave button commonly ends up invoking DataModel:Shutdown().
	-- Hook it when supported so playback begins before the client is destroyed.
	if hookfunction then
		pcall(function()
			local originalShutdown
			local replacement = function(self, ...)
				playLeaveSound(true)
				return originalShutdown(self, ...)
			end

			if newcclosure then
				replacement = newcclosure(replacement)
			end

			originalShutdown = hookfunction(game.Shutdown, replacement)
			vape:Clean(function()
				pcall(function()
					if originalShutdown then
						hookfunction(game.Shutdown, originalShutdown)
					end
				end)
			end)
		end)
	end

	-- Uninjecting Vape removes the sound/listeners, so leaving afterwards stays silent.
	vape:Clean(function()
		leaving = true
		pcall(function()
			leaveSound:Stop()
			leaveSound:Destroy()
		end)
	end)
end
-- ILLUSIONHD_LEAVE_SOUND_END

]====]
	local insertAt = pos + #marker
	return data:sub(1, insertAt - 1)..patch..'\n'..data:sub(insertAt)
end

local function applyFirefliesPatch(data)
	if type(data) ~= 'string' then return data end
	if data:find('-- ILLUSIONHD_FIREFLIES_V1', 1, true) then
		return data
	end

	local marker = '-- ILLUSIONHD_HITEFFECTS_V1'
	local pos = data:find(marker, 1, true)
	if not pos then
		local fallback = '\nrun(function()\n\tlocal KillEffects'
		pos = data:find(fallback, 1, true)
		if not pos then
			return data
		end
	end

	local patch = [====[

-- ILLUSIONHD_FIREFLIES_V1
run(function()
	local Fireflies
	local Count
	local Radius
	local Height
	local Speed
	local Size
	local Brightness
	local ColorMode
	local PrimaryColor
	local SecondaryColor
	local Trails

	local Folder = Instance.new('Folder')
	Folder.Name = 'IllusionHDFireflies'
	Folder.Parent = workspace

	local fireflies = {}
	local rng = Random.new()

	local function currentCenter()
		if entitylib.isAlive and entitylib.character and entitylib.character.RootPart then
			return entitylib.character.RootPart.Position
		end
		if gameCamera then
			return gameCamera.CFrame.Position
		end
		return Vector3.zero
	end

	local function chooseColor(index)
		if ColorMode.Value == 'Rainbow' then
			return Color3.fromHSV((tick() * 0.08 + index / math.max(Count.Value, 1)) % 1, 0.75, 1)
		elseif ColorMode.Value == 'Warm' then
			local alpha = rng:NextNumber()
			return Color3.fromRGB(
				math.floor(255),
				math.floor(180 + 70 * alpha),
				math.floor(60 + 90 * alpha)
			)
		end

		local a = Color3.fromHSV(PrimaryColor.Hue, PrimaryColor.Sat, PrimaryColor.Value)
		local b = Color3.fromHSV(SecondaryColor.Hue, SecondaryColor.Sat, SecondaryColor.Value)
		return a:Lerp(b, rng:NextNumber())
	end

	local function randomOffset()
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist = math.sqrt(rng:NextNumber()) * Radius.Value
		local y = rng:NextNumber(-Height.Value * 0.25, Height.Value)
		return Vector3.new(math.cos(angle) * dist, y, math.sin(angle) * dist)
	end

	local function respawn(data, center)
		data.Base = center + randomOffset()
		data.Offset = Vector3.zero
		data.Phase = rng:NextNumber(0, math.pi * 2)
		data.Phase2 = rng:NextNumber(0, math.pi * 2)
		data.Drift = Vector3.new(
			rng:NextNumber(-1, 1),
			rng:NextNumber(-0.3, 0.8),
			rng:NextNumber(-1, 1)
		)
		if data.Drift.Magnitude < 0.05 then
			data.Drift = Vector3.new(1, 0.2, 0)
		end
		data.Drift = data.Drift.Unit
		data.Color = chooseColor(data.Index)
		data.Part.Color = data.Color
		data.Light.Color = data.Color
		if data.Trail then
			data.Trail.Color = ColorSequence.new(data.Color)
		end
	end

	local function createFirefly(index)
		local p = Instance.new('Part')
		p.Name = 'Firefly'
		p.Shape = Enum.PartType.Ball
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Size = Vector3.one * Size.Value
		p.Transparency = 0.05
		p.Parent = Folder

		local light = Instance.new('PointLight')
		light.Brightness = Brightness.Value
		light.Range = math.max(3, Size.Value * 22)
		light.Shadows = false
		light.Parent = p

		local att0 = Instance.new('Attachment')
		att0.Position = Vector3.new(0, 0, -Size.Value * 0.4)
		att0.Parent = p

		local att1 = Instance.new('Attachment')
		att1.Position = Vector3.new(0, 0, Size.Value * 0.4)
		att1.Parent = p

		local trail = Instance.new('Trail')
		trail.Attachment0 = att0
		trail.Attachment1 = att1
		trail.FaceCamera = true
		trail.Lifetime = 0.25
		trail.MinLength = 0.01
		trail.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.15),
			NumberSequenceKeypoint.new(1, 1)
		})
		trail.WidthScale = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, 0)
		})
		trail.Enabled = Trails.Enabled
		trail.Parent = p

		local data = {
			Index = index,
			Part = p,
			Light = light,
			Trail = trail,
			Base = Vector3.zero,
			Offset = Vector3.zero,
			Phase = 0,
			Phase2 = 0,
			Drift = Vector3.zero,
			Color = Color3.new(1, 1, 1),
			Age = rng:NextNumber(0, 8)
		}

		respawn(data, currentCenter())
		fireflies[index] = data
	end

	local function rebuild()
		for _, data in fireflies do
			pcall(function()
				data.Part:Destroy()
			end)
		end
		table.clear(fireflies)

		if not Fireflies.Enabled then return end
		for i = 1, Count.Value do
			createFirefly(i)
		end
	end

	Fireflies = vape.Categories.Render:CreateModule({
		Name = 'Fireflies',
		Function = function(callback)
			if callback then
				rebuild()

				Fireflies:Clean(runService.RenderStepped:Connect(function(dt)
					local center = currentCenter()
					local now = tick()

					for i, data in fireflies do
						if not data.Part or not data.Part.Parent then
							continue
						end

						data.Age += dt
						local speed = Speed.Value
						local bob = Vector3.new(
							math.sin(now * (0.8 + speed * 0.35) + data.Phase) * (0.7 + speed * 0.15),
							math.sin(now * (1.2 + speed * 0.22) + data.Phase2) * (0.55 + speed * 0.12),
							math.cos(now * (0.9 + speed * 0.3) + data.Phase) * (0.7 + speed * 0.15)
						)

						data.Offset += data.Drift * dt * speed * 1.5
						local target = data.Base + data.Offset + bob

						-- If the player has moved far away, recycle the firefly around the new area.
						if (target - center).Magnitude > Radius.Value * 1.45 + Height.Value then
							respawn(data, center)
							target = data.Base
						end

						-- Small random direction changes keep movement organic.
						if math.floor(data.Age * 2) ~= math.floor((data.Age - dt) * 2) and rng:NextNumber() < 0.22 then
							local change = Vector3.new(
								rng:NextNumber(-0.65, 0.65),
								rng:NextNumber(-0.2, 0.35),
								rng:NextNumber(-0.65, 0.65)
							)
							if change.Magnitude > 0.05 then
								data.Drift = (data.Drift:Lerp(change.Unit, 0.35)).Unit
							end
						end

						if ColorMode.Value == 'Rainbow' then
							data.Color = Color3.fromHSV((now * 0.08 + i / math.max(#fireflies, 1)) % 1, 0.75, 1)
							data.Part.Color = data.Color
							data.Light.Color = data.Color
							data.Trail.Color = ColorSequence.new(data.Color)
						end

						local pulse = 0.72 + math.sin(now * 2.2 + data.Phase) * 0.28
						data.Part.Size = Vector3.one * Size.Value * (0.8 + pulse * 0.3)
						data.Light.Brightness = Brightness.Value * (0.65 + pulse * 0.65)
						data.Light.Range = math.max(3, Size.Value * 22) * (0.85 + pulse * 0.25)

						data.Part.CFrame = CFrame.new(target)
					end
				end))
			else
				for _, data in fireflies do
					pcall(function()
						data.Part:Destroy()
					end)
				end
				table.clear(fireflies)
				Folder:ClearAllChildren()
			end
		end,
		Tooltip = 'Spawns glowing fireflies that drift around the world as you move.'
	})

	Count = Fireflies:CreateSlider({
		Name = 'Quantity',
		Min = 10,
		Max = 250,
		Default = 85
	})

	Radius = Fireflies:CreateSlider({
		Name = 'Radius',
		Min = 15,
		Max = 250,
		Default = 90,
		Suffix = ' studs'
	})

	Height = Fireflies:CreateSlider({
		Name = 'Height',
		Min = 5,
		Max = 80,
		Default = 30,
		Suffix = ' studs'
	})

	Speed = Fireflies:CreateSlider({
		Name = 'Speed',
		Min = 0.1,
		Max = 6,
		Default = 1.5,
		Decimal = 10
	})

	Size = Fireflies:CreateSlider({
		Name = 'Size',
		Min = 0.05,
		Max = 0.8,
		Default = 0.18,
		Decimal = 100,
		Function = function()
			for _, data in fireflies do
				if data.Part then
					data.Part.Size = Vector3.one * Size.Value
				end
			end
		end
	})

	Brightness = Fireflies:CreateSlider({
		Name = 'Brightness',
		Min = 0,
		Max = 5,
		Default = 1.8,
		Decimal = 10,
		Function = function()
			for _, data in fireflies do
				if data.Light then
					data.Light.Brightness = Brightness.Value
				end
			end
		end
	})

	ColorMode = Fireflies:CreateDropdown({
		Name = 'Color Mode',
		List = {'Custom', 'Warm', 'Rainbow'},
		Default = 'Warm',
		Function = function()
			for _, data in fireflies do
				respawn(data, currentCenter())
			end
		end
	})

	PrimaryColor = Fireflies:CreateColorSlider({
		Name = 'Primary Color',
		DefaultHue = 0.13,
		DefaultSat = 0.85,
		DefaultValue = 1,
		Function = function()
			if ColorMode.Value == 'Custom' then
				for _, data in fireflies do
					respawn(data, currentCenter())
				end
			end
		end
	})

	SecondaryColor = Fireflies:CreateColorSlider({
		Name = 'Secondary Color',
		DefaultHue = 0.18,
		DefaultSat = 0.7,
		DefaultValue = 1,
		Function = function()
			if ColorMode.Value == 'Custom' then
				for _, data in fireflies do
					respawn(data, currentCenter())
				end
			end
		end
	})

	Trails = Fireflies:CreateToggle({
		Name = 'Trails',
		Default = true,
		Function = function(callback)
			for _, data in fireflies do
				if data.Trail then
					data.Trail.Enabled = callback
				end
			end
		end
	})

	vape:Clean(function()
		for _, data in fireflies do
			pcall(function()
				data.Part:Destroy()
			end)
		end
		table.clear(fireflies)
		pcall(function()
			Folder:Destroy()
		end)
	end)
end)
-- ILLUSIONHD_FIREFLIES_END

]====]
	return data:sub(1, pos - 1)..patch..'\n'..data:sub(pos)
end

local function applySkyThemesPatch(data)
	if type(data) ~= 'string' then return data end

	local startMarker = '-- ILLUSIONHD_SKYTHEMES_V1'
	local endMarker = '-- ILLUSIONHD_SKYTHEMES_END'
	local startPos = data:find(startMarker, 1, true)
	if startPos then
		local endPos = data:find(endMarker, startPos, true)
		if endPos then
			endPos += #endMarker
			data = data:sub(1, startPos - 1)..data:sub(endPos)
		end
	end

	local marker = '-- ILLUSIONHD_FIREFLIES_V1'
	local pos = data:find(marker, 1, true)
	if not pos then
		marker = '-- ILLUSIONHD_HITEFFECTS_V1'
		pos = data:find(marker, 1, true)
	end
	if not pos then
		local fallback = '\nrun(function()\n\tlocal KillEffects'
		pos = data:find(fallback, 1, true)
	end
	if not pos then return data end

	local patch = [====[

-- ILLUSIONHD_SKYTHEMES_V1
run(function()
	local SkyThemes
	local Theme
	local lightingService = cloneref(game:GetService('Lighting'))

	local skyThemes = {
		        NetherWorld = {
			            MoonAngularSize = 0,
			            SunAngularSize = 0,
			            SkyboxBk = 'rbxassetid://14365019002',
			            SkyboxDn = 'rbxassetid://14365023350',
			            SkyboxFt = 'rbxassetid://14365018399',
			            SkyboxLf = 'rbxassetid://14365018705',
			            SkyboxRt = 'rbxassetid://14365018143',
			            SkyboxUp = 'rbxassetid://14365019327',
		        },
		        Neptune = {
				    SkyboxBk = 'rbxassetid://218955819',
				    SkyboxDn = 'rbxassetid://218953419',
				    SkyboxFt = 'rbxassetid://218954524',
				    SkyboxLf = 'rbxassetid://218958493',
				    SkyboxRt = 'rbxassetid://218957134',
				    SkyboxUp = 'rbxassetid://218950090',
		        },
		        Velocity = {
			            SkyboxBk = 'rbxassetid://570557514',
			            SkyboxDn = 'rbxassetid://570557775',
			            SkyboxFt = 'rbxassetid://570557559',
			            SkyboxLf = 'rbxassetid://570557620',
			            SkyboxRt = 'rbxassetid://570557672',
			            SkyboxUp = 'rbxassetid://570557727',
		        },
		        Minecraft = {
			            SkyboxBk = 'rbxassetid://591058823',
			            SkyboxDn = 'rbxassetid://591059876',
			            SkyboxFt = 'rbxassetid://591058104',
			            SkyboxLf = 'rbxassetid://591057861',
			            SkyboxRt = 'rbxassetid://591057625',
			            SkyboxUp = 'rbxassetid://591059642',
		        },
		        Purple = {
			            SkyboxBk = "rbxassetid://8539982183",
			            SkyboxDn = "rbxassetid://8539981943",
			            SkyboxFt = "rbxassetid://8539981721",
			            SkyboxLf = "rbxassetid://8539981424",
			            SkyboxRt = "rbxassetid://8539980766",
			            SkyboxUp = "rbxassetid://8539981085",
			            MoonAngularSize = 0,
			            SunAngularSize = 0,
			            StarCount = 3000,
		        }, 
		        ["日の出"] = {
				    SkyboxBk = "rbxassetid://600830446",
				    SkyboxDn = "rbxassetid://600831635",
				    SkyboxFt = "rbxassetid://600832720",
				    SkyboxLf = "rbxassetid://600886090",
				    SkyboxRt = "rbxassetid://600833862",
				    SkyboxUp = "rbxassetid://600835177",
		        },
		        Sakura = {
			            SkyboxBk = "http://www.roblox.com/asset/?id=16694315897",
			            SkyboxDn = "http://www.roblox.com/asset/?id=16694319417",
			            SkyboxFt = "http://www.roblox.com/asset/?id=16694324910",
			            SkyboxLf = "http://www.roblox.com/asset/?id=16694328308",
			            SkyboxRt = "http://www.roblox.com/asset/?id=16694331447",
			            SkyboxUp = "http://www.roblox.com/asset/?id=16694334666",
			            SunAngularSize = 21,
			            StarCount = 3000,
		        },
		        Hexagonal = {
			            SkyboxBk = "http://www.roblox.com/asset/?id=15876463105",
			            SkyboxDn = "http://www.roblox.com/asset/?id=15876464432",
			            SkyboxFt = "http://www.roblox.com/asset/?id=15876465852",
			            SkyboxLf = "http://www.roblox.com/asset/?id=15876467260",
			            SkyboxRt = "http://www.roblox.com/asset/?id=15876469097",
			            SkyboxUp = "http://www.roblox.com/asset/?id=15876470945",
			            SunAngularSize = 21,
			            StarCount = 3000,
		        },
		        Reality = {
			            SkyboxBk = "http://www.roblox.com/asset/?id=6778646360",
			            SkyboxDn = "http://www.roblox.com/asset/?id=6778658683",
			            SkyboxFt = "http://www.roblox.com/asset/?id=6778648039",
			            SkyboxLf = "http://www.roblox.com/asset/?id=6778649136",
			            SkyboxRt = "http://www.roblox.com/asset/?id=6778650519",
			            SkyboxUp = "http://www.roblox.com/asset/?id=6778658364",
		        },
		        LunarNight = {
			            SkyboxBk = 'rbxassetid://187713366',
			            SkyboxDn = 'rbxassetid://187712428',
			            SkyboxFt = 'rbxassetid://187712836',
			            SkyboxLf = 'rbxassetid://187713755',
			            SkyboxRt = 'rbxassetid://187714525',
			            SkyboxUp = 'rbxassetid://187712111',
			            SunAngularSize = 0,
			            StarCount = 0,
		        },
		        FPSBoost = {
			            SkyboxBk = 'rbxassetid://11457548274',
			            SkyboxDn = 'rbxassetid://11457548274',
			            SkyboxFt = 'rbxassetid://11457548274',
			            SkyboxLf = 'rbxassetid://11457548274',
			            SkyboxRt = 'rbxassetid://11457548274',
			            SkyboxUp = 'rbxassetid://11457548274',
			            SunAngularSize = 0,
			            StarCount = 3000,
		        },
		        Etheral = {
			            SkyboxBk = 'rbxassetid://16262356578',
			            SkyboxDn = 'rbxassetid://16262358026',
			            SkyboxFt = 'rbxassetid://16262360469',
			            SkyboxLf = 'rbxassetid://16262362003',
			            SkyboxRt = 'rbxassetid://16262363873',
			            SkyboxUp = 'rbxassetid://16262366016',
			            SunAngularSize = 21,
			            StarCount = 3000,
		        },
		        Pandora = {
			            SkyboxBk = 'http://www.roblox.com/asset/?id=16739324092',
			            SkyboxDn = 'http://www.roblox.com/asset/?id=16739325541',
			            SkyboxFt = 'http://www.roblox.com/asset/?id=16739327056',
			            SkyboxLf = 'http://www.roblox.com/asset/?id=16739329370',
			            SkyboxRt = 'http://www.roblox.com/asset/?id=16739331050',
			            SkyboxUp = 'http://www.roblox.com/asset/?id=16739332736',
			            SunAngularSize = 21,
			            StarCount = 3000,
		        },
		        Polaris = {
			            SkyboxBk = 'http://www.roblox.com/asset/?id=16823270864',
			            SkyboxDn = 'http://www.roblox.com/asset/?id=16823272150',
			            SkyboxFt = 'http://www.roblox.com/asset/?id=16823273508',
			            SkyboxLf = 'http://www.roblox.com/asset/?id=16823274898',
			            SkyboxRt = 'http://www.roblox.com/asset/?id=16823276281',
			            SkyboxUp = 'http://www.roblox.com/asset/?id=16823277547',
			            SunAngularSize = 21,
			            StarCount = 3000,
		        },
		        Diaphanous = {
			            SkyboxBk = 'http://www.roblox.com/asset/?id=16888989874',
			            SkyboxDn = 'http://www.roblox.com/asset/?id=16888991855',
			            SkyboxFt = 'http://www.roblox.com/asset/?id=16888995219',
			            SkyboxLf = 'http://www.roblox.com/asset/?id=16888998994',
			            SkyboxRt = 'http://www.roblox.com/asset/?id=16889000916',
			            SkyboxUp = 'http://www.roblox.com/asset/?id=16889004122',
			            SunAngularSize = 21,
			            StarCount = 3000,
		        },
		        Transcendent = {
			            SkyboxBk = 'http://www.roblox.com/asset/?id=17124357467',
			            SkyboxDn = 'http://www.roblox.com/asset/?id=17124359797',
			            SkyboxFt = 'http://www.roblox.com/asset/?id=17124362093',
			            SkyboxLf = 'http://www.roblox.com/asset/?id=17124365127',
			            SkyboxRt = 'http://www.roblox.com/asset/?id=17124367200',
			            SkyboxUp = 'http://www.roblox.com/asset/?id=17124369657',
			            SunAngularSize = 21,
			            StarCount = 3000,
		        },
		        Truth = {
			            SkyboxBk = "http://www.roblox.com/asset/?id=144933338",
			            SkyboxDn = "http://www.roblox.com/asset/?id=144931530",
			            SkyboxFt = "http://www.roblox.com/asset/?id=144933262",
			            SkyboxLf = "http://www.roblox.com/asset/?id=144933244",
			            SkyboxRt = "http://www.roblox.com/asset/?id=144933299",
			            SkyboxUp = "http://www.roblox.com/asset/?id=144931564",
		        },
		        RayTracing = {
			            SkyboxBk = "http://www.roblox.com/asset/?id=271042516",
			            SkyboxDn = "http://www.roblox.com/asset/?id=271077243",
			            SkyboxFt = "http://www.roblox.com/asset/?id=271042556",
			            SkyboxLf = "http://www.roblox.com/asset/?id=271042310",
			            SkyboxRt = "http://www.roblox.com/asset/?id=271042467",
			            SkyboxUp = "http://www.roblox.com/asset/?id=271077958",
		        },
		        Nebula = {
			            MoonAngularSize = 0,
			            SunAngularSize = 0,
			            SkyboxBk = 'rbxassetid://5260808177',
			            SkyboxDn = 'rbxassetid://5260653793',
			            SkyboxFt = 'rbxassetid://5260817288',
			            SkyboxLf = 'rbxassetid://5260800833',
			            SkyboxRt = 'rbxassetid://5260811073',
			            SkyboxUp = 'rbxassetid://5260824661',
		        },
		        Planets = {
			            MoonAngularSize = 0,
			            SunAngularSize = 0,
			            SkyboxBk = 'rbxassetid://15983968922',
			            SkyboxDn = 'rbxassetid://15983966825',
			            SkyboxFt = 'rbxassetid://15983965025',
			            SkyboxLf = 'rbxassetid://15983967420',
			            SkyboxRt = 'rbxassetid://15983966246',
			            SkyboxUp = 'rbxassetid://15983964246',
			            StarCount = 3000,
		        },
		        Galaxy = {
			            SkyboxBk = "rbxassetid://159454299",
			            SkyboxDn = "rbxassetid://159454296",
			            SkyboxFt = "rbxassetid://159454293",
			            SkyboxLf = "rbxassetid://159454293",
			            SkyboxRt = "rbxassetid://159454293",
			            SkyboxUp = "rbxassetid://159454288",
			            SunAngularSize = 0,
		        }, 
		        Blues = {
			            SkyboxBk = 'http://www.roblox.com/asset/?id=17124357467',
			            SkyboxDn = 'http://www.roblox.com/asset/?id=17124359797',
			            SkyboxFt = 'http://www.roblox.com/asset/?id=17124362093',
			            SkyboxLf = 'http://www.roblox.com/asset/?id=17124365127',
			            SkyboxRt = 'http://www.roblox.com/asset/?id=17124367200',
			            SkyboxUp = 'http://www.roblox.com/asset/?id=17124369657',
			            SunAngularSize = 21,
			            StarCount = 3000,
		        },
		        Milkyway = {
			            MoonTextureId = 'rbxassetid://1075087760',
			            SkyboxBk = 'rbxassetid://2670643994',
			            SkyboxDn = 'rbxassetid://2670643365',
			            SkyboxFt = 'rbxassetid://2670643214',
			            SkyboxLf = 'rbxassetid://2670643070',
			            SkyboxRt = 'rbxassetid://2670644173',
			            SkyboxUp = 'rbxassetid://2670644331',
			            MoonAngularSize = 1.5,
			            StarCount = 500,
		        },
		        Orange = {
			            SkyboxBk = 'rbxassetid://150939022',
			            SkyboxDn = 'rbxassetid://150939038',
			            SkyboxFt = 'rbxassetid://150939047',
			            SkyboxLf = 'rbxassetid://150939056',
			            SkyboxRt = 'rbxassetid://150939063',
			            SkyboxUp = 'rbxassetid://150939082',
		        },
		        DarkMountains = {
			            SkyboxBk = 'rbxassetid://5098814730',
			            SkyboxDn = 'rbxassetid://5098815227',
			            SkyboxFt = 'rbxassetid://5098815653',
			            SkyboxLf = 'rbxassetid://5098816155',
			            SkyboxRt = 'rbxassetid://5098820352',
			            SkyboxUp = 'rbxassetid://5098819127',
		        },
		        Space = {
			            MoonAngularSize = 0,
			            SunAngularSize = 0,
			            SkyboxBk = 'rbxassetid://166509999',
			            SkyboxDn = 'rbxassetid://166510057',
			            SkyboxFt = 'rbxassetid://166510116',
			            SkyboxLf = 'rbxassetid://166510092',
			            SkyboxRt = 'rbxassetid://166510131',
			            SkyboxUp = 'rbxassetid://166510114',
		        },
		        Void = {
			            MoonAngularSize = 0,
			            SunAngularSize = 0,
			            SkyboxBk = 'rbxassetid://14543264135',
			            SkyboxDn = 'rbxassetid://14543358958',
			            SkyboxFt = 'rbxassetid://14543257810',
			            SkyboxLf = 'rbxassetid://14543275895',
			            SkyboxRt = 'rbxassetid://14543280890',
			            SkyboxUp = 'rbxassetid://14543371676',
		        },
		        Stary = {
			            SkyboxBk = 'rbxassetid://248431616',
			            SkyboxDn = 'rbxassetid://248431677',
			            SkyboxFt = 'rbxassetid://248431598',
			            SkyboxLf = 'rbxassetid://248431686',
			            SkyboxRt = 'rbxassetid://248431611',
			            SkyboxUp = 'rbxassetid://248431605',
				    StarCount = 3000,       
		        },
			Violet = {
				    SkyboxBk = 'rbxassetid://8107841671',
				    SkyboxDn = 'rbxassetid://6444884785',
				    SkyboxFt = 'rbxassetid://8107841671',
				    SkyboxLf = 'rbxassetid://8107841671',
				    SkyboxRt = 'rbxassetid://8107841671',
				    SkyboxUp = 'rbxassetid://8107849791',
				    SunTextureId = 'rbxassetid://6196665106',
				    MoonTextureId = 'rbxassetid://6444320592',
				    MoonAngularSize = 0,
		        },
			Cloudy = {
				    SkyboxBk = 'rbxassetid://15876597103',
				    SkyboxDn = 'rbxassetid://15876592775',
				    SkyboxFt = 'rbxassetid://15876640231',
				    SkyboxLf = 'rbxassetid://15876638420',
				    SkyboxRt = 'rbxassetid://15876595486',
				    SkyboxUp = 'rbxassetid://15876639348',
				    SunTextureId = 'rbxasset://sky/sun.jpg',
				    MoonTextureId = 'rbxasset://sky/moon.jpg',
				    MoonAngularSize = 11,
		            	    SunAngularSize = 21,
				    StarCount = 3000,
		    	}
	}
	local themeNames = {'NetherWorld', 'Neptune', 'Velocity', 'Minecraft', 'Purple', '日の出', 'Sakura', 'Hexagonal', 'Reality', 'LunarNight', 'FPSBoost', 'Etheral', 'Pandora', 'Polaris', 'Diaphanous', 'Transcendent', 'Truth', 'RayTracing', 'Nebula', 'Planets', 'Galaxy', 'Blues', 'Milkyway', 'Orange', 'DarkMountains', 'Space', 'Void', 'Stary', 'Violet', 'Cloudy'}

	local skyProperties = {
		'CelestialBodiesShown',
		'MoonAngularSize',
		'MoonTextureId',
		'SkyboxBk',
		'SkyboxDn',
		'SkyboxFt',
		'SkyboxLf',
		'SkyboxRt',
		'SkyboxUp',
		'SkyboxOrientation',
		'SunAngularSize',
		'SunTextureId',
		'SunTextureId',
		'StarCount'
	}

	local defaultSky = Instance.new('Sky')
	local defaults = {}
	for _, property in skyProperties do
		pcall(function()
			defaults[property] = defaultSky[property]
		end)
	end
	defaultSky:Destroy()

	local storedSkies = Instance.new('Folder')
	storedSkies.Name = 'IllusionHDStoredSkies'
	storedSkies.Parent = vape.holder

	local activeSky

	local function resetSky(sky)
		for property, value in defaults do
			pcall(function()
				sky[property] = value
			end)
		end
	end

	local function applyTheme(name)
		local data = skyThemes[name]
		if not data then return end

		if not activeSky or not activeSky.Parent then
			activeSky = Instance.new('Sky')
			activeSky.Name = 'IllusionHDSky'
			activeSky.Parent = lightingService
		end

		-- Reset first so one theme cannot leak StarCount/sun/moon settings into another.
		resetSky(activeSky)

		for property, value in data do
			pcall(function()
				activeSky[property] = value
			end)
		end
	end

	local function storeGameSkies()
		for _, obj in lightingService:GetChildren() do
			if obj:IsA('Sky') and obj ~= activeSky then
				obj.Parent = storedSkies
			end
		end
	end

	local function restoreGameSkies()
		if activeSky then
			activeSky:Destroy()
			activeSky = nil
		end

		for _, obj in storedSkies:GetChildren() do
			if obj:IsA('Sky') then
				obj.Parent = lightingService
			end
		end
	end

	SkyThemes = vape.Categories.Render:CreateModule({
		Name = 'SkyThemes',
		Function = function(callback)
			if callback then
				storeGameSkies()
				applyTheme(Theme.Value)

				SkyThemes:Clean(lightingService.ChildAdded:Connect(function(obj)
					if obj:IsA('Sky') and obj ~= activeSky then
						task.defer(function()
							if SkyThemes.Enabled and obj.Parent == lightingService and obj ~= activeSky then
								obj.Parent = storedSkies
							end
						end)
					end
				end))
			else
				restoreGameSkies()
			end
		end,
		Tooltip = 'Replaces the game sky with selectable custom skybox themes.'
	})

	Theme = SkyThemes:CreateDropdown({
		Name = 'Theme',
		List = themeNames,
		Default = 'Purple',
		Function = function(value)
			if SkyThemes.Enabled then
				applyTheme(value)
			end
		end
	})

	vape:Clean(function()
		restoreGameSkies()
		pcall(function()
			storedSkies:Destroy()
		end)
	end)
end)
-- ILLUSIONHD_SKYTHEMES_END

]====]
	return data:sub(1, pos - 1)..patch..'\n'..data:sub(pos)
end

local function applyCustomKnifePatch(data)
	if type(data) ~= 'string' then return data end

	-- Remove any previous CustomKnife version first.
	for _, startMarker in {
		'-- ILLUSIONHD_CUSTOMKNIFE_V1',
		'-- ILLUSIONHD_CUSTOMKNIFE_V2'
	} do
		local startPos = data:find(startMarker, 1, true)
		if startPos then
			local endMarker = '-- ILLUSIONHD_CUSTOMKNIFE_END'
			local endPos = data:find(endMarker, startPos, true)
			if endPos then
				endPos += #endMarker
				data = data:sub(1, startPos - 1)..data:sub(endPos)
			end
		end
	end

	local marker = '-- ILLUSIONHD_SKYTHEMES_V1'
	local pos = data:find(marker, 1, true)
	if not pos then
		marker = '-- ILLUSIONHD_FIREFLIES_V1'
		pos = data:find(marker, 1, true)
	end
	if not pos then
		marker = '-- ILLUSIONHD_HITEFFECTS_V1'
		pos = data:find(marker, 1, true)
	end
	if not pos then
		local fallback = '\nrun(function()\n\tlocal KillEffects'
		pos = data:find(fallback, 1, true)
	end
	if not pos then return data end

	local patch = [====[
-- ILLUSIONHD_CUSTOMKNIFE_V2
run(function()
	local CustomKnife
	local AssetID
	local AssetModel
	local TargetModel
	local Scale
	local OffsetX
	local OffsetY
	local OffsetZ
	local RotationX
	local RotationY
	local RotationZ
	local HideOriginal

	local optionsReady = false
	local started = false

	local Folder = Instance.new('Folder')
	Folder.Name = 'IllusionHDCustomKnife'
	Folder.Parent = gameCamera

	local validNames = {
		Knife1 = true,
		Knife2 = true,
		combat_knife = true
	}

	local template
	local visual
	local currentTarget
	local hiddenParts = {}
	local lastSearch = 0

	local function value(option, fallback)
		if option and option.Value ~= nil then
			return option.Value
		end
		return fallback
	end

	local function enabled(option, fallback)
		if option and option.Enabled ~= nil then
			return option.Enabled
		end
		return fallback
	end

	local function restoreOriginal()
		for part, transparency in hiddenParts do
			if part and part.Parent then
				pcall(function()
					part.LocalTransparencyModifier = transparency
				end)
			end
		end
		table.clear(hiddenParts)
	end

	local function destroyVisual()
		if visual then
			visual:Destroy()
			visual = nil
		end
		currentTarget = nil
		restoreOriginal()
	end

	local function getObjectCFrame(obj)
		if not obj then return nil end

		if obj:IsA('BasePart') then
			return obj.CFrame
		elseif obj:IsA('Model') then
			local ok, cf = pcall(function()
				return obj:GetPivot()
			end)
			return ok and cf or nil
		elseif obj:IsA('Attachment') then
			return obj.WorldCFrame
		elseif obj:IsA('Bone') then
			return obj.TransformedWorldCFrame
		end

		local part = obj:FindFirstChildWhichIsA('BasePart', true)
		return part and part.CFrame or nil
	end

	local function addSearchRoot(list, seen, obj)
		if typeof(obj) ~= 'Instance' or seen[obj] then return end
		seen[obj] = true
		table.insert(list, obj)
	end

	local function getSearchRoots()
		local roots = {}
		local seen = {}

		addSearchRoot(roots, seen, gameCamera)
		addSearchRoot(roots, seen, lplr.Character)

		local instances = frontlines.Main
			and frontlines.Main.globals
			and frontlines.Main.globals.fpv_sol_instances

		if type(instances) == 'table' then
			for _, obj in instances do
				addSearchRoot(roots, seen, obj)
			end
		end

		return roots
	end

	local function findKnifeObjects()
		local found = {}
		local used = {}

		local function add(obj)
			if not obj or used[obj] then return end
			if obj == Folder or obj:IsDescendantOf(Folder) then return end

			if validNames[obj.Name] then
				used[obj] = true
				table.insert(found, obj)
			end
		end

		for _, root in getSearchRoots() do
			add(root)
			for _, obj in root:GetDescendants() do
				add(obj)
			end
		end

		return found
	end

	local function chooseTarget(objects)
		if #objects == 0 then return nil end

		local selected = value(TargetModel, 'Auto')
		if selected ~= 'Auto' then
			for _, obj in objects do
				if obj.Name == selected then
					return obj
				end
			end
		end

		-- Prefer the whole knife model when available.
		for _, wanted in {'combat_knife', 'Knife1', 'Knife2'} do
			for _, obj in objects do
				if obj.Name == wanted then
					return obj
				end
			end
		end

		return objects[1]
	end

	local function hideKnifeObjects(objects)
		restoreOriginal()
		if not enabled(HideOriginal, true) then return end

		for _, obj in objects do
			if obj:IsA('BasePart') then
				if hiddenParts[obj] == nil then
					hiddenParts[obj] = obj.LocalTransparencyModifier
					obj.LocalTransparencyModifier = 1
				end
			else
				for _, desc in obj:GetDescendants() do
					if desc:IsA('BasePart') and hiddenParts[desc] == nil then
						hiddenParts[desc] = desc.LocalTransparencyModifier
						desc.LocalTransparencyModifier = 1
					end
				end
			end
		end
	end

	local function findAssetObject(root)
		if not root then return nil end

		local selected = value(AssetModel, 'Auto')
		if selected ~= 'Auto' then
			if root.Name == selected then
				return root
			end

			local exact = root:FindFirstChild(selected, true)
			if exact then
				return exact
			end
		end

		-- Your model layout:
		-- combat_knife
		--   Knife1
		--   Knife2
		-- so Auto intentionally grabs combat_knife as a whole.
		if root.Name == 'combat_knife' then
			return root
		end

		local combat = root:FindFirstChild('combat_knife', true)
		if combat then
			return combat
		end

		if validNames[root.Name] then
			return root
		end

		for _, wantedName in {'Knife1', 'Knife2'} do
			local exact = root:FindFirstChild(wantedName, true)
			if exact then
				return exact
			end
		end

		-- Generic wrapper fallback.
		return root
	end

	local function makeTemplate(obj)
		local wrapper = Instance.new('Model')
		wrapper.Name = 'CustomKnifeTemplate'

		local clone = obj:Clone()

		if clone:IsA('Model') then
			-- Keep the cloned model intact so Knife1 + Knife2 retain their
			-- relative transforms inside combat_knife.
			clone.Parent = wrapper
		else
			clone.Parent = wrapper
		end

		for _, desc in wrapper:GetDescendants() do
			if desc:IsA('Script') or desc:IsA('LocalScript') or desc:IsA('ModuleScript') then
				desc:Destroy()
			elseif desc:IsA('BasePart') then
				desc.Anchored = true
				desc.CanCollide = false
				desc.CanTouch = false
				desc.CanQuery = false
				desc.CastShadow = false
				desc.Massless = true
			end
		end

		if not wrapper:FindFirstChildWhichIsA('BasePart', true) then
			wrapper:Destroy()
			return nil
		end

		return wrapper
	end

	local function rebuildVisual()
		if visual then
			visual:Destroy()
			visual = nil
		end

		if not template or not CustomKnife or not CustomKnife.Enabled then
			return
		end

		visual = template:Clone()
		visual.Name = 'IllusionHDCustomKnifeModel'

		pcall(function()
			visual:ScaleTo(value(Scale, 1))
		end)

		for _, desc in visual:GetDescendants() do
			if desc:IsA('BasePart') then
				desc.Anchored = true
				desc.CanCollide = false
				desc.CanTouch = false
				desc.CanQuery = false
				desc.CastShadow = false
				desc.Massless = true
			end
		end

		visual.Parent = Folder
	end

	local function loadAsset(showError)
		if not optionsReady then return end

		if template then
			template:Destroy()
			template = nil
		end

		destroyVisual()

		local id = tostring(value(AssetID, '')):match('%d+')
		if not id then
			if showError then
				notif('CustomKnife', 'Enter a valid asset ID.', 5, 'alert')
			end
			return
		end

		local success, objects = pcall(function()
			return game:GetObjects('rbxassetid://'..id)
		end)

		if not success or type(objects) ~= 'table' or not objects[1] then
			notif('CustomKnife', 'Failed to load asset '..id, 5, 'alert')
			return
		end

		local root = objects[1]
		local chosen = findAssetObject(root)

		if chosen then
			local ok, result = pcall(makeTemplate, chosen)
			if ok then
				template = result
			end
		end

		for _, obj in objects do
			pcall(function()
				obj:Destroy()
			end)
		end

		if not template then
			notif('CustomKnife', 'Asset has no usable combat_knife / Knife1 / Knife2 model.', 5, 'alert')
			return
		end

		rebuildVisual()
		currentTarget = nil
		lastSearch = 0
	end

	local function updateVisual()
		if not optionsReady or not visual or not visual.Parent then return end

		local now = tick()
		if not currentTarget or not currentTarget.Parent or now - lastSearch > 0.25 then
			lastSearch = now

			local objects = findKnifeObjects()
			currentTarget = chooseTarget(objects)
			hideKnifeObjects(objects)
		end

		if not currentTarget then
			visual.Parent = nil
			return
		end

		if visual.Parent ~= Folder then
			visual.Parent = Folder
		end

		local cf = getObjectCFrame(currentTarget)
		if not cf then return end

		local offset = CFrame.new(
			value(OffsetX, 0),
			value(OffsetY, 0),
			value(OffsetZ, 0)
		) * CFrame.Angles(
			math.rad(value(RotationX, 0)),
			math.rad(value(RotationY, 0)),
			math.rad(value(RotationZ, 0))
		)

		pcall(function()
			visual:PivotTo(cf * offset)
		end)
	end

	local function startKnife()
		if started or not optionsReady or not CustomKnife or not CustomKnife.Enabled then
			return
		end
		started = true

		if tostring(value(AssetID, '')):match('%d+') then
			loadAsset(false)
		end

		CustomKnife:Clean(runService.RenderStepped:Connect(updateVisual))

		CustomKnife:Clean(entitylib.Events.LocalAdded:Connect(function()
			task.delay(0.5, function()
				if CustomKnife and CustomKnife.Enabled and optionsReady then
					currentTarget = nil
					lastSearch = 0

					if template then
						rebuildVisual()
					elseif tostring(value(AssetID, '')):match('%d+') then
						loadAsset(false)
					end
				end
			end)
		end))
	end

	local function stopKnife()
		started = false
		destroyVisual()
	end

	CustomKnife = vape.Categories.Render:CreateModule({
		Name = 'CustomKnife',
		Function = function(callback)
			if callback then
				-- Vape can restore this module from config before its controls
				-- below have finished being created. Wait until they exist.
				task.defer(function()
					while CustomKnife and CustomKnife.Enabled and not optionsReady do
						task.wait()
					end

					if CustomKnife and CustomKnife.Enabled and optionsReady then
						startKnife()
					end
				end)
			else
				stopKnife()
			end
		end,
		Tooltip = 'Replaces the local FPV knife with a model loaded from a Roblox asset ID.'
	})

	AssetID = CustomKnife:CreateTextBox({
		Name = 'Asset ID',
		Default = '',
		Function = function()
			if optionsReady and CustomKnife.Enabled then
				loadAsset(false)
			end
		end
	})

	AssetModel = CustomKnife:CreateDropdown({
		Name = 'Asset Model',
		List = {'Auto', 'Knife1', 'Knife2', 'combat_knife'},
		Default = 'Auto',
		Function = function()
			if optionsReady
				and CustomKnife.Enabled
				and tostring(value(AssetID, '')):match('%d+') then
				loadAsset(false)
			end
		end
	})

	TargetModel = CustomKnife:CreateDropdown({
		Name = 'Target Model',
		List = {'Auto', 'Knife1', 'Knife2', 'combat_knife'},
		Default = 'Auto',
		Function = function()
			if not optionsReady then return end
			currentTarget = nil
			lastSearch = 0
		end
	})

	Scale = CustomKnife:CreateSlider({
		Name = 'Scale',
		Min = 0.1,
		Max = 5,
		Default = 1,
		Decimal = 100,
		Function = function()
			if optionsReady and CustomKnife.Enabled and template then
				rebuildVisual()
			end
		end
	})

	OffsetX = CustomKnife:CreateSlider({
		Name = 'Offset X',
		Min = -5,
		Max = 5,
		Default = 0,
		Decimal = 100
	})

	OffsetY = CustomKnife:CreateSlider({
		Name = 'Offset Y',
		Min = -5,
		Max = 5,
		Default = 0,
		Decimal = 100
	})

	OffsetZ = CustomKnife:CreateSlider({
		Name = 'Offset Z',
		Min = -5,
		Max = 5,
		Default = 0,
		Decimal = 100
	})

	RotationX = CustomKnife:CreateSlider({
		Name = 'Rotation X',
		Min = -180,
		Max = 180,
		Default = 0
	})

	RotationY = CustomKnife:CreateSlider({
		Name = 'Rotation Y',
		Min = -180,
		Max = 180,
		Default = 0
	})

	RotationZ = CustomKnife:CreateSlider({
		Name = 'Rotation Z',
		Min = -180,
		Max = 180,
		Default = 0
	})

	HideOriginal = CustomKnife:CreateToggle({
		Name = 'Hide Original',
		Default = true,
		Function = function(callback)
			if not optionsReady then return end

			currentTarget = nil
			lastSearch = 0

			if not callback then
				restoreOriginal()
			end
		end
	})

	optionsReady = true

	-- Handles the case where Vape restored CustomKnife.Enabled from config
	-- before the option objects above existed.
	if CustomKnife.Enabled then
		task.defer(startKnife)
	end

	vape:Clean(function()
		stopKnife()

		if template then
			template:Destroy()
			template = nil
		end

		pcall(function()
			Folder:Destroy()
		end)
	end)
end)
-- ILLUSIONHD_CUSTOMKNIFE_END
]====]
	return data:sub(1, pos - 1)..patch..'\n'..data:sub(pos)
end

local function writeRemote(remotePath, localPath, required)
	local data = getRemote(remotePath)
	if not data then
		if required then
			error('Failed to download '..remotePath..' from '..OWNER..'/'..REPO, 2)
		end
		return false
	end

	if remotePath == 'main.lua' then
		data = applyLeaveSoundPatch(data)
	elseif remotePath == 'games/5938036553.lua' or remotePath == '5938036553.lua' then
		data = repairFrontlines(data)
		data = applyHitEffectsPatch(data)
		data = applyKillEffectsVisualPatch(data)
		data = applyFirefliesPatch(data)
		data = applySkyThemesPatch(data)
		data = applyCustomKnifePatch(data)
	end

	ensureParent(localPath)
	if localPath:match('%.lua$') and not data:find('--This watermark is used to delete the file if its cached', 1, true) then
		data = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..data
	end
	writefile(localPath, data)
	return true
end

local profileFiles = {
	['10314536465.gui.txt'] = true,
	['2132866904.gui.txt'] = true,
	['asset.txt'] = true,
	['commit.txt'] = true,
	['default5938036553.txt'] = true,
	['default87228682752583.txt'] = true,
	['gui.txt'] = true,
	['spotify.txt'] = true,
	['spotifydata.txt'] = true,
	['whitelist.json'] = true
}

local flatMirrors = {
	['5938036553.lua'] = 'games/5938036553.lua',
	['universal.lua'] = 'games/universal.lua',
	['drawing.lua'] = 'libraries/drawing.lua',
	['entity.lua'] = 'libraries/entity.lua',
	['hash.lua'] = 'libraries/hash.lua',
	['prediction.lua'] = 'libraries/prediction.lua',
	['loading.lua'] = 'guis/loading.lua',
	['new.lua'] = 'guis/new.lua',
	['rise-v7.lua'] = 'guis/rise-v7.lua',
	['themes.lua'] = 'guis/themes.lua',
	['RISE-V7.md'] = 'guis/RISE-V7.md'
}

local function destinationFor(remotePath, treePaths)
	if remotePath == 'main.lua' then
		return 'newvape/main.lua'
	elseif remotePath == 'loader.lua' then
		return 'newvape/loader.lua'
	elseif remotePath == 'headshot.mp3' then
		return 'newvape/headshot.mp3'
	elseif profileFiles[remotePath] then
		return 'newvape/profiles/'..remotePath
	elseif flatMirrors[remotePath] then
		if treePaths and treePaths[flatMirrors[remotePath]] then
			return nil
		end
		return 'newvape/'..flatMirrors[remotePath]
	elseif remotePath:match('^(assets|games|guis|libraries|rise|wurst)/') then
		return 'newvape/'..remotePath
	end
	return 'newvape/'..remotePath
end

if not shared.VapeDeveloper then
	local treeBody = httpGet(API_TREE)
	if treeBody then
		local ok, treeData = pcall(function()
			return httpService:JSONDecode(treeBody)
		end)
		if ok and type(treeData) == 'table' and type(treeData.tree) == 'table' then
			local treePaths = {}
			for _, item in treeData.tree do
				if item.type == 'blob' and type(item.path) == 'string' then
					treePaths[item.path] = true
				end
			end
			for _, item in treeData.tree do
				if item.type == 'blob' and type(item.path) == 'string' then
					local localPath = destinationFor(item.path, treePaths)
					if localPath then
						writeRemote(item.path, localPath, false)
					end
				end
			end
		end
	end
end

local required = {
	{'main.lua', 'newvape/main.lua'},
	{'loader.lua', 'newvape/loader.lua'},
	{'guis/loading.lua', 'newvape/guis/loading.lua'},
	{'guis/themes.lua', 'newvape/guis/themes.lua'},
	{'guis/new.lua', 'newvape/guis/new.lua'},
	{'guis/rise-v7.lua', 'newvape/guis/rise-v7.lua'},
	{'games/universal.lua', 'newvape/games/universal.lua'},
	{'games/5938036553.lua', 'newvape/games/5938036553.lua'},
	{'libraries/drawing.lua', 'newvape/libraries/drawing.lua'},
	{'libraries/entity.lua', 'newvape/libraries/entity.lua'},
	{'libraries/hash.lua', 'newvape/libraries/hash.lua'},
	{'libraries/prediction.lua', 'newvape/libraries/prediction.lua'}
}

for _, pair in required do
	if not isfile(pair[2]) then
		writeRemote(pair[1], pair[2], true)
	end
end

-- Re-apply the Frontlines hotfix even if a repo sync just overwrote the local file.
if isfile('newvape/games/5938036553.lua') then
	local data = readfile('newvape/games/5938036553.lua')
	local fixed = applyCustomKnifePatch(applySkyThemesPatch(applyFirefliesPatch(applyKillEffectsVisualPatch(applyHitEffectsPatch(repairFrontlines(data))))))
	if fixed ~= data then
		writefile('newvape/games/5938036553.lua', fixed)
	end
end

if not isfile('newvape/headshot.mp3') then
	writeRemote('headshot.mp3', 'newvape/headshot.mp3', false)
end

writefile('newvape/profiles/commit.txt', BRANCH)

if isfile('newvape/main.lua') then
	local data = readfile('newvape/main.lua')
	local fixed = applyLeaveSoundPatch(data)
	if fixed ~= data then
		writefile('newvape/main.lua', fixed)
	end
end

return loadstring(readfile('newvape/main.lua'), 'main')()
