# GlowTracker

`GlowTrackerDB` is account-wide and now includes alias support:

- `GlowTrackerDB.alias[triggerSpellID] = displaySpellID`
- `GlowTrackerDB.triggers[triggerSpellID] = { firstSeen, lastSeen, count, ... }`

Seed aliases are defined in `GlowTrackerSeed.lua` and merged on `PLAYER_LOGIN`.
Seed values only fill missing keys and never overwrite user-defined aliases.

You can add aliases at runtime with:

```lua
/run GlowTracker:AddAlias(209697, 184367)
```
