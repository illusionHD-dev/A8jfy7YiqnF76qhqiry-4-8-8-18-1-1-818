-- Rise v7: optional sidebar interface inspired by the supplied legacy Rise GUI.
-- Reuses the current component API so existing game modules and profiles stay compatible.
local vape = assert(loadstring(readfile('newvape/guis/new.lua'), 'Rise v7 components'))()
local input = game:GetService('UserInputService')
local runService = game:GetService('RunService')
local http = game:GetService('HttpService')
local tween = vape.Libraries.tween
local scaled = vape.gui:FindFirstChild('ScaledGui')
local click = scaled:FindFirstChild('ClickGui')
local C = {Main = Color3.fromRGB(20, 22, 28), Side = Color3.fromRGB(16, 18, 23), Card = Color3.fromRGB(15, 18, 23), Line = Color3.fromRGB(38, 41, 48), Text = Color3.fromRGB(233, 235, 239), Muted = Color3.fromRGB(132, 138, 148), Accent = Color3.fromRGB(52, 241, 163)}
local motion = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local function create(class, properties, parent)
 local object = Instance.new(class)
 for key, value in properties do object[key] = value end
 object.Parent = parent
 return object
end
local function round(parent, radius)
 return create('UICorner', {CornerRadius = UDim.new(0, radius or 10)}, parent)
end
local function text(parent, value, size, position, bounds)
 return create('TextLabel', {BackgroundTransparency = 1, Text = value, TextSize = size, FontFace = Font.fromEnum(Enum.Font.Gotham), TextColor3 = C.Text, TextXAlignment = Enum.TextXAlignment.Left, Position = position, Size = bounds, TextTruncate = Enum.TextTruncate.AtEnd}, parent)
end
local function button(parent, value, position, size)
 local object = create('TextButton', {AutoButtonColor = false, BackgroundTransparency = 1, Text = value, TextSize = 15, FontFace = Font.fromEnum(Enum.Font.Gotham), TextColor3 = C.Text, Position = position, Size = size}, parent)
 return object
end
-- Preserve the original category objects for their APIs and profile positions.
-- Only this optional instance replaces their visible presentation.
for _, object in click:GetChildren() do
 if object:IsA('GuiObject') then object.Visible = false end
end
local shell = create('Frame', {Name = 'RiseV7', AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(900, 660), BackgroundColor3 = C.Main, BorderSizePixel = 0, ClipsDescendants = true}, click)
round(shell, 22)
create('UIStroke', {Color = C.Line, Thickness = 1}, shell)
local shellScale = create('UIScale', {Scale = 1}, shell)
local sidebar = create('Frame', {Size = UDim2.new(0, 205, 1, 0), BackgroundColor3 = C.Side, BorderSizePixel = 0}, shell)
round(sidebar, 22)
create('Frame', {Position = UDim2.new(1, -1, 0, 24), Size = UDim2.new(0, 1, 1, -48), BackgroundColor3 = C.Line, BorderSizePixel = 0}, sidebar)
local monogram = text(sidebar, 'R', 48, UDim2.fromOffset(24, 18), UDim2.fromOffset(65, 65))
monogram.FontFace = Font.fromEnum(Enum.Font.Gotham, Enum.FontWeight.Bold)
local edition = text(sidebar, 'RISE v7.0.0', 11, UDim2.new(0, 26, 1, -38), UDim2.fromOffset(160, 20))
edition.TextColor3 = C.Muted
local nav = create('ScrollingFrame', {Position = UDim2.fromOffset(16, 98), Size = UDim2.new(1, -32, 1, -154), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y}, sidebar)
create('UIListLayout', {Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder}, nav)
local drag = button(shell, '', UDim2.fromOffset(205, 0), UDim2.new(1, -205, 0, 28))
local search = create('TextBox', {Name = 'RiseSearch', Position = UDim2.fromOffset(232, 31), Size = UDim2.new(1, -292, 0, 42), BackgroundTransparency = 1, ClearTextOnFocus = false, Text = '', PlaceholderText = 'Search modules...', PlaceholderColor3 = C.Muted, TextColor3 = C.Text, TextSize = 21, FontFace = Font.fromEnum(Enum.Font.Gotham), TextXAlignment = Enum.TextXAlignment.Left}, shell)
local close = button(shell, '×', UDim2.new(1, -48, 0, 30), UDim2.fromOffset(32, 36))
local body = create('ScrollingFrame', {Name = 'Content', Position = UDim2.fromOffset(230, 92), Size = UDim2.new(1, -253, 1, -116), BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3, ScrollBarImageColor3 = C.Muted}, shell)
create('UIListLayout', {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder}, body)
create('UIPadding', {PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10)}, body)
local empty = text(body, 'No matching modules', 16, UDim2.new(), UDim2.new(1, 0, 0, 60))
empty.TextColor3 = C.Muted
local cards, settingsCards, navigation = {}, {}, {}
local selected = 'Search'
local descriptions = {}
local refresh
local function styleControl(object)
 if object:IsA('GuiObject') then object.BorderSizePixel = 0 end
 if object:IsA('TextLabel') or object:IsA('TextBox') or object:IsA('TextButton') then
  object.FontFace = Font.fromEnum(Enum.Font.Gotham)
 end
