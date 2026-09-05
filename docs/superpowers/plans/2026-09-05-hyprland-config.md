# Hyprland Desktop Configuration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the Hyprland session on this machine the xmonad setup's shortcuts, workspaces and mouse-driven bar, restyled as translucent "glass" on the old palette, all managed by chezmoi.

**Architecture:** Hyprland's Lua config is split into small modules required from `hyprland.lua`. The colour palette, fonts, monitor and wallpaper live once in a chezmoi data file; every app config that needs them (Hyprland, Waybar, rofi, dunst, kitty, nwg-bar, hyprpaper) is a chezmoi template reading that file. Offline checks execute the Lua under a mocked `hl` API with LuaJIT and parse each rendered config with its own tool.

**Tech Stack:** chezmoi 2.72 (Go templates, `.chezmoidata`), Hyprland 0.56.2 Lua config (Lua 5.4 in the compositor, LuaJIT 2.1 for offline checks, so write 5.1-compatible Lua), Waybar 0.15, rofi 2.0, dunst 1.13, kitty 0.48, hyprpaper 0.8, nwg-bar 0.1.6.

**Spec:** `docs/superpowers/specs/2026-09-05-hyprland-config-design.md` in `~/Projects/bazzy`. Read it first; this plan argues from it.

## Global Constraints

- Every file lives in the chezmoi source dir `~/.local/share/chezmoi` and targets `~/.config/…`. Nothing is written to `~/.config` by hand except the one-time cleanup in Task 12.
- Palette, fonts, monitor and wallpaper are read only from `.chezmoidata/desktop.toml`. No hex colour appears in any other source file.
- Lua must load under LuaJIT (Lua 5.1 syntax: no `//`, no bitwise operators, no `goto` labels needed). Hyprland itself runs Lua 5.4.
- Hyprland API reference is `/usr/share/hypr/stubs/hl.meta.lua` and the wiki clone at `/tmp/claude-1000/-var-home-gamer/a8357384-9ea7-4f01-829d-6ab985fa5d93/scratchpad/hyprland-wiki/content/configuring/` (re-clone `https://github.com/hyprwm/hyprland-wiki` if the scratchpad is gone). Do not use the deprecated `hyprland.conf` syntax anywhere. The wiki is newer than the installed 0.56.2; when a name is in doubt, `strings /usr/bin/Hyprland | grep -x <name>` settles it (this is how `dampening` and the absence of `reload_config` were confirmed).
- Keys keep their xmonad positions (Colemak via kmonad, Hyprland sees `us`): focus next/prev on `N`/`E`, width on `H`/`L`, master on `M`.
- No hyprlock, no hypridle, no Steam in autostart. Sunshine is in autostart (Homebrew binary on PATH via `~/.bash_env`, and `hl.exec_cmd` runs through `sh -c`; use the absolute path `/home/linuxbrew/.linuxbrew/bin/sunshine` to be safe).
- Commits go to the chezmoi repo (`~/.local/share/chezmoi`, branch `master`). That repo already has an unrelated modified `README.md` and untracked `.chezmoiscripts/run_onchange_after_20-storage-mounts.sh` from a previous session; commit by explicit path so they are never swept in. Commit trailer on every commit:

```
Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_013YJzzxRLr6TNFaFEHbomJF
```

- The spec's file table is amended by this plan (recorded in the spec's "Files" section too): `colours.lua.tmpl` becomes `desktop.lua.tmpl` (palette plus monitor, font, wallpaper); added `dot_config/nwg-bar/bar.json` and `style.css.tmpl`, `dot_config/xdg-desktop-portal/hyprland-portals.conf`, `dot_config/hypr/dot_luarc.json`, and `tests/` (chezmoi-ignored).

---

## File structure

| Source (under `~/.local/share/chezmoi`) | Target | Responsibility |
|---|---|---|
| `.chezmoidata/desktop.toml` | (template data) | Palette, glass alpha, fonts, monitor, wallpaper |
| `.chezmoiignore` | | Adds `tests/` |
| `tests/hl-mock.lua` | | Fake `hl` API so the config runs under LuaJIT |
| `tests/check.sh` | | Renders templates and validates every config offline |
| `dot_config/hypr/hyprland.lua` | `~/.config/hypr/hyprland.lua` | Entry point: `require`s modules in order |
| `dot_config/hypr/desktop.lua.tmpl` | `hypr/desktop.lua` | Generated table `D` with `colours`, `rgba()`, `monitor`, `font`, `wallpaper` |
| `dot_config/hypr/apps.lua` | `hypr/apps.lua` | Every external command, one table |
| `dot_config/hypr/look.lua` | `hypr/look.lua` | Monitor, general, decoration, animations, layer rules, input |
| `dot_config/hypr/rules.lua` | `hypr/rules.lua` | Workspace names, window rules |
| `dot_config/hypr/binds.lua` | `hypr/binds.lua` | All keybinds, submaps, mouse binds |
| `dot_config/hypr/autostart.lua` | `hypr/autostart.lua` | Environment variables, start-event programs |
| `dot_config/hypr/hyprpaper.conf.tmpl` | `hypr/hyprpaper.conf` | Wallpaper |
| `dot_config/hypr/dot_luarc.json` | `hypr/.luarc.json` | LSP stub path for editing |
| `dot_config/xdg-desktop-portal/hyprland-portals.conf` | | KDE file chooser under Hyprland |
| `dot_config/waybar/config.jsonc` | | Bar modules and click actions |
| `dot_config/waybar/style.css.tmpl` | | Glass styling |
| `dot_config/waybar/executable_keys.sh` | `waybar/keys.sh` (mode 755) | Key table in rofi |
| `dot_config/rofi/config.rasi` | | modi, icons |
| `dot_config/rofi/theme.rasi.tmpl` | | Centred glass panel |
| `dot_config/dunst/dunstrc.tmpl` | | Notifications |
| `dot_config/kitty/kitty.conf.tmpl` | | Terminal font and colours |
| `dot_config/nwg-bar/bar.json` | | Logout / reboot / shutdown buttons |
| `dot_config/nwg-bar/style.css.tmpl` | | nwg-bar colours |
| `README.md` | (source only) | "Hyprland desktop" section |

---

### Task 1: Palette data, chezmoi ignore, and the offline check harness

**Files:**
- Create: `.chezmoidata/desktop.toml`
- Modify: `.chezmoiignore`
- Create: `tests/hl-mock.lua`
- Create: `tests/check.sh`

**Interfaces:**
- Produces: template data `.desktop.colours.<name>` (strings with leading `#`), `.desktop.glass_alpha` (two hex digits), `.desktop.font`, `.desktop.font_size`, `.desktop.icon_font`, `.desktop.wallpaper`, `.desktop.monitor.{output,mode,position,scale}`.
- Produces: `tests/check.sh` which every later task runs. It exits non-zero on any failure and prints one `ok <file>` line per validated file. Its Lua stage prints `bind <keys>`, `submap <name>`, `window_rule <name>`, `workspace_rule <workspace>`, `layer_rule <name>`, `exec <cmd>`, `env <NAME>` lines that later tasks grep.

- [ ] **Step 1: Write the data file**

`~/.local/share/chezmoi/.chezmoidata/desktop.toml`:

```toml
# Desktop theme data for every Hyprland-session template.
# This is the seam a theme engine (themescheme, matugen, wallust) writes to.
# Change a value here, run `chezmoi apply`, and every config follows.

[desktop]
wallpaper   = "/usr/share/hypr/wall2.png"   # placeholder until one is chosen
font        = "Fira Code"
font_size   = 12
icon_font   = "Symbols Nerd Font"
glass_alpha = "cc"                          # hex alpha for translucent surfaces

[desktop.monitor]
output   = "HDMI-A-1"
mode     = "2560x1440@60"
position = "0x0"
scale    = 1.25

[desktop.colours]
bg     = "#14191e"   # bar, rofi, dunst background
bg_alt = "#0f1316"
fg     = "#e6e6e8"
border = "#2c3034"
muted  = "#909aa2"
dim    = "#454459"   # inactive workspace dots, inactive border
teal   = "#42aa9e"   # selected, focused border start
cyan   = "#62d2db"   # active workspace, accents
violet = "#8d74a7"   # focused border end
rose   = "#e55c7a"   # close button, urgent, critical
green  = "#31e183"   # window title
yellow = "#f4c744"   # launcher glyph
```

- [ ] **Step 2: Verify chezmoi sees the data**

Run:
```sh
chezmoi execute-template '{{ .desktop.colours.bg }} {{ .desktop.glass_alpha }} {{ .desktop.monitor.scale }} {{ trimPrefix "#" .desktop.colours.teal }}'
```
Expected output exactly: `#14191e cc 1.25 42aa9e`

- [ ] **Step 3: Ignore the tests directory**

Append to `~/.local/share/chezmoi/.chezmoiignore` so it reads:

```
# Files in the source directory that are not dotfiles to be applied.
README.md
tests
```

Run `chezmoi managed | grep -c tests` and expect `0`.

- [ ] **Step 4: Write the `hl` mock**

`~/.local/share/chezmoi/tests/hl-mock.lua`:

