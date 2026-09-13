--!strict
--[[
    MissionsConfig.luau
    Declarative configuration for mission chains, categories, objective stages,
    and completion reward matrices in ALIEN: NIGHTFALL.
]]

export type MissionCategory =
    | "REPAIR"
    | "SEARCH"
    | "RESCUE"
    | "ESCORT"
    | "INVESTIGATE"
    | "ACTIVATE"
    | "COLLECT"
    | "SURVIVE"
    | "DEFEND"
    | "ESCAPE"
    | "RECOVER"
    | "DELIVER"

export type ZoneId =
    | "LANDING_BASE"
    | "RESEARCH_COMPLEX"
    | "MEDICAL_FACILITY"
    | "ABANDONED_CITY"
    | "DARK_FOREST"
    | "UNDERGROUND_FACILITY"
    | "MINING_COMPLEX"
    | "SUBWAY_SYSTEM"
    | "SECRET_LABORATORY"
    | "ALIEN_NEST"
    | "EXTRACTION_AREA"

export type ObjectiveType =
    | "INTERACT"
    | "COLLECT_ITEMS"
    | "ELIMINATE_TARGETS"
    | "HOLD_POSITION"
    | "ACTIVATE_CONSOLE"
    | "ESCORT_ENTITY"
    | "REACH_ZONE"

export type ObjectiveDefinition = {
    Id: string,
    Title: string,
    Description: string,
    Type: ObjectiveType,
    TargetId: string,
    TargetQuantity: number,
    TargetZone: ZoneId,
    TimeLimitSeconds: number?,
    Optional: boolean?,
    RewardMultiplier: number?,
}

export type MissionTemplate = {
    TemplateId: string,
    Title: string,
    Category: MissionCategory,
    PrimaryZone: ZoneId,
    Difficulty: 1 | 2 | 3 | 4 | 5,
    Objectives: { ObjectiveDefinition },
    BaseXPReward: number,
    BaseCreditsReward: number,
    BonusConditions: {
        NoDowns: number,
        UnderTimeSeconds: number,
        TimeBonusPercent: number,
    },
}

