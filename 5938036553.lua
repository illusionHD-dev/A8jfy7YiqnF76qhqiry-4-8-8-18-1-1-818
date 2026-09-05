-- Local customization: additive Legit speed (+1.7 studs/second).
local loadstring = function(...)
	local res, err = loadstring(...)
	if err and vape then
		vape:CreateNotification('Vape', 'Failed to load : '..err, 30, 'alert')
	end
	return res
end
local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end
local function downloadFile(path, func)
	if not isfile(path) then
		local suc, res = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/7GrandDadPGN/illusionhd-dev/A8jfy7YiqnF76qhqiry-4-8-8-18-1-1-818/'..readfile('newvape/profiles/commit.txt')..'/'..select(1, path:gsub('newvape/', '')), true)
		end)
		if not suc or res == '404: Not Found' then
			error(res)
		end
		if path:find('.lua') then
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end
local run = function(func)
	func()
end
local cloneref = cloneref or function(obj)
	return obj
end

local playersService = cloneref(game:GetService('Players'))
local inputService = cloneref(game:GetService('UserInputService'))
local runService = cloneref(game:GetService('RunService'))
local tweenService = cloneref(game:GetService('TweenService'))
local debrisService = cloneref(game:GetService('Debris'))

local gameCamera = workspace.CurrentCamera
local lplr = playersService.LocalPlayer

local vape = shared.vape
local entitylib = vape.Libraries.entity
local whitelist = vape.Libraries.whitelist
local prediction = vape.Libraries.prediction
local targetinfo = vape.Libraries.targetinfo
local sessioninfo = vape.Libraries.sessioninfo
local getvapeasset = vape.Libraries.getvapeasset
local drawingactor = loadstring(downloadFile('newvape/libraries/drawing.lua'), 'drawing')(...)
local function notif(...)
	return vape:CreateNotification(...)
end

if not select(1, ...) and game.PlaceId == 5938036553 then
	if run_on_actor and getactors then
		local oldreload = shared.vapereload
		vape.Load = function()
			task.delay(0.1, function()
				vape:Uninject()
			end)
		end

		task.spawn(function()
			repeat task.wait() until not shared.vape
			local executionString = "loadfile('newvape/main.lua')("..drawingactor..")"
			for i, v in shared do
				if type(v) == 'string' then
					executionString = string.format("shared.%s = '%s'", i, v)..'\n'..executionString
				elseif type(v) == 'boolean' then
					executionString = string.format("shared.%s = %s", i, tostring(v))..'\n'..executionString
				end
			end
			if oldreload then
				executionString = 'shared.vapereload = true\n'..executionString
			end

			for i, v in getactors() do
				if tostring(v) == 'frontlines_client_actor' then
					run_on_actor(v, executionString)
					return
				end
			end
			notif('Vape', 'Failed to find actor', 10, 'alert')
		end)
	else
		vape.Load = function()
			notif('Vape', 'Missing actor functions.', 10, 'alert')
		end
	end

	return
end

local frontlines = {Functions = {}}
frontlines.KillEffectEvent = Instance.new('BindableEvent')
frontlines.LocalBulletEvent = Instance.new('BindableEvent')
frontlines.LocalHitEvent = Instance.new('BindableEvent')
frontlines.LastLocalHit = nil

local function addBlur(parent)
	local blur = Instance.new('ImageLabel')
	blur.Name = 'Blur'
	blur.Size = UDim2.new(1, 89, 1, 52)
	blur.Position = UDim2.fromOffset(-48, -31)
	blur.BackgroundTransparency = 1
	blur.Image = getvapeasset('newvape/assets/new/blur.png')
	blur.ScaleType = Enum.ScaleType.Slice
	blur.SliceCenter = Rect.new(52, 31, 261, 502)
	blur.Parent = parent
	return blur
end

local function getTeam(ent)
	return frontlines.Main.globals.cli_teams[ent.Id]
end

local function getKey(id, server)
	for i, v in frontlines.Main.enums[(server and 's' or 'c')..'_net_msg'] do
		if v == id then
			return i
		end
	end
end

local function hookEvent(id, rfunc)
	local suc, res = pcall(function()
		local func = frontlines.Events[frontlines.Main.exe_func_t[id]]
		local hook

		local function newFunc(...)
			if rfunc(...) then return end
			return hook(...)
		end

		hook = hookfunction(func, function(...) return newFunc(...) end)
		frontlines.Functions[func] = hook
		return function()
			if not frontlines.Functions[func] then return end
			--restorefunction(func)
			hookfunction(func, frontlines.Functions[func])
			frontlines.Functions[func] = nil
		end
	end)

	if not suc then
		notif('Vape', 'Failed to hook ('..id..')', 10, 'alert')
	end

	return type(res) == 'function' and res or function() end
end

local function isFriend(plr, recolor)
	if vape.Categories.Friends.Options['Use friends'].Enabled then
		local friend = table.find(vape.Categories.Friends.ListEnabled, plr.Name) and true
		if recolor then
			friend = friend and vape.Categories.Friends.Options['Recolor visuals'].Enabled
		end
		return friend
	end
	return nil
end

--[[run(function()
	repeat
		if not frontlines.ShootFunction then
			local gc = getgc(true)
			for _, v in gc do
				if type(v) == 'table' then
					if rawget(v, 'script') and v._G and v._G.append_exe_set then
						frontlines.Main = v._G
					end
				elseif type(v) == 'function' and islclosure(v) then
					local name = debug.info(v, 'n')
					if name == 'spawn_bullet' and debug.getinfo(v).nups > 11 then
						frontlines.ShootFunction = v
						frontlines.ShootRay = typeof(debug.getupvalue(v, 6)) == 'RaycastParams' and debug.getupvalue(v, 6) or debug.getupvalue(v, 5)
					elseif name == 'on_melee_hit' then
						frontlines.KnifeFunction = v
					elseif name == 'spawn_throwable' then
						frontlines.SpawnThrowable = v
						frontlines.Throwables = debug.getupvalue(v, 1)
					end
				end
			end
			table.clear(gc)
		end

		if not (frontlines.ShootFunction and (game.PlaceId == 5938036553 or game.StarterGui:GetCore('ResetButtonCallback') == false)) then
			task.wait(1)
		else
			break
		end
	until vape.Loaded == nil
	if vape.Loaded == nil then return end
	frontlines.Events = debug.getupvalue(frontlines.Main.append_exe_set, 1)
	frontlines.PickupBit = debug.getupvalue(frontlines.Events[frontlines.Main.exe_func_t.INIT_FPV_SOL_AMMO_PICKUP], 5)
	--frontlines.Chat = debug.getupvalue(frontlines.Events[frontlines.Main.exe_func_t.UPDATE_CHAT_GUI], 1)

	-- One shared FPV bullet hook. Modules listen to LocalBulletEvent / LocalHitEvent instead of
	-- stacking hookfunction calls on SPAWN_FPV_SOL_BULLET.
	hookEvent('SPAWN_FPV_SOL_BULLET', function(id, btype, origin, velocity)
		if frontlines.LocalBulletEvent then
			frontlines.LocalBulletEvent:Fire(id, btype, origin, velocity)
		end
		task.defer(function()
			if not frontlines.ResolveBulletHit then return end
			local ent, ray, headshot = frontlines.ResolveBulletHit(origin, velocity)
			if ent and ray then
				frontlines.LastLocalHit = {
					Id = ent.Id,
					Time = tick(),
					Headshot = headshot,
					Position = ray.Position
				}
				if frontlines.LocalHitEvent then
					frontlines.LocalHitEvent:Fire(ent, ray.Position, headshot, ray.Instance)
				end
			end
		end)
	end)

	local kills = sessioninfo:AddItem('Kills')
	local deaths = sessioninfo:AddItem('Deaths')

	hookEvent('SET_CLI_MATCH_KILLS', function(id)
		if id == frontlines.Main.globals.cli_state.fpv_sol_id then
			kills:Increment()
			if frontlines.KillEffectEvent then
				frontlines.KillEffectEvent:Fire()
			end
		end
	end)

	hookEvent('PLAY_FPV_SOL_DEATH_SOUND', function(self, id)
		if id == frontlines.Main.globals.cli_state.fpv_sol_id then
			deaths:Increment()
		end
	end)

	hookEvent('SET_GBL_SOL_HEALTH', function(id, health)
		local entity = entitylib.getEntity(id)
		if entity then
			entity.Health = health
			entitylib.Events.EntityUpdated:Fire(entity)
		end
	end)

	hookEvent('INIT_SOLDIER_MODEL', function(id)
		entitylib.refreshEntity(frontlines.Main.globals.soldier_models[id], id)
	end)

	hookEvent('DEINIT_SOL_STATE', function(id)
		entitylib.refreshEntity(frontlines.Main.globals.soldier_models[id], id)
	end)

	hookEvent('SET_CLI_TEAM', function(id)
		task.defer(function()
			entitylib.refreshEntity(frontlines.Main.globals.soldier_models[id], id)
		end)
	end)

	--[[if game.PlaceId == 5938036553 then
		hookEvent('UPDATE_CHAT_GUI', function(id, text)
			text = string.unpack('z', text)
			task.delay(0, function()
				local name = frontlines.Main.globals.cli_names[id]
				local plr = playersService:FindFirstChild(name)
				if not plr then return end
				for i, v in frontlines.Chat do
					if v.TextLabel.TextTransparency > 0.5 and v.TextLabel.Text:find(name) then
						v.TextLabel.Text = whitelist:tag(plr, true, true)..v.TextLabel.Text
						whitelist:process(text, plr)
						break
					end
				end
			end)
		end)
	end]]

	vape:Clean(Drawing.kill or function() end)
	vape:Clean(function()
		if frontlines.KillEffectEvent then frontlines.KillEffectEvent:Destroy() end
		if frontlines.LocalBulletEvent then frontlines.LocalBulletEvent:Destroy() end
		if frontlines.LocalHitEvent then frontlines.LocalHitEvent:Destroy() end
		for i, v in frontlines.Functions do
			hookfunction(i, v)
		end
		table.clear(frontlines.Functions)
		table.clear(frontlines)
	end)
end)]]
if vape.Loaded == nil then return end

