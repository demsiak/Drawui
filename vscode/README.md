# Drawui for VS Code

Completion, hover docs and snippets for [Drawui](https://github.com/demsiak/Drawui) in `.lua` / `.luau` files.

- `New "` and `UI.new("` complete class names
- inside `New "Class" { ... }`: properties (with value placeholders), events, sugar keys (`Corner`, `Stroke`, `Gradient`, `Shadow`, `Padding`, `List`, ...), `[UI.Children]`, `[UI.Ref]`
- inside `Stroke = { }`, `Gradient = { }`, `Padding = { }`, ...: that modifier's properties
- inside `[UI.Children] = { }`: `New "Class" { }` entries
- `TextXAlignment = "` and other enum properties: allowed values
- `UI.` library members, `obj:` methods, `label.` properties for objects created with `New "..."`
- hover on classes, properties, sugar keys and events
- snippets: `drawui` (load from GitHub), `dui-load-file`, `dui-window`, `dui-button`, `dui-label`, `dui-textbox`, `dui-toggle`, `dui-scroll`

API data lives in `api.json`; update it when the library adds properties.

## Install

```powershell
.\build-vsix.ps1
code --install-extension .\drawui-1.0.0.vsix
```