end
local styled = setmetatable({}, {__mode = 'k'})
local function styleOption(option)
 local root = option.Object
 if not root or styled[root] then return end
 styled[root] = true
 root.BackgroundTransparency = 1
 for _, object in root:GetDescendants() do styleControl(object) end
 if option.Type == 'Slider' then
  root.Size = UDim2.new(1, 0, 0, 44)
  for _, object in root:GetChildren() do
   if object:IsA('TextLabel') then
    object.Position = UDim2.fromOffset(10, 0)
    object.Size = UDim2.new(0.38, -10, 1, 0)
    object.TextSize = 15
   elseif object:IsA('TextButton') or object:IsA('TextBox') then
    object.Position = UDim2.new(0.38, 0, 0, 10)
    object.Size = UDim2.new(0.15, -8, 0, 24)
    object.TextSize = 14
   elseif object:IsA('Frame') then
    object.Position = UDim2.new(0.56, 0, 0.5, 0)
    object.Size = UDim2.new(0.42, 0, 0, 3)
   end
  end
 end
end
local function section(title)
 local card = create('Frame', {Name = title, Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = C.Card, BorderSizePixel = 0, AutomaticSize = Enum.AutomaticSize.Y}, body)
 round(card, 14)
 create('UIStroke', {Color = C.Line, Thickness = 1}, card)
 create('UIListLayout', {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2)}, card)
 create('UIPadding', {PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), PaddingBottom = UDim.new(0, 14)}, card)
 local heading = text(card, title, 19, UDim2.new(), UDim2.new(1, 0, 0, 52))
 heading.LayoutOrder = -10000
 return card
end
local function mount(module)
 if cards[module] or not module.Object or not module.Children then return end
 local card = section(module.Name)
 -- Module header is custom; the real option controls and API are retained.
 local heading = card:FindFirstChildWhichIsA('TextLabel')
 heading:Destroy()
 local header = create('Frame', {Size = UDim2.new(1, 0, 0, 104), BackgroundTransparency = 1, LayoutOrder = -10000}, card)
 local name = text(header, module.Name, 23, UDim2.fromOffset(4, 10), UDim2.new(1, -104, 0, 31))
 local description = text(header, descriptions[module.Name] or 'Configure '..module.Name, 13, UDim2.fromOffset(4, 43), UDim2.new(1, -12, 0, 22))
 description.TextColor3 = C.Muted
 local expand = button(header, 'Options  ›', UDim2.new(1, -110, 0, 72), UDim2.fromOffset(108, 28))
 expand.TextColor3 = C.Muted
 local toggle = button(header, '', UDim2.new(1, -54, 0, 15), UDim2.fromOffset(42, 23))
 toggle.BackgroundTransparency = 0
 round(toggle, 12)
 local knob = create('Frame', {Size = UDim2.fromOffset(15, 15), Position = UDim2.fromOffset(4, 4), BackgroundColor3 = C.Card, BorderSizePixel = 0}, toggle)
 round(knob, 9)
 text(header, 'Keybind', 14, UDim2.fromOffset(4, 74), UDim2.fromOffset(100, 26))
 local bind = button(header, 'None', UDim2.fromOffset(100, 74), UDim2.fromOffset(110, 26))
 bind.TextSize = 12
 bind.BackgroundTransparency = 0
 bind.BackgroundColor3 = C.Main
 round(bind, 6)
 local content = module.Children
 content.Parent = card
 content.LayoutOrder = 1
 content.BackgroundTransparency = 1
 content.Visible = false
 content.Size = UDim2.new(1, 0, 0, 0)
 module.Object.Visible = false
 local entry = {Card = card, Module = module, Content = content, Open = false, Toggle = toggle, Knob = knob, Bind = bind, Expand = expand, Name = name}
 cards[module] = entry
 local function layout()
  local list = content:FindFirstChildWhichIsA('UIListLayout')
  -- AbsoluteContentSize is in screen pixels. Convert using the GUI and shell scales.
  local globalScale = scaled:FindFirstChildWhichIsA('UIScale')
  local height = list and list.AbsoluteContentSize.Y / math.max(shellScale.Scale * (globalScale and globalScale.Scale or 1), 0.01) or 0
  if entry.Open then content.Size = UDim2.new(1, 0, 0, height) end
 end
 local list = content:FindFirstChildWhichIsA('UIListLayout')
 if list then vape:Clean(list:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(layout)) end
 for _, object in content:GetDescendants() do styleControl(object) end
 vape:Clean(content.DescendantAdded:Connect(function(object) styleControl(object) end))
 vape:Clean(toggle.MouseButton1Click:Connect(function() module:Toggle() end))
 vape:Clean(bind.MouseButton1Click:Connect(function() vape.Binding = module.Bind end))
 vape:Clean(expand.MouseButton1Click:Connect(function()
  entry.Open = not entry.Open
  content.Visible = entry.Open
  content:SetAttribute('VapeExpanded', entry.Open)
  expand.Text = entry.Open and 'Options  ˅' or 'Options  ›'
  layout()
 end))
 if refresh then refresh() end