```lua
-- Stand-in for Hyprland's global `hl` so hyprland.lua can be executed by
-- LuaJIT outside the compositor. Every call is recorded; `hl_dump()` prints
-- the interesting ones as "kind<TAB>value" lines for tests to grep.
-- Only the API surface the config uses is modelled; unknown fields return
-- a recording function so a typo never crashes the harness silently --
-- it shows up as an "unknown" line instead.

local calls = {}

local function record(kind, value)
  calls[#calls + 1] = { kind = kind, value = value }
end

local function handle()
  -- Object returned by rules and binds; supports :set_enabled etc.
  return setmetatable({}, { __index = function() return function() end end })
end

-- Dispatcher namespaces: any method returns an opaque dispatcher table.
local function dsp_namespace(prefix)
  return setmetatable({}, {
    __index = function(_, k)
      return function(args) return { dispatcher = prefix .. k, args = args } end
    end,
  })
end

local dsp = setmetatable({
  window    = dsp_namespace("window."),
  workspace = dsp_namespace("workspace."),
  group     = dsp_namespace("group."),
  cursor    = dsp_namespace("cursor."),
}, {
  __index = function(_, k)
    return function(args) return { dispatcher = k, args = args } end
  end,
})

local api = {
  dsp = dsp,

  bind = function(keys, action, opts)
    assert(type(keys) == "string", "bind: keys must be a string")
    assert(type(action) == "table" or type(action) == "function",
      "bind: action must be a dispatcher table or a function (" .. keys .. ")")
    record("bind", keys)
    return handle()
  end,

  define_submap = function(name, reset_or_fn, fn)
    record("submap", name)
    local body = fn or reset_or_fn
    assert(type(body) == "function", "define_submap: no body for " .. name)
    body()
  end,

  window_rule = function(spec)
    assert(type(spec.match) == "table", "window_rule needs match")
    record("window_rule", spec.name or "(unnamed)")
    return handle()
  end,

  workspace_rule = function(spec)
    assert(type(spec.workspace) == "string", "workspace_rule.workspace must be a string")
    record("workspace_rule", spec.workspace)
    return handle()
  end,

  layer_rule = function(spec)
    assert(type(spec.match) == "table", "layer_rule needs match")
    record("layer_rule", spec.name or "(unnamed)")
    return handle()
  end,

  monitor = function(spec)
    assert(type(spec.output) == "string", "monitor.output must be a string")
    record("monitor", spec.output)
  end,

  config = function(t) record("config", "table") end,
  curve = function(name) record("curve", name) end,
  animation = function(spec) record("animation", spec.leaf) end,
  env = function(name, value)
    assert(type(value) == "string", "env " .. name .. " must be a string")
    record("env", name)
  end,
  exec_cmd = function(cmd) record("exec", cmd) end,
  dispatch = function(d) record("dispatch", d.dispatcher or "function") end,
  on = function(event, fn)
    record("on", event)
    if event == "hyprland.start" then fn() end
  end,

  get_config = function(key)
    return ({ ["general.border_size"] = 2 })[key]
  end,
  get_active_workspace = function() return { id = 1, name = "chat" } end,
  get_workspace_windows = function() return {} end,
  get_active_window = function() return nil end,
  version = function() return "0.56.2" end,
}

hl = setmetatable(api, {
  __index = function(_, k)
    record("unknown", k)
    return function() return handle() end
  end,
})

function hl_dump()
  for _, c in ipairs(calls) do
    print(c.kind .. "\t" .. tostring(c.value))
  end
end
```

- [ ] **Step 5: Write the check script**

`~/.local/share/chezmoi/tests/check.sh`:

```bash
#!/usr/bin/env bash
# Offline validation of every Hyprland-session config in the chezmoi source.
# Renders *.tmpl with `chezmoi execute-template`, then:
#   hypr/*.lua      -> executed by luajit under tests/hl-mock.lua; dumps calls
#   waybar/*.jsonc  -> comments stripped, parsed as JSON
#   rofi/*.rasi     -> rofi -dump-theme
#   dunst/dunstrc   -> dunst -print (parse warnings fail the check)
#   nwg-bar/*.json  -> parsed as JSON
# Usage: tests/check.sh            validate everything present
#        tests/check.sh --dump     also print the hl call dump
set -euo pipefail

src=$(chezmoi source-path)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
dump=${1:-}
fail=0

render() { # render <source file> <output path>
  if [[ $1 == *.tmpl ]]; then
    chezmoi execute-template < "$1" > "$2"
  else
    cp "$1" "$2"
  fi
}

ok()   { echo "ok   $1"; }
bad()  { echo "FAIL $1: $2"; fail=1; }

# ---- Hyprland Lua -----------------------------------------------------
if compgen -G "$src/dot_config/hypr/*.lua*" > /dev/null; then
  mkdir -p "$tmp/hypr"
  for f in "$src"/dot_config/hypr/*.lua "$src"/dot_config/hypr/*.lua.tmpl; do
    [[ -e $f ]] || continue
    out="$tmp/hypr/$(basename "${f%.tmpl}")"
    render "$f" "$out"
    if luajit -e "assert(loadfile('$out'))" 2> "$tmp/err"; then
      ok "hypr/$(basename "$out") (syntax)"
    else
      bad "hypr/$(basename "$out")" "$(cat "$tmp/err")"
    fi
  done
  if [[ -e $tmp/hypr/hyprland.lua ]]; then
    if (cd "$tmp/hypr" && luajit -e "
        package.path = './?.lua;' .. package.path
        dofile('$src/tests/hl-mock.lua')
        require('hyprland')
        hl_dump()" > "$tmp/hl.dump" 2> "$tmp/err"); then
      ok "hypr/hyprland.lua (executes under mock hl)"
      if grep -q '^unknown' "$tmp/hl.dump"; then
        bad "hypr" "config called hl fields the mock does not know: $(grep '^unknown' "$tmp/hl.dump" | cut -f2 | sort -u | tr '\n' ' ')"
      fi
      [[ $dump == --dump ]] && cat "$tmp/hl.dump"
    else
      bad "hypr/hyprland.lua (runtime)" "$(cat "$tmp/err")"
    fi
  fi
fi

# ---- JSON / JSONC ------------------------------------------------------
strip_jsonc() { # remove // and /* */ comments, then trailing commas
  python3 - "$1" <<'PY'
import json, re, sys
text = open(sys.argv[1]).read()
text = re.sub(r'/\*.*?\*/', '', text, flags=re.S)
text = re.sub(r'^\s*//.*$', '', text, flags=re.M)
text = re.sub(r',(\s*[}\]])', r'\1', text)
json.loads(text)
PY
}
for f in "$src"/dot_config/waybar/config.jsonc "$src"/dot_config/nwg-bar/bar.json; do
  [[ -e $f ]] || continue
  if strip_jsonc "$f" 2> "$tmp/err"; then ok "$(basename "$(dirname "$f")")/$(basename "$f")"
  else bad "$(basename "$f")" "$(cat "$tmp/err")"; fi
done

# ---- CSS templates just have to render ---------------------------------
for f in "$src"/dot_config/waybar/style.css.tmpl "$src"/dot_config/nwg-bar/style.css.tmpl "$src"/dot_config/kitty/kitty.conf.tmpl "$src"/dot_config/hypr/hyprpaper.conf.tmpl; do
  [[ -e $f ]] || continue
  out="$tmp/$(basename "${f%.tmpl}")"
  if render "$f" "$out" 2> "$tmp/err" && ! grep -q '{{' "$out"; then ok "$(basename "$out") (renders)"
  else bad "$(basename "$f")" "$(cat "$tmp/err")"; fi
done

# ---- rofi ----------------------------------------------------------------
if [[ -e $src/dot_config/rofi/theme.rasi.tmpl ]]; then
  mkdir -p "$tmp/rofi"
  render "$src/dot_config/rofi/theme.rasi.tmpl" "$tmp/rofi/theme.rasi"
  [[ -e $src/dot_config/rofi/config.rasi ]] && cp "$src/dot_config/rofi/config.rasi" "$tmp/rofi/config.rasi"
  if rofi -no-config -theme "$tmp/rofi/theme.rasi" -dump-theme > /dev/null 2> "$tmp/err"; then ok "rofi/theme.rasi"
  else bad "rofi/theme.rasi" "$(cat "$tmp/err")"; fi
fi

# ---- dunst ---------------------------------------------------------------
if [[ -e $src/dot_config/dunst/dunstrc.tmpl ]]; then
  render "$src/dot_config/dunst/dunstrc.tmpl" "$tmp/dunstrc"
  # dunst -print parses the file, prints it, then tries to own the bus; we
  # only care about parse warnings, so give it a second and ignore the exit.
  timeout 2 dunst -conf "$tmp/dunstrc" -print > /dev/null 2> "$tmp/err" || true
  if grep -qiE 'WARNING.*(unknown|invalid|legacy|cannot parse)' "$tmp/err"; then
    bad "dunst/dunstrc" "$(grep -iE 'WARNING' "$tmp/err")"
  else ok "dunst/dunstrc"; fi
fi

# ---- portals -------------------------------------------------------------
if [[ -e $src/dot_config/xdg-desktop-portal/hyprland-portals.conf ]]; then
  if grep -q '^\[preferred\]' "$src/dot_config/xdg-desktop-portal/hyprland-portals.conf"; then ok "xdg-desktop-portal/hyprland-portals.conf"
  else bad "hyprland-portals.conf" "missing [preferred] section"; fi
fi

exit $fail
```

Then `chmod +x ~/.local/share/chezmoi/tests/check.sh`.

- [ ] **Step 6: Run the harness against nothing**

Run: `~/.local/share/chezmoi/tests/check.sh; echo "exit $?"`
Expected: no `ok` lines, no `FAIL` lines, `exit 0` (nothing exists yet to check).

- [ ] **Step 7: Prove the mock catches a broken config**

```sh
mkdir -p /tmp/hlprobe && cd /tmp/hlprobe
printf 'hl.bind("SUPER + Q", hl.dsp.window.close())\nhl.bind("SUPER + X", 42)\n' > hyprland.lua
luajit -e "package.path='./?.lua;'..package.path; dofile('$HOME/.local/share/chezmoi/tests/hl-mock.lua'); require('hyprland')"; echo "exit $?"
```
Expected: an error mentioning `bind: action must be a dispatcher table or a function (SUPER + X)` and `exit 1`. Then `rm -rf /tmp/hlprobe`.

- [ ] **Step 8: Commit**

```sh
cd ~/.local/share/chezmoi
git add .chezmoidata/desktop.toml .chezmoiignore tests/hl-mock.lua tests/check.sh
git commit -m "desktop: palette data file and offline config check harness

.chezmoidata/desktop.toml is the single source for colours, fonts, monitor
and wallpaper; every Hyprland-session template reads it. tests/check.sh
renders the templates and validates each config with its own tool, running
the Lua under a mocked hl API with LuaJIT.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_013YJzzxRLr6TNFaFEHbomJF"
```

---

### Task 2: Hyprland entry point, generated `desktop.lua`, and `apps.lua`

**Files:**
- Create: `dot_config/hypr/hyprland.lua`
- Create: `dot_config/hypr/desktop.lua.tmpl`
- Create: `dot_config/hypr/apps.lua`
- Create: `dot_config/hypr/dot_luarc.json`

**Interfaces:**
- Produces: `require("desktop")` returns `D` with `D.colours.<name>` (hex without `#`), `D.glass_alpha`, `D.rgba(name, alpha?)` → `"rgba(rrggbbaa)"`, `D.monitor = { output, mode, position, scale }`, `D.font`, `D.font_size`, `D.wallpaper`.
- Produces: `require("apps")` returns a table of command strings: `terminal, task_manager, launcher, window_switcher, browser, alt_browser, aux_browser, file_manager, editor, music, games, photos, images, alt_images, logout, keys_help, screenshot, wallpaper_apply, wallpaper_restart`.
- Produces: `hyprland.lua` requires, in order: `desktop`, `apps`, `look`, `rules`, `binds`, `autostart`. Tasks 3 to 6 create the last four; until then `pcall(require, …)` keeps the harness green.