run(function()
	entitylib.Wallcheck = function(origin, position, ignoreobject)
		local ray = workspace.Raycast(workspace, origin, (position - origin), frontlines.ShootRay)
		return ray and ray.Instance and (ray.Instance == workspace.Terrain or ray.Instance:IsDescendantOf(workspace.workspace)) or false
	end

	entitylib.targetCheck = function(ent)
		if ent.Player then
			if isFriend(ent.Player) then return false end
			if not select(2, whitelist:get(ent.Player)) then return false end
		end

		return getTeam({Id = frontlines.Main.globals.cli_state.id}) ~= getTeam(ent)
	end

	entitylib.getEntityColor = function(ent)
		if not (ent.Player and vape.Settings.Modules.Options['Use team color'].Enabled) then return end
		if isFriend(ent.Player, true) then
			return Color3.fromHSV(vape.Categories.Friends.Options['Friends color'].Hue, vape.Categories.Friends.Options['Friends color'].Sat, vape.Categories.Friends.Options['Friends color'].Value)
		end
		return getTeam({Id = frontlines.Main.globals.cli_state.id}) == getTeam(ent) and Color3.fromRGB(67, 140, 229) or Color3.fromRGB(234, 50, 50)
	end

	entitylib.getEntity = function(char)
		for i, v in entitylib.List do
			if v.Id == char then
				return v, i
			end
		end
	end

	entitylib.addEntity = function(char, id, teamfunc)
		if not char then return end
		entitylib.EntityThreads[char] = task.spawn(function()
			local plr
			if game.PlaceId == 5938036553 then
				plr = playersService:FindFirstChild(frontlines.Main.globals.cli_names[id])
			else
				plr = playersService:GetPlayerByUserId(frontlines.Main.globals.cli_user_ids[id] or -1)
			end

			if not id or not frontlines.Main.globals.soldiers_alive[id] then
				entitylib.EntityThreads[char] = nil
				return
			end

			local hum = {
				HipHeight = 2,
				MoveDirection = Vector3.zero,
				Health = 100,
				MaxHealth = 100,
				GetState = function()
					return Enum.HumanoidStateType.Running
				end
			}

			if plr == lplr then
				repeat
					hum = frontlines.Main.globals.fpv_sol_instances.humanoid
					task.wait()
				until hum or not frontlines.Main
				if not frontlines.Main then
					entitylib.EntityThreads[char] = nil
					return
				end
			end

			local humrootpart = char:WaitForChild('HumanoidRootPart', 10)
			local head = humrootpart and setmetatable({Name = 'Head', Size = Vector3.one, Parent = char}, {__index = function(t, k)
				if k == 'Position' then
					return humrootpart.Position + Vector3.new(0, 3, 0)
				elseif k == 'CFrame' then
					return humrootpart.CFrame + Vector3.new(0, 3, 0)
				end
			end})

			if hum and humrootpart then
				local entity = {
					Connections = {},
					Character = char,
					Health = hum.Health,
					Head = head,
					Humanoid = hum,
					HumanoidRootPart = humrootpart,
					HipHeight = hum.HipHeight + (humrootpart.Size.Y / 2) + (hum.RigType == Enum.HumanoidRigType.R6 and 2 or 0),
					Id = id,
					MaxHealth = hum.MaxHealth,
					NPC = plr == nil,
					Player = plr,
					RootPart = humrootpart,
					TeamCheck = teamfunc
				}

				if plr == lplr then
					entitylib.character = entity
					entitylib.isAlive = true
					entitylib.Events.LocalAdded:Fire(entity)
				else
					entity.Targetable = entitylib.targetCheck(entity)
					table.insert(entitylib.List, entity)
					entitylib.Events.EntityAdded:Fire(entity)
				end
			end

			entitylib.EntityThreads[char] = nil
		end)
	end

	entitylib.refreshEntity = function(char, id)
		entitylib.removeEntity(id)
		entitylib.addEntity(char, id)
	end

	entitylib.refresh = function()
		local cloned = table.clone(entitylib.List)
		for _, v in cloned do
			entitylib.refreshEntity(v.Character, v.Id)
		end
		table.clear(cloned)
	end

	entitylib.start = function()
		if entitylib.Running then
			entitylib.stop()
		end

		for id, actor in frontlines.Main.soldier_actors do
			if actor.main.model.Value then
				entitylib.refreshEntity(actor.main.model.Value, id)
			end
		end

		table.insert(entitylib.Connections, workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()
			gameCamera = workspace.CurrentCamera or workspace:FindFirstChildWhichIsA('Camera')
		end))

		entitylib.Running = true
	end
end)

-- Resolve the local FPV bullet ray back to a Vape entity and classify the hit as a headshot.
-- Frontlines' hitboxes are not guaranteed to literally be named "Head", so Smart detection
-- falls back to the hit position relative to the soldier root/head proxy.
frontlines.ResolveBulletHit = function(origin, velocity)
	if typeof(origin) ~= 'Vector3' or typeof(velocity) ~= 'Vector3' or velocity.Magnitude <= 0.001 then
		return
	end

	local ray = workspace:Raycast(origin, velocity.Unit * 1000, frontlines.ShootRay)
	if not ray or not ray.Instance then return end

	local hit = ray.Instance
	local ent
	local matchedHitbox
	local hash = frontlines.Main and frontlines.Main.globals and frontlines.Main.globals.soldier_hitbox_hash

	if hash then
		for hitbox, id in hash do
			if typeof(hitbox) == 'Instance' and (hit == hitbox or hit:IsDescendantOf(hitbox)) then
				matchedHitbox = hitbox
				ent = entitylib.getEntity(id)

				if not ent then
					local weld = hitbox:FindFirstChild('Weld')
					local root = weld and weld.Part0
					if root then
						if entitylib.character and root == entitylib.character.RootPart then
							ent = entitylib.character
						else
							for _, candidate in entitylib.List do
								if candidate.RootPart == root then
									ent = candidate
									break
								end
							end
						end
					end
				end
				break
			end
		end
	end

	if not ent then
		for _, candidate in entitylib.List do
			if candidate.Character and hit:IsDescendantOf(candidate.Character) then
				ent = candidate
				break
			end
		end
	end

	if not ent or ent == entitylib.character or ent.Targetable == false then return end

	local function hasHeadName(obj)
		local depth = 0
		while obj and depth < 5 do
			if tostring(obj.Name):lower():find('head', 1, true) then
				return true
			end
			obj = obj.Parent
			depth += 1
		end
		return false
	end

	local headshot = hasHeadName(hit) or hasHeadName(matchedHitbox)
	if not headshot and ent.RootPart then
		local headpos = ent.Head and ent.Head.Position or (ent.RootPart.Position + Vector3.new(0, 3, 0))
		local relativeY = ray.Position.Y - ent.RootPart.Position.Y
		headshot = relativeY >= 2.0 or (ray.Position - headpos).Magnitude <= 1.35
	end

	return ent, ray, headshot, matchedHitbox
end

entitylib.start()

for i, v in {'Reach', 'Health', 'TriggerBot', 'AntiFall', 'AntiRagdoll', 'Invisible', 'Disabler', 'Freecam', 'Parkour', 'HitBoxes', 'SafeWalk', 'Spider', 'Swim', 'GamingChair', 'TargetStrafe', 'Timer', 'MurderMystery', 'Blink', 'AnimationPlayer'} do
	vape:Remove(v)
end

run(function()
	vape.Modules.Speed:AddMode('Legit', function(options, moveDirection, dt)
		local root = entitylib.character.RootPart
		local direction = moveDirection * Vector3.new(1, 0, 1)
		local magnitude = direction.Magnitude
		if magnitude <= 0 or dt <= 0 then return end

		-- Add 1.7 studs/second to normal movement, including backwards and strafing.
		-- Position offset avoids repeatedly compounding the previous frame's velocity.
		local offset = direction / magnitude * math.min(magnitude, 1) * 1.7 * dt
		if options.WallCheck.Enabled then
			options.rayCheck.FilterDescendantsInstances = {entitylib.character.Character, gameCamera}
			options.rayCheck.CollisionGroup = root.CollisionGroup
			local ray = workspace:Raycast(root.Position, offset, options.rayCheck)
			if ray then return end
		end
		root.CFrame += offset
	end)
end)


run(function()
	local AimAssist
	local FOV
	local Speed
	local CircleColor
	local CircleTransparency
	local CircleFilled
	local CircleObject
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	
	AimAssist = vape.Categories.Combat:CreateModule({
		Name = 'AimAssist',
		Function = function(callback)
			if CircleObject then
				CircleObject.Visible = callback
			end
			if callback then 
				repeat
					local dt = task.wait()
					if not AimAssist.Enabled then break end
					if CircleObject then 
						CircleObject.Position = inputService:GetMouseLocation() 
					end
	
					if inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then 
						local origin = entitylib.isAlive and frontlines.Main.globals.fpv_sol_instances.camera_bone.WorldPosition or Vector3.zero
						local ent = entitylib.EntityMouse({
							Range = FOV.Value,
							Players = true,
							Wallcheck = true,
							Part = 'RootPart',
							Origin = origin
						})
	
						if ent then 
							local gun = frontlines.Main.globals.fpv_sol_equipment.curr_equipment
							if gun and gun.fire_params then
								rayCheck.FilterDescendantsInstances = {gameCamera, ent.Character}
								rayCheck.CollisionGroup = ent.RootPart.CollisionGroup
								local velo = gun.fire_params.muzzle_velocity
								local targetpos = ent.RootPart.Root_M.Spine1_M.Spine2_M.Chest_M.Neck_M.Head_M.WorldCFrame.Position
								local calc = prediction.SolveTrajectory(origin, velo, workspace.Gravity, targetpos, Vector3.zero, workspace.Gravity, ent.HipHeight, nil, rayCheck)
								
								if calc then 
									local pos = gameCamera:WorldToViewportPoint(calc)
									local localmouse = (inputService:GetMouseLocation() - Vector2.new(pos.X, pos.Y)) * dt * (Speed.Value / 10000)
									targetinfo.Targets[ent] = tick() + 1
									frontlines.Main.exe_set(frontlines.Main.exe_set_t.CTRL_SOL_ATT_ROT, localmouse.Y, localmouse.X)
								end
							end
						end
					end
				until not AimAssist.Enabled
			end
		end,
		Tooltip = 'Uses game functions to move the camera towards players'
	})
	FOV = AimAssist:CreateSlider({
		Name = 'FOV',
		Min = 1,
		Max = 1000,
		Default = 300,
		Function = function(val)
			if CircleObject then
				CircleObject.Radius = val
			end
		end
	})
	Speed = AimAssist:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 100,
		Default = 10
	})
	AimAssist:CreateToggle({
		Name = 'Range Circle',
		Function = function(callback)
			if callback then
				CircleObject = Drawing.new('Circle')
				CircleObject.Filled = CircleFilled.Enabled
				CircleObject.Color = Color3.fromHSV(CircleColor.Hue, CircleColor.Sat, CircleColor.Value)
				CircleObject.Position = vape.gui.AbsoluteSize / 2
				CircleObject.Radius = FOV.Value
				CircleObject.NumSides = 100
				CircleObject.Transparency = 1 - CircleTransparency.Value
				CircleObject.Visible = AimAssist.Enabled
			else
				pcall(function()
					CircleObject.Visible = false
					CircleObject:Remove()
				end)
			end
			CircleColor.Object.Visible = callback
			CircleTransparency.Object.Visible = callback
			CircleFilled.Object.Visible = callback
		end
	})
	CircleColor = AimAssist:CreateColorSlider({
		Name = 'Circle Color', 
		Function = function(hue, sat, val)
			if CircleObject then
				CircleObject.Color = Color3.fromHSV(hue, sat, val)
			end
		end, 
		Darker = true, 
		Visible = false
	})
	CircleTransparency = AimAssist:CreateSlider({
		Name = 'Transparency',
		Min = 0,
		Max = 1,
		Decimal = 10,
		Default = 0.5,
		Function = function(val)
			if CircleObject then
				CircleObject.Transparency = 1 - val
			end
		end,
		Darker = true,
		Visible = false
	})
	CircleFilled = AimAssist:CreateToggle({
		Name = 'Circle Filled', 
		Function = function(callback)
			if CircleObject then
				CircleObject.Filled = callback
			end
		end, 
		Darker = true, 
		Visible = false
	})
	
