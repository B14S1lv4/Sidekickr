# Auto Companion Summoner

A World of Warcraft Classic addon for Turtle WoW that automatically summons a random companion every 15 minutes when you're stationary.

## Features

- ✅ Automatically summons a random companion every 15 minutes while stationary
- ✅ Smart retry system: checks every 15 seconds if conditions aren't met
- ✅ Respects combat and instance restrictions
- ✅ Works while mounted
- ✅ Dismisses previous companion before summoning new one

## Companion Detection

The addon automatically scans your spellbook for companion spells when you log in. It currently recognizes:

- Baby Shark
- Blitzen
- Hawksbill Snapjaw
- Hadwig
- Loggerhead Snapjaw
- Moonkin Hatchling
- Olive Snapjaw
- Wally
- Webwood Hatchling

Use `/acs scan` to manually rescan your spellbook and see which companions were found.

## Installation

1. Copy the `AutoCompanionSummoner` folder to your WoW addons directory:
   - **Windows:** `C:\Program Files\World of Warcraft\_classic_\Interface\AddOns\`
   - **Mac:** `~/Applications/World of Warcraft/_classic_/Interface/AddOns/`

2. Restart WoW or type `/reload` in-game

3. You should see a message: `[Auto Companion Summoner] Loaded! Will check every 15 minutes.`

## How It Works

1. **Every 15 minutes**, the addon checks if you're stationary
2. If you're **stationary for 1+ seconds** and **not in combat** and **not in an instance**:
   - Dismisses your current companion (if any)
   - Summons a random companion from the list
   - Resets the 15-minute timer

3. If conditions aren't met (moving, in combat, in instance):
   - Enters retry mode
   - Checks every **15 seconds** until conditions are met
   - Then summons and resets the 15-minute timer

## Commands

- `/acs` or `/autocompanion` - Show help
- `/acs summon` - Manually summon a random companion (change targets to cast)
- `/acs scan` - Scan spellbook and list all found companions
- `/acs check` - Check current status (stationary, can summon, retry mode)
- `/acs reset` - Reset the 15-minute timer (forces check on next interval)

## Troubleshooting

**Nothing happens:**
- Make sure you have the companion spells learned
- Use `/acs check` to see your current status
- Try `/acs summon` to manually test

**Wrong spell names:**
- If the spell names don't match exactly, edit `AutoCompanionSummoner.lua` 
- Find the `ACS.companions` table and update with the exact spell names from your spellbook

**Companions don't dismiss:**
- The addon uses `CancelPlayerBuff()` which should work on Turtle WoW
- If issues persist, you may need to manually dismiss before the new one summons

## Notes

- The addon is OK with summoning while mounted
- It will NOT summon in combat or in instances/raids/battlegrounds
- The random selection ensures variety in your companion choices

## Version

1.0 - Initial release

Enjoy your automated companions! 🐢✨