- [ ] **Step 1: Write the generated palette module**

`~/.local/share/chezmoi/dot_config/hypr/desktop.lua.tmpl`:

```lua
-- GENERATED by chezmoi from .chezmoidata/desktop.toml. Do not edit here.
-- Shared desktop data for the Hyprland config: palette, monitor, font.
local D = {}

D.colours = {
{{- range $name, $hex := .desktop.colours }}
  {{ $name }} = "{{ trimPrefix "#" $hex }}",
{{- end }}
}

D.glass_alpha = "{{ .desktop.glass_alpha }}"
D.font        = "{{ .desktop.font }}"
D.font_size   = {{ .desktop.font_size }}
D.wallpaper   = "{{ .desktop.wallpaper }}"

D.monitor = {
  output   = "{{ .desktop.monitor.output }}",
  mode     = "{{ .desktop.monitor.mode }}",
  position = "{{ .desktop.monitor.position }}",
  scale    = {{ .desktop.monitor.scale }},
}

-- Hyprland colour string for a palette entry, with optional hex alpha.
function D.rgba(name, alpha)
  local hex = assert(D.colours[name], "unknown colour " .. tostring(name))
  return "rgba(" .. hex .. (alpha or "ff") .. ")"
end

return D
```

- [ ] **Step 2: Check the render**

Run: `chezmoi execute-template < ~/.local/share/chezmoi/dot_config/hypr/desktop.lua.tmpl | luajit -e 'local D = dofile("/dev/stdin"); print(D.rgba("teal", "ee"), D.monitor.scale, D.colours.bg)'`
Expected: `rgba(42aa9eee)	1.25	14191e`

- [ ] **Step 3: Write apps.lua**

`~/.local/share/chezmoi/dot_config/hypr/apps.lua`:

```lua
-- Every external command the config launches, in one place.
-- Commands run through `sh -c`, so shell syntax is fine.
local D = require("desktop")

local A = {}

A.terminal        = "kitty"
A.task_manager    = "kitty -e btop"
A.launcher        = "rofi -show drun"
A.window_switcher = "rofi -show window"

A.browser      = "flatpak run io.gitlab.librewolf-community"
A.alt_browser  = "flatpak run com.brave.Browser"
A.aux_browser  = "freetube"
A.file_manager = "dolphin"
A.editor       = "emacsclient -c"
A.music        = "flatpak run org.kde.haruna"   -- no music player installed yet
A.games        = "steam"

-- The three hydrus databases, via the Hob NFS lock helpers. These may fail
-- until ~/.home/bash/rc/hob is revived; kept as-is on purpose.
A.photos     = "bash ~/.home/bash/exec/hydrus.sh"
A.images     = "bash ~/.home/bash/exec/hydrus-1.sh"
A.alt_images = "bash ~/.home/bash/exec/hydrus-0.sh"

A.logout    = "nwg-bar"
A.keys_help = "~/.config/waybar/keys.sh"

-- Region screenshot: saved to ~/Pictures and copied to the clipboard.
A.screenshot = [[grim -g "$(slurp)" - | tee "$HOME/Pictures/$(date +%Y-%m-%d_%H.%M.%S).png" | wl-copy]]

-- Wallpaper. Placeholders until mpvpaper is in the image: `apply` re-sends
-- the configured still to hyprpaper, `restart` relaunches hyprpaper.
A.wallpaper_apply   = "hyprctl hyprpaper wallpaper ', " .. D.wallpaper .. "'"
A.wallpaper_restart = "pkill -x hyprpaper; hyprpaper"

return A
```

- [ ] **Step 4: Write the entry point**

`~/.local/share/chezmoi/dot_config/hypr/hyprland.lua`:

```lua
-- Hyprland configuration, split into modules. Each `require` runs in its
-- own protected scope, so an error in one file does not stop the others.
-- Order matters: desktop and apps are data, look sets the layout that
-- binds and rules refer to, autostart comes last.
--
-- Edit .chezmoidata/desktop.toml for colours, fonts, monitor, wallpaper.
-- Reload with super+shift+r or `hyprctl reload`.

require("desktop")
require("apps")
require("look")
require("rules")
require("binds")
require("autostart")
```

- [ ] **Step 5: Write the LSP hint**

`~/.local/share/chezmoi/dot_config/hypr/dot_luarc.json`:

```json
{
  "workspace": {
    "library": ["/usr/share/hypr/stubs"]
  },
  "runtime": { "version": "Lua 5.4" }
}
```

- [ ] **Step 6: Run the harness**

Run: `~/.local/share/chezmoi/tests/check.sh --dump`
Expected: `ok` lines for `desktop.lua`, `apps.lua`, `hyprland.lua` syntax and `hyprland.lua (executes under mock hl)`. Hyprland's protective `require` swallows missing modules, but plain LuaJIT does not, so until Task 3 the harness will fail on `require("look")`. Confirm that is the only failure:

```
FAIL hypr/hyprland.lua (runtime): ... module 'look' not found ...
```

If anything else fails, fix it now. (Do not add `pcall` to hyprland.lua; the missing modules arrive in the next tasks.)

- [ ] **Step 7: Commit**

```sh
cd ~/.local/share/chezmoi
git add dot_config/hypr/hyprland.lua dot_config/hypr/desktop.lua.tmpl dot_config/hypr/apps.lua dot_config/hypr/dot_luarc.json
git commit -m "hypr: entry point, generated desktop data module, app commands

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_013YJzzxRLr6TNFaFEHbomJF"
```

---

### Task 3: `look.lua` (monitor, layout, decoration, animations, layer blur)

**Files:**
- Create: `dot_config/hypr/look.lua`

**Interfaces:**
- Consumes: `require("desktop")` → `D.monitor`, `D.rgba`.
- Produces: `require("look")` returns `{ border_size = 2 }` (binds.lua reads it for the border toggle).

- [ ] **Step 1: Write look.lua**

```lua
-- Monitor, tiling layout, decoration, animations, input and layer rules.
-- Colours come from desktop.lua (generated from .chezmoidata/desktop.toml).
local D = require("desktop")

local L = { border_size = 2 }

hl.monitor({
  output   = D.monitor.output,
  mode     = D.monitor.mode,
  position = D.monitor.position,
  scale    = D.monitor.scale,
})
-- Anything else that gets plugged in: preferred mode, placed to the right.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

hl.config({
  general = {
    layout      = "master",
    gaps_in     = 6,
    gaps_out    = 12,
    border_size = L.border_size,
    col = {
      active_border   = { colors = { D.rgba("teal", "ee"), D.rgba("violet", "ee") }, angle = 45 },
      inactive_border = D.rgba("dim", "aa"),
    },
    resize_on_border = true,
    allow_tearing    = false,
  },

  master = {
    new_status = "slave",   -- new windows go to the stack, like xmonad's tall
    mfact      = 0.55,
  },

  decoration = {
    rounding       = 10,
    rounding_power = 2,
    active_opacity   = 1.0,
    inactive_opacity = 1.0,
    shadow = {
      enabled      = true,
      range        = 14,
      render_power = 3,
      color        = "rgba(00000077)",
    },
    blur = {
      enabled  = true,
      size     = 6,
      passes   = 3,
      popups   = true,
      vibrancy = 0.17,
    },
  },

  animations = { enabled = true },

  group = {
    col = {
      border_active   = { colors = { D.rgba("cyan", "ee"), D.rgba("teal", "ee") }, angle = 45 },
      border_inactive = D.rgba("dim", "aa"),
    },
    groupbar = {
      enabled     = true,
      font_family = D.font,
      font_size   = D.font_size,
      gradients   = false,
      col = {
        active   = D.rgba("teal", "cc"),
        inactive = D.rgba("bg", D.glass_alpha),
      },
    },
  },

  misc = {
    disable_hyprland_logo   = true,
    force_default_wallpaper = 0,
    background_color        = D.rgba("bg_alt"),
  },

  input = {
    kb_layout    = "us",
    follow_mouse = 1,
    sensitivity  = 0,
  },
})

-- Curves and animations: Hyprland's stock set, with workspaces sliding
-- instead of fading so switching reads as movement.
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1} } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1} } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1} } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1} } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1} } })
hl.curve("easy",           { type = "spring", mass = 1, stiffness = 238.1191, dampening = 24.21279333 })  -- 0.56.2 spells it "dampening"

hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.1,  spring = "easy",         style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 1.94, bezier = "easeOutQuint", style = "slide" })
hl.animation({ leaf = "zoomFactor",    enabled = true, speed = 7,    bezier = "quick" })

-- Glass: blur what sits behind the bar, launcher and notifications.
-- ignore_alpha keeps fully transparent gaps (between Waybar's pills) crisp.
hl.layer_rule({
  name  = "glass-bar",
  match = { namespace = "^waybar$" },
  blur = true, ignore_alpha = 0.2,
})
hl.layer_rule({
  name  = "glass-launcher",
  match = { namespace = "^rofi$" },
  blur = true, ignore_alpha = 0.2,
})
hl.layer_rule({
  name  = "glass-notifications",
  match = { namespace = "^(dunst|notifications)$" },
  blur = true, ignore_alpha = 0.2,
})

return L
```

- [ ] **Step 2: Run the harness**

Run: `~/.local/share/chezmoi/tests/check.sh --dump | grep -E '^(ok|FAIL|monitor|layer_rule|curve)'`
Expected: `ok hypr/look.lua (syntax)`, a `monitor	HDMI-A-1` line, three `layer_rule` lines named `glass-bar`, `glass-launcher`, `glass-notifications`, six `curve` lines, and the only `FAIL` is still `module 'rules' not found`.

- [ ] **Step 3: Commit**

```sh
cd ~/.local/share/chezmoi
git add dot_config/hypr/look.lua
git commit -m "hypr: look module - master layout, glass decoration, animations

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_013YJzzxRLr6TNFaFEHbomJF"
```

---

### Task 4: `rules.lua` (workspace names and window rules)

**Files:**
- Create: `dot_config/hypr/rules.lua`

**Interfaces:**
- Produces: `require("rules")` returns `{ names = { "chat", … , "media" } }` (binds.lua uses `#names` for the 1–9 loop).
- Window classes are best guesses for flatpaks; Task 13's checklist verifies them with `hyprctl clients`.

- [ ] **Step 1: Write rules.lua**

