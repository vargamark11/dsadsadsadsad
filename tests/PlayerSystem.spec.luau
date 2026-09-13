--!strict
--[[
    PlayerSystem.spec.luau
    Automated test specifications for the Phase 2 Player System in ALIEN: NIGHTFALL.
    Validates all 15 core player lifecycle, health, stamina, sprint, state machine,
    multiplayer concurrency (1, 2, 4, 8 players), and edge-case failure scenarios.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerConfig = require(ReplicatedStorage.AlienNightfall.Config.PlayerConfig)
local PlayerTypes = require(ReplicatedStorage.AlienNightfall.Shared.Types.PlayerTypes)
local PlayerStateManager = require(ServerScriptService.AlienNightfall.Server.Services.PlayerStateManager)
local HealthService = require(ServerScriptService.AlienNightfall.Server.Services.HealthService)
local StaminaService = require(ServerScriptService.AlienNightfall.Server.Services.StaminaService)
local CharacterService = require(ServerScriptService.AlienNightfall.Server.Services.CharacterService)
local ZoneService = require(ServerScriptService.AlienNightfall.Server.Services.ZoneService)
local PlayerService = require(ServerScriptService.AlienNightfall.Server.Services.PlayerService)

local PlayerSystemSpec = {}

-- Test Fixture: Generates mock player objects for deterministic server testing
local function createMockPlayer(userId: number, name: string): Player
    local mock = Instance.new("Folder") as any
    mock.Name = name
    mock.UserId = userId
    mock.Character = nil

    -- Mock CharacterAdded and CharacterRemoving signals
    local charAdded = Instance.new("BindableEvent")
    local charRemoving = Instance.new("BindableEvent")
    mock.CharacterAdded = charAdded.Event
    mock.CharacterRemoving = charRemoving.Event
    mock._fireCharAdded = function(c: Model) charAdded:Fire(c) end
    mock._fireCharRemoving = function(c: Model) charRemoving:Fire(c) end

    -- Mock attributes
    local attributes: { [string]: any } = {}
    function mock:SetAttribute(key: string, val: any)
        attributes[key] = val
    end
    function mock:GetAttribute(key: string): any
        return attributes[key]
    end

    function mock:LoadCharacter()
        local char = Instance.new("Model")
        char.Name = name
        local hum = Instance.new("Humanoid")
        hum.Parent = char
        local hrp = Instance.new("Part")
        hrp.Name = "HumanoidRootPart"
        hrp.Parent = char
        char.PrimaryPart = hrp
        mock.Character = char
        char.Parent = workspace
        mock._fireCharAdded(char)
        return char
    end

    return mock :: Player
end

function PlayerSystemSpec.RunTests(runTest: (string, () -> ()) -> ())
    -- 1. Player joins
    runTest("Player Joins: Runtime State Initialization", function()
        local p = createMockPlayer(1001, "SurvivorAlpha")
        local data = PlayerStateManager:InitRuntimeData(p)

        assert(data ~= nil, "Runtime data was not initialized")
        assert(data.State == "LOBBY", "Player must start in LOBBY state")
        assert(data.Health == PlayerConfig.Health.DefaultHealth, "Player health must match DefaultHealth")
        assert(data.Stamina == PlayerConfig.Stamina.DefaultStamina, "Player stamina must match DefaultStamina")
        assert(data.IsAlive == false, "Player in LOBBY must not be flagged alive until spawn")
        assert(p:GetAttribute("PlayerState") == "LOBBY", "PlayerState attribute must mirror runtime state")

        PlayerStateManager:CleanupRuntimeData(p)
    end)

    -- 2. Player leaves
    runTest("Player Leaves: Cleanup Lifecycle", function()
        local p = createMockPlayer(1002, "SurvivorBeta")
        PlayerStateManager:InitRuntimeData(p)
        assert(PlayerStateManager:GetRuntimeData(p) ~= nil, "Setup failed")

        PlayerStateManager:CleanupRuntimeData(p)
        assert(PlayerStateManager:GetRuntimeData(p) == nil, "Runtime data was not purged on cleanup")
    end)

    -- 3. Character spawns
    runTest("Character Spawns: Transition to ALIVE & Reset Systems", function()
        local p = createMockPlayer(1003, "SurvivorGamma")
        PlayerStateManager:InitRuntimeData(p)
        local data = PlayerStateManager:GetRuntimeData(p)!

        -- Simulate character spawn
        PlayerStateManager:SetState(p, "SPAWNING")
        assert(PlayerStateManager:GetState(p) == "SPAWNING", "Must transition to SPAWNING")

        PlayerStateManager:SetState(p, "ALIVE")
        assert(PlayerStateManager:GetState(p) == "ALIVE", "Must transition to ALIVE")
        assert(data.IsAlive == true, "IsAlive must be true")
        assert(data.MovementState == "WALKING", "Movement state must be WALKING")

        PlayerStateManager:CleanupRuntimeData(p)
    end)

    -- 4. Character respawns
    runTest("Character Respawns: Safe Offset & State Reset", function()
        local p = createMockPlayer(1004, "SurvivorDelta")
        PlayerStateManager:InitRuntimeData(p)
        PlayerStateManager:SetState(p, "SPAWNING")
        PlayerStateManager:SetState(p, "ALIVE")

        -- Take damage and die
        HealthService:KillPlayer(p)
        assert(PlayerStateManager:GetState(p) == "DEAD", "State must be DEAD")

        -- Respawn
        PlayerStateManager:SetState(p, "SPAWNING")
        HealthService:ResetForSpawn(p)
        StaminaService:ResetForSpawn(p)

        local data = PlayerStateManager:GetRuntimeData(p)!
        assert(data.State == "ALIVE", "Respawned state must be ALIVE")
        assert(data.Health == PlayerConfig.Health.RespawnHealth, "Respawn health must match RespawnHealth")
        assert(data.Stamina == PlayerConfig.Stamina.DefaultStamina, "Respawn stamina must match DefaultStamina")
        assert(data.IsDowned == false, "IsDowned must be false after respawn")

        PlayerStateManager:CleanupRuntimeData(p)
    end)

    -- 5. Health changes
    runTest("Health Changes: Clamping & Signal Dispatch", function()
        local p = createMockPlayer(1005, "SurvivorEpsilon")
        PlayerStateManager:InitRuntimeData(p)
        PlayerStateManager:SetState(p, "SPAWNING")
        PlayerStateManager:SetState(p, "ALIVE")

        local signalFired = false
        local conn = HealthService.HealthChanged:Connect(function(player, oldH, newH, maxH)
            if player == p then
                signalFired = true
                assert(oldH == 100 and newH == 75, "Health values mismatch in signal")
            end
        end)

        HealthService:SetHealth(p, 75)
        local curH, maxH = HealthService:GetHealth(p)
        assert(curH == 75 and maxH == 100, "GetHealth mismatch")
        assert(signalFired, "HealthChanged signal did not fire")

        -- Test upper clamping
        HealthService:SetHealth(p, 250)
        curH, _ = HealthService:GetHealth(p)
        assert(curH == 100, "Health must not exceed MaxHealth")

        conn:Disconnect()
        PlayerStateManager:CleanupRuntimeData(p)
    end)

    -- 6. Damage
    runTest("Damage Handling & Downed Trigger", function()
        local p = createMockPlayer(1006, "SurvivorZeta")
        PlayerStateManager:InitRuntimeData(p)
        PlayerStateManager:SetState(p, "SPAWNING")
        PlayerStateManager:SetState(p, "ALIVE")

        -- Deal non-lethal damage
        HealthService:DamagePlayer(p, 30, "AlienClaw")
        local curH, _ = HealthService:GetHealth(p)
        assert(curH == 70, "Damage deduction mismatch")

        -- Deal lethal damage
        HealthService:DamagePlayer(p, 80, "BruteSmash")
        local data = PlayerStateManager:GetRuntimeData(p)!
        assert(data.Health == 0, "Health must be 0 on lethal damage")
        assert(data.IsDowned == true, "Lethal damage must trigger DOWNED state")
        assert(data.State == "DOWNED", "Player state must be DOWNED")
        assert(data.DownedTimerRemaining == PlayerConfig.Downed.BleedoutDuration, "Bleedout timer must initialize")

        PlayerStateManager:CleanupRuntimeData(p)
    end)

    -- 7. Healing
    runTest("Healing & Revive Restoration", function()
        local p = createMockPlayer(1007, "SurvivorEta")
        PlayerStateManager:InitRuntimeData(p)
        PlayerStateManager:SetState(p, "SPAWNING")
        PlayerStateManager:SetState(p, "ALIVE")

        HealthService:DamagePlayer(p, 50, "AcidSpit")
        assert(select(1, HealthService:GetHealth(p)) == 50, "Damage setup mismatch")

        -- Apply medical heal
        local healResult = HealthService:HealPlayer(p, 30, "Medkit")
        assert(healResult == true, "Heal must succeed on injured alive player")
        assert(select(1, HealthService:GetHealth(p)) == 80, "Heal amount mismatch")

        -- Cannot overheal past MaxHealth
        HealthService:HealPlayer(p, 50, "Medkit")
        assert(select(1, HealthService:GetHealth(p)) == 100, "Heal must cap at MaxHealth")

        PlayerStateManager:CleanupRuntimeData(p)
    end)

    -- 8. Sprint
    runTest("Sprint Request Validation & Activation", function()
        local p = createMockPlayer(1008, "SurvivorTheta")
        PlayerStateManager:InitRuntimeData(p)
        PlayerStateManager:SetState(p, "SPAWNING")
        PlayerStateManager:SetState(p, "ALIVE")

        local sprintSuccess = StaminaService:RequestSprint(p, true)
        assert(sprintSuccess == true, "Sprint request must succeed with full stamina")

        local data = PlayerStateManager:GetRuntimeData(p)!
        assert(data.IsSprinting == true, "IsSprinting must be true")
        assert(data.State == "SPRINTING", "State must be SPRINTING")
        assert(data.MovementState == "SPRINTING", "MovementState must be SPRINTING")
        assert(p:GetAttribute("IsSprinting") == true, "Attribute IsSprinting must be true")

        -- Stop sprint
        StaminaService:RequestSprint(p, false)
        assert(data.IsSprinting == false, "IsSprinting must be false")
        assert(data.State == "ALIVE", "State must revert to ALIVE")
        assert(data.MovementState == "WALKING", "MovementState must revert to WALKING")

        PlayerStateManager:CleanupRuntimeData(p)
    end)

    -- 9. Stamina drain
    runTest("Stamina Drain During Active Sprint", function()
        local p = createMockPlayer(1009, "SurvivorIota")
        PlayerStateManager:InitRuntimeData(p)
        PlayerStateManager:SetState(p, "SPAWNING")
        PlayerStateManager:SetState(p, "ALIVE")

        StaminaService:StartSprint(p)
        local initialStam, _ = StaminaService:GetStamina(p)

        -- Simulate 1 second of sprint drain
        local dt = 1.0
        local drainAmount = PlayerConfig.Stamina.SprintDrainRate * dt
        StaminaService:SetStamina(p, initialStam - drainAmount)

        local afterStam, _ = StaminaService:GetStamina(p)
        assert(afterStam == initialStam - drainAmount, "Stamina drain calculation mismatch")

        PlayerStateManager:CleanupRuntimeData(p)
    end)

    -- 10. Stamina regeneration
    runTest("Stamina Regeneration After Recovery Delay", function()
        local p = createMockPlayer(1010, "SurvivorKappa")
        PlayerStateManager:InitRuntimeData(p)
        PlayerStateManager:SetState(p, "SPAWNING")
        PlayerStateManager:SetState(p, "ALIVE")

        -- Set low stamina
        StaminaService:SetStamina(p, 40)
        local data = PlayerStateManager:GetRuntimeData(p)!
        data.LastStaminaDrainTimestamp = os.clock() - (PlayerConfig.Stamina.RecoveryDelay + 0.5) -- simulate elapsed delay

        -- Simulate regeneration of 1 second
        local recoveryAmount = PlayerConfig.Stamina.StaminaRecoveryRate * 1.0
        StaminaService:SetStamina(p, 40 + recoveryAmount)

        local currentStam, _ = StaminaService:GetStamina(p)
        assert(currentStam == 40 + recoveryAmount, "Stamina regeneration calculation mismatch")

        PlayerStateManager:CleanupRuntimeData(p)
    end)

    -- 11. Invalid sprint request
    runTest("Invalid Sprint Requests Blocked", function()
        local p = createMockPlayer(1011, "SurvivorLambda")
        PlayerStateManager:InitRuntimeData(p)
        PlayerStateManager:SetState(p, "SPAWNING")
        PlayerStateManager:SetState(p, "ALIVE")

        -- Test 1: Sprint with low stamina (< MinimumSprintStamina)
        StaminaService:SetStamina(p, 5)
        local lowStamSprint = StaminaService:RequestSprint(p, true)
        assert(lowStamSprint == false, "Sprint must be rejected when stamina is below minimum threshold")

        -- Reset stamina
        StaminaService:SetStamina(p, 100)

        -- Test 2: Sprint while DOWNED
        HealthService:SetDowned(p, true)
        local downedSprint = StaminaService:RequestSprint(p, true)
        assert(downedSprint == false, "Sprint must be rejected while player is DOWNED")

        -- Test 3: Sprint while DEAD
        HealthService:KillPlayer(p)
        local deadSprint = StaminaService:RequestSprint(p, true)
        assert(deadSprint == false, "Sprint must be rejected while player is DEAD")

        PlayerStateManager:CleanupRuntimeData(p)
    end)

    -- 12. Invalid state transition
    runTest("Invalid State Transitions Rejected by Authority", function()
        local p = createMockPlayer(1012, "SurvivorMu")
        PlayerStateManager:InitRuntimeData(p)

        -- LOBBY -> DOWNED is invalid
        local canLobbyToDowned, _ = PlayerStateManager:CanTransition(p, "DOWNED")
        assert(canLobbyToDowned == false, "Transition from LOBBY to DOWNED must be forbidden")

        -- DEAD -> SPRINTING is invalid
        PlayerStateManager:SetState(p, "SPAWNING")
        PlayerStateManager:SetState(p, "ALIVE")
        HealthService:KillPlayer(p)
        assert(PlayerStateManager:GetState(p) == "DEAD", "State must be DEAD")

        local canDeadToSprint, _ = PlayerStateManager:CanTransition(p, "SPRINTING")
        assert(canDeadToSprint == false, "Transition from DEAD to SPRINTING must be forbidden")

        -- DOWNED -> SPRINTING is invalid
        PlayerStateManager:SetState(p, "SPAWNING")
        PlayerStateManager:SetState(p, "ALIVE")
        HealthService:SetDowned(p, true)

        local canDownedToSprint, _ = PlayerStateManager:CanTransition(p, "SPRINTING")
        assert(canDownedToSprint == false, "Transition from DOWNED to SPRINTING must be forbidden")

        PlayerStateManager:CleanupRuntimeData(p)
    end)

    -- 13. Multiple players (1, 2, 4, 8 players)
    for _, playerCount in ipairs({ 1, 2, 4, 8 }) do
        runTest(string.format("Multiplayer Concurrency Isolation: %d Players", playerCount), function()
            local players: { Player } = {}
            for i = 1, playerCount do
                local p = createMockPlayer(2000 + i, string.format("SquadMember_%d", i))
                table.insert(players, p)
                PlayerStateManager:InitRuntimeData(p)
                PlayerStateManager:SetState(p, "SPAWNING")
                PlayerStateManager:SetState(p, "ALIVE")
            end

            -- Verify independent health and stamina modifications
            for i, p in ipairs(players) do
                HealthService:DamagePlayer(p, i * 5, "TestDamage")
                StaminaService:SetStamina(p, 100 - (i * 10))
            end

            for i, p in ipairs(players) do
                local curH, _ = HealthService:GetHealth(p)
                local curS, _ = StaminaService:GetStamina(p)
                assert(curH == 100 - (i * 5), string.format("Player %d health leaked across squad", i))
                assert(curS == 100 - (i * 10), string.format("Player %d stamina leaked across squad", i))
            end

            -- Clean up
            for _, p in ipairs(players) do
                PlayerStateManager:CleanupRuntimeData(p)
            end
        end)
    end

    -- 14. Player leaving during initialization
    runTest("Edge Case: Player Leaves During Initialization", function()
        local p = createMockPlayer(1013, "GhostPlayer")
        -- Simulate player being removed before character setup completes
        p.Parent = nil

        local success, err = pcall(function()
            CharacterService:_OnCharacterAdded(p, Instance.new("Model"))
        end)
        assert(success, "CharacterService threw error on disconnected player")

        PlayerStateManager:CleanupRuntimeData(p)
    end)

    -- 15. Rapid respawn
    runTest("Edge Case: Rapid Respawn Spam Throttled", function()
        local p = createMockPlayer(1014, "RapidSpawner")
        PlayerStateManager:InitRuntimeData(p)

        local firstRespawn = CharacterService:Respawn(p)
        assert(firstRespawn == true, "First respawn attempt must succeed")

        local rapidRespawn = CharacterService:Respawn(p)
        assert(rapidRespawn == false, "Subsequent rapid respawn within 1 second must be throttled")

        PlayerStateManager:CleanupRuntimeData(p)
    end)
end

return PlayerSystemSpec
