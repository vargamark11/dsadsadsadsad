# ALIEN: NIGHTFALL — Core Gameplay Mechanics

## Game Synopsis

**ALIEN: NIGHTFALL** is an intense, cooperative multiplayer survival horror experience set in the overrun research colony of New Eden on the desolate exoplanet LV-894. Up to 8 players deploy as salvage operatives, security contractors, and researchers to restore critical systems, extract confidential xenobiology data, and survive the onslaught of intelligent alien predators.

---

## 1. Player Loop & Mechanics

### Survival Hierarchy
- **Health (100 HP)**: Does not regenerate naturally. Players must scavenge medical supplies (Bandages, Medkits, Stim Injectors) to heal.
- **Stamina (100 Units)**:
  - Consumed while sprinting (18 units/second).
  - Regenerates after a 1.25s delay at 22 units/second.
  - Sprints require a minimum of 10 stamina units.
- **Downed & Bleedout State**:
  - Reaching 0 HP places the player into the `DOWNED` state rather than instant death.
  - Downed players crawl slowly (4 studs/second) and enter a 45-second bleedout countdown.
  - Teammates can perform a continuous 5.0-second hold interaction to revive them to 40% HP.
  - If unrevived within 45 seconds, the operative succumbs and dies.

---

## 2. Interaction System

The interaction system is completely server-authoritative and drives all environment puzzle solving:

- **Simple / Instant**: Flicking light switches, toggling airlock doors, picking up uncontained items.
- **Hold Interactions**: Searching crates, hotwiring power couplings, bandaging wounds (1.5s - 8.0s).
- **Security Keycards**: Five clearance levels (`NONE`, `KEYCARD_LEVEL_1`, `KEYCARD_LEVEL_2`, `KEYCARD_LEVEL_3`, `KEYCARD_MASTER`).
- **Environmental Hazards**: Biometric locks, atmospheric depressurization, generator repair.

---

## 3. World Zones & Threat Levels

Operatives navigate through 7 distinct sectors of the colony:
1. **Landing Base (Aegis Hub)**: Safe zone with defensive turrets, gear lockers, and medical bays.
2. **Research Complex Sector Alpha**: High-tech bio labs requiring Level 2 keycards.
3. **Medical Center & Quarantine**: Contaminated wards filled with crawling facehuggers.
4. **Blackwood Perimeter Forest**: Dense alien pine woods shrouded in thick fog.
5. **Subterranean Geothermal Tunnels**: Pitch-black pipeline shafts with zero light.
6. **New Eden Colony Ruins**: Collapsed residential and commercial high-rises.
7. **Sub-Surface Hive Infestation**: Extreme threat zone with bio-resin hive chambers.

---

## 4. Extraction & Victory Conditions

To survive a run, the fireteam must:
1. Complete assigned primary objectives (e.g., download flight telemetry, restore secondary power, retrieve specimen samples).
2. Signal the extraction dropship at an designated LZ.
3. Defend the landing perimeter for 90 seconds against swarming predators.
4. Board the shuttle before dust-off.
