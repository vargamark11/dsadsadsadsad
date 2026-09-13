--!strict
--[[
    AlienStatsConfig.luau
    Authoritative balance and sensory parameters for Alien classes in ALIEN: NIGHTFALL.
    Strictly server-authoritative. Detection is grounded in mathematical sensory cones,
    auditory threshold radii, and occlusion raycasts.
]]

export type AlienBehaviorType = "SCOUT" | "HUNTER" | "STALKER" | "BRUTE" | "SWARM" | "BOSS"

export type AlienSensoryConfig = {
    DetectionDistance: number,     -- Max visual sightline distance (studs)
    FieldOfView: number,            -- Angular field of view in degrees (e.g. 90 deg forward cone)
    HearingDistance: number,        -- Auditory baseline radius for standard sound profiles
    SoundThreshold: number,         -- Minimum sound impulse amplitude to trigger investigation
    MemoryDuration: number,         -- Duration (seconds) alien searches last known location
    SearchDuration: number,         -- Duration of localized search patterns before resuming patrol
    PatrolRadius: number,           -- Radial distance around anchor points for ambient patrol
    DarknessVisionBuff: number,     -- Sensitivity multiplier in low light / nightfall conditions
}

export type AlienCombatConfig = {
    MaxHealth: number,
    MovementSpeed: number,          -- Normal patrol speed (studs/sec)
    ChaseSpeed: number,             -- Sprint/chase speed (studs/sec)
    AttackDistance: number,         -- Melee strike trigger range (studs)
    AttackDamage: number,           -- Instant damage delivered on successful hit
    AttackCooldown: number,         -- Cooldown in seconds between attacks
    StaggerThreshold: number,       -- Damage required in short window to stagger/interrupt
    RetreatHealthPercent: number,   -- Health threshold (0.0 - 1.0) to trigger tactical retreat
}

export type AlienClassDef = {
    ClassId: AlienBehaviorType,
    DisplayName: string,
    Description: string,
    Sensory: AlienSensoryConfig,
    Combat: AlienCombatConfig,
    SpecialTraits: { [string]: any },
}

