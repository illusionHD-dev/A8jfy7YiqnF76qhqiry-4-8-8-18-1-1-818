-- Local customization: dismiss the full-screen loader after initialization.
repeat task.wait() until game:IsLoaded()
local launchEnvironment = (getgenv and getgenv()) or _G
local riseRequested = launchEnvironment.Rise
if riseRequested == nil then riseRequested = shared.Rise end
shared.Rise = riseRequested == true
if shared.vape then shared.vape:Uninject() end

local vape
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
local function downloadFile(path, func)
	if not isfile(path) then
		local suc, res = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/illusionhd-dev/A8jfy7YiqnF76qhqiry-4-8-8-18-1-1-818/'..readfile('newvape/profiles/commit.txt')..'/'..select(1, path:gsub('newvape/', '')), true)
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

downloadFile('newvape/guis/themes.lua')
local loading = loadstring(downloadFile('newvape/guis/loading.lua'), 'Vape loading screen')()

local function finishLoading()
	vape.Init = nil
	loading:WaitForMinimumDisplay()
	vape:Load()
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
			teleportScript = 'shared.Rise = '..tostring(shared.Rise == true)..'\n'..teleportScript
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

if not isfile('newvape/profiles/gui.txt') then
	writefile('newvape/profiles/gui.txt', 'new')
end
local gui = shared.Rise and 'rise-v7' or 'new'
if shared.Rise then
	assert(isfile('newvape/guis/rise-v7.lua'), 'Rise v7 is missing: install newvape/guis/rise-v7.lua')
end

if not isfolder('newvape/assets/'..gui) then
	makefolder('newvape/assets/'..gui)
end
vape = loadstring(downloadFile('newvape/guis/'..gui..'.lua'), 'gui')()
shared.vape = vape
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
		loadstring(readfile('newvape/games/'..game.PlaceId..'.lua'), tostring(game.PlaceId))(...)
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
