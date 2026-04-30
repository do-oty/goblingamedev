# Goblin Game - Current State

Current build is a Vampire Survivors-style prototype with a lobby -> portal -> run loop.

## Core Flow

1. Start game from main menu (no continue button).
2. Spawn in `LobbyMap`, move around, use NPC upgrades, pick a portal.
3. Enter `ForestMap`, `DesertMap`, or `SnowMap` run.
4. Survive for `15:00` or die.
5. Earn coins from drops and spend them in lobby for permanent upgrades.

## Active Scenes

- `scenes/maps/LobbyMap.tscn` - lobby, 3 portals, upgrade NPC.
- `scenes/maps/ForestMap.tscn` - main run scene + HUD + debug.
- `scenes/maps/DesertMap.tscn` - placeholder map scene (currently based on Forest).
- `scenes/maps/SnowMap.tscn` - placeholder map scene (currently based on Forest).

## Main Systems

- `scripts/GameRoot.gd` - run timer, enemy spawning, XP/leveling, drops, debug panel.
- `scripts/player.gd` - movement, dash, auto attack, sword progression, lobby mode toggle.
- `scripts/enemy.gd` - enemy base behavior, elites, brute/blink/tank variants.
- `scripts/goblin_mage.gd` - fire mage behavior.
- `scripts/goblin_electric_mage.gd` - electric mage behavior.
- `scripts/goblin_sword.gd` - sword goblin behavior.
- `scripts/XpOrb.gd` - XP orb pickup and magnet behavior.
- `scripts/PickupDrop.gd` - coin/health pickup behavior.
- `scripts/GameState.gd` - save data, coins, permanent upgrades.
- `scripts/data/ItemCatalog.gd` - item + talent data.
- `scripts/data/CharacterCatalog.gd` - base character data.

## Current Balance Snapshot

### Run

| Stat | Value |
|---|---:|
| Run Duration | 15:00 |
| Spawn Interval | 2.45s -> 0.18s |
| Max Enemies Alive | 18 -> 260 |
| Min Enemies Floor | 1 -> 120 |
| Horde Event Interval | 28s -> 44s |
| Elite Start Time | 90s |

### Enemy Unlock Timings

| Enemy Type | Unlock Time |
|---|---:|
| Grunt | 0:00 |
| Sword Goblin | 3:00 |
| Fire Mage | 6:30 |
| Electric Mage | 9:00 |

### Player (Knight Base)

| Stat | Value |
|---|---:|
| Move Speed | 110 |
| Max HP | 100 |
| Pickup Radius | 20 |
| Magnet Range | 26 |
| Magnet Strength | 70 |
| Luck | 0.0 |
| Dash Cooldown | 3.2s base (modifiable) |
| Dash Duration | 0.16s |
| Dash Distance | 165 base |
| Dash I-frames | 0.18s base |

### Enemies

#### Grunt Goblin (`enemy.gd`)

| Stat | Value |
|---|---:|
| Move Speed | 82 |
| Horde Run Speed | 240 |
| Max HP | 30 |
| Contact Damage | 9 |
| Contact Cooldown | 0.75s |
| XP Reward | 1 (blue tier) |

#### Sword Goblin (`goblin_sword.gd`)

| Stat | Value |
|---|---:|
| HP Multiplier | 1.55x |
| Speed Multiplier | 1.20x |
| Damage Multiplier | 1.35x |
| Contact Cooldown Multiplier | 0.78x |
| Knockback Taken Multiplier | 0.42x |
| Visual Scale | 1.08x |
| XP Reward | 2 (green tier) |

#### Fire Mage Goblin (`goblin_mage.gd`)

| Stat | Value |
|---|---:|
| HP Multiplier | 1.25x |
| Speed Multiplier | 0.90x |
| Damage Multiplier | 1.15x |
| Cast Cooldown | 2.9s to 4.1s |
| Channel Time | 1.85s |
| Volley Count | 2 |
| AOE Radius | 56 |
| AOE Damage Multiplier | 1.30x |
| Cast Range | 140 to 520 |
| Chase Distance Threshold | 250 |
| XP Reward | 2 (green tier) |

#### Electric Mage Goblin (`goblin_electric_mage.gd`)

| Stat | Value |
|---|---:|
| HP Multiplier | 1.20x |
| Speed Multiplier | 0.92x |
| Damage Multiplier | 1.12x |
| Cast Cooldown | 3.2s to 4.6s |
| Channel Time | 1.55s |
| Segment Count | 7 |
| Segment Length | 72 |
| Segment Half Width | 24 |
| Segment Damage Multiplier | 1.15x |
| Cast Range | 150 to 560 |
| Chase Distance Threshold | 260 |
| XP Reward | 2 (green tier) |

#### Elite Modifiers (`enemy.gd`)

| Stat | Value |
|---|---:|
| Elite HP Multiplier | 3.0x to 4.3x (time-scaled) |
| Elite Damage Multiplier | 1.8x to 2.15x (time-scaled) |
| Elite Speed Multiplier | 0.82x to 0.94x (time-scaled) |
| Elite XP Multiplier | 6x |
| Elite XP Tier | red |

#### Elite Type Extras

| Type | Extra Effects |
|---|---|
| Brute | +35% HP, +15% damage, charge ability, lower knockback taken |
| Blink | Slightly lower speed, periodic blink teleport, blink-specific VFX |
| Tank | +85% HP, -5% damage, extra size, lower speed |

## Weapon and Leveling

### Starter Weapon: Sword Slash

Sword is data-driven in `ItemCatalog` and currently implemented to max level `8`.
Milestones: `Lv5` adds +1 angled slash, `Lv8` adds +2 angled slashes total.

| Level | Damage | AOE Radius | Cooldown |
|---:|---:|---:|---:|
| 1 | 5 | 70 | 1.15s |
| 2 | 8 | 84 | 1.00s |
| 3 | 12 | 98 | 0.88s |
| 4 | 17 | 116 | 0.76s |
| 5 | 23 | 136 | 0.64s |
| 6 | 30 | 152 | 0.58s |
| 7 | 38 | 170 | 0.52s |
| 8 | 48 | 192 | 0.46s |

### Item Pool

- `sword_slash` (implemented)
- `bow_placeholder` (not yet implemented)
- `wand_placeholder` (not yet implemented)

### Talent Pool

- `might` (+20% weapon damage)
- `reach` (+20% sword AOE)
- `haste` (+15% attack speed)
- `blade_fan` (+1 angled slash, max 2)
- `dash_mastery` (-15% dash cooldown, +0.03s i-frames)
- `longstep` (+45 dash distance)

## Drops and Meta Progression

### Enemy Drops

- XP orb always drops on enemy defeat.
- Additional random drop chances:
  - Coin drop chance: `0.18` (luck-scaled)
  - Health drop chance: `0.012` (luck-scaled)
  - Health pickup heal: `22`

### Coins and Permanent Upgrades (Lobby NPC)

Persistent save data stores:
- `coins`
- `permanent_upgrades`

Current permanent upgrade effects in `GameState`:
- Max HP: `+8` per level
- Move Speed: `+3` per level
- Luck: `+0.08` per level
- Dash cooldown reduction: `+0.03` per level

## Debug Tools (Run Scene)

Current debug actions include:
- Time skip (+60s)
- Spawn horde
- Spawn elite variants
- Spawn enemy archetypes (normal + elite)
- AOE increase
- Level up
- Full heal

Debug panel position now respects editor-authored placement.