end
local categories = {Search = true, Combat = 'Combat', Movement = 'Blatant', Render = 'Render', World = 'World', Utility = 'Utility', Inventory = 'Inventory'}
refresh = function()
 local query = search.Text:lower()
 local count = 0
 local ordered = {}
 for module, entry in cards do
  if not module.Object.Parent then entry.Card:Destroy(); cards[module] = nil
  else table.insert(ordered, entry) end
 end
 table.sort(ordered, function(a, b) return a.Module.Name:lower() < b.Module.Name:lower() end)
 for index, entry in ordered do
  local matches = selected == 'Search' or entry.Module.Category == categories[selected]
  entry.Card.Visible = matches and (query == '' or (entry.Module.Name..' '..(descriptions[entry.Module.Name] or '')):lower():find(query, 1, true) ~= nil)
  entry.Card.LayoutOrder = index
  if entry.Card.Visible then count += 1 end
 end
 for _, entry in settingsCards do entry.Card.Visible = entry.Page == selected end
 empty.Visible = categories[selected] ~= nil and count == 0
 for name, item in navigation do
  tween:Tween(item, motion, {BackgroundTransparency = name == selected and 0 or 1, TextColor3 = name == selected and C.Text or C.Muted})
 end
end
local function selectPage(name)
 if name == 'Legit' then vape:SetClickGUIVisible(false); vape:SetLegitGUIVisible(true); return end
 selected = name
 body.CanvasPosition = Vector2.zero
 refresh()
end
local names = {'Search', 'Combat', 'Movement', 'Render', 'World', 'Utility', 'Inventory', 'Themes', 'Client', 'Legit'}
local glyphs = {Search = '⌕', Combat = '×', Movement = '›', Render = '◉', World = '◇', Utility = '＋', Inventory = '▤', Themes = '◈', Client = '⚙', Legit = '✓'}
for index, name in names do
 local item = button(nav, '  '..glyphs[name]..'   '..name, UDim2.new(), UDim2.new(1, 0, 0, 39))
 item.Name = name
 item.LayoutOrder = index
 item.TextXAlignment = Enum.TextXAlignment.Left
 item.BackgroundColor3 = Color3.fromRGB(31, 35, 43)
 round(item, 9)
 navigation[name] = item
 vape:Clean(item.MouseButton1Click:Connect(function() selectPage(name) end))
end
vape:Clean(search:GetPropertyChangedSignal('Text'):Connect(function() selected = 'Search'; refresh() end))
vape:Clean(close.MouseButton1Click:Connect(function() vape:SetClickGUIVisible(false) end))
-- Capture descriptions and mount modules as each game registers them.
for _, category in vape.Categories do
 if category.CreateModule then
  local original = category.CreateModule
  category.CreateModule = function(self, props)
   descriptions[props.Name] = props.Tooltip
   local module = original(self, props)
   mount(module)
   return module
  end
 end