```lua
-- Workspaces and window rules, ported from the xmonad manage hooks.
-- Matches are RE2 regexes; "negative:" inverts one. Several match fields
-- in one rule must all hold.

local R = {}

R.names = { "chat", "work1", "work2", "work3", "work4", "work5", "game", "image", "media" }

local id = {}
for i, name in ipairs(R.names) do
  id[name] = tostring(i)
  hl.workspace_rule({ workspace = tostring(i), default_name = name, persistent = true })
end

-- Borderless: video and the hydrus media viewer draw edge to edge.
hl.window_rule({
  name  = "borderless-mpv",
  match = { class = "^(mpv)$" },
  border_size = 0, rounding = 0,
})
hl.window_rule({
  name  = "borderless-hydrus-viewer",
  match = { title = "^hydrus client media viewer" },
  border_size = 0, rounding = 0,
})

-- Float centres: programs whose every window except the main one floats.
hl.window_rule({
  name  = "float-hydrus-dialogs",
  match = { class = "(?i)hydrus", title = "negative:^(main|hydrus client media viewer)" },
  float = true,
})
hl.window_rule({
  name  = "float-gimp-dialogs",
  match = { class = "^Gimp-", title = "negative:^GNU Image Manipulation Program$" },
  float = true,
})
hl.window_rule({
  name  = "float-blender-dialogs",
  match = { class = "^Blender$", title = "negative:^Blender$" },
  float = true,
})
hl.window_rule({
  name  = "float-inkscape-dialogs",
  match = { class = "^Inkscape$", title = "negative: - Inkscape$" },
  float = true,
})

-- Shifts: open on a workspace and follow it there.
local function shift(name, class_regex, workspace)
  hl.window_rule({
    name  = "shift-" .. name,
    match = { class = class_regex },
    workspace = id[workspace],
  })
end
shift("discord", "^(discord|com\\.discordapp\\.Discord)$",            "chat")
shift("steam",   "^(steam|Steam)$",                                    "game")
shift("lutris",  "^(Lutris|net\\.lutris\\.Lutris)$",                   "game")
shift("polymc",  "^(PolyMC|polyrun|org\\.polymc\\.PolyMC)$",           "game")
shift("hydrus",  "(?i)hydrus",                                         "image")
shift("freetube","^(FreeTube|io\\.freetubeapp\\.FreeTube)$",           "media")

-- Xwayland drag fix from the stock config: unfocusable empty popups.
hl.window_rule({
  name  = "fix-xwayland-drags",
  match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
  no_focus = true,
})

-- Games and video tell the compositor what they are, so no per-app rules.
hl.window_rule({ name = "content-steam-games", match = { class = "^steam_app_" }, content = "game" })
hl.window_rule({ name = "content-mpv", match = { class = "^(mpv)$" }, content = "video" })

return R
```

- [ ] **Step 2: Run the harness**

Run: `~/.local/share/chezmoi/tests/check.sh --dump | grep -E '^(ok|FAIL|workspace_rule|window_rule)'`
Expected: nine `workspace_rule` lines (`1` … `9`), thirteen `window_rule` lines with the names above, and the only `FAIL` is `module 'binds' not found`.

- [ ] **Step 3: Commit**

```sh
cd ~/.local/share/chezmoi
git add dot_config/hypr/rules.lua
git commit -m "hypr: workspace names and window rules ported from xmonad

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_013YJzzxRLr6TNFaFEHbomJF"
```

---

### Task 5: `binds.lua` (all keybinds, chords, mouse)

**Files:**
- Create: `dot_config/hypr/binds.lua`

