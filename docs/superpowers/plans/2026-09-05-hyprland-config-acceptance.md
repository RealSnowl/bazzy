# Hyprland configuration acceptance checklist

Log out of Plasma, pick **Hyprland** in SDDM, log in. Then in order:

## 1. Config loads
- [ ] Bar appears at the top, floating, translucent, nine dots on the left.
- [ ] `super+Return` opens kitty. In it: `hyprctl configerrors` prints nothing.
- [ ] `hyprctl binds -j | jq length` is at least 80.
- [ ] `super+shift+r` reloads without a red error notification.
- [ ] `hyprctl workspacerules | grep -c persistent` prints 9, not 18 (a higher number means Hyprland re-ran `rules.lua` on a repeated `require`; report it).
- [ ] Waybar's log has no CSS errors: `pkill -x waybar; waybar 2>&1 | grep -i css` for a few seconds, then Ctrl+C and relaunch with `waybar &`. Expect no output.

## 2. Keys (walk the table: super+shift+/ shows it)
- [ ] super+r rofi drun; super+w rofi window; Escape closes both.
- [ ] super+s then b: LibreWolf. super+s then d: Dolphin. super+s then e: Emacs frame.
- [ ] Chords with a modifier on the second key: super+s then shift+b opens Brave; super+s then ctrl+b opens FreeTube. Watch the yellow "apps" pill in the bar: it must stay until the second key. super+s then Escape cancels the chord.
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
- [ ] super+v re-applies it without a hyprpaper error notification; super+shift+v restarts hyprpaper and the wallpaper comes back.

## 6. Back to Plasma
- [ ] Log out (nwg-bar → Logout), log into Plasma. Konsole, Dolphin, notifications behave as before.

Report every unchecked box with what happened instead.
