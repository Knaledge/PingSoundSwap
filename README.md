# PingSoundSwap

PingSoundSwap is a lightweight World of Warcraft addon that lets you assign custom sounds to the native Ping System types:

- Warning
- Attack
- On My Way
- Assist

Each ping type can use its own sound selection and all addon-triggered playback is sent to the Master channel.

## Features

- Replaces ping feedback with your selected sounds for the four primary ping types.
- Saves configuration between sessions.
- Supports profile scopes:
	- Character
	- Realm
	- Account
	- Custom key
- Native Settings integration under AddOns.
- Slash command workflow for quick edits and testing.

## Installation

1. Copy the `PingSoundSwap` folder into your WoW AddOns directory:
	 - `_retail_/Interface/AddOns/PingSoundSwap`
2. Start or restart WoW.
3. Enable `PingSoundSwap` at character select.

## Settings

Open the WoW Settings panel, go to AddOns, and select PingSoundSwap.

Available controls:

- Suppress Native Ping Sounds checkbox (optional native ping sound mute).
- Profile Scope dropdown: Character, Realm, Account, Custom.
- Custom Profile Key dropdown (for existing custom keys).
- Two dropdowns for each ping type:
	- Ping Sound List (bucket selector)
	- Ping Sound (actual SOUNDKIT pick inside selected bucket)

Ping sound controls:

	- Attack Ping Sound List / Attack Ping Sound
	- Warning Ping Sound List / Warning Ping Sound
	- Assist Ping Sound List / Assist Ping Sound
	- OnMyWay Ping Sound List / OnMyWay Ping Sound

Sound list bucket behavior:

	- `Curated` contains common high-signal sounds.
	- Other buckets are grouped by first character (`A`-`Z`, `0-9`, `Other`) to avoid giant unusable menus.
	- Changing the bucket limits the Ping Sound dropdown to that subset only.
	- Non-curated buckets are capped to a native-dropdown-safe list size; use `/pss find <text>` for precise SOUNDKIT lookup.

Sound option labels:

	- Include both ID and constant name.
	- Include an inferred tag such as `UI`, `Alert`, `Combat`, `Quest`, or `Misc`.
	- Curated entries are marked so you can find defaults quickly.

## Slash Commands

- `/pss open`
	- Open PingSoundSwap settings.
- `/pss status`
	- Print active profile mode, profile key, and sound mappings.
- `/pss mode <character|realm|account|custom>`
	- Switch active profile scope.
- `/pss custom <profileKey>`
	- Set or create the active custom profile key.
- `/pss set <attack|warning|assist|onmyway> <soundID>`
	- Assign any sound kit ID manually.
- `/pss test <attack|warning|assist|onmyway>`
	- Play the configured sound for that ping type through Master.
- `/pss find <text>`
	- Search native SOUNDKIT constant names and IDs.
- `/pss debug <on|off|status>`
	- Toggle or show debug logging.

## Notes

- PingSoundSwap uses a safe, non-invasive hook strategy to avoid modifying secure ping send paths.
- The native ping system remains intact; PingSoundSwap overlays custom audio behavior.
- If `Suppress Native Ping Sounds` is enabled, the addon sets `Sound_EnablePingSounds=0` so only replacement sounds are heard.

## Current Version

`0.1.0`