end)

run(function()
	local SilentAim
	local Target
	local Mode
	local Range
	local HitChance
	local HeadshotChance
	local AutoFire
	local Wallbang
	local CircleColor
	local CircleTransparency
	local CircleFilled
	local CircleObject
	local ProjectileRaycast = RaycastParams.new()
	ProjectileRaycast.RespectCanCollide = true
	local rand, old = Random.new()
	
	local function getMousePosition()
		if inputService.TouchEnabled then
			return gameCamera.ViewportSize / 2
		end
	
		return inputService:GetMouseLocation()
	end
	
	local function getTarget(origin, obj)
		if rand.NextNumber(rand, 0, 100) > (AutoFire.Enabled and 100 or HitChance.Value) then
			return
		end
		--local targetPart = (Random.new().NextNumber(Random.new(), 0, 100) < (AutoFire.Enabled and 100 or HeadshotChance.Value)) and 'Head' or 'RootPart'
		local targetPart = 'RootPart'
		local entity = entitylib['Entity'..Mode.Value]({
			Range = Range.Value,
			Wallcheck = Target.Walls.Enabled and (obj or true) or nil,
			Part = targetPart,
			Origin = origin,
			Players = Target.Players.Enabled,
			NPCs = Target.NPCs.Enabled
		})
	
		if entity then
			targetinfo.Targets[entity] = tick() + 1
		end
	
		return entity, entity and entity[targetPart]
	end
	
	local function raycastLoop(origin, pos)
		local returned
		local real = origin
		for i = 1, 20 do
			local ray = workspace:Raycast(origin, (pos - origin), frontlines.ShootRay)
			if ray and not ray.Instance:HasTag('SOLDIER') then
				returned = ray.Position - ray.Normal * 0.1
				origin = returned
			else
				break
			end
		end
		return returned
	end
	
	SilentAim = vape.Categories.Combat:CreateModule({
		Name = 'SilentAim',
		Function = function(callback)
			if CircleObject then
				CircleObject.Visible = callback and Mode.Value == 'Mouse'
			end
	
			if callback then
				old = hookfunction(frontlines.ShootFunction, function(shootid, fire, pos, dir, ...)
					if not frontlines.Main then return end
	
					local cstate = frontlines.Main.globals.cli_state
					if cstate.state == frontlines.Main.cli_state_t.COMBAT and (shootid % frontlines.Main.globals.cli_id_alloc.m) == cstate.id then
						local ent, targetPart = getTarget(pos)
						if ent then
							local velo = dir.Magnitude
							local targetpos = targetPart.Root_M.Spine1_M.WorldCFrame.Position
							ProjectileRaycast.FilterDescendantsInstances = {gameCamera, ent.Character}
							ProjectileRaycast.CollisionGroup = targetPart.CollisionGroup
	
							if Wallbang.Enabled then
								local wall = raycastLoop(pos, targetpos)
								if wall and (pos - wall).Magnitude < 8 then
									pos = wall
								end
							end
	
							local calc = prediction.SolveTrajectory(pos, velo, workspace.Gravity, targetpos, Vector3.zero, workspace.Gravity, ent.HipHeight, nil, ProjectileRaycast)
							if calc then
								dir = -CFrame.new(pos, calc).ZVector * velo
							end
						end
					end
	
					return old(shootid, fire, pos, dir, ...)
				end)
	
				local oldent
				repeat
					if CircleObject then
						CircleObject.Position = getMousePosition()
					end
	
					if AutoFire.Enabled then
						local entity = entitylib['Entity'..Mode.Value]({
							Range = Range.Value,
							Wallcheck = Target.Walls.Enabled or nil,
							Part = 'RootPart',
							Origin = entitylib.isAlive and frontlines.Main.globals.fpv_sol_instances.camera_bone.WorldPosition or Vector3.zero,
							Players = Target.Players.Enabled,
							NPCs = Target.NPCs.Enabled
						})
	
						local gun = frontlines.Main.globals.fpv_sol_equipment.curr_equipment
						entity = gun and gun.type ~= 2 and entity or nil
						if entity ~= oldent or entity then
							frontlines.Main.globals.ctrl_states.trigger = entity and true or false
							if entity then
								frontlines.Main.globals.ctrl_ts.trigger = time()
							end
	
							oldent = entity
						end
					end
	
					task.wait()
				until not SilentAim.Enabled
			else
				if old then
					hookfunction(frontlines.ShootFunction, old)
					old = nil
				end
			end
		end,
		Tooltip = 'Silently adjusts your aim towards the enemy'
	})
	Target = SilentAim:CreateTargets({
		Players = true
	})
	Mode = SilentAim:CreateDropdown({
		Name = 'Mode',
		List = {'Mouse', 'Position'},
		Function = function(val)
			if CircleObject then
				CircleObject.Visible = SilentAim.Enabled and val == 'Mouse'
			end
		end
	})
	Range = SilentAim:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 1000,
		Default = 150,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end,
		Function = function(val)
			if CircleObject then
				CircleObject.Radius = val
			end
		end
	})
	HitChance = SilentAim:CreateSlider({
		Name = 'Hit Chance',
		Min = 0,
		Max = 100,
		Default = 85,
		Suffix = '%'
	})
	AutoFire = SilentAim:CreateToggle({
		Name = 'AutoFire'
	})
	Wallbang = SilentAim:CreateToggle({
		Name = 'Wallbang'
	})
	SilentAim:CreateToggle({
		Name = 'Range Circle',
		Function = function(callback)
			if callback then
				CircleObject = Drawing.new('Circle')
				CircleObject.Filled = CircleFilled.Enabled
				CircleObject.Color = Color3.fromHSV(CircleColor.Hue, CircleColor.Sat, CircleColor.Value)
				CircleObject.Position = vape.gui.AbsoluteSize / 2
				CircleObject.Radius = Range.Value
				CircleObject.NumSides = 100
				CircleObject.Transparency = 1 - CircleTransparency.Value
				CircleObject.Visible = SilentAim.Enabled and Mode.Value == 'Mouse'
			else
				pcall(function()
					CircleObject.Visible = false
					CircleObject:Remove()
				end)
			end
			CircleColor.Object.Visible = callback
			CircleTransparency.Object.Visible = callback
			CircleFilled.Object.Visible = callback
		end
	})
	CircleColor = SilentAim:CreateColorSlider({
		Name = 'Circle Color',
		Function = function(hue, sat, val)
			if CircleObject then
				CircleObject.Color = Color3.fromHSV(hue, sat, val)
			end
		end,
		Darker = true,
		Visible = false
	})
	CircleTransparency = SilentAim:CreateSlider({
		Name = 'Transparency',
		Min = 0,
		Max = 1,
		Decimal = 10,
		Default = 0.5,
		Function = function(val)
			if CircleObject then
				CircleObject.Transparency = 1 - val
			end
		end,
		Darker = true,
		Visible = false
	})
	CircleFilled = SilentAim:CreateToggle({
		Name = 'Circle Filled',
		Function = function(callback)
			if CircleObject then
				CircleObject.Filled = callback
			end
		end,
		Darker = true,
		Visible = false
	})
end)

run(function()
	local Sprint
	
	Sprint = vape.Categories.Combat:CreateModule({
		Name = 'Sprint',
		Function = function(callback)
			if callback then
				repeat
					local states = frontlines.Main.globals.ctrl_states
					local statetimes = frontlines.Main.globals.ctrl_ts
					local sprintcheck = true
					
					if not (states.hold_ads or (time() - statetimes.trigger) < 0.2 or (time() - statetimes.press_crouch) < 0.4) then
						if not states.hold_accel then 
							statetimes.press_accel_prev = time() 
							statetimes.press_accel = time() 
						end
						states.hold_accel = true
					end
					task.wait(0.1)
				until not Sprint.Enabled
			end
		end,
		Tooltip = 'Holds the sprint button'
	})
end)

run(function()
	local GrenadeTP
	local Range
	
	GrenadeTP = vape.Categories.Blatant:CreateModule({
		Name = 'GrenadeTP',
		Function = function(callback)
			if callback then
				repeat
					for _, v in frontlines.Throwables do
						if v.model and v.network_ownership then
							local ent = entitylib.EntityPosition({
								Range = Range.Value,
								Part = 'RootPart',
								Origin = v.model.PrimaryPart.Position,
								Players = true
							})
	
							if ent then
								local id
								for i, hash in frontlines.Main.globals.soldier_hitbox_hash do
									if i.Weld.Part0 == v.RootPart then
										id = hash
										break
									end
								end
	
								if id then
									v.model:PivotTo(ent.RootPart.Root_M.Spine1_M.WorldCFrame)
								end
							end
						end
					end
					task.wait(0.016)
				until not GrenadeTP.Enabled
			end
		end,
		Tooltip = 'Teleports throwables near enemy players'
	})
	Range = GrenadeTP:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 1000,
		Default = 1000
	})
end)