**Interfaces:**
- Consumes: `require("apps")` fields listed in Task 2; `require("look").border_size`; `require("rules").names`.
- Produces: submaps named `apps` and `layout` (Waybar's submap module shows these names while a chord is pending).

- [ ] **Step 1: Write binds.lua**

```lua
-- Keybinds. Positions match the old xmonad config (Colemak via kmonad;
-- Hyprland sees `us`, so the keysyms below are the physical us labels).
-- Chords use submaps that reset after one key or on any unknown key.
local apps  = require("apps")
local look  = require("look")
local rules = require("rules")

local mod = "SUPER"
local function key(k) return mod .. " + " .. k end

-- Session ---------------------------------------------------------------
hl.bind(key("SHIFT + R"),     hl.dsp.exec_cmd("hyprctl reload"), { description = "Reload config" })
hl.bind(key("SHIFT + S"),     hl.dsp.exec_cmd(apps.logout),  { description = "Logout menu" })
hl.bind(key("SHIFT + slash"), hl.dsp.exec_cmd(apps.keys_help), { description = "Show keys" })

-- Launch ----------------------------------------------------------------
hl.bind(key("R"),             hl.dsp.exec_cmd(apps.launcher),        { description = "App launcher" })
hl.bind(key("W"),             hl.dsp.exec_cmd(apps.window_switcher), { description = "Window switcher" })
hl.bind(key("Return"),        hl.dsp.exec_cmd(apps.terminal),        { description = "Terminal" })
hl.bind(key("CTRL + Delete"), hl.dsp.exec_cmd(apps.task_manager),    { description = "Task manager" })

-- super+s chord: applications -------------------------------------------
hl.bind(key("S"), hl.dsp.submap("apps"), { description = "Apps chord" })
hl.define_submap("apps", "reset", function()
  hl.bind("B",         hl.dsp.exec_cmd(apps.browser))
  hl.bind("SHIFT + B", hl.dsp.exec_cmd(apps.alt_browser))
  hl.bind("CTRL + B",  hl.dsp.exec_cmd(apps.aux_browser))
  hl.bind("D",         hl.dsp.exec_cmd(apps.file_manager))
  hl.bind("E",         hl.dsp.exec_cmd(apps.editor))
  hl.bind("M",         hl.dsp.exec_cmd(apps.music))
  hl.bind("G",         hl.dsp.exec_cmd(apps.games))
  hl.bind("P",         hl.dsp.exec_cmd(apps.photos))
  hl.bind("SHIFT + P", hl.dsp.exec_cmd(apps.images))
  hl.bind("CTRL + P",  hl.dsp.exec_cmd(apps.alt_images))
  hl.bind("catchall",  hl.dsp.submap("reset"))
end)

-- Windows ---------------------------------------------------------------
local function close_all_on_workspace()
  local ws = hl.get_active_workspace()
  if not ws then return end
  for _, w in ipairs(hl.get_workspace_windows(ws)) do
    hl.dispatch(hl.dsp.window.close({ window = w }))
  end
end

hl.bind(key("Q"),                 hl.dsp.window.close(),  { description = "Close window" })
hl.bind(key("BackSpace"),         hl.dsp.window.close())
hl.bind(key("SHIFT + Q"),         close_all_on_workspace, { description = "Close all on workspace" })
hl.bind(key("SHIFT + BackSpace"), close_all_on_workspace)

hl.bind(key("H"),       hl.dsp.window.resize({ x = -40, y = 0,   relative = true }), { repeating = true, description = "Shrink width" })
hl.bind(key("L"),       hl.dsp.window.resize({ x = 40,  y = 0,   relative = true }), { repeating = true, description = "Grow width" })
hl.bind(key("ALT + J"), hl.dsp.window.resize({ x = 0,   y = -40, relative = true }), { repeating = true, description = "Shrink height" })
hl.bind(key("ALT + K"), hl.dsp.window.resize({ x = 0,   y = 40,  relative = true }), { repeating = true, description = "Grow height" })

hl.bind(key("M"),         hl.dsp.layout("focusmaster auto"),    { description = "Focus master" })
hl.bind(key("SHIFT + M"), hl.dsp.layout("swapwithmaster auto"), { description = "Swap with master" })
hl.bind(key("N"),         hl.dsp.layout("cyclenext"),           { description = "Focus next" })
hl.bind(key("E"),         hl.dsp.layout("cycleprev"),           { description = "Focus previous" })
hl.bind(key("SHIFT + N"), hl.dsp.layout("swapnext"),            { description = "Swap with next" })
hl.bind(key("SHIFT + E"), hl.dsp.layout("swapprev"),            { description = "Swap with previous" })
hl.bind(key("SHIFT + Tab"), hl.dsp.layout("rollnext"),          { description = "Roll stack forward" })
hl.bind(key("CTRL + Tab"),  hl.dsp.layout("rollprev"),          { description = "Roll stack back" })
hl.bind(key("F"),         hl.dsp.window.float(),                { description = "Toggle floating" })

-- Groups (tabbed windows, the old sublayout tabs) -------------------------
hl.bind(key("CTRL + M"),      hl.dsp.group.toggle(),                        { description = "Toggle group" })
hl.bind(key("CTRL + U"),      hl.dsp.window.move({ out_of_group = true }),  { description = "Leave group" })
hl.bind(key("CTRL + period"), hl.dsp.group.next(),                          { description = "Next tab" })
hl.bind(key("CTRL + comma"),  hl.dsp.group.prev(),                          { description = "Previous tab" })

-- super+a chord: layout ---------------------------------------------------
-- t: tiled, f: maximized (bar visible), shift+f: true fullscreen.
hl.bind(key("A"), hl.dsp.submap("layout"), { description = "Layout chord" })
hl.define_submap("layout", "reset", function()
  hl.bind("T",         hl.dsp.window.fullscreen({ action = "unset" }))
  hl.bind("F",         hl.dsp.window.fullscreen({ action = "set", mode = "maximized" }))
  hl.bind("SHIFT + F", hl.dsp.window.fullscreen({ action = "set", mode = "fullscreen" }))
  hl.bind("catchall",  hl.dsp.submap("reset"))
end)

-- Toggles -----------------------------------------------------------------
hl.bind(key("CTRL + space"), hl.dsp.exec_cmd("pkill -SIGUSR1 -x waybar"), { description = "Toggle bar" })
hl.bind(key("SHIFT + space"), function()
  local current = hl.get_config("general.border_size")
  hl.config({ ["general.border_size"] = (current == 0) and look.border_size or 0 })
end, { description = "Toggle borders" })

-- Workspaces ---------------------------------------------------------------
for i = 1, #rules.names do
  hl.bind(key(tostring(i)),            hl.dsp.focus({ workspace = i }))
  hl.bind(key("SHIFT + " .. i),        hl.dsp.window.move({ workspace = i }))
end
-- All nine are persistent, so e+1 / e-1 walk them in order and wrap.
hl.bind(key("SHIFT + KP_Add"),      hl.dsp.window.move({ workspace = "e+1", follow = true }), { description = "Window to next workspace" })
hl.bind(key("SHIFT + KP_Subtract"), hl.dsp.window.move({ workspace = "e-1", follow = true }), { description = "Window to previous workspace" })

-- Wallpaper and screenshots -------------------------------------------------
hl.bind(key("V"),         hl.dsp.exec_cmd(apps.wallpaper_apply),   { description = "Re-apply wallpaper" })
hl.bind(key("SHIFT + V"), hl.dsp.exec_cmd(apps.wallpaper_restart), { description = "Restart wallpaper" })
hl.bind("Print",          hl.dsp.exec_cmd(apps.screenshot),        { description = "Screenshot region" })

-- Mouse ----------------------------------------------------------------------
hl.bind(key("mouse:272"),  hl.dsp.window.drag(),   { mouse = true })
hl.bind(key("mouse:273"),  hl.dsp.window.resize(), { mouse = true })
hl.bind(key("mouse_down"), hl.dsp.focus({ workspace = "e+1" }))
hl.bind(key("mouse_up"),   hl.dsp.focus({ workspace = "e-1" }))

-- Media keys ----------------------------------------------------------------
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true })
hl.bind("XF86AudioNext",        hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPrev",        hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
hl.bind("XF86AudioPlay",        hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause",       hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
```

- [ ] **Step 2: Run the harness and check the key set**

Run: `out=$(mktemp); ~/.local/share/chezmoi/tests/check.sh --dump > "$out"; grep -c '^bind' "$out"; grep -E '^(FAIL|submap)' "$out"`
Expected: bind count `82` (3 session + 4 launch + 12 apps chord incl. entry and catchall + 4 close + 4 resize + 9 focus/swap/roll/float + 4 group + 5 layout chord incl. entry and catchall + 2 toggles + 18 workspace + 2 keypad + 3 wallpaper/print + 4 mouse + 8 media). If your count differs, list `grep '^bind' "$out"` and reconcile against the table in the spec before moving on. Two `submap` lines: `apps`, `layout`. The only `FAIL` is `module 'autostart' not found`.

Then spot-check the exact strings the spec promises:
```sh
grep -E "^bind\t(SUPER \+ Return|SUPER \+ SHIFT \+ slash|SUPER \+ SHIFT \+ KP_Add|SUPER \+ mouse:272|Print|SHIFT \+ F|CTRL \+ P)$" "$out" | wc -l
```
Expected: `7`.

- [ ] **Step 3: Commit**

```sh
cd ~/.local/share/chezmoi
git add dot_config/hypr/binds.lua
git commit -m "hypr: keybinds ported from xmonad with apps and layout chords

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_013YJzzxRLr6TNFaFEHbomJF"
```

---

### Task 6: `autostart.lua`, hyprpaper, and the portal preference

**Files:**
- Create: `dot_config/hypr/autostart.lua`
- Create: `dot_config/hypr/hyprpaper.conf.tmpl`
- Create: `dot_config/xdg-desktop-portal/hyprland-portals.conf`

**Interfaces:**
- Consumes: `require("desktop")` for cursor and font values.
- Produces: the running session's environment; every later program (Waybar, rofi, dunst) is started here.

- [ ] **Step 1: Write autostart.lua**

```lua
-- Environment for the session and the programs started with it.
-- `hyprland.start` fires once per session, not on config reload, so a
-- reload never spawns duplicates.
local D = require("desktop")

-- Session identity, portals, toolkits ------------------------------------
hl.env("XDG_CURRENT_DESKTOP",  "Hyprland")
hl.env("XDG_SESSION_TYPE",     "wayland")
hl.env("XDG_SESSION_DESKTOP",  "Hyprland")
hl.env("QT_QPA_PLATFORM",      "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "kde")          -- Dolphin, Kitty dialogs follow the Plasma theme
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("MOZ_ENABLE_WAYLAND",   "1")
hl.env("XCURSOR_THEME",        "breeze_cursors")
hl.env("XCURSOR_SIZE",         "24")
hl.env("HYPRCURSOR_SIZE",      "24")

-- Programs -----------------------------------------------------------------
hl.on("hyprland.start", function()
  hl.exec_cmd("waybar")
  hl.exec_cmd("hyprpaper")
  hl.exec_cmd("dunst")
  hl.exec_cmd("/usr/libexec/hyprpolkitagent")
  hl.exec_cmd("nm-applet")
  hl.exec_cmd("blueman-applet")
  hl.exec_cmd("wl-paste --watch cliphist store")
  hl.exec_cmd("emacs --daemon")
  hl.exec_cmd("/home/linuxbrew/.linuxbrew/bin/sunshine")
  -- Not installed today; harmless if it stays that way.
  hl.exec_cmd("command -v syncthing >/dev/null && syncthing --no-browser")
end)
```

- [ ] **Step 2: Write hyprpaper.conf.tmpl**

```ini
# GENERATED by chezmoi from .chezmoidata/desktop.toml.
# Still-image wallpaper. When mpvpaper reaches the bazzy image, replace the
# `hyprpaper` line in hypr/autostart.lua with
#   mpvpaper -o "no-audio loop" '*' <video>
# and point apps.wallpaper_* at it; this file then goes unused.
splash = false

wallpaper {
    monitor =
    path = {{ .desktop.wallpaper }}
    fit_mode = cover
}
```

- [ ] **Step 3: Write the portal preference**

`~/.local/share/chezmoi/dot_config/xdg-desktop-portal/hyprland-portals.conf`:

```ini
# Portal backends while XDG_CURRENT_DESKTOP=Hyprland.
# Hyprland's portal handles screenshots and screencast; KDE's handles file
# dialogs so flatpaks get the Dolphin-style picker. Overrides the package
# default (hyprland;gtk) in /usr/share/xdg-desktop-portal/.
[preferred]
default=hyprland;gtk
org.freedesktop.impl.portal.FileChooser=kde
```

- [ ] **Step 4: Run the harness; it should be fully green now**

Run: `out=$(mktemp); ~/.local/share/chezmoi/tests/check.sh --dump > "$out"; echo "exit $?"; grep -E '^(FAIL|exec|env)' "$out"`
Expected: `exit 0`, no `FAIL`, ten `env` lines, eleven `exec` lines including `exec	waybar` and `exec	/home/linuxbrew/.linuxbrew/bin/sunshine`, and `ok hyprpaper.conf (renders)` plus `ok xdg-desktop-portal/hyprland-portals.conf` earlier in the output.

- [ ] **Step 5: Commit**

```sh
cd ~/.local/share/chezmoi
git add dot_config/hypr/autostart.lua dot_config/hypr/hyprpaper.conf.tmpl dot_config/xdg-desktop-portal/hyprland-portals.conf
git commit -m "hypr: session environment, autostart, wallpaper, portal preference

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_013YJzzxRLr6TNFaFEHbomJF"
```

---

### Task 7: Waybar config, glass style, and the keys helper

**Files:**
- Create: `dot_config/waybar/config.jsonc`
- Create: `dot_config/waybar/style.css.tmpl`
- Create: `dot_config/waybar/executable_keys.sh`

**Interfaces:**
- Consumes: Hyprland submap names `apps` and `layout`; workspace ids 1–9; `hyprctl dispatch` with Lua dispatcher strings.
- Produces: `~/.config/waybar/keys.sh`, the target of `apps.keys_help`.

Note on the clock: Waybar formats with C++ chrono, which does not support glibc's `%-d` unpadded flags. `%e` is space-padded day, `%I` zero-padded 12-hour.

- [ ] **Step 1: Write config.jsonc**

```jsonc
// Waybar for the Hyprland session. Styling is in style.css (generated).
// Layout: launcher · workspaces · submap · close/prev/next · title
//         | clock | volume · network · bluetooth · tray · power
{
  "layer": "top",
  "position": "top",
  "height": 34,
  "margin-top": 8,
  "margin-left": 12,
  "margin-right": 12,
  "spacing": 0,

  "modules-left": [
    "custom/launcher",
    "hyprland/workspaces",
    "hyprland/submap",
    "custom/close",
    "custom/prev",
    "custom/next",
    "hyprland/window"
  ],
  "modules-center": ["clock"],
  "modules-right": [
    "pulseaudio",
    "network",
    "bluetooth",
    "tray",
    "custom/power"
  ],

  "custom/launcher": {
    "format": "",
    "on-click": "rofi -show drun",
    "on-click-right": "rofi -show window",
    "tooltip": false
  },

  "hyprland/workspaces": {
    "format": "{icon}",
    "format-icons": {
      "active": "●",
      "default": "◎",
      "empty": "○",
      "urgent": "◉"
    },
    "persistent-workspaces": { "*": 9 },
    "all-outputs": true,
    "sort-by": "id",
    "on-click": "activate"
  },

  "hyprland/submap": {
    "format": "{}",
    "tooltip": false
  },

  "custom/close": {
    "format": "×",
    "on-click": "hyprctl dispatch 'hl.dsp.window.close()'",
    "tooltip": false
  },
  "custom/prev": {
    "format": "«",
    "on-click": "hyprctl dispatch 'hl.dsp.layout(\"cycleprev\")'",
    "tooltip": false
  },
  "custom/next": {
    "format": "»",
    "on-click": "hyprctl dispatch 'hl.dsp.layout(\"cyclenext\")'",
    "tooltip": false
  },

  "hyprland/window": {
    "format": "{title}",
    "max-length": 60,
    "separate-outputs": false
  },

  "clock": {
    "format": "{:%a %b %e  %I:%M %p}",
    "tooltip-format": "<tt>{calendar}</tt>",
    "calendar": { "mode": "month", "weeks-pos": "right" }
  },

  "pulseaudio": {
    "format": "{icon} {volume}%",
    "format-muted": "󰝟 muted",
    "format-icons": { "default": ["󰕿", "󰖀", "󰕾"] },
    "scroll-step": 5,
    "on-click": "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle",
    "on-click-right": "pavucontrol",
    "tooltip-format": "{desc}"
  },

  "network": {
    "format-ethernet": "󰈀",
    "format-wifi": "󰤨 {essid}",
    "format-disconnected": "󰤭",
    "tooltip-format": "{ifname} {ipaddr}/{cidr}",
    "on-click": "nm-connection-editor"
  },

  "bluetooth": {
    "format": "󰂯",
    "format-connected": "󰂱 {num_connections}",
    "format-disabled": "󰂲",
    "tooltip-format-connected": "{device_enumerate}",
    "on-click": "blueman-manager"
  },

  "tray": {
    "spacing": 8,
    "icon-size": 16
  },

  "custom/power": {
    "format": "⏻",
    "on-click": "nwg-bar",
    "tooltip": false
  }
}
```

- [ ] **Step 2: Write style.css.tmpl**

```css
/* GENERATED by chezmoi from .chezmoidata/desktop.toml. Glass bar:
   transparent window, each module group a translucent rounded pill that
   Hyprland blurs (layer rule "glass-bar" in hypr/look.lua). */

{{- $c := .desktop.colours }}
{{- $a := .desktop.glass_alpha }}

* {
  font-family: "{{ .desktop.font }}", "{{ .desktop.icon_font }}", sans-serif;
  font-size: {{ .desktop.font_size }}pt;
  min-height: 0;
  border: none;
  border-radius: 0;
}

window#waybar {
  background: transparent;
  color: {{ $c.fg }};
}

/* Pills ------------------------------------------------------------- */
.modules-left, .modules-center, .modules-right {
  background: {{ $c.bg }}{{ $a }};
  border: 1px solid {{ $c.border }}{{ $a }};
  border-radius: 17px;
  padding: 0 6px;
}

#custom-launcher, #workspaces, #submap, #custom-close, #custom-prev,
#custom-next, #window, #clock, #pulseaudio, #network, #bluetooth, #tray,
#custom-power {
  padding: 0 8px;
}

/* Launcher ----------------------------------------------------------- */
#custom-launcher {
  color: {{ $c.yellow }};
  font-size: 16pt;
  padding-right: 4px;
}

/* Workspaces --------------------------------------------------------- */
#workspaces button {
  padding: 0 4px;
  color: {{ $c.dim }};
  background: transparent;
  transition: color 150ms ease, text-shadow 150ms ease;
}
#workspaces button:hover {
  color: {{ $c.teal }};
  box-shadow: none;
  background: transparent;
}
#workspaces button.persistent, #workspaces button.empty { color: {{ $c.dim }}; }
#workspaces button:not(.empty) { color: {{ $c.teal }}; }
#workspaces button.active {
  color: {{ $c.cyan }};
  text-shadow: 0 0 6px {{ $c.cyan }};
}
#workspaces button.urgent { color: {{ $c.rose }}; }

/* Submap indicator: only visible while a chord is pending ---------------- */
#submap {
  color: {{ $c.bg }};
  background: {{ $c.yellow }};
  border-radius: 12px;
  margin: 6px 4px;
  padding: 0 10px;
  font-weight: bold;
}

/* Window controls and title ---------------------------------------------- */
#custom-close { color: {{ $c.rose }}; font-weight: bold; }
#custom-prev, #custom-next { color: {{ $c.cyan }}; }
#window { color: {{ $c.green }}; font-style: italic; }
window#waybar.empty #window,
window#waybar.empty #custom-close,
window#waybar.empty #custom-prev,
window#waybar.empty #custom-next { padding: 0; opacity: 0; }

/* Centre ------------------------------------------------------------------ */
#clock { color: {{ $c.fg }}; padding: 0 14px; }

/* Right ------------------------------------------------------------------- */
#pulseaudio { color: {{ $c.fg }}; }
#pulseaudio.muted { color: {{ $c.rose }}; }
#network { color: {{ $c.teal }}; }
#network.disconnected { color: {{ $c.rose }}; }
#bluetooth { color: {{ $c.violet }}; }
#bluetooth.disabled { color: {{ $c.dim }}; }
#tray > .passive { -gtk-icon-effect: dim; }
#custom-power { color: {{ $c.rose }}; padding-right: 10px; }

tooltip {
  background: {{ $c.bg }}{{ $a }};
  border: 1px solid {{ $c.border }};
  border-radius: 10px;
  color: {{ $c.fg }};
}
```

- [ ] **Step 3: Write the keys helper**

`~/.local/share/chezmoi/dot_config/waybar/executable_keys.sh` (chezmoi's `executable_` prefix makes the target mode 755):

```bash
#!/usr/bin/env bash
# Show the Hyprland key table in rofi. Bound to super+shift+/.
# Keep this in step with ~/.config/hypr/binds.lua; it is the human-readable
# copy that the README links to.
rofi -dmenu -i -p "keys" -no-custom -theme-str 'window { width: 900px; } listview { lines: 24; }' <<'EOF'
super+Return                terminal            super+q / super+Backspace     close window
super+r                     app launcher        super+shift+q                 close all on workspace
super+w                     window switcher     super+h / super+l             shrink / grow width
super+ctrl+Delete           task manager        super+alt+j / super+alt+k     shrink / grow height
super+shift+r               reload config       super+m / super+shift+m       focus / swap with master
super+shift+s               logout menu         super+n / super+e             focus next / previous
super+shift+/               this list           super+shift+n / super+shift+e swap with next / previous
super+s  b / B / ^b         librewolf / brave / freetube                       super+shift+Tab / super+ctrl+Tab   roll stack
super+s  d / e / m / g      dolphin / emacs / haruna / steam                   super+f                            toggle floating
super+s  p / P / ^p         hydrus photos / images / alt images                super+ctrl+m / super+ctrl+u        group / ungroup
super+a  t / f / F          tiled / maximized / fullscreen                     super+ctrl+. / super+ctrl+,        next / previous tab
super+1..9                  go to workspace     super+ctrl+Space              toggle bar
super+shift+1..9            move window there   super+shift+Space             toggle borders
super+shift+KP+ / KP-       move window to next / previous workspace and follow
super+v / super+shift+v     re-apply / restart wallpaper                       Print                              screenshot region
super+LMB / super+RMB drag  move / resize       super+scroll                  cycle workspaces
EOF
```

- [ ] **Step 4: Validate**

Run: `~/.local/share/chezmoi/tests/check.sh | grep -E '^(ok|FAIL) .*(waybar|style|config.jsonc)'; echo "exit ${PIPESTATUS[0]}"`
Expected: `ok waybar/config.jsonc`, `ok style.css (renders)`, `exit 0`.

Render the CSS once and eyeball it for a leaked template or an empty colour:
```sh
chezmoi execute-template < ~/.local/share/chezmoi/dot_config/waybar/style.css.tmpl | grep -nE '\{\{|: ;|#cc;'
```
Expected: no output.

Check the script parses and is executable in the target:
```sh
bash -n ~/.local/share/chezmoi/dot_config/waybar/executable_keys.sh && chezmoi managed --include=files | grep waybar/keys.sh
```
Expected: `.config/waybar/keys.sh`.

- [ ] **Step 5: Commit**

```sh
cd ~/.local/share/chezmoi
git add dot_config/waybar/config.jsonc dot_config/waybar/style.css.tmpl dot_config/waybar/executable_keys.sh
git commit -m "waybar: glass bar with clickable workspaces, window controls, tray

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_013YJzzxRLr6TNFaFEHbomJF"
```

---

### Task 8: rofi config and glass theme

**Files:**
- Create: `dot_config/rofi/config.rasi`
- Create: `dot_config/rofi/theme.rasi.tmpl`

**Interfaces:**
- Consumes: palette from the data file; Hyprland layer rule `glass-launcher` blurs behind the `rofi` namespace.
- Produces: `rofi -show drun`, `rofi -show window`, and `rofi -dmenu` all use this theme.

- [ ] **Step 1: Write config.rasi**

```css
/* rofi for the Hyprland session. Theme colours live in theme.rasi
   (generated from .chezmoidata/desktop.toml). */
configuration {
    modi: "drun,window";
    show-icons: true;
    icon-theme: "breeze-dark";
    drun-display-format: "{name}";
    window-format: "{w}  {c}   {t}";
    display-drun: "run";
    display-window: "win";
    kb-cancel: "Escape";
    matching: "fuzzy";
    sort: true;
}
@theme "theme"
```

- [ ] **Step 2: Write theme.rasi.tmpl**

```css
/* GENERATED by chezmoi from .chezmoidata/desktop.toml.
   Centred glass panel; Hyprland blurs behind it (layer rule glass-launcher). */
{{- $c := .desktop.colours }}
{{- $a := .desktop.glass_alpha }}

* {
    font:                        "{{ .desktop.font }} {{ .desktop.font_size }}";
    background:                  {{ $c.bg }}{{ $a }};
    background-color:            transparent;
    foreground:                  {{ $c.fg }};
    border-color:                {{ $c.border }};
    separatorcolor:              {{ $c.teal }};

    normal-background:           transparent;
    normal-foreground:           {{ $c.fg }};
    alternate-normal-background: transparent;
    alternate-normal-foreground: {{ $c.fg }};
    selected-normal-background:  {{ $c.teal }};
    selected-normal-foreground:  {{ $c.bg }};

    active-background:           transparent;
    active-foreground:           {{ $c.cyan }};
    alternate-active-background: transparent;
    alternate-active-foreground: {{ $c.cyan }};
    selected-active-background:  {{ $c.violet }};
    selected-active-foreground:  {{ $c.bg }};

    urgent-background:           transparent;
    urgent-foreground:           {{ $c.rose }};
    alternate-urgent-background: transparent;
    alternate-urgent-foreground: {{ $c.rose }};
    selected-urgent-background:  {{ $c.rose }};
    selected-urgent-foreground:  {{ $c.bg }};
}

window {
    background-color: @background;
    border:           1px;
    border-color:     @border-color;
    border-radius:    14px;
    padding:          12px;
    width:            800px;
    location:         center;
    anchor:           center;
}

mainbox { border: 0; padding: 0; spacing: 8px; }

inputbar {
    children:   [ prompt, textbox-prompt-sep, entry ];
    padding:    8px 12px;
    border:     0 0 1px 0;
    border-color: @separatorcolor;
    spacing:    6px;
}
prompt, entry, textbox-prompt-sep { text-color: @foreground; }
prompt { text-color: {{ $c.yellow }}; }
textbox-prompt-sep { str: "›"; text-color: {{ $c.muted }}; }

listview {
    lines:      8;
    spacing:    2px;
    scrollbar:  false;
    padding:    4px 0 0 0;
    border:     0;
}

element {
    padding:       6px 10px;
    border-radius: 10px;
    spacing:       10px;
    children:      [ element-icon, element-text ];
}
element-icon { size: 1.6em; background-color: transparent; }
element-text { background-color: transparent; text-color: inherit; vertical-align: 0.5; }

element.normal.normal    { background-color: @normal-background;           text-color: @normal-foreground; }
element.normal.active    { background-color: @active-background;           text-color: @active-foreground; }
element.normal.urgent    { background-color: @urgent-background;           text-color: @urgent-foreground; }
element.alternate.normal { background-color: @alternate-normal-background; text-color: @alternate-normal-foreground; }
element.alternate.active { background-color: @alternate-active-background; text-color: @alternate-active-foreground; }
element.alternate.urgent { background-color: @alternate-urgent-background; text-color: @alternate-urgent-foreground; }
element.selected.normal  { background-color: @selected-normal-background;  text-color: @selected-normal-foreground; }
element.selected.active  { background-color: @selected-active-background;  text-color: @selected-active-foreground; }
element.selected.urgent  { background-color: @selected-urgent-background;  text-color: @selected-urgent-foreground; }

mode-switcher { border: 1px 0 0 0; border-color: @separatorcolor; spacing: 0; }
button { padding: 6px; text-color: {{ $c.muted }}; }
button.selected { text-color: {{ $c.cyan }}; }
message { border: 0; padding: 4px; }
textbox { text-color: @foreground; }
```

- [ ] **Step 3: Validate**

Run: `~/.local/share/chezmoi/tests/check.sh | grep -E '^(ok|FAIL) rofi'`
Expected: `ok rofi/theme.rasi`.

Since this KDE session is Wayland, rofi can be launched for a visual check right now with the rendered theme. `-dmenu` avoids needing Hyprland's window list:
```sh
tmp=$(mktemp -d); chezmoi execute-template < ~/.local/share/chezmoi/dot_config/rofi/theme.rasi.tmpl > $tmp/theme.rasi
printf 'one\ntwo\nthree\n' | rofi -dmenu -theme $tmp/theme.rasi -p test; rm -rf $tmp
```
Expected: a centred dark translucent panel with a yellow prompt and teal selection. Press Escape. (No blur here; KWin does not apply Hyprland's layer rule.)

- [ ] **Step 4: Commit**

```sh
cd ~/.local/share/chezmoi
git add dot_config/rofi/config.rasi dot_config/rofi/theme.rasi.tmpl
git commit -m "rofi: centred glass theme on the shared palette

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_013YJzzxRLr6TNFaFEHbomJF"
```

---

### Task 9: dunst, kitty, and nwg-bar

**Files:**
- Create: `dot_config/dunst/dunstrc.tmpl`
- Create: `dot_config/kitty/kitty.conf.tmpl`
- Create: `dot_config/nwg-bar/bar.json`
- Create: `dot_config/nwg-bar/style.css.tmpl`

**Interfaces:**
- Consumes: palette; Hyprland layer rule `glass-notifications`.
- Produces: the logout menu behind `apps.logout` and the bar's power button.

- [ ] **Step 1: Write dunstrc.tmpl**

```ini
# GENERATED by chezmoi from .chezmoidata/desktop.toml.
# Ported from the old dunstrc; sits under the floating Waybar top right.
{{- $c := .desktop.colours }}
{{- $a := .desktop.glass_alpha }}

[global]
    monitor = 0
    follow = none
    origin = top-right
    offset = (12, 54)
    width = (280, 420)
    height = (0, 300)
    gap_size = 6
    corner_radius = 10
    frame_width = 1
    frame_color = "{{ $c.border }}"
    separator_height = 1
    separator_color = "{{ $c.teal }}"
    padding = 10
    horizontal_padding = 12
    font = {{ .desktop.font }} {{ .desktop.font_size }}
    format = "<b>%a</b>  %s\n%b"
    markup = full
    alignment = left
    icon_position = left
    max_icon_size = 48
    sort = yes
    ignore_newline = no
    show_indicators = no
    idle_threshold = 0
    mouse_left_click = close_current
    mouse_middle_click = do_action, close_current
    mouse_right_click = close_all

[urgency_low]
    background = "{{ $c.bg }}{{ $a }}"
    foreground = "{{ $c.muted }}"
    highlight = "{{ $c.teal }}"
    timeout = 6

[urgency_normal]
    background = "{{ $c.bg }}{{ $a }}"
    foreground = "{{ $c.fg }}"
    highlight = "{{ $c.teal }}"
    timeout = 10

[urgency_critical]
    background = "{{ $c.bg }}{{ $a }}"
    foreground = "{{ $c.rose }}"
    frame_color = "{{ $c.rose }}"
    highlight = "{{ $c.rose }}"
    timeout = 0
```

- [ ] **Step 2: Write kitty.conf.tmpl**

```conf
# GENERATED by chezmoi from .chezmoidata/desktop.toml.
{{- $c := .desktop.colours }}

font_family      {{ .desktop.font }}
font_size        {{ .desktop.font_size }}.0
symbol_map U+E000-U+F8FF,U+F0000-U+FFFFF {{ .desktop.icon_font }}

background_opacity   0.92
window_padding_width 8
confirm_os_window_close 0
enable_audio_bell no

foreground {{ $c.fg }}
background {{ $c.bg }}
cursor     {{ $c.cyan }}
selection_background {{ $c.teal }}
selection_foreground {{ $c.bg }}
url_color  {{ $c.cyan }}

active_tab_background   {{ $c.teal }}
active_tab_foreground   {{ $c.bg }}
inactive_tab_background {{ $c.bg_alt }}
inactive_tab_foreground {{ $c.muted }}

# black, red, green, yellow, blue, magenta, cyan, white
color0  {{ $c.bg_alt }}
color1  {{ $c.rose }}
color2  {{ $c.green }}
color3  {{ $c.yellow }}
color4  {{ $c.teal }}
color5  {{ $c.violet }}
color6  {{ $c.cyan }}
color7  {{ $c.fg }}
color8  {{ $c.dim }}
color9  {{ $c.rose }}
color10 {{ $c.green }}
color11 {{ $c.yellow }}
color12 {{ $c.teal }}
color13 {{ $c.violet }}
color14 {{ $c.cyan }}
color15 {{ $c.fg }}
```

- [ ] **Step 3: Write nwg-bar files**

`dot_config/nwg-bar/bar.json`:

```json
[
  {
    "label": "Logout",
    "exec": "hyprctl dispatch 'hl.dsp.exit()'",
    "icon": "/usr/share/nwg-bar/images/system-log-out.svg"
  },
  {
    "label": "Reboot",
    "exec": "systemctl reboot",
    "icon": "/usr/share/nwg-bar/images/system-reboot.svg"
  },
  {
    "label": "Shutdown",
    "exec": "systemctl -i poweroff",
    "icon": "/usr/share/nwg-bar/images/system-shutdown.svg"
  }
]
```

`dot_config/nwg-bar/style.css.tmpl`:

```css
/* GENERATED by chezmoi from .chezmoidata/desktop.toml. */
{{- $c := .desktop.colours }}
{{- $a := .desktop.glass_alpha }}
window { background-color: {{ $c.bg_alt }}{{ $a }}; }
#outer-box { margin: 0; }
#inner-box {
  background-color: {{ $c.bg }}{{ $a }};
  border: 1px solid {{ $c.border }};
  border-radius: 14px;
  padding: 20px;
}
button {
  background: transparent;
  border: none;
  border-radius: 12px;
  padding: 12px 20px;
  color: {{ $c.fg }};
  font-family: "{{ .desktop.font }}";
}
button:hover, button:focus { background-color: {{ $c.teal }}; color: {{ $c.bg }}; }
```

- [ ] **Step 4: Validate**

Run: `~/.local/share/chezmoi/tests/check.sh; echo "exit $?"`
Expected: every `ok` line from earlier tasks plus `ok dunst/dunstrc`, `ok kitty.conf (renders)`, `ok nwg-bar/bar.json`, `ok style.css (renders)` twice, and `exit 0`.

Kitty can be launched now for a visual check of the rendered config:
```sh
tmp=$(mktemp -d); chezmoi execute-template < ~/.local/share/chezmoi/dot_config/kitty/kitty.conf.tmpl > $tmp/kitty.conf
kitty --config $tmp/kitty.conf -e bash -c 'for i in 1 2 3 4 5 6; do tput setaf $i; echo colour $i; done; read -p "press enter"'; rm -rf $tmp
```
Expected: a translucent dark window, Fira Code, and six coloured lines: rose, green, yellow, teal, violet, cyan. No "unknown option" line at the top.

- [ ] **Step 5: Commit**

```sh
cd ~/.local/share/chezmoi
git add dot_config/dunst/dunstrc.tmpl dot_config/kitty/kitty.conf.tmpl dot_config/nwg-bar/bar.json dot_config/nwg-bar/style.css.tmpl
git commit -m "dunst, kitty, nwg-bar on the shared palette

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_013YJzzxRLr6TNFaFEHbomJF"
```

---

### Task 10: README section

**Files:**
- Modify: `README.md` in the chezmoi repo (append a section; leave the pre-existing uncommitted edits in that file untouched and commit only the appended lines by path)

- [ ] **Step 1: Check what is already modified in README.md**

Run: `cd ~/.local/share/chezmoi && git diff --stat README.md && git diff README.md | head -40`
Note the existing hunk; it belongs to the storage-mounts work from an earlier session. Do not revert it. Appending a new section at the end keeps both changes in one file; the commit in Step 3 will include the earlier hunk too, so say so in the commit message.

- [ ] **Step 2: Append the section**

Append to `~/.local/share/chezmoi/README.md`:

````markdown

## Hyprland desktop

Configuration for the Hyprland session that the
[bazzy](https://github.com/RealSnowl/bazzy) image provides. Design notes
live in that repo under `docs/superpowers/specs/2026-09-05-hyprland-config-design.md`.

| Source | Target | Purpose |
|---|---|---|
| `.chezmoidata/desktop.toml` | | Palette, fonts, monitor, wallpaper: the one place to change the look |
| `dot_config/hypr/hyprland.lua` | `~/.config/hypr/` | Entry point; requires `desktop`, `apps`, `look`, `rules`, `binds`, `autostart` |
| `dot_config/hypr/desktop.lua.tmpl` | | Generated from the data file; do not edit |
| `dot_config/hypr/apps.lua` | | Every external command |
| `dot_config/hypr/look.lua` | | Master layout, glass decoration, animations, blur layer rules |
| `dot_config/hypr/rules.lua` | | Workspace names, float/borderless/shift window rules |
| `dot_config/hypr/binds.lua` | | Keys; `super+s` and `super+a` chords are submaps |
| `dot_config/hypr/autostart.lua` | | Environment and programs started with the session |
| `dot_config/hypr/hyprpaper.conf.tmpl` | | Still wallpaper, mpvpaper swap point documented inside |
| `dot_config/waybar/` | `~/.config/waybar/` | Bar; `keys.sh` is the key table (`super+shift+/`) |
| `dot_config/rofi/`, `dunst/`, `kitty/`, `nwg-bar/` | | Themed from the same palette |
| `dot_config/xdg-desktop-portal/hyprland-portals.conf` | | KDE file picker, Hyprland screenshots |
| `tests/check.sh` | (not applied) | Offline validation of all of the above |

### Keys

`~/.config/waybar/keys.sh` is the readable list; `hyprctl binds` is the
truth. Positions are the xmonad ones: focus on `n`/`e`, width on `h`/`l`,
master on `m`. Layout chord `super+a` then `t` (tiled), `f` (maximized,
bar stays), `shift+f` (fullscreen). App chord `super+s` then a letter.

### Theme seam

Every templated config reads only `.desktop.*` from
`.chezmoidata/desktop.toml`. A theme engine (themescheme, matugen,
wallust) only has to write that file, then `chezmoi apply`. The Hyprland
COPR carries matugen if it is ever wanted in the image.

### Checking without logging in

```sh
tests/check.sh          # render templates, run the Lua under a mock hl, parse the rest
tests/check.sh --dump   # also list every bind, rule and exec the Lua registers
```

Lua runs under LuaJIT here and Lua 5.4 inside Hyprland, so keep the config
5.1-compatible. `hyprctl configerrors` inside a session is the final word.

### Not carried over

No lock screen and no idle handling, by choice. Steam is not autostarted.
Video wallpaper waits on mpvpaper reaching the image. The hydrus keys call
the old Hob helpers and will fail until those are revived.
````

- [ ] **Step 3: Commit**

```sh
cd ~/.local/share/chezmoi
git add README.md
git commit -m "README: document the Hyprland desktop configuration

Also carries the earlier uncommitted storage-mounts README hunk from a
previous session.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_013YJzzxRLr6TNFaFEHbomJF"
```

---

### Task 11: Amend the spec's file table

**Files:**
- Modify: `~/Projects/bazzy/docs/superpowers/specs/2026-09-05-hyprland-config-design.md` (the "Files" table)

- [ ] **Step 1: Update the table rows**

In the spec's Files table:
- Replace the `dot_config/hypr/colours.lua.tmpl` row with `| dot_config/hypr/desktop.lua.tmpl | hypr/desktop.lua | Palette, monitor, font and wallpaper as a Lua table, generated from the data file |`
- Add rows: `| dot_config/hypr/dot_luarc.json | hypr/.luarc.json | LSP stub path for editing |`, `| dot_config/xdg-desktop-portal/hyprland-portals.conf | xdg-desktop-portal/hyprland-portals.conf | KDE file chooser, Hyprland screenshots |`, `| dot_config/nwg-bar/bar.json, style.css.tmpl | nwg-bar/ | Logout menu (stock file calls sway) |`, `| tests/hl-mock.lua, tests/check.sh | (ignored) | Offline validation |`.
- In the Autostart section, change `syncthing --no-browser` to `syncthing --no-browser (guarded; not installed today)`.

- [ ] **Step 2: Commit**

```sh
cd ~/Projects/bazzy
git add docs/superpowers/specs/2026-09-05-hyprland-config-design.md
git commit -m "Spec: file table matches the implementation plan

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_013YJzzxRLr6TNFaFEHbomJF"
```

---

### Task 12: First apply

**Files:**
- Removes (in `$HOME`, not the repo): dead symlinks `~/.config/rofi/config.rasi`, `~/.config/rofi/theme-common.rasi`, `~/.config/dunst/dunstrc`
- Renames: `~/.config/hypr/hyprland.lua` → `~/.config/hypr/hyprland.lua.orig`

- [ ] **Step 1: Confirm the targets are what the spec says they are**

```sh
ls -l ~/.config/rofi/ ~/.config/dunst/ ~/.config/hypr/
head -3 ~/.config/hypr/hyprland.lua
```
Expected: the three `.rasi`/`dunstrc` entries are symlinks into `/gnu/store/...` (dangling), and `hyprland.lua` starts with the `AUTOGENERATED HYPRLAND CONFIG` banner. If anything differs, stop and report; do not delete.

- [ ] **Step 2: Clear the way**

```sh
rm ~/.config/rofi/config.rasi ~/.config/rofi/theme-common.rasi ~/.config/dunst/dunstrc
mv ~/.config/hypr/hyprland.lua ~/.config/hypr/hyprland.lua.orig
```

- [ ] **Step 3: Preview**

Run: `chezmoi diff | grep -E '^(\+\+\+|---) ' | sort -u`
Expected: only additions under `.config/hypr`, `.config/waybar`, `.config/rofi`, `.config/dunst`, `.config/kitty`, `.config/nwg-bar`, `.config/xdg-desktop-portal`, and the two scripts in `.chezmoiscripts` if they report changes (they are `run_onchange`; if their diff appears, note it and let them run: they are idempotent by design). No `---` lines for files outside those directories.

- [ ] **Step 4: Apply and verify**

```sh
chezmoi apply -v && chezmoi verify && echo VERIFIED
ls -l ~/.config/hypr ~/.config/waybar ~/.config/rofi ~/.config/dunst ~/.config/kitty ~/.config/nwg-bar ~/.config/xdg-desktop-portal
test -x ~/.config/waybar/keys.sh && echo "keys.sh executable"
head -4 ~/.config/hypr/desktop.lua
```
Expected: `VERIFIED`, every file present, `keys.sh executable`, and `desktop.lua` beginning with the GENERATED banner and a real hex value.

- [ ] **Step 5: Final offline check against the applied files**

```sh
cd ~/.config/hypr && luajit -e "package.path='./?.lua;'..package.path; dofile('$HOME/.local/share/chezmoi/tests/hl-mock.lua'); require('hyprland'); print('applied config loads')"
```
Expected: `applied config loads`.

---

### Task 13: Acceptance checklist for the Hyprland session

This task produces the checklist the user runs after logging into Hyprland; nothing here can be executed from the Plasma session. Write it, hand it over, and fix whatever comes back.

**Files:**
- Create: `~/Projects/bazzy/docs/superpowers/plans/2026-09-05-hyprland-config-acceptance.md`

- [ ] **Step 1: Write the checklist**

````markdown
# Hyprland configuration acceptance checklist

Log out of Plasma, pick **Hyprland** in SDDM, log in. Then in order:

## 1. Config loads
- [ ] Bar appears at the top, floating, translucent, nine dots on the left.
- [ ] `super+Return` opens kitty. In it: `hyprctl configerrors` prints nothing.
- [ ] `hyprctl binds -j | jq length` is at least 80.
- [ ] `super+shift+r` reloads without a red error notification.

## 2. Keys (walk the table: super+shift+/ shows it)
- [ ] super+r rofi drun; super+w rofi window; Escape closes both.
- [ ] super+s then b: LibreWolf. super+s then d: Dolphin. super+s then e: Emacs frame.
- [ ] Open three kitty windows: super+n / super+e move focus; super+shift+n swaps; super+m focuses master; super+shift+m swaps to master; super+h / super+l resize.
- [ ] super+shift+Tab rolls the stack.
- [ ] super+ctrl+m groups two windows into tabs; super+ctrl+. switches; super+ctrl+u leaves the group.
- [ ] super+a then f: window fills the screen, bar still visible. super+a then shift+f: covers the bar. super+a then t: back to tiles.
- [ ] super+f floats and unfloats.
- [ ] super+1..9 switch; super+shift+3 moves a window to work2; super+shift+KP+ moves and follows.
- [ ] super+ctrl+Space hides and shows the bar. super+shift+Space toggles borders.
- [ ] super+q closes; super+shift+q closes everything on the workspace.
- [ ] Print: crosshair, drag a region, file appears in ~/Pictures and pastes into kitty.
- [ ] super+LMB drag moves a floating window; super+RMB drag resizes; super+scroll cycles workspaces.
- [ ] Volume keys change level; the bar's volume number follows.
- [ ] super+shift+s shows the nwg-bar menu (Escape to dismiss).

## 3. Bar mouse actions
- [ ] Launcher glyph: left click drun, right click window list.
- [ ] Workspace dots: click switches, scroll cycles; active dot is cyan with a glow.
- [ ] × closes the focused window; « » move focus.
- [ ] Clock hover shows a calendar.
- [ ] Volume: scroll changes, click mutes (turns rose), right click opens pavucontrol.
- [ ] Network and Bluetooth icons show; tray shows nm-applet and blueman.
- [ ] Power glyph opens nwg-bar.

## 4. Rules (record `hyprctl clients | grep -E 'class|title'` output for each)
- [ ] mpv (`mpv /usr/share/hypr/wall0.png`): no border, square corners.
- [ ] Discord opens on chat and the view follows.
- [ ] Steam opens on game.
- [ ] hydrus opens on image; its dialogs float, the main window tiles.
- [ ] FreeTube opens on media.

Note any window that landed wrong with its class from `hyprctl clients`;
rules.lua gets the real value.

## 5. Look
- [ ] Blur visible behind the bar and rofi; notifications (`notify-send hi`) are translucent, top right under the bar.
- [ ] Focused window has the teal→violet gradient border; unfocused are dim.
- [ ] Workspace switch slides.
- [ ] Wallpaper shows (stock Hyprland image until one is chosen).

## 6. Back to Plasma
- [ ] Log out (nwg-bar → Logout), log into Plasma. Konsole, Dolphin, notifications behave as before.

Report every unchecked box with what happened instead.
````

- [ ] **Step 2: Commit and hand over**

```sh
cd ~/Projects/bazzy
git add docs/superpowers/plans/2026-09-05-hyprland-config-acceptance.md
git commit -m "Add acceptance checklist for the Hyprland configuration

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_013YJzzxRLr6TNFaFEHbomJF"
```

Tell the user the config is applied and the checklist is at that path. Then wait. For each failure reported: reproduce the cause from the report and `hyprctl` output, change the chezmoi source (never `~/.config` directly), rerun `tests/check.sh`, `chezmoi apply`, commit, and ask for that section of the checklist to be re-run.

---

## Self-review notes

- **Spec coverage.** Palette and seam: Task 1, 2. Layout and look: Task 3. Workspaces and rules: Task 4. Every key in the spec table: Task 5 (the count check reconciles against the table). Autostart and env: Task 6. Waybar with all listed modules and mouse actions: Task 7. rofi, dunst, kitty: Tasks 8, 9. README: Task 10. Verification: Tasks 12, 13. Out-of-scope items are not touched. Deviations from the spec are listed under Global Constraints and written back in Task 11.
- **Type consistency.** `desktop.lua` exports `D.colours`, `D.rgba`, `D.monitor`, `D.font`, `D.font_size`, `D.glass_alpha`, `D.wallpaper`; used by `apps.lua` (`D.wallpaper`), `look.lua` (`D.monitor`, `D.rgba`, `D.font`, `D.font_size`, `D.glass_alpha`). `look.lua` exports `border_size`; `rules.lua` exports `names`; both consumed by `binds.lua` under those names. Submap names `apps` and `layout` match between binds.lua and the Waybar submap module. `apps.keys_help` targets `~/.config/waybar/keys.sh`, produced by Task 7's `executable_keys.sh`.
- **Placeholders.** None: every file is given in full. The one deliberately unverifiable set of values (flatpak window classes) is called out in Task 4 and closed by Task 13.
