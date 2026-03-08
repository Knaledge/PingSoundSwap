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

- Profile Scope dropdown: Character, Realm, Account, Custom.
- Custom Profile Key dropdown (for existing custom keys).
- One dropdown for each ping type sound:
	- Attack Ping Sound
	- Warning Ping Sound
	- Assist Ping Sound
	- OnMyWay Ping Sound

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

## Notes

- PingSoundSwap uses a safe, non-invasive hook strategy to avoid modifying secure ping send paths.
- The native ping system remains intact; PingSoundSwap overlays custom audio behavior.

## Current Version

`0.1.0`
