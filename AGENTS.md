# AGENTS.md

This is a Godot 4.7.2 base game project that is being developed. It will act as a foundational base to build 2D games. It will have everything that will be common to different games.

## Requirements

- Godot 4.7.2.
- GDScript.
- Statically typed (every function signature fully annotated; no untyped vars in new code).
- Fluid layout, must look good in desktop, mobile, and web.
- Keyboard, game controller, mouse, and touch support.
- Use snake case and screaming snake case for constants.
- All assets (images, musics, fonts, and so on) will be provided by the human developer.
- No secrets in the repo (no committed keys, HMAC secrets, or ad tokens).
- No commented-out dead code (git keeps history).

## Folder Structure

What follows is the folder structure of this project relative to its root. Sub-folders are indicated by the tab level. The string after the dash is the folder name (all lowercase). What comes after the equals sign is just the explanation of what the folder contains.

- addons = third-party addons and plugins
- scenes = scenes files (`main_menu.tscn` is the boot/main scene; per-game scenes go in subfolders)
- scripts = scripts files with the exception of the globals auto-loaded ones (`main_menu.gd` is the boot script)
- assets = different assets
	- fonts = TrueType Font files (base pair: Kenney Future for titles, Kenney Future Narrow for body)
	- images = all images
		- actors = sprites, sprite sheets, and any other image file for the actors
		- items = game items images (inventory, in-game, etc)
		- backgrounds = game backgrounds
		- tiles = individual tiles images
		- tilesets = tile sheets
		- textures = images to be used with shaders or other nodes that expect textures
		- ui = application icon and all UI images (interface menus and in-game)
	- sounds = all sounds and musics
		- sfx = sound effects
		- bgm = background musics
	- videos = all video files
- shaders = 2D shaders files
- resources = Godot resource files `.tres` and their associated scripts, if any
	- i18n = language files (`translations.csv` is the source; `.translation` files are generated)
- autoloaders = all globals auto-loaded `.gd` scripts (file `gm.gd` ↔ autoload `Gm`; do not rename without updating uids and references)

## Foundation Contracts (Step 0, locked)

- Boot: `scenes/main_menu.tscn` is the main scene. Its script calls `Gm.initialize()` once (autoload `_ready` stays out of the boot path so load order is deterministic).
- Settings (global): `user://settings.cfg` via ConfigFile. Keys: `[audio] sfx_db, music_db` · `[video] mode, resolution_w/h` · `[controls] <action> = serialized events` · `[locale] code` · `[meta] version`.
- Save slots: `user://save_slot_1..3.json`. Reserved top-level keys: `version, created_at (UTC), playtime_seconds (int), scene_to_resume, data (opaque per-game Dictionary)`.
- Input actions (canonical, persisted in `project.godot`, repaired at runtime by `Gm.ensure_default_actions()`): `move_up (W/Up/stick/D-pad up)` · `move_down` · `move_left` · `move_right` · `jump (Space/pad A)` · `fire (J/X/pad X)` · `dash (K/Shift/pad B)` · `map (M/Tab/pad Y/Back)` · `menu (Esc/P/pad Start)`. Display names live in `Gm.ACTION_LABELS`. Remap UI persists overrides to the global settings file.
- Audio buses: `Master/Music/SFX` (clean, no effects, 0 dB defaults) defined in `resources/default_bus_layout.tres` and wired via `audio/driver/default_bus_layout`. SFX uses the `Gm` player pool (polyphonic); music via `Gm.start_music()` on the Music bus.
- Video (adaptive per platform): desktop exposes Exclusive Fullscreen / Windowed / Borderless + resolution list (seed: 1920x1080, 320x200); on web/mobile `Gm.apply_video_settings()` is a no-op and the OS owns window management. Stretch: `canvas_items` + `expand`; handheld orientation: sensor.
- Exit/Esc: Exit button hidden on web/mobile (`Gm.is_exit_allowed()`), confirm dialog on desktop (Step 1). `menu` action (Esc) opens Settings from gameplay, acts as back/cancel in menus.
- Theme tokens: `Gm.TITLE_FONT/SECTION_FONT/TEXT_FONT` + sizes Small 12 / Normal 18 / Big 24 + margins/separations. All menu panels build on these.
- UI shell (Step 1): single-scene panels (Main/Slots/Settings + Controls/Video/Audio stubs) under `MainMenu/Center/Card/Margin`; navigator = `show_panel()` + history stack in `main_menu.gd`; every panel's first control is focus-grabbed on show for gamepad/keyboard; `menu` action (Esc) = back, exit-confirm on Main. Slot buttons show `playtime_seconds` + selection marker; per-game start hook is `_on_slot_pressed()`. Audio screen: percent sliders (0% = −60 dB mute) applied live to buses, persisted on drag-end + panel exit; Test button plays `click_001.ogg` on SFX.
- Out of scope for the UI milestone: `scripts/beat_sync.gd`, the `warpgal` hero sprite, Wii-only input prompts (keyboard/mouse/touch + Xbox/PS packs to be added when needed).

## i18n

All user-facing strings will be localized for the following languages: English, French, Italian, German, Spanish, and Brazilian Portuguese. The default and reference language is English. Don't translate anything from English to any other language. Just keep key parity with the English language to other languages.

Workflow: `resources/i18n/translations.csv` is the source with header `keys,en,fr,it,de,es,pt_BR`. Non-English cells stay empty until a human translates them (the CSV importer only emits `.translation` files for columns with content). After editing the CSV, run a filesystem scan (reimport if the outputs look stale) and verify the generated files' mtimes actually refreshed before wiring them. Ensure `internationalization/locale/translations` lists the generated files. Fallback locale is `en`, so missing entries fall back to English. Key naming: `MENU_*`, `SETTINGS_*`, `SLOT_*`, `VIDEO_*`, `AUDIO_*`, `CONTROLS_*`.

## Testing

All testing will be done manually by human after every iteration, so don't run the game.
The testing devices are:

1. Samsung Odyssey laptop running Omarchy Quattro in 1920 x 1080 @ 60 Hz.
2. Samsung Galaxy A03 phone running Android in 360 x 800 (portrait mode).

Manual checklist after every iteration: cold boot shows the menu placeholder with no errors; `user://settings.cfg` is created with the contracted keys; layout is unclipped at 1920x1080 and 360x800 portrait; deleting settings/slot files regenerates defaults on next boot. Agents must still rely on script parse-validation diagnostics (never ship a script with errors).

Before duplicating this base for a real game: remove the `_mcp_game_helper` dev autoload and its editor plugin entry if present.

## Commit Convention

When there are changes to commit, AI agents should suggest an one-line commit message at the end of their response following conventional commit format: `type(scope): description`. Use types like `feat`, `fix`, `refactor`, `docs`, `chore` and keep descriptions concise but descriptive — focus on the "why" rather than the "what". This message must be in own line to facilitate copying.
