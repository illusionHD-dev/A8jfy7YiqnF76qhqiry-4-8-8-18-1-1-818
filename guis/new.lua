-- Local customization: dismiss the full-screen loader after initialization.
repeat task.wait() until game:IsLoaded()

if shared.vape then shared.vape:Uninject() end

local vape
local baseVapeLoad
local loadstring = function(...)
	local res, err = loadstring(...)
	if err then
		warn('Vape failed to compile: '..tostring(err))
		if vape then
			vape:CreateNotification('Vape', 'Failed to load : '..err, 30, 'alert')
		end
		error(err, 2)
	end
	return res
end
local queue_on_teleport = queue_on_teleport or function() end
local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end
local cloneref = cloneref or function(obj)
	return obj
end
local playersService = cloneref(game:GetService('Players'))
local REPO_RAW = 'https://raw.githubusercontent.com/illusionhd-dev/A8jfy7YiqnF76qhqiry-4-8-8-18-1-1-818/main/'

-- Always use the normal Vape GUI.
local gui = 'new'

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

local function validCachedFile(path)
	if not isfile(path) then return false end
	local ok, data = pcall(readfile, path)
	return ok and not invalidDownload(data, path)
end

local function downloadFile(path, func)
	if not validCachedFile(path) then
		local remotePath = select(1, path:gsub('newvape/', ''))
		local suc, res = pcall(function()
			return game:HttpGet(REPO_RAW..remotePath, true)
		end)
		if not suc or invalidDownload(res, path) then
			error('Failed to download '..remotePath..' from GitHub: '..tostring(res), 2)
		end
		if path:find('.lua', 1, true) then
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end

downloadFile('newvape/guis/themes.lua')
local loading = loadstring(downloadFile('newvape/guis/loading.lua'), 'Vape loading screen')()

local function finishLoading()
	vape.Init = nil
	loading:WaitForMinimumDisplay()

	-- Frontlines can replace vape.Load during the actor bootstrap.
	-- Some executors lose that temporary method during the handoff, so keep
	-- the GUI's original Load function as a guaranteed fallback.
	local loadMethod = vape and vape.Load
	if type(loadMethod) ~= 'function' then
		loadMethod = baseVapeLoad
		if type(loadMethod) == 'function' then
			vape.Load = loadMethod
		end
	end

	if type(loadMethod) ~= 'function' then
		error('[illusionHD] GUI loaded without a usable Load method.', 0)
	end

	loadMethod(vape)
	if vape.HideLoadingScreen then
		vape:HideLoadingScreen()
	end
	task.spawn(function()
		repeat
			vape:Save()
			task.wait(10)
		until not vape.Loaded
	end)

	local teleportedServers
	vape:Clean(playersService.LocalPlayer.OnTeleport:Connect(function()
		if (not teleportedServers) and (not shared.VapeIndependent) then
			teleportedServers = true
			local teleportScript = [[
				shared.vapereload = true
				if shared.VapeDeveloper then
					loadstring(readfile('newvape/loader.lua'), 'loader')()
				else
					loadstring(game:HttpGet('https://raw.githubusercontent.com/illusionhd-dev/A8jfy7YiqnF76qhqiry-4-8-8-18-1-1-818/'..readfile('newvape/profiles/commit.txt')..'/loader.lua', true), 'loader')()
				end
			]]
			if shared.VapeDeveloper then
				teleportScript = 'shared.VapeDeveloper = true\n'..teleportScript
			end
			if shared.VapeCustomProfile then
				teleportScript = 'shared.VapeCustomProfile = "'..shared.VapeCustomProfile..'"\n'..teleportScript
			end
			vape:Save()
			queue_on_teleport(teleportScript)
		end
	end))

	if not shared.vapereload then
		if not vape.Categories then return end
		if vape.Settings.GUI.Options['GUI bind indicator'].Enabled then
			vape:CreateNotification('Finished Loading', vape.VapeButton and 'Press the button in the top right to open GUI' or 'Press '..table.concat(vape.GUIBind.Keys, ' + '):upper()..' to open GUI', 5)
		end
	end
end

if not isfolder('newvape/assets/'..gui) then
	makefolder('newvape/assets/'..gui)
end
vape = loadstring(downloadFile('newvape/guis/'..gui..'.lua'), 'gui')()
if type(vape) ~= 'table' then
	error('[illusionHD] GUI file did not return the Vape table.', 0)
end
baseVapeLoad = vape.Load
if type(baseVapeLoad) ~= 'function' then
	error('[illusionHD] GUI file is missing vape:Load(). Re-upload guis/new.lua.', 0)
end
shared.vape = vape

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

vape.HideLoadingScreen = function(_, immediate)
	loading:HideLoadingScreen(immediate)
end
vape:Clean(function()
	if loading.LoadingScreen then
		loading.LoadingScreen:Destroy()
		loading.LoadingScreen = nil
	end
end)
if loading.LoadingStatus then
	loading.LoadingStatus.Text = 'Loading Vape\nPreparing game modules'
end

if not shared.VapeIndependent then
	loadstring(downloadFile('newvape/games/universal.lua'), 'universal')()
	if isfile('newvape/games/'..game.PlaceId..'.lua') then
		loadstring(downloadFile('newvape/games/'..game.PlaceId..'.lua'), tostring(game.PlaceId))(...)
	else
		if not shared.VapeDeveloper then
			local suc, res = pcall(function()
				return game:HttpGet('https://raw.githubusercontent.com/illusionhd-dev/A8jfy7YiqnF76qhqiry-4-8-8-18-1-1-818/'..readfile('newvape/profiles/commit.txt')..'/games/'..game.PlaceId..'.lua', true)
			end)
			if suc and res ~= '404: Not Found' then
				loadstring(downloadFile('newvape/games/'..game.PlaceId..'.lua'), tostring(game.PlaceId))(...)
			end
		end
	end
	finishLoading()
else
	vape.Init = finishLoading
	return vape
end
