# Rise v7

Rise v7 is an optional GUI. The default `guis/new.lua` is unchanged.
The supplied legacy Rise layout is ported onto the current component API so
current game modules, keybinds, overlays and module profiles remain compatible.

Enable:
```lua
getgenv().Rise = true
assert(loadstring(readfile("newvape/main.lua")))()
```

Return to the default GUI:
```lua
getgenv().Rise = false
assert(loadstring(readfile("newvape/main.lua")))()
```

Runtimes without `getgenv` can use `shared.Rise = true` (or `false`).
An explicit `getgenv().Rise` value takes precedence over `shared.Rise`.

Right Shift opens the GUI (or your existing GUI keybind). Click the switch to
toggle a module, Options to expand its settings, or its keybind to rebind it.
Search matches module names and descriptions. Movement contains Blatant modules.
Themes opens GUI appearance settings; Client contains the other settings and
overlay toggles. Legit opens the existing Legit menu.

Only the Rise window position uses a separate `.rise-v7.json` layout file.
Module settings, GUI preferences and keybinds use the existing profile system.
Both `guis/new.lua` and `guis/rise-v7.lua` must be installed under `newvape`.
