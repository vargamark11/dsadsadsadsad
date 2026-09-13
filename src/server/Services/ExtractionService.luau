--!strict
--[[
    ExtractionService.luau
    Cooperative extraction sequence manager in ALIEN: NIGHTFALL.
    Coordinates extraction countdowns, defense waves, vehicle arrivals,
    and final match reward distribution.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NetworkProtocol = require(ReplicatedStorage.AlienNightfall.Shared.Network.NetworkProtocol)
local ServiceManager = require(script.Parent.Parent.ServiceManager)
local Signal = require(ReplicatedStorage.AlienNightfall.Shared.Utility.Signal)

export type ExtractionStatus = "IDLE" | "COUNTDOWN" | "ARRIVED" | "COMPLETED"

local ExtractionService = {
    Name = "ExtractionService",
    ExtractionTriggered = Signal.new(),
    ExtractionCompleted = Signal.new(),
    _status = "IDLE" :: ExtractionStatus,
    _holdoutSecondsRemaining = 0,
    _activePadId = "",
}

function ExtractionService:OnInit()
    print("[ExtractionService] Initialized.")
end

function ExtractionService:OnStart()
    -- Countdown tick loop
    task.spawn(function()
        while true do
            local dt = task.wait(1.0)
            if self._status == "COUNTDOWN" then
                self._holdoutSecondsRemaining -= dt
                if self._holdoutSecondsRemaining <= 0 then
                    self:_OnExtractionVehicleArrived()
                else
                    NetworkProtocol.ServerFireAllClients("AdminRemotes", "AdminNotice", {
                        Title = "EVACUATION INBOUND",
                        Message = string.format("Hold the extraction zone! Transport arrives in %ds", math.ceil(self._holdoutSecondsRemaining)),
                        Duration = 1.0,
                    })
                end
            end
        end
    end)
    print("[ExtractionService] Started.")
end

function ExtractionService:RequestExtraction(padId: string)
    if self._status ~= "IDLE" then return end

    self._status = "COUNTDOWN"
    self._activePadId = padId
    self._holdoutSecondsRemaining = 60 -- 60 second defensive holdout

    print(string.format("[ExtractionService] Extraction requested at %s. 60s holdout timer started.", padId))

    -- Trigger high tension world event
    local EventService = ServiceManager.GetService("EventService") :: any
    if EventService then
        EventService:TriggerEvent("EXTRACTION_ATTACK")
    end

    self.ExtractionTriggered:Fire(padId)
end

function ExtractionService:_OnExtractionVehicleArrived()
    self._status = "ARRIVED"
    print("[ExtractionService] Extraction vehicle has landed! Boarding doors open for 20s.")

    NetworkProtocol.ServerFireAllClients("AdminRemotes", "AdminNotice", {
        Title = "EXTRACTION TRANSPORT READY",
        Message = "Board the airlock now! Takeoff in 20 seconds.",
        Duration = 5.0,
    })

    task.delay(20, function()
        self:_FinalizeExtraction()
    end)
end

function ExtractionService:_FinalizeExtraction()
    self._status = "COMPLETED"
    print("[ExtractionService] Extraction completed! Awarding successful survival bonuses.")

    local ProgressionService = ServiceManager.GetService("ProgressionService") :: any
    local EconomyService = ServiceManager.GetService("EconomyService") :: any

    for _, player in ipairs(Players:GetPlayers()) do
        if ProgressionService then
            ProgressionService:AddXP(player, 1000, "EXTRACTION_SUCCESS")
            ProgressionService:IncrementStat(player, "ExtractionsSuccessful", 1)
        end
        if EconomyService then
            EconomyService:AddCredits(player, 750, "EXTRACTION_PAYOUT")
        end
    end

    self.ExtractionCompleted:Fire()
    self._status = "IDLE"
end

return ExtractionService