local AlienStatsConfig: { [AlienBehaviorType]: AlienClassDef } = {
    SCOUT = {
        ClassId = "SCOUT",
        DisplayName = "Xeno Scout",
        Description = "Hyper-fast recon drone with fragile exoskeleton and acute visual-auditory detection.",
        Sensory = {
            DetectionDistance = 140,
            FieldOfView = 120,
            HearingDistance = 160,
            SoundThreshold = 10,
            MemoryDuration = 8,
            SearchDuration = 10,
            PatrolRadius = 120,
            DarknessVisionBuff = 1.3,
        },
        Combat = {
            MaxHealth = 120,
            MovementSpeed = 16,
            ChaseSpeed = 28,
            AttackDistance = 6,
            AttackDamage = 18,
            AttackCooldown = 0.9,
            StaggerThreshold = 35,
            RetreatHealthPercent = 0.35,
        },
        SpecialTraits = {
            CallBackupOnSight = true,
            BackupCallDelay = 2.5,
            WallClimbEnabled = true,
            StealthFootsteps = true,
        },
    },

    HUNTER = {
        ClassId = "HUNTER",
        DisplayName = "Colony Hunter",
        Description = "Relentless apex predator equipped with olfactory glands and tracking adaptations.",
        Sensory = {
            DetectionDistance = 120,
            FieldOfView = 100,
            HearingDistance = 190,
            SoundThreshold = 15,
            MemoryDuration = 15,
            SearchDuration = 18,
            PatrolRadius = 150,
            DarknessVisionBuff = 1.5,
        },
        Combat = {
            MaxHealth = 320,
            MovementSpeed = 14,
            ChaseSpeed = 23,
            AttackDistance = 7,
            AttackDamage = 34,
            AttackCooldown = 1.2,
            StaggerThreshold = 80,
            RetreatHealthPercent = 0.15,
        },
        SpecialTraits = {
            BleedTracking = true,
            CanLeap = true,
            LeapDistance = 35,
            LeapCooldown = 7,
        },
    },

    STALKER = {
        ClassId = "STALKER",
        DisplayName = "Shadow Stalker",
        Description = "Ambusher that moves through dark vents and shadows, striking when players isolate.",
        Sensory = {
            DetectionDistance = 110,
            FieldOfView = 80,
            HearingDistance = 140,
            SoundThreshold = 12,
            MemoryDuration = 20,
            SearchDuration = 25,
            PatrolRadius = 200,
            DarknessVisionBuff = 2.0,
        },
        Combat = {
            MaxHealth = 240,
            MovementSpeed = 12,
            ChaseSpeed = 25,
            AttackDistance = 5,
            AttackDamage = 50,
            AttackCooldown = 1.8,
            StaggerThreshold = 50,
            RetreatHealthPercent = 0.50,
        },
        SpecialTraits = {
            InvisibilityInShadows = true,
            TargetsIsolatedPlayers = true,
            CeilingLurking = true,
            SmokeVanishOnRetreat = true,
        },
    },

    BRUTE = {
        ClassId = "BRUTE",
        DisplayName = "Heavy Bio-Brute",
        Description = "Massive bio-mechanized siege mutant with armored chitinous plating.",
        Sensory = {
            DetectionDistance = 80,
            FieldOfView = 75,
            HearingDistance = 110,
            SoundThreshold = 30,
            MemoryDuration = 10,
            SearchDuration = 12,
            PatrolRadius = 80,
            DarknessVisionBuff = 1.0,
        },
        Combat = {
            MaxHealth = 950,
            MovementSpeed = 9,
            ChaseSpeed = 17,
            AttackDistance = 9,
            AttackDamage = 75,
            AttackCooldown = 2.2,
            StaggerThreshold = 250,
            RetreatHealthPercent = 0.0,
        },
        SpecialTraits = {
            ArmorFrontDamageReduction = 0.65,
            ChargeAttack = true,
            ChargeSpeed = 32,
            BreakDoors = true,
            ShockwaveOnSlam = true,
        },
    },

    SWARM = {
        ClassId = "SWARM",
        DisplayName = "Brood Swarmlet",
        Description = "Insectoid hatchling that hunts in aggressive packs of 4 to 12.",
        Sensory = {
            DetectionDistance = 75,
            FieldOfView = 130,
            HearingDistance = 120,
            SoundThreshold = 20,
            MemoryDuration = 6,
            SearchDuration = 8,
            PatrolRadius = 60,
            DarknessVisionBuff = 1.2,
        },
        Combat = {
            MaxHealth = 45,
            MovementSpeed = 18,
            ChaseSpeed = 24,
            AttackDistance = 4,
            AttackDamage = 12,
            AttackCooldown = 0.7,
            StaggerThreshold = 15,
            RetreatHealthPercent = 0.10,
        },
        SpecialTraits = {
            PackBonusDamage = 0.15,
            Climbing = true,
            ExplodeOnDeath = false,
        },
    },

    BOSS = {
        ClassId = "BOSS",
        DisplayName = "The Hive Empress",
        Description = "Colossal matriarch presiding over the colony alien nest. Multi-phase apex encounter.",
        Sensory = {
            DetectionDistance = 200,
            FieldOfView = 160,
            HearingDistance = 280,
            SoundThreshold = 5,
            MemoryDuration = 45,
            SearchDuration = 35,
            PatrolRadius = 250,
            DarknessVisionBuff = 1.5,
        },
        Combat = {
            MaxHealth = 6500,
            MovementSpeed = 13,
            ChaseSpeed = 22,
            AttackDistance = 14,
            AttackDamage = 90,
            AttackCooldown = 1.5,
            StaggerThreshold = 800,
            RetreatHealthPercent = 0.0,
        },
        SpecialTraits = {
            Phases = 3,
            SummonSwarmThresholds = { 0.75, 0.50, 0.25 },
            AcidPoolProjectiles = true,
            ArenaEnrage = true,
            GroundSlamRadius = 30,
        },
    },
}

return table.freeze(AlienStatsConfig)
