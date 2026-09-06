-- illusionHD simple loader
-- No GitHub API, no commit hashes, no patch injection, no background sync.

repeat task.wait() until game:IsLoaded()

local REPO = 'https://raw.githubusercontent.com/illusionhd-dev/A8jfy7YiqnF76qhqiry-4-8-8-18-1-1-818/main/'

-- These executor filesystem functions are required by Vape.
assert(type(writefile) == 'function', 'Your executor does not support writefile.')
assert(type(readfile) == 'function', 'Your executor does not support readfile.')
assert(type(makefolder) == 'function', 'Your executor does not support makefolder.')

local function folder(path)
	pcall(makefolder, path)
end

folder('newvape')
folder('newvape/assets')
folder('newvape/assets/new')
folder('newvape/games')
folder('newvape/guis')
folder('newvape/libraries')
folder('newvape/profiles')

local function badResponse(data)
	if type(data) ~= 'string' or data == '' then
		return true
	end

	local head = data:sub(1, 300):lower()
	return head:find('404: not found', 1, true)
		or head:find('<!doctype html', 1, true)
		or head:find('<html', 1, true)
		or head:find('<svg', 1, true)
		or head:find('repository not found', 1, true)
end

local function download(remote, localPath, required)
	local ok, data = pcall(function()
		return game:HttpGet(REPO..remote, true)
	end)

	if not ok or badResponse(data) then
		if required then
			error('[illusionHD] Failed to download '..remote..'\n'..tostring(data), 0)
		end
		warn('[illusionHD] Optional file skipped: '..remote)
		return false
	end

	writefile(localPath, data)
	return true
end

-- Always refresh the actual runtime files.
-- This avoids broken/stale files on somebody else's workspace.
local files = {
	{'main.lua',                    'newvape/main.lua'},
	{'loader.lua',                  'newvape/loader.lua'},

	{'games/universal.lua',         'newvape/games/universal.lua'},
	{'games/5938036553.lua',        'newvape/games/5938036553.lua'},

	{'guis/loading.lua',            'newvape/guis/loading.lua'},
	{'guis/themes.lua',             'newvape/guis/themes.lua'},
	{'guis/new.lua',                'newvape/guis/new.lua'},
	{'guis/rise-v7.lua',            'newvape/guis/rise-v7.lua'},

	{'libraries/drawing.lua',       'newvape/libraries/drawing.lua'},
	{'libraries/entity.lua',        'newvape/libraries/entity.lua'},
	{'libraries/hash.lua',          'newvape/libraries/hash.lua'},
	{'libraries/prediction.lua',    'newvape/libraries/prediction.lua'}
}

for _, file in files do
	download(file[1], file[2], true)
end

-- main.lua still uses this for teleport reload URLs.
writefile('newvape/profiles/commit.txt', 'main')

-- Optional workspace headshot sound.
pcall(function()
	download('headshot.mp3', 'newvape/headshot.mp3', false)
end)

local source = readfile('newvape/main.lua')
local chunk, compileError = loadstring(source, 'main')

if not chunk then
	error('[illusionHD] main.lua compile error:\n'..tostring(compileError), 0)
end

local ok, runtimeError = pcall(chunk)
if not ok then
	error('[illusionHD] main.lua runtime error:\n'..tostring(runtimeError), 0)
end