run(function()
	local Reload
	local Recoil
	local Spread
	local FireRate
	local Automatic
	
	GunModifications = vape.Categories.Blatant:CreateModule({
		Name = 'GunModifications',
		Function = function(callback)
			if callback then
				GunModifications:Clean(hookEvent('START_FPV_SOL_RECOIL_ANIM', function()
					if Recoil.Enabled then
						frontlines.Main.globals.fpv_sol_recoil.attitude_delta = Vector3.zero
						return true
					end
				end))
	
				GunModifications:Clean(hookEvent('STEP_FPV_SOL_FIREARM_SPREAD', function()
					if Spread.Enabled then
						frontlines.Main.globals.fpv_sol_spread.spread = 0
						return true
					end
				end))
	
				repeat
					local gun = frontlines.Main.globals.fpv_sol_equipment.curr_equipment
					if Reload.Enabled then
						local ammo = frontlines.Main.globals.fpv_sol_ammo
						if gun and gun.reload_params and ammo.ammo == 0 and ammo.reserve > 0 then
							frontlines.Main.exe_set(frontlines.Main.exe_set_t.FPV_SOL_AMMO_IN, gun)
						end
					end
					
					if FireRate.Enabled then
						if gun and gun.fire_params then 
							gun.fire_params.rpm = 4000 
						end
					end
	
					if Automatic.Enabled then 
						if gun and gun.fire_params then 
							gun.fire_params.cycle_mode = frontlines.Main.cycle_mode.AUTO
						end
					end
	
					task.wait()
				until not GunModifications.Enabled
			end
		end,
		Tooltip = 'Modifications to empower the firearm'
	})
	Reload = GunModifications:CreateToggle({Name = 'Auto Reload'})
	Recoil = GunModifications:CreateToggle({Name = 'No Recoil'})
	Spread = GunModifications:CreateToggle({Name = 'No Spread'})
	FireRate = GunModifications:CreateToggle({Name = 'Fire rate'})
	Automatic = GunModifications:CreateToggle({Name = 'Full Automatic'})
end)

