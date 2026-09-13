--!strict
--[[
    AdminService.luau
    Authoritative administrative command execution engine in ALIEN: NIGHTFALL.
    Strictly validates caller permissions, logs every command with metadata,
    and executes actions across game systems.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NetworkProtocol = require(ReplicatedStorage.AlienNightfall.Shared.Network.NetworkProtocol)
local ServiceManager = require(script.Parent.Parent.ServiceManager)

local AdminService = {
    Name = "AdminService",
}

function AdminService:OnInit()
    print("[AdminService] Initialized.")
end

function AdminService:OnStart()
    -- Bind command execution function
    NetworkProtocol.ServerBindFunction("AdminRemotes", "ExecuteCommand", function(player: Player, commandName: any, targetUserId: any, args: any)
        return self:ExecuteCommand(player, tostring(commandName), tonumber(targetUserId), args or {})
    end)

    -- Bind log viewer function
    NetworkProtocol.ServerBindFunction("AdminRemotes", "FetchLogs", function(player: Player, categoryFilter: any)
        local PermissionService = ServiceManager.GetService("PermissionService") :: any
        if not PermissionService or not PermissionService:HasRank(player, "MODERATOR") then
            return { Success = false, Error = "Unauthorized" }
        end

        local LoggingService = ServiceManager.GetService("LoggingService") :: any
        local logs = LoggingService and LoggingService:GetRecentLogs(50, categoryFilter) or {}
        return { Success = true, Logs = logs }
    end)

    print("[AdminService] Started.")
end

function AdminService:ExecuteCommand(adminPlayer: Player, commandId: string, targetUserId: number?, args: { [string]: any }): any
    local PermissionService = ServiceManager.GetService("PermissionService") :: any
    local LoggingService = ServiceManager.GetService("LoggingService") :: any

    if not PermissionService then
        return { Success = false, Error = "Permission system offline" }
    end

    local allowed, err = PermissionService:CanExecuteCommand(adminPlayer, commandId)
    if not allowed then
        return { Success = false, Error = err or "Access denied" }
    end

    local targetPlayer: Player? = targetUserId and Players:GetPlayerByUserId(targetUserId) or nil

    -- Command Handlers
    if commandId == "HEAL" and targetPlayer then
        local PlayerService = ServiceManager.GetService("PlayerService") :: any
        if PlayerService then
            PlayerService:Heal(targetPlayer, 100)
            if LoggingService then
                LoggingService:Log("ADMIN", "HEAL", {}, adminPlayer, targetPlayer)
            end
            return { Success = true, Message = string.format("Healed %s", targetPlayer.Name) }
        end

    elseif commandId == "RESPAWN" and targetPlayer then
        local PlayerService = ServiceManager.GetService("PlayerService") :: any
        if PlayerService then
            PlayerService:SetDowned(targetPlayer, false)
            targetPlayer:LoadCharacter()
            if LoggingService then
                LoggingService:Log("ADMIN", "RESPAWN", {}, adminPlayer, targetPlayer)
            end
            return { Success = true, Message = string.format("Respawned %s", targetPlayer.Name) }
        end

    elseif commandId == "TELEPORT" and targetPlayer then
        local adminChar = adminPlayer.Character
        local targetChar = targetPlayer.Character
        if adminChar and targetChar and adminChar.PrimaryPart and targetChar.PrimaryPart then
            adminChar:SetPrimaryPartCFrame(targetChar.PrimaryPart.CFrame * CFrame.new(0, 0, 3))
            if LoggingService then
                LoggingService:Log("ADMIN", "TELEPORT_TO", {}, adminPlayer, targetPlayer)
            end
            return { Success = true, Message = string.format("Teleported to %s", targetPlayer.Name) }
        end

    elseif commandId == "BRING" and targetPlayer then
        local adminChar = adminPlayer.Character
        local targetChar = targetPlayer.Character
        if adminChar and targetChar and adminChar.PrimaryPart and targetChar.PrimaryPart then
            targetChar:SetPrimaryPartCFrame(adminChar.PrimaryPart.CFrame * CFrame.new(0, 0, -3))
            if LoggingService then
                LoggingService:Log("ADMIN", "BRING_PLAYER", {}, adminPlayer, targetPlayer)
            end
            return { Success = true, Message = string.format("Brought %s", targetPlayer.Name) }
        end

    elseif commandId == "KICK" and targetPlayer then
        local ModerationService = ServiceManager.GetService("ModerationService") :: any
        if ModerationService then
            ModerationService:KickPlayer(adminPlayer, targetPlayer, args.Reason or "Staff action")
            return { Success = true, Message = string.format("Kicked %s", targetPlayer.Name) }
        end

    elseif commandId == "FREEZE" and targetPlayer then
        local ModerationService = ServiceManager.GetService("ModerationService") :: any
        if ModerationService then
            ModerationService:FreezePlayer(adminPlayer, targetPlayer, args.Freeze == true)
            return { Success = true, Message = string.format("Freeze state updated for %s", targetPlayer.Name) }
        end

    elseif commandId == "TRIGGER_EVENT" and args.EventType then
        local EventService = ServiceManager.GetService("EventService") :: any
        if EventService and EventService:TriggerEvent(args.EventType) then
            if LoggingService then
                LoggingService:Log("ADMIN", "TRIGGER_EVENT", { EventType = args.EventType }, adminPlayer, nil)
            end
            return { Success = true, Message = string.format("Event %s triggered", args.EventType) }
        end

    elseif commandId == "SET_WEATHER" and args.WeatherState then
        local WeatherService = ServiceManager.GetService("WeatherService") :: any
        if WeatherService then
            WeatherService:SetWeather(args.WeatherState)
            if LoggingService then
                LoggingService:Log("ADMIN", "SET_WEATHER", { WeatherState = args.WeatherState }, adminPlayer, nil)
            end
            return { Success = true, Message = string.format("Weather set to %s", args.WeatherState) }
        end

    elseif commandId == "SPAWN_ALIEN" and args.ClassType then
        local AlienService = ServiceManager.GetService("AlienService") :: any
        local adminChar = adminPlayer.Character
        local root = adminChar and adminChar:FindFirstChild("HumanoidRootPart") :: BasePart?
        local spawnPos = root and (root.Position + root.CFrame.LookVector * 15) or Vector3.new(0, 10, 0)

        if AlienService then
            local alien = AlienService:SpawnAlien(args.ClassType, spawnPos)
            if alien then
                if LoggingService then
                    LoggingService:Log("ADMIN", "SPAWN_ALIEN", { ClassType = args.ClassType, Pos = tostring(spawnPos) }, adminPlayer, nil)
                end
                return { Success = true, Message = string.format("Spawned %s", args.ClassType) }
            end
        end

    elseif commandId == "GIVE_CURRENCY" and targetPlayer and args.CurrencyType and args.Amount then
        local EconomyService = ServiceManager.GetService("EconomyService") :: any
        if EconomyService then
            if args.CurrencyType == "ColonyCredits" then
                EconomyService:AddCredits(targetPlayer, tonumber(args.Amount) or 0, "ADMIN_GRANT")
            else
                EconomyService:AddNanites(targetPlayer, tonumber(args.Amount) or 0, "ADMIN_GRANT")
            end
            return { Success = true, Message = string.format("Granted %s %s to %s", tostring(args.Amount), args.CurrencyType, targetPlayer.Name) }
        end

    elseif commandId == "SERVER_ANNOUNCEMENT" and args.Message then
        NetworkProtocol.ServerFireAllClients("AdminRemotes", "AdminNotice", {
            Title = "PRIORITY BROADCAST",
            Message = tostring(args.Message),
            Duration = 8.0,
        })
        return { Success = true, Message = "Announcement broadcasted" }
    end

    return { Success = false, Error = "Command unhandled or parameters missing" }
end

return AdminService
