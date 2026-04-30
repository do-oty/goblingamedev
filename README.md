# Goblin Game - Combat Loop Scaffold

This project now contains a first-pass Vampire Survivors style run loop scaffold:

- 20-minute survival run (`GameRoot`)
- Knight starter loadout
- Auto-targeting Sword Slash weapon
- Curved slash AOE effect generated in code
- Time-scaled enemy spawning
- Enemy XP orb drops and pickup magnet
- Level-up item choices every level
- Talent choices every 5 levels
- Struct-like item/talent data catalog

## Current Gameplay Loop

1. Start run as `Knight`.
2. Knight auto-attacks nearest enemy with `Sword Slash`.
3. Enemies spawn over time with increasing pressure.
4. Defeat enemies and collect dropped XP orbs.
5. Every level-up: choose 1 of 3 item choices.
6. Every 5 levels: choose 1 of 3 talent choices.
7. Picking duplicate `Sword Slash` levels up the weapon (AOE growth focus).
8. Survive until `20:00` or die and retry.

## Systems and File Map

- `scenes/maps/ForestMap.tscn` - run scene, HUD, game over panel, level-up panel.
- `scripts/GameRoot.gd` - run timer, spawner scaling, XP/leveling, item/talent choice flow.
- `scripts/player.gd` - movement, cursor aim, auto-attack, sword runtime stats, curved slash VFX.
- `scripts/enemy.gd` - chase AI, contact damage, death + orb-drop signal.
- `scripts/XpOrb.gd` - magnetized XP orb pickup behavior.
- `scenes/XpOrb.tscn` - XP orb scene.
- `scripts/data/ItemCatalog.gd` - item/talent definitions and stat structures.
- `scripts/data/CharacterCatalog.gd` - base character stat definitions (Knight scaffold).

## Stats Reference

### Player Base

| Stat | Value | Notes |
|---|---:|---|
| Move Speed | 150 | Base Knight movement speed |
| Max HP | 100 | Starting and max health |
| Invulnerability on Hit | 0.45s | Damage grace window after being hit |
| Auto-Attack Targeting Range | 160 | Finds nearest enemy in this range |
| Pickup Radius | 24 | Orb is collected at this distance |
| Magnet Range | 90 | Orb starts moving to player in this radius |
| Magnet Strength | 220 | Orb magnet pull speed |

### Run / Spawn Scaling

| Stat | Start | End | Notes |
|---|---:|---:|---|
| Run Duration | 20:00 | 20:00 | Run win condition |
| Spawn Interval | 2.5s | 0.6s | Interpolates over full run time |
| Max Enemies Alive | 10 | 90 | Interpolates over full run time |
| Spawn Distance Min | 340 | 340 | From player position |
| Spawn Distance Max | 520 | 520 | From player position |

### Enemy (Current Basic Goblin)

| Stat | Value | Notes |
|---|---:|---|
| Move Speed | 62 | Constant chase speed |
| Max HP | 30 | Dies at 0 |
| Contact Damage | 6 | Damage to player on contact |
| Contact Cooldown | 0.75s | Delay between contact hits |
| XP Reward | 1 | Granted on defeat |

### Progression / XP

| Stat | Value | Notes |
|---|---:|---|
| Starting Level | 1 | Run starts at level 1 |
| Starting XP | 0 | XP carried in run only |
| XP to First Level-Up | 5 | Base threshold |
| XP Growth Per Level | +3 | `next = 5 + (level-1)*3` |
| XP Tier Source | Enemy-defined | Set per enemy variant (`XP_TIER`) |
| Default Enemy Tier | Blue | Current base goblin uses blue tier |
| XP Value Source | Enemy-defined | Set per enemy (`XP_REWARD`) |
| Rainbow Tier | Reserved | Intended for miniboss/boss drops |

### Knight Starter Weapon - Sword Slash

| Level | Damage | AOE Radius | Cooldown |
|---:|---:|---:|---:|
| 1 | 12 | 80 | 0.65s |
| 2 | 14 | 96 | 0.62s |
| 3 | 16 | 116 | 0.58s |
| 4 | 20 | 138 | 0.54s |
| 5 | 24 | 165 | 0.48s |

### Level-Up Choices

| Type | Choice | Effect |
|---|---|---|
| Item | Sword Slash | Duplicate pickup -> +1 sword level |
| Item | Hunter Bow (placeholder) | UI/data placeholder, not yet implemented |
| Item | Arcane Wand (placeholder) | UI/data placeholder, not yet implemented |
| Talent (every 5 levels) | Might | +20% weapon damage |
| Talent (every 5 levels) | Reach | +20% sword AOE |
| Talent (every 5 levels) | Haste | +15% attack speed |

## Item Structure (Struct-Like)

The code now uses struct-like Dictionaries in `scripts/data/ItemCatalog.gd`.

Item schema:

```gdscript
{
  "id": String,
  "name": String,
  "type": String, # weapon/passive/placeholder
  "max_level": int,
  "implemented": bool,
  "description": String,
  "stats_by_level": Array[Dictionary]
}
```

Per-level stat schema:

```gdscript
{
  "damage": int,
  "aoe_radius": float,
  "cooldown": float,
  "projectiles": int,
  "duration": float,
  "crit_chance": float
}
```

Talent schema:

```gdscript
{
  "id": String,
  "name": String,
  "description": String,
  "stats": {
    "damage_multiplier": float,
    "aoe_multiplier": float,
    "attack_speed_multiplier": float
  }
}
```

## Design Notes

- `Sword Slash +1` represents duplicate item pickup behavior.
- Curved slash visual is code-generated, so no new art dependency is required.
- Item/talent data is now centralized and expandable.
- Weapon runtime currently supports `Sword Slash` and placeholder items.

## Suggested Next Implementation Step

1. Convert catalog Dictionaries to `.tres` resources for editor-driven balancing.
2. Add true random weighted choice rolls and reroll/banish mechanics.
3. Implement placeholder items (`Hunter Bow`, `Arcane Wand`) as real weapons.
4. Add character catalog so each character has unique base stats + starting item.