run(function()
	local Killaura
	local Targets
	local SwingRange
	local AttackRange
	local Angle
	local Max
	local Mouse
	local Limit
	local Box
	local BoxSwingColor
	local BoxAttackColor
	local Particle
	local ParticleTexture
	local ParticleColor1
	local ParticleColor2
	local ParticleSize
	local Boxes = {}
	local Particles = {}
	local hitdelay = tick()
	local didattack = false
	
	local function getAttackData()
		if Mouse.Enabled then
			if not inputService:IsMouseButtonPressed(0) then return false end
		end
	
		local gun = frontlines.Main.globals.fpv_sol_equipment.curr_equipment
		local knifecheck = gun and gun.type == 2 and true or false
		if Limit.Enabled then
			if not knifecheck then return false end
		end
	
		return true, knifecheck
	end
	
	Killaura = vape.Categories.Blatant:CreateModule({
		Name = 'Killaura',
		Function = function(callback)
			if callback then
				repeat
					local suc, knifecheck = getAttackData()
					local attacked = {}
					local prevattack = didattack
					didattack = false
					if suc then
						local plrs = entitylib.AllPosition({
							Range = SwingRange.Value,
							Wallcheck = Targets.Walls.Enabled or nil,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Limit = Max.Value
						})
	
						if #plrs > 0 then
							local gun = frontlines.Main.globals.fpv_sol_equipment.curr_equipment
							local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
	
							for i, v in plrs do
								local delta = (v.RootPart.Position - entitylib.character.RootPart.Position)
								local angle = math.acos(localfacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
								if angle > (math.rad(Angle.Value) / 2) then continue end
								table.insert(attacked, {Entity = v, Check = delta.Magnitude > AttackRange.Value and BoxSwingColor or BoxAttackColor})
								targetinfo.Targets[v] = tick() + 1
	
								if delta.Magnitude > AttackRange.Value then continue end
								didattack = knifecheck
								if hitdelay < tick() then
									local id, part
									for i2, v2 in frontlines.Main.globals.soldier_hitbox_hash do
										if i2.Weld.Part0 == v.RootPart then
											id, part = v2, i2
											break
										end
									end
	
									if id then
										hitdelay = tick() + 0.1
										frontlines.Main.utils.net_msg_util.c_prep_net_msg(frontlines.Main.globals.combat_net_msg_state, frontlines.Main.enums.c_net_msg.MELEE_HIT_SOL, id)
										if knifecheck then
											frontlines.Main.globals.ctrl_states.trigger = true
											frontlines.Main.globals.ctrl_ts.trigger = time()
											frontlines.Main.exe_set(frontlines.Main.exe_set_t.FPV_SOL_MELEE_SOL_HIT, gun, part, Vector3.zero)
											if vape.ThreadFix then
												setthreadidentity(8)
											end
										end
									end
								end
							end
						end
					end
	
					if didattack ~= prevattack and prevattack then
						frontlines.Main.globals.ctrl_states.trigger = false
					end
	
					for i, v in Boxes do
						v.Adornee = attacked[i] and attacked[i].Entity.RootPart or nil
						if v.Adornee then
							v.Color3 = Color3.fromHSV(attacked[i].Check.Hue, attacked[i].Check.Sat, attacked[i].Check.Value)
							v.Transparency = 1 - attacked[i].Check.Opacity
						end
					end
	
					for i, v in Particles do
						v.Position = attacked[i] and attacked[i].Entity.RootPart.Position or Vector3.new(9e9, 9e9, 9e9)
						v.Parent = attacked[i] and gameCamera or nil
					end
	
					task.wait()
				until not Killaura.Enabled
			else
				for i, v in Boxes do
					v.Adornee = nil
				end
				for i, v in Particles do
					v.Parent = nil
				end
			end
		end,
		Tooltip = 'Attack players around you\nwithout aiming at them.'
	})
	Targets = Killaura:CreateTargets({Players = true})
	SwingRange = Killaura:CreateSlider({
		Name = 'Swing range',
		Min = 1,
		Max = 8,
		Default = 8,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AttackRange = Killaura:CreateSlider({
		Name = 'Attack range',
		Min = 1,
		Max = 8,
		Default = 8,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	Angle = Killaura:CreateSlider({
		Name = 'Max angle',
		Min = 1,
		Max = 360,
		Default = 360
	})
	Max = Killaura:CreateSlider({
		Name = 'Max targets',
		Min = 1,
		Max = 10,
		Default = 10
	})
	Mouse = Killaura:CreateToggle({Name = 'Require mouse down'})
	Limit = Killaura:CreateToggle({Name = 'Knife only'})
	Box = Killaura:CreateToggle({
		Name = 'Show target',
		Function = function(callback)
			BoxSwingColor.Object.Visible = callback
			BoxAttackColor.Object.Visible = callback
			if callback then
				for i = 1, 10 do
					local box = Instance.new('BoxHandleAdornment')
					box.Adornee = nil
					box.AlwaysOnTop = true
					box.Size = Vector3.new(3, 5, 3)
					box.CFrame = CFrame.new(0, -0.5, 0)
					box.ZIndex = 0
					box.Parent = vape.holder
					Boxes[i] = box
				end
			else
				for i, v in Boxes do
					v:Destroy()
				end
				table.clear(Boxes)
			end
		end
	})
	BoxSwingColor = Killaura:CreateColorSlider({
		Name = 'Target Color',
		Darker = true,
		Visible = false,
		DefaultHue = 0.6,
		DefaultOpacity = 0.5
	})
	BoxAttackColor = Killaura:CreateColorSlider({
		Name = 'Attack Color',
		Darker = true,
		Visible = false,
		DefaultOpacity = 0.5
	})
	Particle = Killaura:CreateToggle({
		Name = 'Target particles',
		Function = function(callback)
			ParticleTexture.Object.Visible = callback
			ParticleColor1.Object.Visible = callback
			ParticleColor2.Object.Visible = callback
			ParticleSize.Object.Visible = callback
			if callback then
				for i = 1, 10 do
					local part = Instance.new('Part')
					part.Size = Vector3.one
					part.Anchored = true
					part.CanCollide = false
					part.Transparency = 1
					part.CanQuery = false
					part.Parent = Killaura.Enabled and gameCamera or nil
					local particles = Instance.new('ParticleEmitter')
					particles.Brightness = 1.5
					particles.Size = NumberSequence.new(ParticleSize.Value)
					particles.Texture = ParticleTexture.Value
					particles.Transparency = NumberSequence.new(0, 1)
					particles.Lifetime = NumberRange.new(0.4)
					particles.Rate = 1000
					particles.Speed = NumberRange.new(12)
					particles.Drag = 6
					particles.Shape = Enum.ParticleEmitterShape.Sphere
					particles.ShapePartial = 1
					particles.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
						ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
					})
					particles.Parent = part
					Particles[i] = part
				end
			else
				for i, v in Particles do
					v:Destroy()
				end
				table.clear(Particles)
			end
		end
	})
	ParticleTexture = Killaura:CreateTextBox({
		Name = 'Texture',
		Default = 'rbxassetid://14736249347',
		Function = function(val)
			for i, v in Particles do
				v.ParticleEmitter.Texture = ParticleTexture.Value
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleColor1 = Killaura:CreateColorSlider({
		Name = 'Color Begin',
		Function = function(hue, sat, val)
			for i, v in Particles do
				v.ParticleEmitter.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(hue, sat, val)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
				})
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleColor2 = Killaura:CreateColorSlider({
		Name = 'Color End',
		Function = function(hue, sat, val)
			for i, v in Particles do
				v.ParticleEmitter.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(hue, sat, val))
				})
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleSize = Killaura:CreateSlider({
		Name = 'Size',
		Min = 0,
		Max = 1,
		Default = 0.25,
		Decimal = 100,
		Function = function(val)
			for i, v in Particles do
				v.ParticleEmitter.Size = NumberSequence.new(val)
			end
		end,
		Darker = true,
		Visible = false
	})
end)

run(function()
	local Phase
	
	Phase = vape.Categories.Blatant:CreateModule({
		Name = 'Phase',
		Function = function(callback)
			if callback then
				Phase:Clean(entitylib.Events.LocalAdded:Connect(function()
					local root = frontlines.Main.globals.fpv_sol_instances.root
					if root then
						root.CanCollide = false
					end
				end))
	
				local root = frontlines.Main.globals.fpv_sol_instances.root
				if root then
					root.CanCollide = false
				end
			else
				local root = frontlines.Main.globals.fpv_sol_instances.root
				if root then
					root.CanCollide = true
				end
			end
		end,
		Tooltip = 'Lets you Phase/Clip through walls.'
	})
end)

run(function()
	local SpinBot
	local Speed
	local Yaw
	local Pitch
	local aimtable = {}
	local maxy = frontlines.Main.consts.fpv_sol_movement.MAX_ATT_X
	local yaw, pitch = 0, 90
	for i = 1, 40 do
		table.insert(aimtable, Vector3.zero)
	end
	
	SpinBot = vape.Categories.Blatant:CreateModule({
		Name = 'SpinBot',
		Function = function(callback)
			if callback then
				SpinBot:Clean(hookEvent('STEP_SOL_CFRAME', function(id)
					if id == frontlines.Main.globals.cli_state.fpv_sol_id then
						local v5 = frontlines.Main.globals.sol_positions[id]
						local v6 = aimtable[frontlines.Main.globals.cli_state.fpv_sol_id]
						frontlines.Main.globals.sol_root_parts[id].Root_M.CFrame = CFrame.Angles(0, 0.5 * v6.y, math.rad(-90))
					end
				end))
	
				debug.setupvalue(frontlines.Events[frontlines.Main.exe_func_t.STEP_FPV_SOL_NET_EGRESS], 3, aimtable)
				debug.setupvalue(frontlines.Events[frontlines.Main.exe_func_t.STEP_TPV_SOLDIER_JOINTS], 16, aimtable)
	
				repeat
					aimtable = table.clone(frontlines.Main.globals.sol_attitudes)
					aimtable[frontlines.Main.globals.cli_state.fpv_sol_id] = Vector3.new(math.clamp(math.rad(pitch), -maxy, maxy), math.rad(yaw))
					yaw += task.wait() * (Yaw.Value == 'Clockwise' and (Speed.Value or 0) or -(Speed.Value or 0)) * 1000
					if Pitch.Value == 'Sine' then
						pitch = math.sin(math.rad(yaw)) * 90
					end
				until not SpinBot.Enabled
			else
				yaw = 0
				debug.setupvalue(frontlines.Events[frontlines.Main.exe_func_t.STEP_FPV_SOL_NET_EGRESS], 3, frontlines.Main.globals.sol_attitudes)
				debug.setupvalue(frontlines.Events[frontlines.Main.exe_func_t.STEP_TPV_SOLDIER_JOINTS], 16, frontlines.Main.globals.sol_attitudes)
				local id = frontlines.Main.globals.cli_state.fpv_sol_id
				if frontlines.Main.globals.sol_root_parts[id] then
					frontlines.Main.globals.sol_root_parts[id].Root_M.CFrame = CFrame.Angles(0, math.rad(90), math.rad(-90))
				end
			end
		end,
		Tooltip = 'Rotates the character in a circle'
	})
	Speed = SpinBot:CreateSlider({
		Name = 'Speed',
		Min = 0,
		Max = 1,
		Default = 1,
		Decimal = 10
	})
	Yaw = SpinBot:CreateDropdown({
		Name = 'Yaw Direction',
		List = {'Clockwise', 'Counter Clockwise'}
	})
	Pitch = SpinBot:CreateDropdown({
		Name = 'Pitch Direction',
		List = {'Up', 'Down', 'Forward', 'Sine'},
		Function = function(val)
			pitch = val == 'Up' and 90 or val == 'Down' and -90 or 0
		end
	})
end)


run(function()
	local KillEffects
	local Mode
	local ColorMode
	local PrimaryColor
	local SecondaryColor
	local EffectSize
	local Lifetime
	local Quality
	local KillSound
	local KillSoundFile
	local KillSoundVolume
	local Folder = Instance.new('Folder')
	Folder.Name = 'VapeKillEffects'
	Folder.Parent = workspace

	local healthCache = {}
	local recentDeaths = {}
	local recentHits = {}
	local cachedSoundInput
	local cachedSoundAsset
	local customAsset = getcustomasset or getsynasset or getasset

	local function resolveSound(value)
		value = tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
		if value == '' then return end
		if cachedSoundInput == value then return cachedSoundAsset end
		cachedSoundInput = value
		cachedSoundAsset = nil

		if value:match('^%d+$') then
			cachedSoundAsset = 'rbxassetid://'..value
		elseif value:match('^rbxassetid://') or value:match('^rbxasset://') then
			cachedSoundAsset = value
		elseif customAsset then
			local path = value:gsub('^file://', ''):gsub('\\', '/')
			local ok, asset = pcall(customAsset, path)
			if ok and asset then
				cachedSoundAsset = asset
			end
		end
		return cachedSoundAsset
	end

	local function amount(base)
		local multiplier = Quality.Value == 'Low' and 0.6 or Quality.Value == 'High' and 1.45 or 1
		return math.max(1, math.floor(base * multiplier + 0.5))
	end

	local function colors(death)
		if ColorMode.Value == 'Target' and death and death.Color then
			return death.Color, death.Color:Lerp(Color3.new(1, 1, 1), 0.55)
		elseif ColorMode.Value == 'Rainbow' then
			local hue = (tick() * 0.18) % 1
			return Color3.fromHSV(hue, 0.8, 1), Color3.fromHSV((hue + 0.5) % 1, 0.8, 1)
		end
		return Color3.fromHSV(PrimaryColor.Hue, PrimaryColor.Sat, PrimaryColor.Value), Color3.fromHSV(SecondaryColor.Hue, SecondaryColor.Sat, SecondaryColor.Value)
	end

	local function cleanup(obj, delayTime)
		debrisService:AddItem(obj, math.max(delayTime or Lifetime.Value, 0.05) + 0.15)
		return obj
	end

	local function part(size, cf, color, transparency, material, shape)
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
		if shape then obj.Shape = shape end
		obj.Parent = Folder
		return obj
	end

	local function tween(obj, duration, props, style, direction)
		local tw = tweenService:Create(obj, TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
		tw:Play()
		tw.Completed:Connect(function()
			pcall(function() tw:Destroy() end)
		end)
		return tw
	end

	local function sphere(pos, startSize, endSize, color, duration, startTransparency)
		local obj = part(Vector3.one * math.max(startSize, 0.05), CFrame.new(pos), color, startTransparency or 0, Enum.Material.Neon, Enum.PartType.Ball)
		tween(obj, duration, {Size = Vector3.one * math.max(endSize, 0.05), Transparency = 1}, Enum.EasingStyle.Quart)
		return cleanup(obj, duration)
	end

	local function line(a, b, width, color, duration)
		local dist = (b - a).Magnitude
		if dist <= 0.01 then return end
		local obj = part(Vector3.new(width, width, dist), CFrame.lookAt((a + b) / 2, b), color, 0, Enum.Material.Neon)
		tween(obj, duration, {Transparency = 1, Size = Vector3.new(math.max(width * 0.15, 0.02), math.max(width * 0.15, 0.02), dist)}, Enum.EasingStyle.Quart)
		return cleanup(obj, duration)
	end

	local function burst(pos, count, radius, size, a, b, life, cubes, upward, rainbow)
		for i = 1, amount(count) do
			local dir = Vector3.new(math.random(-100, 100) / 100, math.random(-35, 100) / 100 + (upward or 0), math.random(-100, 100) / 100)
			if dir.Magnitude < 0.05 then dir = Vector3.yAxis end
			dir = dir.Unit
			local color = rainbow and Color3.fromHSV(i / math.max(amount(count), 1), 0.85, 1) or (i % 2 == 0 and a or b)
			local obj = part(Vector3.one * size, CFrame.new(pos) * CFrame.Angles(math.random(), math.random(), math.random()), color, 0, Enum.Material.Neon, cubes and nil or Enum.PartType.Ball)
			local endpoint = pos + dir * radius * (0.65 + math.random() * 0.45)
			tween(obj, life, {
				CFrame = CFrame.new(endpoint) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6),
				Size = Vector3.one * math.max(size * 0.15, 0.03),
				Transparency = 1
			}, Enum.EasingStyle.Quart)
			cleanup(obj, life)
		end
	end

	local function symbol(pos, text, color, life, count, scale)
		for i = 1, amount(count or 1) do
			local anchor = part(Vector3.one * 0.05, CFrame.new(pos + Vector3.new(math.random(-12, 12) / 10, math.random(0, 12) / 10, math.random(-12, 12) / 10)), color, 1, Enum.Material.SmoothPlastic)
			local gui = Instance.new('BillboardGui')
			gui.Size = UDim2.fromOffset(72 * (scale or 1), 72 * (scale or 1))
			gui.AlwaysOnTop = true
			gui.Adornee = anchor
			gui.Parent = anchor
			local label = Instance.new('TextLabel')
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Text = text
			label.TextScaled = true
			label.TextColor3 = color
			label.TextStrokeTransparency = 0.35
			label.Font = Enum.Font.GothamBold
			label.Parent = gui
			tween(anchor, life, {CFrame = anchor.CFrame + Vector3.new(math.random(-18, 18) / 10, 5 + math.random() * 2, math.random(-18, 18) / 10)}, Enum.EasingStyle.Sine)
			tween(label, life, {TextTransparency = 1, TextStrokeTransparency = 1}, Enum.EasingStyle.Quad)
			cleanup(anchor, life)
		end
	end

	local function playKillSound()
		if not KillSound.Enabled then return end
		local asset = resolveSound(KillSoundFile.Value)
		if not asset then return end
		local sound = Instance.new('Sound')
		sound.SoundId = asset
		sound.Volume = KillSoundVolume.Value
		sound.Parent = gameCamera
		sound:Play()
		debrisService:AddItem(sound, 6)
	end

	local function ghostEffect(death, a, scale, life)
		local char = death.Character
		if not char or not char.Parent then
			sphere(death.Position + Vector3.new(0, 1.5 * scale, 0), 0.5 * scale, 4 * scale, a, life, 0.35)
			return
		end
		local archivable = char.Archivable
		char.Archivable = true
		local ok, clone = pcall(function() return char:Clone() end)
		char.Archivable = archivable
		if not ok or not clone then return end
		clone.Name = 'KillEffectGhost'
		clone.Parent = Folder
		for _, obj in clone:GetDescendants() do
			if obj:IsA('BasePart') then
				obj.Anchored = true
				obj.CanCollide = false
				obj.CanTouch = false
				obj.CanQuery = false
				obj.CastShadow = false
				obj.Material = Enum.Material.ForceField
				obj.Color = a
				obj.Transparency = math.max(obj.Transparency, 0.28)
				tween(obj, life, {CFrame = obj.CFrame + Vector3.new(0, 6 * scale, 0), Transparency = 1}, Enum.EasingStyle.Sine)
			elseif obj:IsA('Decal') or obj:IsA('Texture') then
				tween(obj, life, {Transparency = 1}, Enum.EasingStyle.Sine)
			elseif obj:IsA('Script') or obj:IsA('LocalScript') then
				obj:Destroy()
			end
		end
		cleanup(clone, life)
	end

	local function runEffect(death)
		if not death or not death.Position then return end
		local pos = death.Position
		local scale = EffectSize.Value
		local life = math.max(Lifetime.Value, 0.15)
		local a, b = colors(death)
		local mode = Mode.Value
		if mode == 'Random' then
			local pool = {'Nova', 'Lightning', 'Soul', 'Rings', 'Spiral', 'Firework', 'Tornado', 'Shatter', 'Slash', 'Beam', 'Pulse', 'Confetti', 'Galaxy', 'Freeze', 'Void', 'Ghost', 'Hearts', 'Skull', 'Black Hole', 'Disintegrate', 'Crystal', 'Orbit'}
			mode = pool[math.random(1, #pool)]
		end

		playKillSound()

		if mode == 'Nova' or mode == 'Explosion' then
			sphere(pos + Vector3.new(0, 1 * scale, 0), 0.35 * scale, 6.5 * scale, a, life * 0.8, 0.1)
			sphere(pos + Vector3.new(0, 1 * scale, 0), 0.2 * scale, 3.8 * scale, b, life * 0.55, 0.15)
			burst(pos + Vector3.new(0, 1 * scale, 0), 18, 7 * scale, 0.24 * scale, a, b, life, false, 0.1)
			for i = 1, amount(10) do
				local ang = (i / amount(10)) * math.pi * 2
				line(pos + Vector3.new(0, 1 * scale, 0), pos + Vector3.new(math.cos(ang) * 7 * scale, 1 * scale, math.sin(ang) * 7 * scale), 0.08 * scale, i % 2 == 0 and a or b, life * 0.7)
			end
		elseif mode == 'Lightning' then
			local top = pos + Vector3.new(0, 13 * scale, 0)
			for strike = 1, amount(3) do
				local last = top + Vector3.new(math.random(-18, 18) / 10 * scale, 0, math.random(-18, 18) / 10 * scale)
				for step = 1, 7 do
					local nextp = top:Lerp(pos + Vector3.new(0, 1 * scale, 0), step / 7) + Vector3.new(math.random(-12, 12) / 10 * scale, 0, math.random(-12, 12) / 10 * scale)
					line(last, nextp, 0.11 * scale, strike % 2 == 0 and b or a, life * 0.65)
					last = nextp
				end
			end
			sphere(pos, 0.25 * scale, 3.5 * scale, b, life * 0.55, 0.1)
		elseif mode == 'Soul' then
			sphere(pos + Vector3.new(0, 1.5 * scale, 0), 0.4 * scale, 3.4 * scale, a, life, 0.4)
			for i = 1, amount(14) do
				local start = pos + Vector3.new(math.random(-16, 16) / 10, math.random(0, 25) / 10, math.random(-16, 16) / 10) * scale
				local orb = part(Vector3.one * 0.18 * scale, CFrame.new(start), i % 2 == 0 and a or b, 0.15, Enum.Material.Neon, Enum.PartType.Ball)
				tween(orb, life, {CFrame = CFrame.new(start + Vector3.new(math.random(-10, 10) / 10, 7 + math.random() * 3, math.random(-10, 10) / 10) * scale), Transparency = 1, Size = Vector3.one * 0.04}, Enum.EasingStyle.Sine)
				cleanup(orb, life)
			end
		elseif mode == 'Rings' or mode == 'Orbit' then
			for ring = 1, 3 do
				for i = 1, amount(14) do
					local ang = (i / amount(14)) * math.pi * 2 + ring
					local start = pos + Vector3.new(math.cos(ang) * 1.2 * scale, (ring - 2) * 0.7 * scale + 1.5 * scale, math.sin(ang) * 1.2 * scale)
					local finish = pos + Vector3.new(math.cos(ang + 1.5) * (3 + ring) * scale, (ring - 2) * 0.8 * scale + 1.5 * scale, math.sin(ang + 1.5) * (3 + ring) * scale)
					local orb = part(Vector3.one * 0.12 * scale, CFrame.new(start), ring % 2 == 0 and a or b, 0, Enum.Material.Neon, Enum.PartType.Ball)
					tween(orb, life, {CFrame = CFrame.new(finish), Transparency = 1}, Enum.EasingStyle.Sine)
					cleanup(orb, life)
				end
			end
		elseif mode == 'Spiral' or mode == 'Tornado' then
			for i = 1, amount(26) do
				local alpha = i / amount(26)
				local ang = alpha * math.pi * (mode == 'Tornado' and 8 or 5)
				local radius = (mode == 'Tornado' and (0.6 + alpha * 3) or 2.6) * scale
				local start = pos + Vector3.new(math.cos(ang) * radius, alpha * 6 * scale, math.sin(ang) * radius)
				local orb = part(Vector3.one * (0.12 + alpha * 0.1) * scale, CFrame.new(start), i % 2 == 0 and a or b, 0, Enum.Material.Neon, Enum.PartType.Ball)
				tween(orb, life, {CFrame = CFrame.new(start + Vector3.new(math.cos(ang + 2) * 2 * scale, 3 * scale, math.sin(ang + 2) * 2 * scale)), Transparency = 1}, Enum.EasingStyle.Sine)
				cleanup(orb, life)
			end
		elseif mode == 'Firework' then
			local sky = pos + Vector3.new(0, 7 * scale, 0)
			line(pos, sky, 0.12 * scale, a, life * 0.45)
			task.delay(life * 0.25, function()
				if KillEffects.Enabled then
					sphere(sky, 0.2 * scale, 2.7 * scale, b, life * 0.55, 0.2)
					burst(sky, 26, 6 * scale, 0.16 * scale, a, b, life * 0.75, false, 0.15)
				end
			end)
		elseif mode == 'Shatter' or mode == 'Disintegrate' or mode == 'Pixel Burst' then
			burst(pos + Vector3.new(0, 1.5 * scale, 0), mode == 'Disintegrate' and 30 or 22, 6 * scale, 0.3 * scale, a, b, life, true, mode == 'Disintegrate' and 0.8 or 0.15)
		elseif mode == 'Slash' then
			for i = 1, amount(4) do
				local yaw = (i / amount(4)) * math.pi
				local center = pos + Vector3.new(0, 1.8 * scale, 0)
				local dir = Vector3.new(math.cos(yaw), (i % 2 == 0 and 0.45 or -0.45), math.sin(yaw)).Unit * 5.5 * scale
				line(center - dir, center + dir, 0.16 * scale, i % 2 == 0 and a or b, life * 0.75)
			end
			sphere(pos + Vector3.new(0, 1.5 * scale, 0), 0.2 * scale, 2.7 * scale, a, life * 0.5, 0.25)
		elseif mode == 'Beam' then
			line(pos - Vector3.new(0, 3 * scale, 0), pos + Vector3.new(0, 14 * scale, 0), 0.35 * scale, a, life)
			line(pos - Vector3.new(0, 2 * scale, 0), pos + Vector3.new(0, 11 * scale, 0), 0.12 * scale, b, life * 0.75)
			sphere(pos + Vector3.new(0, 1.5 * scale, 0), 0.4 * scale, 4 * scale, b, life * 0.65, 0.25)
		elseif mode == 'Pulse' or mode == 'Shockwave' then
			for i = 1, 3 do
				task.delay((i - 1) * life * 0.12, function()
					if KillEffects.Enabled then
						sphere(pos + Vector3.new(0, 1 * scale, 0), 0.3 * scale, (3 + i * 1.8) * scale, i % 2 == 0 and a or b, life * 0.65, 0.65)
					end
				end)
			end
		elseif mode == 'Confetti' or mode == 'Rainbow' then
			burst(pos + Vector3.new(0, 2 * scale, 0), 34, 7 * scale, 0.18 * scale, a, b, life, true, 0.8, mode == 'Rainbow')
		elseif mode == 'Galaxy' then
			sphere(pos + Vector3.new(0, 1.5 * scale, 0), 0.4 * scale, 3.2 * scale, b, life, 0.45)
			for i = 1, amount(30) do
				local ang = (i / amount(30)) * math.pi * 4
				local rad = (1 + (i % 5) * 0.45) * scale
				local start = pos + Vector3.new(math.cos(ang) * rad, 1.5 * scale + math.sin(ang * 0.5) * 0.8 * scale, math.sin(ang) * rad)
				local orb = part(Vector3.one * 0.11 * scale, CFrame.new(start), i % 2 == 0 and a or b, 0, Enum.Material.Neon, Enum.PartType.Ball)
				tween(orb, life, {CFrame = CFrame.new(pos + Vector3.new(math.cos(ang + 2) * (rad + 2 * scale), 1.5 * scale + math.sin(ang) * 1.5 * scale, math.sin(ang + 2) * (rad + 2 * scale))), Transparency = 1}, Enum.EasingStyle.Sine)
				cleanup(orb, life)
			end
		elseif mode == 'Freeze' or mode == 'Crystal' then
			for i = 1, amount(16) do
				local ang = (i / amount(16)) * math.pi * 2
				local endpoint = pos + Vector3.new(math.cos(ang) * (2.5 + math.random() * 3) * scale, (1 + math.random() * 4) * scale, math.sin(ang) * (2.5 + math.random() * 3) * scale)
				local shard = line(pos + Vector3.new(0, 0.6 * scale, 0), endpoint, (0.08 + math.random() * 0.13) * scale, i % 2 == 0 and a or b, life)
				if shard then shard.Material = Enum.Material.Ice end
			end
			sphere(pos + Vector3.new(0, 1 * scale, 0), 0.25 * scale, 3.2 * scale, a, life * 0.65, 0.45)
		elseif mode == 'Void' or mode == 'Black Hole' then
			local center = pos + Vector3.new(0, 1.7 * scale, 0)
			sphere(center, 0.35 * scale, 3.8 * scale, Color3.new(0.01, 0.01, 0.02), life, 0.05)
			for i = 1, amount(26) do
				local ang = (i / amount(26)) * math.pi * 5
				local start = center + Vector3.new(math.cos(ang) * 5 * scale, math.sin(ang * 0.5) * 2.2 * scale, math.sin(ang) * 5 * scale)
				local orb = part(Vector3.one * 0.14 * scale, CFrame.new(start), i % 2 == 0 and a or b, 0, Enum.Material.Neon, Enum.PartType.Ball)
				tween(orb, life, {CFrame = CFrame.new(center), Transparency = 1, Size = Vector3.one * 0.03}, Enum.EasingStyle.Quint)
				cleanup(orb, life)
			end
		elseif mode == 'Ghost' then
			ghostEffect(death, a, scale, life)
		elseif mode == 'Hearts' then
			symbol(pos + Vector3.new(0, 1.5 * scale, 0), '♥', a, life, 9, scale)
		elseif mode == 'Skull' then
			symbol(pos + Vector3.new(0, 3 * scale, 0), '☠', a, life, 1, 1.35 * scale)
			sphere(pos + Vector3.new(0, 1 * scale, 0), 0.25 * scale, 3.5 * scale, b, life * 0.7, 0.5)
		end
	end

	local function rememberDeath(ent)
		if not ent or ent == entitylib.character or not ent.Id then return end
		local newHealth = ent.Health or 0
		local oldHealth = healthCache[ent.Id]
		healthCache[ent.Id] = newHealth
		if oldHealth and oldHealth > 0 and newHealth <= 0 and ent.RootPart then
			local hit = recentHits[ent.Id]
			table.insert(recentDeaths, 1, {
				Id = ent.Id,
				Position = ent.RootPart.Position,
				CFrame = ent.RootPart.CFrame,
				Character = ent.Character,
				Color = entitylib.getEntityColor(ent),
				Time = tick(),
				LocalHitTime = hit and hit.Time,
				Headshot = hit and hit.Headshot or false,
				Used = false
			})
			while #recentDeaths > 16 do table.remove(recentDeaths) end
		end
	end

	local function consumeDeath()
		local now = tick()
		local preferred = frontlines.LastLocalHit
		if preferred and now - preferred.Time <= 1.5 then
			for _, death in recentDeaths do
				if not death.Used and death.Id == preferred.Id and now - death.Time <= 1.5 then
					death.Used = true
					return death
				end
			end
		end
		for _, death in recentDeaths do
			if not death.Used and death.LocalHitTime and now - death.LocalHitTime <= 1.6 and now - death.Time <= 1.5 then
				death.Used = true
				return death
			end
		end
		for _, death in recentDeaths do
			if not death.Used and now - death.Time <= 0.7 then
				death.Used = true
				return death
			end
		end
	end

	KillEffects = vape.Categories.Render:CreateModule({
		Name = 'KillEffects',
		Function = function(callback)
			if callback then
				table.clear(healthCache)
				table.clear(recentDeaths)
				table.clear(recentHits)
				for _, ent in entitylib.List do
					healthCache[ent.Id] = ent.Health or 100
				end

				KillEffects:Clean(frontlines.LocalHitEvent.Event:Connect(function(ent, pos, headshot)
					if ent and ent.Id then
						recentHits[ent.Id] = {Time = tick(), Position = pos, Headshot = headshot}
					end
				end))
				KillEffects:Clean(entitylib.Events.EntityUpdated:Connect(rememberDeath))
				KillEffects:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
					healthCache[ent.Id] = ent.Health or 100
				end))
				KillEffects:Clean(entitylib.Events.EntityRemoved:Connect(function(ent)
					if ent and ent.Id then healthCache[ent.Id] = nil end
				end))
				KillEffects:Clean(frontlines.KillEffectEvent.Event:Connect(function()
					task.spawn(function()
						for _ = 1, 8 do
							if not KillEffects.Enabled then return end
							local death = consumeDeath()
							if death then
								runEffect(death)
								return
							end
							task.wait(0.035)
						end
					end)
				end))
			else
				Folder:ClearAllChildren()
				table.clear(healthCache)
				table.clear(recentDeaths)
				table.clear(recentHits)
			end
		end,
		Tooltip = 'Reworked kill effects with local-hit matching and performance-aware visuals.'
	})

	Mode = KillEffects:CreateDropdown({
		Name = 'Mode',
		List = {'Nova', 'Explosion', 'Lightning', 'Soul', 'Rings', 'Spiral', 'Firework', 'Tornado', 'Shatter', 'Slash', 'Beam', 'Pulse', 'Shockwave', 'Confetti', 'Rainbow', 'Galaxy', 'Freeze', 'Void', 'Ghost', 'Hearts', 'Skull', 'Black Hole', 'Disintegrate', 'Crystal', 'Orbit', 'Pixel Burst', 'Random'},
		Default = 'Nova'
	})
	ColorMode = KillEffects:CreateDropdown({Name = 'Color Mode', List = {'Custom', 'Target', 'Rainbow'}, Default = 'Custom'})
	PrimaryColor = KillEffects:CreateColorSlider({Name = 'Primary Color', DefaultHue = 0.78, DefaultSat = 0.75, DefaultValue = 1})
	SecondaryColor = KillEffects:CreateColorSlider({Name = 'Secondary Color', DefaultHue = 0.58, DefaultSat = 0.7, DefaultValue = 1})
	EffectSize = KillEffects:CreateSlider({Name = 'Size', Min = 0.5, Max = 2.5, Default = 1, Decimal = 10})
	Lifetime = KillEffects:CreateSlider({Name = 'Lifetime', Min = 0.2, Max = 3, Default = 0.9, Decimal = 100, Suffix = 's'})
	Quality = KillEffects:CreateDropdown({Name = 'Quality', List = {'Low', 'Normal', 'High'}, Default = 'Normal'})
	KillSound = KillEffects:CreateToggle({
		Name = 'Kill Sound',
		Function = function(callback)
			KillSoundFile.Object.Visible = callback
			KillSoundVolume.Object.Visible = callback
		end
	})
	KillSoundFile = KillEffects:CreateTextBox({
		Name = 'Kill Sound File / ID',
		Default = 'rbxassetid://9118823106',
		Darker = true,
		Visible = false,
		Function = function()
			cachedSoundInput = nil
			cachedSoundAsset = nil
		end
	})
	KillSoundVolume = KillEffects:CreateSlider({Name = 'Kill Sound Volume', Min = 0, Max = 2, Default = 0.7, Decimal = 100, Darker = true, Visible = false})

	vape:Clean(function()
		if Folder then Folder:Destroy() end
	end)
end)

run(function()
	local HeadshotSound
	local SoundFile
	local Volume
	local Pitch
	local ConfirmedHits
	local Cooldown
	local pending = {}
	local cachedPath
	local cachedAsset
	local lastPlay = 0
	local lastError = 0
	local customAsset = getcustomasset or getsynasset or getasset

	-- SoundFile is ALWAYS a real file inside the executor workspace.
	-- Examples: "headshot.mp3", "sounds/headshot.ogg", "assets/hit.wav"
	local function normalizeWorkspacePath(value)
		local path = tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', ''):gsub('\\', '/')
		path = path:gsub('^file://', '')
		path = path:gsub('^workspace/', '')
		path = path:gsub('^Workspace/', '')
		path = path:gsub('^/', '')
		return path
	end

	local function resolveWorkspaceSound(value)
		local path = normalizeWorkspacePath(value)
		if path == '' then return nil, 'No file selected.' end

		-- Explicitly reject Roblox asset IDs: this module is workspace-file only.
		if path:match('^%d+$') or path:lower():match('^rbxasset') then
			return nil, 'Use a file from your executor workspace, not a Roblox asset ID.'
		end

		if cachedPath == path and cachedAsset then
			return cachedAsset
		end

		if type(isfile) == 'function' then
			local ok, exists = pcall(isfile, path)
			if ok and not exists then
				return nil, 'File not found in workspace: '..path
			end
		end

		if not customAsset then
			return nil, 'Your executor does not provide getcustomasset/getsynasset/getasset.'
		end

		local ok, asset = pcall(customAsset, path)
		if not ok or not asset then
			return nil, 'Could not load workspace file: '..path
		end

		cachedPath = path
		cachedAsset = asset
		return asset
	end

	local function playHeadshot()
		if tick() - lastPlay < Cooldown.Value then return end

		local asset, err = resolveWorkspaceSound(SoundFile.Value)
		if not asset then
			if tick() - lastError > 2 then
				lastError = tick()
				notif('HeadshotSound', err or 'Failed to load workspace sound file.', 5, 'alert')
			end
			return
		end

		lastPlay = tick()
		local sound = Instance.new('Sound')
		sound.Name = 'VapeHeadshotSound'
		-- Roblox Sound objects still require a Content string internally.
		-- getcustomasset/getsynasset creates that Content string directly from the local workspace file.
		sound.SoundId = asset
		sound.Volume = Volume.Value
		sound.PlaybackSpeed = Pitch.Value
		sound.Parent = gameCamera
		sound:Play()
		debrisService:AddItem(sound, 8)
	end

	local function trimPending()
		local now = tick()
		for i = #pending, 1, -1 do
			if now - pending[i].Time > 0.7 then
				table.remove(pending, i)
			end
		end
	end

	HeadshotSound = vape.Categories.Render:CreateModule({
		Name = 'HeadshotSound',
		Function = function(callback)
			if callback then
				table.clear(pending)
				cachedPath = nil
				cachedAsset = nil

				HeadshotSound:Clean(frontlines.LocalHitEvent.Event:Connect(function(ent, _, headshot)
					if not headshot or not ent or not ent.Id then return end
					if not ConfirmedHits.Enabled then
						playHeadshot()
						return
					end

					trimPending()
					table.insert(pending, {
						Id = ent.Id,
						Health = ent.Health or 100,
						Time = tick()
					})
				end))

				HeadshotSound:Clean(entitylib.Events.EntityUpdated:Connect(function(ent)
					if not ent or not ent.Id then return end
					trimPending()
					for i = #pending, 1, -1 do
						local hit = pending[i]
						if hit.Id == ent.Id and (ent.Health or 0) < hit.Health then
							table.remove(pending, i)
							playHeadshot()
							break
						end
					end
				end))
			else
				table.clear(pending)
			end
		end,
		Tooltip = 'Plays a sound file directly from your executor workspace when you land a headshot.'
	})

	SoundFile = HeadshotSound:CreateTextBox({
		Name = 'Workspace Sound File',
		Default = 'headshot.mp3',
		Function = function()
			cachedPath = nil
			cachedAsset = nil
		end
	})
	Volume = HeadshotSound:CreateSlider({Name = 'Volume', Min = 0, Max = 2, Default = 1, Decimal = 100})
	Pitch = HeadshotSound:CreateSlider({Name = 'Pitch', Min = 0.5, Max = 2, Default = 1, Decimal = 100})
	Cooldown = HeadshotSound:CreateSlider({Name = 'Cooldown', Min = 0, Max = 0.5, Default = 0.03, Decimal = 100, Suffix = 's'})
	ConfirmedHits = HeadshotSound:CreateToggle({Name = 'Confirmed Hits', Default = true})
end)

run(function()
	local GrenadeESP
	local Background
	local Color = {}
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.holder
	local old
	
	local function addESP(v)
		if vape.ThreadFix then
			setthreadidentity(8)
		end
		if not v.model or v.model.Name ~= 'frag' then return end
		local billboard = Instance.new('BillboardGui')
		billboard.Parent = Folder
		billboard.Name = v.model.Name
		billboard.Size = UDim2.fromOffset(32, 32)
		billboard.AlwaysOnTop = true
		billboard.ClipsDescendants = false
		billboard.Adornee = v.model.PrimaryPart
		local blur = addBlur(billboard)
		blur.Visible = Background.Enabled
		local image = Instance.new('ImageLabel')
		image.Size = UDim2.fromScale(1, 1)
		image.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		image.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
		image.BorderSizePixel = 0
		image.Image = 'rbxassetid://12660993553'
		image.Parent = billboard
		local uicorner = Instance.new('UICorner')
		uicorner.CornerRadius = UDim.new(0, 4)
		uicorner.Parent = image
		Reference[v.model] = billboard
		v.model.Destroying:Connect(function()
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			if Reference[v.model] then
				Reference[v.model]:Destroy()
				Reference[v.model] = nil
			end
		end)
	end
	
	GrenadeESP = vape.Categories.Render:CreateModule({
		Name = 'GrenadeESP',
		Function = function(callback)
			if callback then
				old = hookfunction(frontlines.SpawnThrowable, function(id, pos, velo)
					local res = old(id, pos, velo)
					addESP(frontlines.Throwables[id])
					return res
				end)
			else
				hookfunction(frontlines.SpawnThrowable, old)
				Folder:ClearAllChildren()
				table.clear(Reference)
			end
		end,
		Tooltip = 'ESP for grenades'
	})
	Background = GrenadeESP:CreateToggle({
		Name = 'Background',
		Function = function(callback)
			if Color.Object then
				Color.Object.Visible = callback
			end
			for i, v in Reference do
				v.ImageLabel.BackgroundTransparency = 1 - (callback and Color.Opacity or 0)
				v.Blur.Visible = callback
			end
		end,
		Default = true
	})
	Color = GrenadeESP:CreateColorSlider({
		Name = 'Background Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			for i, v in Reference do
				v.ImageLabel.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
				v.ImageLabel.BackgroundTransparency = 1 - opacity
			end
		end,
		Darker = true
	})
end)

run(function()
	local NoHurtCam
	
	NoHurtCam = vape.Categories.Render:CreateModule({
		Name = 'NoHurtCam',
		Function = function(callback)
			if callback then
				NoHurtCam:Clean(hookEvent('UPDATE_FPV_SOL_DAMAGE_GFX', function() return true end))
				NoHurtCam:Clean(hookEvent('UPDATE_FPV_SOL_HEALTH_SFX', function() return true end))
				NoHurtCam:Clean(hookEvent('DISPLAY_SUPPRESSION_VIGNETTE', function() return true end))
			end
		end,
		Tooltip = 'Removes camera flash after taking damage'
	})
end)

run(function()
	local ThirdPerson
	local Distance
	local hook = false
	
	ThirdPerson = vape.Categories.Render:CreateModule({
		Name = 'ThirdPerson',
		Function = function(callback)
			if callback then
				ThirdPerson:Clean(hookEvent('STEP_FPV_SOL_CAMERA', function()
					local bone = frontlines.Main.globals.fpv_sol_instances.camera_bone
					local state = frontlines.Main.globals.cli_state
					if bone and state.state == frontlines.Main.cli_state_t.COMBAT then
						local id = state.fpv_sol_id
						local actor = frontlines.Main.soldier_actors[id]
						local cf = bone.TransformedWorldCFrame
						if actor then 
							actor.main.direction.Value = frontlines.Main.globals.fpv_sol_dir.dir 
						end
						
						gameCamera.CFrame = cf * CFrame.new(0, 2, Distance.Value)
						gameCamera.Focus = cf + cf.LookVector
						frontlines.Main.exe_set(frontlines.Main.exe_set_t.TPV_SOLDIER_JOINT_STEP, id)
						return true
					end
				end))
	
				if entitylib.isAlive then
					local char = entitylib.character.Character
					for i, v in char:GetDescendants() do
						if v:IsA('BasePart') then 
							v.LocalTransparencyModifier = v.Parent ~= char and 1 or 0 
						end
					end
				end
	
				ThirdPerson:Clean(entitylib.Events.LocalAdded:Connect(function(ent)
					local id = frontlines.Main.globals.cli_state.fpv_sol_id
					local actor = frontlines.Main.soldier_actors[id]
					if actor then
						local gun = frontlines.Main.globals.fpv_sol_equipment.curr_equipment
						frontlines.Events[frontlines.Main.exe_func_t.INIT_TPV_SOL_JOINTS](id)
						frontlines.Events[frontlines.Main.exe_func_t.INIT_TPV_SOL_EQUIPMENT_JOINTS](id, gun)
						frontlines.Events[frontlines.Main.exe_func_t.SET_SOLDIER_ANIMATION_VALUES](id, gun)
						actor.main.alive.Value = true
					end
	
					for i, v in ent.Character:GetDescendants() do
						if v:IsA('BasePart') then 
							v.LocalTransparencyModifier = v.Parent ~= ent.Character and 1 or 0 
						end
					end
				end))
			else
				if entitylib.isAlive then
					local char = entitylib.character.Character
					for i, v in char:GetDescendants() do
						if v:IsA('BasePart') then 
							v.LocalTransparencyModifier = v.Parent ~= char and 0 or 1 
						end
					end
				end
			end
		end,
		Tooltip = 'View your character in third person'
	})
	Distance = ThirdPerson:CreateSlider({
		Name = 'Distance',
		Min = 1,
		Max = 15,
		Default = 8
	})
end)

run(function()
	local AutoRespawn
	
	AutoRespawn = vape.Categories.Utility:CreateModule({
		Name = 'AutoRespawn',
		Function = function(callback)
			if callback then
				AutoRespawn:Clean(hookEvent('ENTER_CLI_KILLCAM', function(id, health)
					task.delay(0, function()
						frontlines.Main.exe_set(frontlines.Main.exe_set_t.CTRL_KILLCAM_TO_COMBAT_RELEASE)
					end)
				end))
			end
		end,
		Tooltip = 'Automatically respawns after death'
	})
end)

run(function()
	local ChatSpammer
	local Lines
	local Mode
	local Delay
	local Hide
	local oldchat
	
	ChatSpammer = vape.Categories.Utility:CreateModule({
		Name = 'ChatSpammer',
		Function = function(callback)
			if callback then
				local ind = 1
				repeat
					local message = (#Lines.ListEnabled > 0 and Lines.ListEnabled[math.random(1, #Lines.ListEnabled)] or 'vxpe on top')
					if Mode.Value == 'Order' and #Lines.ListEnabled > 0 then
						message = Lines.ListEnabled[ind] or Lines.ListEnabled[1]
						ind += 1
						if ind > #Lines.ListEnabled then 
							ind = 1 
						end
					end
					frontlines.Main.utils.net_msg_util.c_prep_net_msg(frontlines.Main.globals.null_net_msg_state, frontlines.Main.enums.c_net_msg.CHAT, message:sub(1, 100))
					task.wait(1)
				until not ChatSpammer.Enabled
			end
		end,
		Tooltip = 'Automatically types in chat'
	})
	Lines = ChatSpammer:CreateTextList({Name = 'Lines'})
	Mode = ChatSpammer:CreateDropdown({
		Name = 'Mode',
		List = {'Random', 'Order'}
	})
end)

run(function()
	local PickupRange
	local Range
	
	PickupRange = vape.Categories.Utility:CreateModule({
		Name = 'PickupRange',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive then
						for i, v in frontlines.Main.globals.equipment_drop_ids do
							local obj = frontlines.Main.globals.equipments[v]
							if obj and obj.model and obj.model.PrimaryPart and (obj.model.PrimaryPart.Position - entitylib.character.RootPart.Position).Magnitude < Range.Value then
								if frontlines.Main.matrix_bit(frontlines.PickupBit, v) == 0 then
									frontlines.Main.set_matrix_bit(frontlines.PickupBit, v, true)
									frontlines.Main.utils.net_msg_util.c_prep_net_msg(frontlines.Main.globals.combat_net_msg_state, frontlines.Main.enums.c_net_msg.PICKUP_AMMO, v)
									break
								end
							end
						end
					end
	
					task.wait(0.05)
				until not PickupRange.Enabled
			end
		end,
		Tooltip = 'Picks up ammo from dropped guns in the proximity'
	})
	Range = PickupRange:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 20,
		Default = 20
	})
end)

run(function()
	local BulletTracers
	local Material
	local Color
	local Lifetime
	local Fade
	local DrawingToggle
	local drawingobjs = {}
	
	BulletTracers = vape.Legit:CreateModule({
		Name = 'BulletTracers',
		Function = function(callback)
			if callback then 
				BulletTracers:Clean(frontlines.LocalBulletEvent.Event:Connect(function(id, btype, origin, velocity)
					if DrawingToggle.Enabled then 
						local obj = Drawing.new('Line')
						obj.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
						drawingobjs[obj] = {origin, origin + (velocity.Unit * 1000), tick()}
						task.delay(Lifetime.Value, function()
							drawingobjs[obj] = nil
							obj.Visible = false
							obj:Remove()
						end)
					else
						local obj = Instance.new('Part')
						obj.Size = Vector3.new(0.05, 0.05, 1000)
						obj.CFrame = CFrame.lookAt(origin + (velocity.Unit * 500), origin + (velocity.Unit * 1000))
						obj.CanCollide = false
						obj.CanQuery = false
						obj.Anchored = true
						obj.Material = Enum.Material[Material.Value]
						obj.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
						obj.Transparency = 1 - Color.Opacity
						obj.Parent = workspace
						if Fade.Enabled then 
							local tween = tweenService:Create(obj, TweenInfo.new(Lifetime.Value), {
								Transparency = 1
							})
							tween.Completed:Connect(function() 
								tween:Destroy() 
							end)
							tween:Play()
						end
						debrisService:AddItem(obj, Lifetime.Value)
					end
				end))
	
				if DrawingToggle.Enabled then
					BulletTracers:Clean(runService.RenderStepped:Connect(function()
						for obj, data in drawingobjs do 
							local from, vis = gameCamera:WorldToViewportPoint(data[1])
							local to, vis2 = gameCamera:WorldToViewportPoint(data[2])
							if vis and vis2 then
								obj.Visible = true
								obj.From = Vector2.new(from.X, from.Y)
								obj.To = Vector2.new(to.X, to.Y)
								if Fade.Enabled then 
									obj.Transparency = Color.Opacity * (1 - math.clamp((tick() - data[3]) / Lifetime.Value, 0, 1))
								end
							else
								obj.Visible = false
							end
						end
					end))
				end
			end
		end,
		Tooltip = 'Replacement tracers for bullets'
	})
	local materials = {'SmoothPlastic'}
	for _, v in Enum.Material:GetEnumItems() do
		if v.Name ~= 'SmoothPlastic' then 
			table.insert(materials, v.Name) 
		end
	end
	Material = BulletTracers:CreateDropdown({
		Name = 'Material',
		List = materials
	})
	Color = BulletTracers:CreateColorSlider({
		Name = 'Tracer Color',
		DefaultOpacity = 0.5
	})
	Lifetime = BulletTracers:CreateSlider({
		Name = 'Lifetime',
		Min = 0,
		Max = 0.5,
		Default = 0.2,
		Decimal = 10
	})
	Fade = BulletTracers:CreateToggle({
		Name = 'Fade',
		Default = true
	})
	DrawingToggle = BulletTracers:CreateToggle({
		Name = 'Drawing',
		Function = function()
			if BulletTracers.Enabled then 
				BulletTracers:Toggle()
				BulletTracers:Toggle()
			end
		end
	})
end)
