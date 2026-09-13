--!strict
--[[
    InteractionSystem.spec.luau
    Automated test specifications for the Phase 3 Interaction System in ALIEN: NIGHTFALL.
    Validates all 23 interaction mechanics, security checks, anti-exploit timing,
    domain object behaviors, and 1, 2, 4, 8 player multiplayer concurrency.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local InteractionTypes = require(ReplicatedStorage.AlienNightfall.Shared.Types.InteractionTypes)
local InteractionConfig = require(ReplicatedStorage.AlienNightfall.Config.InteractionConfig)
local InteractionRegistry = require(ReplicatedStorage.AlienNightfall.Shared.Interaction.InteractionRegistry)
local InteractionValidator = require(ServerScriptService.AlienNightfall.Server.Services.InteractionValidator)
local InteractionService = require(ServerScriptService.AlienNightfall.Server.Services.InteractionService)
local PlayerStateManager = require(ServerScriptService.AlienNightfall.Server.Services.PlayerStateManager)
local InventoryService = require(ServerScriptService.AlienNightfall.Server.Services.InventoryService)
local DataService = require(ServerScriptService.AlienNightfall.Server.Services.DataService)

local InteractionSystemSpec = {}

-- Helper to create mock player with physical character and inventory
local function createMockPlayer(userId: number, name: string, startPos: Vector3?): Player
    local mock = Instance.new("Folder") as any
    mock.Name = name
    mock.UserId = userId
    mock.Character = nil

    local charAdded = Instance.new("BindableEvent")
    local charRemoving = Instance.new("BindableEvent")
    mock.CharacterAdded = charAdded.Event
    mock.CharacterRemoving = charRemoving.Event

    local attributes: { [string]: any } = {}
    function mock:SetAttribute(key: string, val: any)
        attributes[key] = val
    end
    function mock:GetAttribute(key: string): any
        return attributes[key]
    end

    function mock:LoadCharacter(pos: Vector3?)
        local char = Instance.new("Model")
        char.Name = name
        local hum = Instance.new("Humanoid")
        hum.Parent = char
        local hrp = Instance.new("Part")
        hrp.Name = "HumanoidRootPart"
        hrp.Position = pos or Vector3.new(0, 5, 0)
        hrp.Parent = char
        char.PrimaryPart = hrp
        mock.Character = char
        char.Parent = Workspace
        return char
    end

    -- Setup mock inventory profile via DataService
    DataService:GetProfile(mock :: Player)

    return mock :: Player
end

function InteractionSystemSpec.RunTests(runTest: (string, () -> ()) -> ())
    print("--------------------------------------------------")
    print("[SPEC] ALIEN: NIGHTFALL Phase 3 Interaction System")
    print("--------------------------------------------------")

    -- Ensure services are initialized
    InteractionService:OnInit()
    PlayerStateManager:OnInit()
    InventoryService:OnInit()

    -- 1. Simple interaction
    runTest("1. Simple Interaction: Instant Trigger & Activation", function()
        local buttonDef = InteractionRegistry.Register({
            Id = "TEST_BUTTON_01",
            Category = "BUTTON",
            Name = "Emergency Alarm Button",
            ActionText = "Sound Alarm",
            Type = "SIMPLE",
            Distance = 10,
            HoldDuration = 0,
            Cooldown = 0.5,
            RequiresLineOfSight = false,
        })

        local p = createMockPlayer(2001, "Survivor_Simple")
        p:LoadCharacter(Vector3.new(0, 5, 0))
        PlayerStateManager:InitRuntimeData(p)
        PlayerStateManager:SetState(p, "ALIVE")

        local res = InteractionService:HandleInteractRequest(p, {
            ObjectId = "TEST_BUTTON_01",
            Action = "INSTANT",
        })

        assert(res.Success == true, "Simple interaction failed to execute")
        assert(res.Feedback == "SUCCESS", "Feedback code mismatch")
        assert(res.NewState == "ACTIVATED", "Object state should be ACTIVATED")
    end)

    -- 2. Hold interaction & Anti-Exploit Timing
    runTest("2. Hold Interaction: Duration Verification & Instant Exploit Prevention", function()
        local holdDef = InteractionRegistry.Register({
            Id = "TEST_CRATE_HOLD",
            Category = "CONTAINER",
            Name = "Scrap Container",
            ActionText = "Search Scrap",
            Type = "HOLD",
            Distance = 10,
            HoldDuration = 0.3, -- Short test duration
            Cooldown = 0.1,
            RequiresLineOfSight = false,
        })

        local p = createMockPlayer(2002, "Survivor_Hold")
        p:LoadCharacter(Vector3.new(0, 5, 0))
        PlayerStateManager:InitRuntimeData(p)
        PlayerStateManager:SetState(p, "ALIVE")

        -- Step A: Start hold
        local startRes = InteractionService:HandleInteractRequest(p, {
            ObjectId = "TEST_CRATE_HOLD",
            Action = "START",
        })
        assert(startRes.Success == true, "Hold start failed")
        assert(PlayerStateManager:GetState(p) == "INTERACTING", "Player must transition to INTERACTING")

        -- Step B: Exploit attempt: instant completion without waiting
        local exploitRes = InteractionService:HandleInteractRequest(p, {
            ObjectId = "TEST_CRATE_HOLD",
            Action = "COMPLETE",
        })
        assert(exploitRes.Success == false, "Instant completion exploit should be rejected!")
        assert(exploitRes.Feedback == "FAILED", "Feedback code should be FAILED for premature completion")

        -- Step C: Legitimate completion after waiting hold duration
        InteractionService:HandleInteractRequest(p, { ObjectId = "TEST_CRATE_HOLD", Action = "START" })
        task.wait(0.35)
        local validRes = InteractionService:HandleInteractRequest(p, {
            ObjectId = "TEST_CRATE_HOLD",
            Action = "COMPLETE",
        })
        assert(validRes.Success == true, "Valid hold completion failed")
        assert(PlayerStateManager:GetState(p) == "ALIVE", "Player should revert to ALIVE after hold")
    end)

    -- 3. Locked interaction
    runTest("3. Locked Interaction: Rejection of Unauthorized Access", function()
        local lockedDoor = InteractionRegistry.CreateDoor("TEST_DOOR_LOCKED", "Blast Door Alpha", {
            IsLocked = true,
        })

        local p = createMockPlayer(2003, "Survivor_Locked")
        p:LoadCharacter(Vector3.new(0, 5, 0))
        PlayerStateManager:InitRuntimeData(p)
        PlayerStateManager:SetState(p, "ALIVE")

        local res = InteractionService:HandleInteractRequest(p, {
            ObjectId = "TEST_DOOR_LOCKED",
            Action = "INSTANT",
        })

        assert(res.Success == false, "Locked door should reject interaction without clearance")
        assert(res.Feedback == "LOCKED", "Feedback must be LOCKED")
    end)

    -- 4. Keycard interaction
    runTest("4. Keycard Interaction: Clearance Level Hierarchy (Level 2 vs Level 3)", function()
        local secureDoor = InteractionRegistry.CreateDoor("TEST_DOOR_KEYCARD", "Research Lab Airlock", {
            KeycardLevel = 3,
        })

        local p = createMockPlayer(2004, "Survivor_Keycard")
        p:LoadCharacter(Vector3.new(0, 5, 0))
        PlayerStateManager:InitRuntimeData(p)
        PlayerStateManager:SetState(p, "ALIVE")

        -- Give player Level 2 keycard (Insufficient for Level 3 door)
        InventoryService:AddItem(p, "KEYCARD_LEVEL_2", 1)

        local deniedRes = InteractionService:HandleInteractRequest(p, {
            ObjectId = "TEST_DOOR_KEYCARD",
            Action = "INSTANT",
        })
        assert(deniedRes.Success == false, "Level 2 keycard must NOT unlock Level 3 door")
        assert(deniedRes.Feedback == "ACCESS_DENIED", "Expected ACCESS_DENIED feedback")

        -- Upgrade player to Level 3 keycard
        InventoryService:AddItem(p, "KEYCARD_LEVEL_3", 1)

        local grantedRes = InteractionService:HandleInteractRequest(p, {
            ObjectId = "TEST_DOOR_KEYCARD",
            Action = "INSTANT",
        })
        assert(grantedRes.Success == true, "Level 3 keycard must unlock Level 3 door")
        assert(grantedRes.Feedback == "ACCESS_GRANTED", "Expected ACCESS_GRANTED feedback")
        assert(grantedRes.NewState == "OPEN", "Door state should transition to OPEN")
    end)

    -- 5. Item-required interaction
    runTest("5. Item-Required Interaction: Item Consumption & Validation", function()
        local fuseBox = InteractionRegistry.Register({
            Id = "TEST_FUSE_BOX",
            Category = "SWITCH",
            Name = "Secondary Auxiliary Fuse Box",
            ActionText = "Insert Grid Fuse",
            Type = "REQUIRES_ITEM",
            Distance = 8,
            HoldDuration = 0,
            Cooldown = 0.5,
            RequiresLineOfSight = false,
            RequiredItem = "ITEM_HV_FUSE",
            ConsumeItem = true,
        })

        local p = createMockPlayer(2005, "Survivor_Item")
        p:LoadCharacter(Vector3.new(0, 5, 0))
        PlayerStateManager:InitRuntimeData(p)
        PlayerStateManager:SetState(p, "ALIVE")

        -- Attempt without fuse
        local noItemRes = InteractionService:HandleInteractRequest(p, {
            ObjectId = "TEST_FUSE_BOX",
            Action = "INSTANT",
        })
        assert(noItemRes.Success == false, "Should fail without required item")
        assert(noItemRes.Feedback == "MISSING_ITEM", "Feedback must be MISSING_ITEM")

        -- Add fuse and retry
        InventoryService:AddItem(p, "ITEM_HV_FUSE", 1)
        local hasItem, _, slotIdx = InteractionValidator.ValidateRequiredItem(p, "ITEM_HV_FUSE", InventoryService)
        assert(hasItem == true and slotIdx ~= nil, "Inventory should contain fuse")

        local successRes = InteractionService:HandleInteractRequest(p, {
            ObjectId = "TEST_FUSE_BOX",
            Action = "INSTANT",
        })
        assert(successRes.Success == true, "Interaction should succeed with item")
        assert(successRes.Feedback == "SUCCESS", "Feedback must be SUCCESS")

        -- Verify item was consumed
        local stillHasItem = InteractionValidator.ValidateRequiredItem(p, "ITEM_HV_FUSE", InventoryService)
        assert(stillHasItem == false, "Consumed item must no longer exist in inventory")
    end)

    -- 6. Door system
    runTest("6. Door System: Open, Close, Toggle & Lockdown", function()
        local door = InteractionRegistry.CreateDoor("TEST_DOOR_CYCLE", "Corridor Door 4", {})
        local p = createMockPlayer(2006, "Survivor_Door")
        p:LoadCharacter(Vector3.new(0, 5, 0))
        PlayerStateManager:InitRuntimeData(p)
        PlayerStateManager:SetState(p, "ALIVE")

        -- Cycle 1: Open
        local openRes = InteractionService:HandleInteractRequest(p, { ObjectId = "TEST_DOOR_CYCLE", Action = "INSTANT" })
        assert(openRes.Success == true and openRes.NewState == "OPEN", "Door failed to open")

        -- Cycle 2: Close
        task.wait(0.55) -- Cooldown
        local closeRes = InteractionService:HandleInteractRequest(p, { ObjectId = "TEST_DOOR_CYCLE", Action = "INSTANT" })
        assert(closeRes.Success == true and closeRes.NewState == "CLOSED", "Door failed to close")

        -- Cycle 3: Lockdown test
        door.Attributes.DoorState = "LOCKDOWN"
        InteractionService:_UpdateObjectState("TEST_DOOR_CYCLE", "LOCKDOWN")
        task.wait(0.55)
        local lockdownRes = InteractionService:HandleInteractRequest(p, { ObjectId = "TEST_DOOR_CYCLE", Action = "INSTANT" })
        assert(lockdownRes.Success == false and lockdownRes.Feedback == "LOCKED", "Lockdown must block opening")
    end)

    -- 7. Generator system
    runTest("7. Generator System: Repair Progress & Activation", function()
        local gen = InteractionRegistry.CreateGenerator("TEST_GEN_01", "Sub-Level Generator", {
            RepairDuration = 0.25,
            RequiredFuse = "ITEM_HV_FUSE",
        })

        local p = createMockPlayer(2007, "Survivor_Gen")
        p:LoadCharacter(Vector3.new(0, 5, 0))
        PlayerStateManager:InitRuntimeData(p)
        PlayerStateManager:SetState(p, "ALIVE")
        InventoryService:AddItem(p, "ITEM_HV_FUSE", 1)

        -- Start repair
        local start = InteractionService:HandleInteractRequest(p, { ObjectId = "TEST_GEN_01", Action = "START" })
        assert(start.Success == true, "Generator repair start failed")

        task.wait(0.3)
        local comp = InteractionService:HandleInteractRequest(p, { ObjectId = "TEST_GEN_01", Action = "COMPLETE" })
        assert(comp.Success == true and comp.NewState == "ACTIVE", "Generator failed to reach ACTIVE state")
    end)

    -- 8. Terminal system
    runTest("8. Terminal System: Security Access & Activation", function()
        local term = InteractionRegistry.CreateTerminal("TEST_TERM_01", "Colony Mainframe", {
            HackDuration = 0.25,
        })

        local p = createMockPlayer(2008, "Survivor_Terminal")
        p:LoadCharacter(Vector3.new(0, 5, 0))
        PlayerStateManager:InitRuntimeData(p)
        PlayerStateManager:SetState(p, "ALIVE")

        InteractionService:HandleInteractRequest(p, { ObjectId = "TEST_TERM_01", Action = "START" })
        task.wait(0.3)
        local comp = InteractionService:HandleInteractRequest(p, { ObjectId = "TEST_TERM_01", Action = "COMPLETE" })
        assert(comp.Success == true and comp.NewState == "ACTIVE", "Terminal failed to reach ACTIVE state")
    end)

    -- 9. Switch system
    runTest("9. Switch System: On/Off Toggling & Signal Dispatch", function()
        local sw = InteractionRegistry.CreateSwitch("TEST_SW_01", "Power Grid Breaker", {})
        local p = createMockPlayer(2009, "Survivor_Switch")
        p:LoadCharacter(Vector3.new(0, 5, 0))
        PlayerStateManager:InitRuntimeData(p)
        PlayerStateManager:SetState(p, "ALIVE")

        local resOn = InteractionService:HandleInteractRequest(p, { ObjectId = "TEST_SW_01", Action = "INSTANT" })
        assert(resOn.Success == true and resOn.NewState == "ON", "Switch failed to toggle ON")

        task.wait(0.55)
        local resOff = InteractionService:HandleInteractRequest(p, { ObjectId = "TEST_SW_01", Action = "INSTANT" })
        assert(resOff.Success == true and resOff.NewState == "OFF", "Switch failed to toggle OFF")
    end)

    -- 10. Container system
    runTest("10. Container System: Search & Transition to OPEN", function()
        local crate = InteractionRegistry.CreateContainer("TEST_CRATE_01", "Medical Locker", {
            SearchDuration = 0.25,
            LootTableId = "MedicalCrate",
        })

        local p = createMockPlayer(2010, "Survivor_Crate")
        p:LoadCharacter(Vector3.new(0, 5, 0))
        PlayerStateManager:InitRuntimeData(p)
        PlayerStateManager:SetState(p, "ALIVE")

        InteractionService:HandleInteractRequest(p, { ObjectId = "TEST_CRATE_01", Action = "START" })
        task.wait(0.3)
        local comp = InteractionService:HandleInteractRequest(p, { ObjectId = "TEST_CRATE_01", Action = "COMPLETE" })
        assert(comp.Success == true and comp.NewState == "OPEN", "Container must enter OPEN state")
    end)

    -- 11. Loot system
    runTest("11. Loot System: Server-Side Random Loot Generation", function()
        local crate = InteractionRegistry.CreateContainer("TEST_CRATE_LOOT", "Supply Stash", {
            SearchDuration = 0.2,
            LootTableId = "AmmoStash",
        })

        local p = createMockPlayer(2011, "Survivor_Loot")
        p:LoadCharacter(Vector3.new(0, 5, 0))
        PlayerStateManager:InitRuntimeData(p)
        PlayerStateManager:SetState(p, "ALIVE")

        InteractionService:HandleInteractRequest(p, { ObjectId = "TEST_CRATE_LOOT", Action = "START" })
        task.wait(0.25)
        local comp = InteractionService:HandleInteractRequest(p, { ObjectId = "TEST_CRATE_LOOT", Action = "COMPLETE" })
        assert(comp.Success == true, "Loot interaction failed")
        assert(comp.Data ~= nil and #comp.Data > 0, "Loot should have generated at least 1 item roll")
    end)

    -- 12. Elevator system
    runTest("12. Elevator System: Floor Calling & Directional State", function()
        local elev = InteractionRegistry.CreateElevator("TEST_ELEV_01", "Sub-Level Lift", {})
        local p = createMockPlayer(2012, "Survivor_Elevator")
        p:LoadCharacter(Vector3.new(0, 5, 0))
        PlayerStateManager:InitRuntimeData(p)
        PlayerStateManager:SetState(p, "ALIVE")

        local callRes = InteractionService:HandleInteractRequest(p, { ObjectId = "TEST_ELEV_01", Action = "INSTANT" })
        assert(callRes.Success == true and callRes.NewState == "MOVING", "Elevator should transition to MOVING")
        assert(callRes.Data.TargetFloor == 2, "Floor 1 should call elevator to Floor 2")
    end)

    -- 13. Multi-Player interaction
    runTest("13. Multi-Player Interaction: Synchronized Multi-Crew Overrides", function()
        local dualConsole = InteractionRegistry.CreateMultiPlayerConsole("TEST_DUAL_CONSOLE", "Airlock Override", {
            RequiredPlayers = 2,
            HoldDuration = 0.25,
        })

        local p1 = createMockPlayer(2013, "Crew_1")
        p1:LoadCharacter(Vector3.new(0, 5, 0))
        PlayerStateManager:InitRuntimeData(p1)
        PlayerStateManager:SetState(p1, "ALIVE")

        local p2 = createMockPlayer(2014, "Crew_2")
        p2:LoadCharacter(Vector3.new(1, 5, 0))
        PlayerStateManager:InitRuntimeData(p2)
        PlayerStateManager:SetState(p2, "ALIVE")

        -- Player 1 begins hold alone
        local p1Start = InteractionService:HandleInteractRequest(p1, { ObjectId = "TEST_DUAL_CONSOLE", Action = "START" })
        assert(p1Start.Feedback == "REQUIRES_MORE_PLAYERS", "Single player must be informed more players are needed")

        -- Player 2 begins hold simultaneously
        local p2Start = InteractionService:HandleInteractRequest(p2, { ObjectId = "TEST_DUAL_CONSOLE", Action = "START" })
        assert(p2Start.Success == true and p2Start.NewState == "OVERRIDE_COMPLETE", "Simultaneous hold should complete override")
    end)

    -- 14. Sequence puzzle
    runTest("14. Sequence Puzzle: Ordered Step Inputs & Error Reset", function()
        local puzzle = InteractionRegistry.CreateSequencePuzzle("TEST_PUZZLE_01", "Security Code Switches", { 3, 1, 4, 2 })
        local p = createMockPlayer(2015, "Survivor_Puzzle")
        p:LoadCharacter(Vector3.new(0, 5, 0))
        PlayerStateManager:InitRuntimeData(p)
        PlayerStateManager:SetState(p, "ALIVE")

        -- Correct Step 1: 3
        local step1 = InteractionService:HandleInteractRequest(p, { ObjectId = "TEST_PUZZLE_01", Action = "INSTANT", StepValue = 3 })
        assert(step1.Feedback == "SEQUENCE_STEP", "Step 1 should be accepted")

        -- Incorrect Step 2: Input 5 (Expected 1)
        local errorStep = InteractionService:HandleInteractRequest(p, { ObjectId = "TEST_PUZZLE_01", Action = "INSTANT", StepValue = 5 })
        assert(errorStep.Feedback == "SEQUENCE_ERROR", "Wrong input should trigger SEQUENCE_ERROR")
        assert(puzzle.Sequence and puzzle.Sequence.CurrentIndex == 1, "Error should reset sequence back to Step 1")

        -- Full correct sequence: 3 -> 1 -> 4 -> 2
        InteractionService:HandleInteractRequest(p, { ObjectId = "TEST_PUZZLE_01", Action = "INSTANT", StepValue = 3 })
        InteractionService:HandleInteractRequest(p, { ObjectId = "TEST_PUZZLE_01", Action = "INSTANT", StepValue = 1 })
        InteractionService:HandleInteractRequest(p, { ObjectId = "TEST_PUZZLE_01", Action = "INSTANT", StepValue = 4 })
        local solved = InteractionService:HandleInteractRequest(p, { ObjectId = "TEST_PUZZLE_01", Action = "INSTANT", StepValue = 2 })
        assert(solved.Success == true and solved.NewState == "UNLOCKED", "Sequence puzzle should unlock on full match")
    end)

    -- 15. Timed interaction
    runTest("15. Timed Interaction: Start Countdown & Success vs Expiry", function()
        local timedConsole = InteractionRegistry.CreateTimedConsole("TEST_TIMED_01", "Coolant Vent", 0.4)
        local p = createMockPlayer(2016, "Survivor_Timed")
        p:LoadCharacter(Vector3.new(0, 5, 0))
        PlayerStateManager:InitRuntimeData(p)
        PlayerStateManager:SetState(p, "ALIVE")

        -- 1. Start timer
        local startRes = InteractionService:HandleInteractRequest(p, { ObjectId = "TEST_TIMED_01", Action = "INSTANT" })
        assert(startRes.Success == true and startRes.NewState == "TIMER_ACTIVE", "Timed override should activate timer")

        -- 2. Complete within time limit
        task.wait(0.1)
        local compRes = InteractionService:HandleInteractRequest(p, { ObjectId = "TEST_TIMED_01", Action = "INSTANT" })
        assert(compRes.Success == true and compRes.NewState == "TIMED_SUCCESS", "Timed override should succeed within time")

        -- 3. Test expiration on a second console
        local timedConsole2 = InteractionRegistry.CreateTimedConsole("TEST_TIMED_02", "Reactor Dump", 0.2)
        InteractionService:HandleInteractRequest(p, { ObjectId = "TEST_TIMED_02", Action = "INSTANT" })
        task.wait(0.25)
        local expiredRes = InteractionService:HandleInteractRequest(p, { ObjectId = "TEST_TIMED_02", Action = "INSTANT" })
        assert(expiredRes.Success == false and expiredRes.Feedback == "TIMED_OUT", "Expired timer must fail with TIMED_OUT")
    end)

    -- 16. Interaction cooldown
    runTest("16. Interaction Cooldown: Anti-Spam Rate Throttling", function()
        local button = InteractionRegistry.Register({
            Id = "TEST_COOLDOWN_BTN",
            Category = "BUTTON",
            Name = "Pneumatic Valve",
            ActionText = "Vent Valve",
            Type = "SIMPLE",
            Distance = 8,
            HoldDuration = 0,
            Cooldown = 0.5,
            RequiresLineOfSight = false,
        })

        local p = createMockPlayer(2017, "Survivor_Spam")
        p:LoadCharacter(Vector3.new(0, 5, 0))
        PlayerStateManager:InitRuntimeData(p)
        PlayerStateManager:SetState(p, "ALIVE")

        local first = InteractionService:HandleInteractRequest(p, { ObjectId = "TEST_COOLDOWN_BTN", Action = "INSTANT" })
        assert(first.Success == true, "First interact should succeed")

        -- Immediate second interact should be rejected by cooldown
        local spam = InteractionService:HandleInteractRequest(p, { ObjectId = "TEST_COOLDOWN_BTN", Action = "INSTANT" })
        assert(spam.Success == false and spam.Feedback == "COOLDOWN", "Immediate repeated interact must be rejected by COOLDOWN")
    end)

    -- 17. Invalid remote request
    runTest("17. Invalid Remote Request: Unregistered ID & Malformed Payload", function()
        local p = createMockPlayer(2018, "Survivor_Malicious")
        p:LoadCharacter(Vector3.new(0, 5, 0))
        PlayerStateManager:InitRuntimeData(p)
        PlayerStateManager:SetState(p, "ALIVE")

        local nilRes = InteractionService:HandleInteractRequest(p, nil :: any)
        assert(nilRes.Success == false and nilRes.Feedback == "DENIED", "Nil payload must be rejected")

        local unregRes = InteractionService:HandleInteractRequest(p, { ObjectId = "NON_EXISTENT_OBJECT_999" })
        assert(unregRes.Success == false and unregRes.Feedback == "DENIED", "Unregistered object must be rejected")
    end)

    -- 18. Player too far away
    runTest("18. Player Too Far Away: Distance Spoofing Prevention", function()
        local terminal = InteractionRegistry.CreateTerminal("TEST_FAR_TERM", "Observation Console", {
            Distance = 8,
        })
        -- Fix terminal position at (0, 0, 0)
        terminal.Attributes = { WorldPosition = Vector3.new(0, 0, 0) }

        local p = createMockPlayer(2019, "Survivor_Far")
        -- Place player 50 studs away
        p:LoadCharacter(Vector3.new(50, 0, 0))
        PlayerStateManager:InitRuntimeData(p)
        PlayerStateManager:SetState(p, "ALIVE")

        local res = InteractionService:HandleInteractRequest(p, { ObjectId = "TEST_FAR_TERM", Action = "START" })
        assert(res.Success == false and res.Feedback == "TOO_FAR", "Player at 50 studs must be rejected with TOO_FAR")
    end)

    -- 19. Player behind wall (Line of Sight)
    runTest("19. Player Behind Wall: Line-of-Sight Raycast Occlusion", function()
        local losObject = InteractionRegistry.Register({
            Id = "TEST_LOS_OBJECT",
            Category = "KEYPAD",
            Name = "Airlock Keypad",
            ActionText = "Enter PIN",
            Type = "SIMPLE",
            Distance = 10,
            HoldDuration = 0,
            Cooldown = 0.5,
            RequiresLineOfSight = true,
            Attributes = { WorldPosition = Vector3.new(0, 5, 10) },
        })

        local p = createMockPlayer(2020, "Survivor_BehindWall")
        p:LoadCharacter(Vector3.new(0, 5, 0))
        PlayerStateManager:InitRuntimeData(p)
        PlayerStateManager:SetState(p, "ALIVE")

        -- Create a thick physical wall between player (0,5,0) and target (0,5,10)
        local wall = Instance.new("Part")
        wall.Name = "OcclusionWall"
        wall.Size = Vector3.new(10, 10, 2)
        wall.Position = Vector3.new(0, 5, 5)
        wall.Anchored = true
        wall.CanCollide = true
        wall.Parent = Workspace

        local res = InteractionService:HandleInteractRequest(p, { ObjectId = "TEST_LOS_OBJECT", Action = "INSTANT" })
        wall:Destroy()

        assert(res.Success == false and res.Feedback == "NO_LINE_OF_SIGHT", "Occluded line-of-sight must be rejected with NO_LINE_OF_SIGHT")
    end)

    -- 20. Player downed
    runTest("20. Player Downed: Interaction Prohibition in Incapacitated State", function()
        local button = InteractionRegistry.Register({
            Id = "TEST_DOWNED_BTN",
            Category = "BUTTON",
            Name = "Lift Call Button",
            ActionText = "Call Lift",
            Type = "SIMPLE",
            Distance = 8,
            HoldDuration = 0,
            Cooldown = 0.5,
            RequiresLineOfSight = false,
        })

        local p = createMockPlayer(2021, "Survivor_Downed")
        p:LoadCharacter(Vector3.new(0, 5, 0))
        PlayerStateManager:InitRuntimeData(p)
        PlayerStateManager:SetState(p, "ALIVE")
        PlayerStateManager:SetState(p, "DOWNED")

        local res = InteractionService:HandleInteractRequest(p, { ObjectId = "TEST_DOWNED_BTN", Action = "INSTANT" })
        assert(res.Success == false and res.Feedback == "WRONG_STATE", "Downed player must be rejected with WRONG_STATE")
    end)

    -- 21. Player dead
    runTest("21. Player Dead: Complete Interaction Prohibition", function()
        local p = createMockPlayer(2022, "Survivor_Dead")
        p:LoadCharacter(Vector3.new(0, 5, 0))
        PlayerStateManager:InitRuntimeData(p)
        PlayerStateManager:SetState(p, "ALIVE")
        PlayerStateManager:SetState(p, "DEAD")

        local res = InteractionService:HandleInteractRequest(p, { ObjectId = "TEST_BUTTON_01", Action = "INSTANT" })
        assert(res.Success == false and res.Feedback == "WRONG_STATE", "Dead player must be rejected with WRONG_STATE")
    end)

    -- 22. Player leaves during interaction
    runTest("22. Player Leaves During Interaction: Active Hold Cleanup", function()
        local p = createMockPlayer(2023, "Survivor_Leaving")
        p:LoadCharacter(Vector3.new(0, 5, 0))
        PlayerStateManager:InitRuntimeData(p)
        PlayerStateManager:SetState(p, "ALIVE")

        local holdObj = InteractionRegistry.Register({
            Id = "TEST_LEAVE_HOLD",
            Category = "CONTAINER",
            Name = "Medical Box",
            ActionText = "Search",
            Type = "HOLD",
            Distance = 8,
            HoldDuration = 5.0,
            Cooldown = 0.5,
            RequiresLineOfSight = false,
        })

        InteractionService:HandleInteractRequest(p, { ObjectId = "TEST_LEAVE_HOLD", Action = "START" })
        assert(InteractionValidator.GetHoldSession(p) ~= nil, "Hold session must exist")

        -- Simulate departure cleanup
        InteractionService:CancelAllHoldsForPlayer(p, "PlayerLeaving")
        assert(InteractionValidator.GetHoldSession(p) == nil, "Hold session must be cleaned up on player exit")
    end)

    -- 23. Multiple players interacting simultaneously (1, 2, 4, 8 players)
    runTest("23. Multiplayer Concurrency: Scaled Simultaneous Interactions (1, 2, 4, 8 Players)", function()
        local playerCounts = { 1, 2, 4, 8 }

        for _, count in ipairs(playerCounts) do
            local players = {}
            for i = 1, count do
                local p = createMockPlayer(3000 + i + (count * 10), string.format("MultiSurvivor_%d_%d", count, i))
                p:LoadCharacter(Vector3.new(i * 0.5, 5, 0))
                PlayerStateManager:InitRuntimeData(p)
                PlayerStateManager:SetState(p, "ALIVE")
                table.insert(players, p)
            end

            -- Create unique container for this concurrency tier
            local tierCrate = InteractionRegistry.CreateContainer("TEST_CRATE_TIER_" .. tostring(count), "Tier Stash", {
                SearchDuration = 0.2,
                LootTableId = "MedicalCrate",
            })

            -- Each player initiates hold simultaneously
            for _, p in ipairs(players) do
                local startRes = InteractionService:HandleInteractRequest(p, { ObjectId = tierCrate.Id, Action = "START" })
                assert(startRes.Success == true, string.format("Tier %d player start failed", count))
            end

            task.wait(0.25)

            -- Each player completes hold independently
            for _, p in ipairs(players) do
                local compRes = InteractionService:HandleInteractRequest(p, { ObjectId = tierCrate.Id, Action = "COMPLETE" })
                assert(compRes.Success == true, string.format("Tier %d player complete failed", count))
                assert(PlayerStateManager:GetState(p) == "ALIVE", "Player must return to ALIVE state")
            end
        end
    end)
end

return InteractionSystemSpec
