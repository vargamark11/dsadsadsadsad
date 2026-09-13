--!strict
--[[
    AlienService.luau
    Authoritative lifecycle, spawning, and state machine simulation for all Alien archetypes.
    Evaluates IDLE, PATROL, INVESTIGATE, ALERT, CHASE, ATTACK, SEARCH, and RETREAT states.
    Features distance-based throttling and sensory raycasts.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local AlienStatsConfig = require(ReplicatedStorage.AlienNightfall.Config.AlienStatsConfig)
local AlienTypes = require(ReplicatedStorage.AlienNightfall.Shared.Types.AlienTypes)
local GameConstants = require(ReplicatedStorage.AlienNightfall.Shared.Constants.GameConstants)
local ServiceManager = require(script.Parent.Parent.ServiceManager)
local Signal = require(ReplicatedStorage.AlienNightfall.Shared.Utility.Signal)

export type AlienInstance = AlienTypes.AlienInstance

local AlienService = {
    Name = "AlienService",
    AlienSpawned = Signal.new(),
    AlienDied = Signal.new(),
    _activeAliens = {} :: { [string]: AlienInstance },
    _modelToEntityId = {} :: { [Model]: string },
}

function AlienService:OnInit()
    print("[AlienService] Initialized.")
end

function AlienService:OnStart()
    -- Main AI Evaluation Loop (4Hz sensory ticks)
    task.spawn(function()
        while true do
            local dt = task.wait(GameConstants.AIUpdateInterval)
            self:_UpdateAliens(dt)
        end
    end)
    print("[AlienService] Started.")
end

function AlienService:GetActiveAliens(): { [string]: AlienInstance }
    return self._activeAliens
end

function AlienService:GetAlienFromModel(model: Model): AlienInstance?
    local entityId = self._modelToEntityId[model]
    return entityId and self._activeAliens[entityId]
end

function AlienService:SpawnAlien(classType: AlienStatsConfig.AlienBehaviorType, spawnPosition: Vector3): AlienInstance?
    local config = AlienStatsConfig[classType]
    if not config then return nil end

    local entityId = "ALIEN_" .. classType .. "_" .. HttpService:GenerateGUID(false):sub(1, 8)

    -- Create physical model container
    local model = Instance.new("Model")
    model.Name = entityId

    local rootPart = Instance.new("Part")
    rootPart.Name = "HumanoidRootPart"
    rootPart.Size = Vector3.new(2.5, 5, 2.5)
    rootPart.CFrame = CFrame.new(spawnPosition)
    rootPart.CanCollide = true
    rootPart.Parent = model

    local head = Instance.new("Part")
    head.Name = "Head"
    head.Size = Vector3.new(1.5, 1.5, 1.5)
    head.CFrame = rootPart.CFrame * CFrame.new(0, 2.5, 0)
    head.CanCollide = false
    head.Parent = model

    local humanoid = Instance.new("Humanoid")
    humanoid.MaxHealth = config.Combat.MaxHealth
    humanoid.Health = config.Combat.MaxHealth
    humanoid.WalkSpeed = config.Combat.MovementSpeed
    humanoid.Parent = model

    model.PrimaryPart = rootPart
    model.Parent = workspace

    local blackboard: AlienTypes.AlienBlackboard = {
        CurrentState = "PATROL",
        TargetPlayer = nil,
        TargetLastSeenPosition = nil,
        TargetLastSeenTimestamp = nil,
        InvestigationPosition = nil,
        InvestigationReason = nil,
        CurrentHealth = config.Combat.MaxHealth,
        MaxHealth = config.Combat.MaxHealth,
        IsAttacking = false,
        LastAttackTimestamp = 0,
        StateEnteredTimestamp = os.clock(),
        SearchTimer = 0,
        PatrolAnchor = spawnPosition,
        CurrentPatrolIndex = 1,
        PatrolWaypoints = {
            spawnPosition + Vector3.new(config.Sensory.PatrolRadius * 0.5, 0, 0),
            spawnPosition + Vector3.new(0, 0, config.Sensory.PatrolRadius * 0.5),
            spawnPosition - Vector3.new(config.Sensory.PatrolRadius * 0.5, 0, 0),
        },
        MemoryTimer = 0,
        IsStaggered = false,
        StaggerEndTimestamp = 0,
    }

    local instance: AlienInstance = {
        EntityId = entityId,
        ClassType = classType,
        Model = model,
        Humanoid = humanoid,
        RootPart = rootPart,
        Blackboard = blackboard,
        Config = config,
        SpawnTimestamp = os.clock(),
    }

    self._activeAliens[entityId] = instance
    self._modelToEntityId[model] = entityId

    print(string.format("[AlienService] Spawned %s at (%.1f, %.1f, %.1f)", entityId, spawnPosition.X, spawnPosition.Y, spawnPosition.Z))
    self.AlienSpawned:Fire(instance)
    return instance
end

function AlienService:OnAlienHeardSound(entityId: string, stimulus: AlienTypes.SoundStimulus)
    local alien = self._activeAliens[entityId]
    if not alien then return end

    local bb = alien.Blackboard
    -- If currently chasing a direct target, don't break chase for distant footsteps
    if bb.CurrentState == "CHASE" or bb.CurrentState == "ATTACK" then
        return
    end

    bb.CurrentState = "INVESTIGATE"
    bb.InvestigationPosition = stimulus.Position
    bb.InvestigationReason = stimulus.Category
    bb.StateEnteredTimestamp = os.clock()
    alien.Humanoid.WalkSpeed = alien.Config.Combat.ChaseSpeed * 0.8
    alien.Humanoid:MoveTo(stimulus.Position)
end

function AlienService:DamageAlien(entityId: string, amount: number, attackerPlayer: Player?, isHeadshot: boolean): boolean
    local alien = self._activeAliens[entityId]
    if not alien then return false end

    local bb = alien.Blackboard
    bb.CurrentHealth = math.max(0, bb.CurrentHealth - amount)
    alien.Humanoid.Health = bb.CurrentHealth

    -- If damaged from unknown direction, instantly investigate attacker location
    if attackerPlayer and attackerPlayer.Character and attackerPlayer.Character.PrimaryPart then
        if bb.CurrentState ~= "CHASE" and bb.CurrentState ~= "ATTACK" then
            bb.CurrentState = "CHASE"
            bb.TargetPlayer = attackerPlayer
            bb.TargetLastSeenPosition = attackerPlayer.Character.PrimaryPart.Position
            bb.TargetLastSeenTimestamp = os.clock()
        end
    end

    -- Check Stagger threshold
    if amount >= alien.Config.Combat.StaggerThreshold then
        bb.IsStaggered = true
        bb.StaggerEndTimestamp = os.clock() + 1.0
        alien.Humanoid.WalkSpeed = 0
    end

    -- Check Low Health Retreat
    if alien.Config.Combat.RetreatHealthPercent > 0 then
        local ratio = bb.CurrentHealth / bb.MaxHealth
        if ratio <= alien.Config.Combat.RetreatHealthPercent and bb.CurrentState ~= "RETREAT" then
            bb.CurrentState = "RETREAT"
            bb.StateEnteredTimestamp = os.clock()
            alien.Humanoid.WalkSpeed = alien.Config.Combat.ChaseSpeed * 1.1
        end
    end

    -- Check Death
    if bb.CurrentHealth <= 0 then
        self:_OnAlienKilled(alien, attackerPlayer)
    end

    return true
end

function AlienService:_OnAlienKilled(alien: AlienInstance, killerPlayer: Player?)
    print(string.format("[AlienService] Alien %s killed by %s!", alien.EntityId, killerPlayer and killerPlayer.Name or "Environment"))

    self._activeAliens[alien.EntityId] = nil
    self._modelToEntityId[alien.Model] = nil

    if killerPlayer then
        local ProgressionService = ServiceManager.GetService("ProgressionService") :: any
        local EconomyService = ServiceManager.GetService("EconomyService") :: any

        if ProgressionService then
            ProgressionService:AddXP(killerPlayer, 100, "KILL_" .. alien.ClassType)
            ProgressionService:IncrementStat(killerPlayer, "TotalKills", 1)
        end
        if EconomyService then
            EconomyService:AddCredits(killerPlayer, 50, "KILL_" .. alien.ClassType)
        end
    end

    self.AlienDied:Fire(alien, killerPlayer)
    alien.Model:Destroy()
end

function AlienService:_UpdateAliens(dt: number)
    local AIService = ServiceManager.GetService("AIService") :: any
    local PlayerService = ServiceManager.GetService("PlayerService") :: any
    local activePlayers = Players:GetPlayers()

    for entityId, alien in pairs(self._activeAliens) do
        local bb = alien.Blackboard
        local rootPart = alien.RootPart
        if not rootPart or not rootPart.Parent then continue end

        -- Handle Stagger recovery
        if bb.IsStaggered then
            if os.clock() >= bb.StaggerEndTimestamp then
                bb.IsStaggered = false
                alien.Humanoid.WalkSpeed = alien.Config.Combat.MovementSpeed
            else
                continue
            end
        end

        -- Sensory visual cone sweep against active players
        local bestVisualTarget: Player? = nil
        local closestDist = math.huge

        for _, player in ipairs(activePlayers) do
            local char = player.Character
            local pRoot = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
            local liveState = PlayerService and PlayerService:GetLiveState(player)

            if pRoot and liveState and not liveState.IsDead and not liveState.IsDowned then
                local inFOV = AIService:IsInFieldOfView(rootPart, pRoot.Position, alien.Config.Sensory.FieldOfView)
                if inFOV then
                    local hasLOS, dist = AIService:CheckLineOfSight(rootPart.Position, pRoot, alien.Config.Sensory.DetectionDistance)
                    if hasLOS and dist < closestDist then
                        closestDist = dist
                        bestVisualTarget = player
                    end
                end
            end
        end

        -- State Machine Dispatcher
        if bestVisualTarget then
            bb.TargetPlayer = bestVisualTarget
            bb.TargetLastSeenPosition = bestVisualTarget.Character.PrimaryPart.Position
            bb.TargetLastSeenTimestamp = os.clock()
            bb.CurrentState = "CHASE"
        end

        if bb.CurrentState == "CHASE" then
            if bb.TargetPlayer and bb.TargetPlayer.Character and bb.TargetPlayer.Character.PrimaryPart then
                local targetPos = bb.TargetPlayer.Character.PrimaryPart.Position
                local dist = (targetPos - rootPart.Position).Magnitude

                if dist <= alien.Config.Combat.AttackDistance then
                    bb.CurrentState = "ATTACK"
                    self:_ExecuteAttack(alien, bb.TargetPlayer)
                else
                    alien.Humanoid.WalkSpeed = alien.Config.Combat.ChaseSpeed
                    alien.Humanoid:MoveTo(targetPos)
                end
            else
                -- Target lost: go to last known position
                bb.CurrentState = "SEARCH"
                bb.SearchTimer = alien.Config.Sensory.SearchDuration
            end

        elseif bb.CurrentState == "SEARCH" then
            bb.SearchTimer -= dt
            if bb.SearchTimer <= 0 then
                bb.CurrentState = "RETURN_TO_PATROL"
                bb.TargetPlayer = nil
            else
                -- Wander locally around last known position
                if bb.TargetLastSeenPosition then
                    alien.Humanoid:MoveTo(bb.TargetLastSeenPosition + Vector3.new(math.random(-15, 15), 0, math.random(-15, 15)))
                end
            end

        elseif bb.CurrentState == "RETURN_TO_PATROL" or bb.CurrentState == "PATROL" then
            alien.Humanoid.WalkSpeed = alien.Config.Combat.MovementSpeed
            local waypoints = bb.PatrolWaypoints
            if #waypoints > 0 then
                local targetWaypoint = waypoints[bb.CurrentPatrolIndex]
                alien.Humanoid:MoveTo(targetWaypoint)
                if (targetWaypoint - rootPart.Position).Magnitude < 8 then
                    bb.CurrentPatrolIndex = (bb.CurrentPatrolIndex % #waypoints) + 1
                end
            end
        end
    end
end

function AlienService:_ExecuteAttack(alien: AlienInstance, targetPlayer: Player)
    local bb = alien.Blackboard
    local now = os.clock()
    if (now - bb.LastAttackTimestamp) < alien.Config.Combat.AttackCooldown then
        return
    end

    bb.LastAttackTimestamp = now
    local PlayerService = ServiceManager.GetService("PlayerService") :: any
    if PlayerService then
        PlayerService:TakeDamage(targetPlayer, alien.Config.Combat.AttackDamage, alien.EntityId)
        print(string.format("[AlienService] %s attacked %s for %d damage!",
            alien.EntityId, targetPlayer.Name, alien.Config.Combat.AttackDamage))
    end

    -- Return to chase after swing
    bb.CurrentState = "CHASE"
end

return AlienService