local MissionsConfig: {
    Categories: { [MissionCategory]: string },
    Templates: { [string]: MissionTemplate },
    ZoneDisplayNames: { [ZoneId]: string },
} = {
    Categories = {
        REPAIR = "Structural & Electrical Restoration",
        SEARCH = "Area Reconnaissance & Scanning",
        RESCUE = "Stranded Personnel Recovery",
        ESCORT = "VIP & Asset Convoy Protection",
        INVESTIGATE = "Bio-Anomalies & Black Box Inquiry",
        ACTIVATE = "Subsystem & Reactor Bootstrapping",
        COLLECT = "Specimen & Resource Scavenging",
        SURVIVE = "Wave Survival Under Siege",
        DEFEND = "Critical Infrastructure Fortification",
        ESCAPE = "Emergency Perimeter Breakthrough",
        RECOVER = "Classified Tech & Datacore Retrieval",
        DELIVER = "Payload Transport Through Hostile Sectors",
    },

    ZoneDisplayNames = {
        LANDING_BASE = "Landing Zone Alpha (Safe Hub)",
        RESEARCH_COMPLEX = "Sector 3 R&D Laboratories",
        MEDICAL_FACILITY = "Hope Memorial Medical Center",
        ABANDONED_CITY = "New Meridian Colony Core",
        DARK_FOREST = "Blackwood Bio-Canopy",
        UNDERGROUND_FACILITY = "Sub-Level 4 Maintenance & Drainage",
        MINING_COMPLEX = "Deep-Shaft Extraction Quarters",
        SUBWAY_SYSTEM = "Metro Line 0 Transit Terminus",
        SECRET_LABORATORY = "Project Chimera Black Site",
        ALIEN_NEST = "Hive Nexus: Deep Spire",
        EXTRACTION_AREA = "Helipad Beta / Rail Shuttle",
    },

    Templates = {
        RESTORE_POWER_SECTOR3 = {
            TemplateId = "RESTORE_POWER_SECTOR3",
            Title = "Restore Main Grid Power",
            Category = "REPAIR",
            PrimaryZone = "RESEARCH_COMPLEX",
            Difficulty = 2,
            Objectives = {
                {
                    Id = "FIND_GENERATOR",
                    Title = "Locate Auxiliary Generator Substation",
                    Description = "Proceed to the Research Complex basement substation.",
                    Type = "REACH_ZONE",
                    TargetId = "SUBSTATION_ALPHA",
                    TargetQuantity = 1,
                    TargetZone = "RESEARCH_COMPLEX",
                },
                {
                    Id = "COLLECT_FUSES",
                    Title = "Scavenge High-Voltage Fuses",
                    Description = "Locate 3 heavy fuses in the maintenance storeroom.",
                    Type = "COLLECT_ITEMS",
                    TargetId = "ITEM_HV_FUSE",
                    TargetQuantity = 3,
                    TargetZone = "RESEARCH_COMPLEX",
                },
                {
                    Id = "INSTALL_FUSES",
                    Title = "Reboot Auxiliary Generator",
                    Description = "Insert fuses into the generator control panel.",
                    Type = "INTERACT",
                    TargetId = "GENERATOR_CONSOLE",
                    TargetQuantity = 1,
                    TargetZone = "RESEARCH_COMPLEX",
                },
                {
                    Id = "DEFEND_REBOOT",
                    Title = "Survive Alien Surge During Startup",
                    Description = "Hold the substation against incoming hostiles for 60 seconds.",
                    Type = "HOLD_POSITION",
                    TargetId = "GENERATOR_ROOM_PERIMETER",
                    TargetQuantity = 60,
                    TargetZone = "RESEARCH_COMPLEX",
                    TimeLimitSeconds = 60,
                },
            },
            BaseXPReward = 600,
            BaseCreditsReward = 450,
            BonusConditions = {
                NoDowns = 200,
                UnderTimeSeconds = 300,
                TimeBonusPercent = 0.25,
            },
        },

        INVESTIGATE_SIGNAL_FOREST = {
            TemplateId = "INVESTIGATE_SIGNAL_FOREST",
            Title = "Emergency Transponder Signal",
            Category = "INVESTIGATE",
            PrimaryZone = "DARK_FOREST",
            Difficulty = 3,
            Objectives = {
                {
                    Id = "ENTER_FOREST",
                    Title = "Trek Into the Dark Forest",
                    Description = "Cross the perimeter fence into the dense bio-canopy.",
                    Type = "REACH_ZONE",
                    TargetId = "FOREST_NORTH_GATE",
                    TargetQuantity = 1,
                    TargetZone = "DARK_FOREST",
                },
                {
                    Id = "RECOVER_RADIO",
                    Title = "Locate Downed Ranger Comm-Relay",
                    Description = "Follow audio ping intervals to the crash site.",
                    Type = "INTERACT",
                    TargetId = "RANGER_RADIO_BEACON",
                    TargetQuantity = 1,
                    TargetZone = "DARK_FOREST",
                },
                {
                    Id = "ELIMINATE_SCOUTS",
                    Title = "Repel Scout Ambush",
                    Description = "Eliminate the lurking xeno scouts alerted by the relay.",
                    Type = "ELIMINATE_TARGETS",
                    TargetId = "SCOUT",
                    TargetQuantity = 4,
                    TargetZone = "DARK_FOREST",
                },
                {
                    Id = "EXTRACT_FOREST",
                    Title = "Fall Back to Evac Vehicle",
                    Description = "Reach the extraction buggy at the forest perimeter.",
                    Type = "REACH_ZONE",
                    TargetId = "EXTRACTION_FOREST_OUTPOST",
                    TargetQuantity = 1,
                    TargetZone = "EXTRACTION_AREA",
                },
            },
            BaseXPReward = 850,
            BaseCreditsReward = 600,
            BonusConditions = {
                NoDowns = 300,
                UnderTimeSeconds = 420,
                TimeBonusPercent = 0.3,
            },
        },

        HIVE_SAMPLE_EXTRACTION = {
            TemplateId = "HIVE_SAMPLE_EXTRACTION",
            Title = "Classified Hive Tissue Specimen",
            Category = "RECOVER",
            PrimaryZone = "ALIEN_NEST",
            Difficulty = 5,
            Objectives = {
                {
                    Id = "BREACH_NEST",
                    Title = "Infiltrate Deep Hive Spire",
                    Description = "Descend through the mining shaft into organic tunnels.",
                    Type = "REACH_ZONE",
                    TargetId = "HIVE_ENTRANCE_PORTAL",
                    TargetQuantity = 1,
                    TargetZone = "ALIEN_NEST",
                },
                {
                    Id = "EXTRACT_EMBRYO",
                    Title = "Harvest Matriarch Chitin Specimen",
                    Description = "Interact with the incubation chamber while suppressing spores.",
                    Type = "INTERACT",
                    TargetId = "MATRIARCH_CHAMBER_CORE",
                    TargetQuantity = 1,
                    TargetZone = "ALIEN_NEST",
                },
                {
                    Id = "SURVIVE_PURSUIT",
                    Title = "Survive the Hive Alert Pursuit",
                    Description = "Flee back toward the mining elevator while hunted by Brutes.",
                    Type = "HOLD_POSITION",
                    TargetId = "MINING_ELEVATOR_CAR",
                    TargetQuantity = 75,
                    TargetZone = "MINING_COMPLEX",
                    TimeLimitSeconds = 90,
                },
                {
                    Id = "SHUTTLE_ESCAPE",
                    Title = "Escape Aboard Heavy Transport Shuttle",
                    Description = "Enter the shuttle airlock before countdown expires.",
                    Type = "REACH_ZONE",
                    TargetId = "EXTRACTION_SHUTTLE_BAY",
                    TargetQuantity = 1,
                    TargetZone = "EXTRACTION_AREA",
                },
            },
            BaseXPReward = 1800,
            BaseCreditsReward = 1500,
            BonusConditions = {
                NoDowns = 600,
                UnderTimeSeconds = 600,
                TimeBonusPercent = 0.5,
            },
        },
    },
}

return table.freeze(MissionsConfig)