end
for _, module in vape.Modules do mount(module) end
local function mountSettings()
 if #settingsCards > 0 then return end
 for name, pane in vape.Settings do
  local card = section(name == 'GUI' and 'Appearance' or name)
  table.insert(settingsCards, {Card = card, Page = name == 'GUI' and 'Themes' or 'Client'})
  for _, option in pane.Options do
   if option.Object and option.Object:IsA('GuiObject') then
    option.Object.Parent = card
    for _, child in option.Object:GetDescendants() do styleControl(child) end
   end
  end
 end
 local overlays = section('Overlays')
 table.insert(settingsCards, {Card = overlays, Page = 'Client'})
 for _, option in vape.Overlays.Options do
  if option.Object and option.Object:IsA('GuiObject') then option.Object.Parent = overlays end
 end
 refresh()
end
-- Keep a separate Rise window position; default category coordinates are never moved.
local layoutPath = 'newvape/profiles/'..game.GameId..'.rise-v7.json'
local ok, saved = pcall(function() return http:JSONDecode(readfile(layoutPath)) end)
if ok and type(saved) == 'table' and type(saved.X) == 'number' and type(saved.Y) == 'number' then
 shell.Position = UDim2.fromScale(math.clamp(saved.X, 0.15, 0.85), math.clamp(saved.Y, 0.15, 0.85))
end
local function savePosition()
 if type(writefile) == 'function' then pcall(writefile, layoutPath, http:JSONEncode({X = shell.Position.X.Scale, Y = shell.Position.Y.Scale})) end
end
local dragging, dragStart, origin
vape:Clean(drag.InputBegan:Connect(function(event)
 if event.UserInputType == Enum.UserInputType.MouseButton1 or event.UserInputType == Enum.UserInputType.Touch then dragging = event; dragStart = event.Position; origin = shell.Position end
end))
vape:Clean(input.InputChanged:Connect(function(event)
 if dragging and (event.UserInputType == Enum.UserInputType.MouseMovement or event == dragging) then
  local delta = event.Position - dragStart
  shell.Position = UDim2.fromScale(math.clamp(origin.X.Scale + delta.X / click.AbsoluteSize.X, 0.15, 0.85), math.clamp(origin.Y.Scale + delta.Y / click.AbsoluteSize.Y, 0.15, 0.85))
 end
end))
vape:Clean(input.InputEnded:Connect(function(event)
 if event == dragging or event.UserInputType == Enum.UserInputType.MouseButton1 then dragging = nil; savePosition() end
end))
local function fit()
 local globalScale = scaled:FindFirstChildWhichIsA('UIScale')
 shellScale.Scale = math.min(1, math.max(click.AbsoluteSize.X - 40, 1) / 900, math.max(click.AbsoluteSize.Y - 40, 1) / 660) / math.max(globalScale and globalScale.Scale or 1, 0.01)
end
vape:Clean(click:GetPropertyChangedSignal('AbsoluteSize'):Connect(fit))
fit()
local last = 0
vape:Clean(runService.RenderStepped:Connect(function(dt)
 last += dt
 if last < 1 / 30 or not click.Visible then return end
 last = 0
 local accent = vape.Theme and vape.Theme.Value ~= 'Custom' and vape:GetGUIColorRGB() or C.Accent
 for module, entry in cards do
  if entry.Card.Visible then
   for _, option in module.Options do styleOption(option) end
   entry.Toggle.BackgroundColor3 = module.Enabled and accent or C.Line
   local position = UDim2.fromOffset(module.Enabled and 23 or 4, 4)
   if entry.Enabled ~= module.Enabled then tween:Tween(entry.Knob, motion, {Position = position}); entry.Enabled = module.Enabled end
   entry.Bind.Text = vape.Binding == module.Bind and 'Press key...' or (#module.Bind.Keys > 0 and table.concat(module.Bind.Keys, ' + ') or 'None')
  end
 end
end))
local originalLoad = vape.Load
function vape:Load(...)
 local result = originalLoad(self, ...)
 mountSettings()
 for _, module in self.Modules do mount(module); module.Object.Visible = false end
 for _, object in click:GetChildren() do if object:IsA('GuiObject') and object ~= shell then object.Visible = false end end
 refresh()
 return result
end
vape:Clean(function() savePosition() end)
vape.GUIStyle = 'Rise v7'
refresh()
return vape
