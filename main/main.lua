-- LocalScript: AutoFarmATM (StarterPlayerScripts)
-- กลับไปใช้แบบเดินไปยังตู้แรกที่พร้อม และเปลี่ยนเป้าหมายหากตู้ถูกใช้ไปก่อนถึง

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local PathfindingService = game:GetService("PathfindingService")
local UserInputService = game:GetService("UserInputService") -- Used for simulating key presses (may not always work)
local TweenService = game:GetService("TweenService") -- Added TweenService (still included for potential future use or if vehicle part uses it)

-- Ensure LocalPlayer is loaded
local player = Players.LocalPlayer
if not player then
    warn("[AutoFarmATM] LocalPlayer is not available!")
    return -- Stop script if LocalPlayer is not ready
end

-- Wait for Character and Humanoid to load completely
local char = player.Character or player.CharacterAdded:Wait()
local humanoid = char:WaitForChild("Humanoid")
local rootPart = char:WaitForChild("HumanoidRootPart")

local ATMFolder = Workspace:WaitForChild("Map"):WaitForChild("Props"):WaitForChild("ATMs")

local currentATM = nil
local moving = false

-- Table to store path visualization parts
local pathVisualizationParts = {}

-- Function to clear previous path visualization
local function ClearPathVisualization()
    for _, part in pairs(pathVisualizationParts) do
        if part and part.Parent then
            part:Destroy()
        end
    end
    pathVisualizationParts = {}
end

-- Function to draw the path using parts
local function DrawPath(waypoints)
    ClearPathVisualization() -- Clear any existing path first

    for i = 1, #waypoints - 1 do
        local p1 = waypoints[i].Position
        local p2 = waypoints[i+1].Position

        local segment = Instance.new("Part")
        segment.Name = "PathSegment"
        segment.Anchored = true
        segment.CanCollide = false
        segment.Transparency = 0.5 -- Adjust transparency as needed
        segment.BrickColor = BrickColor.new("Bright blue") -- Adjust color as needed

        local distance = (p2 - p1).Magnitude
        segment.Size = Vector3.new(0.5, 0.5, distance) -- Thickness and length
        segment.CFrame = CFrame.new(p1:Lerp(p2, 0.5), p2) -- Position halfway between, facing p2

        segment.Parent = Workspace -- Parent to Workspace or a specific folder for organization
        table.insert(pathVisualizationParts, segment)
    end

    -- Also draw a marker at each waypoint for clarity
    for _, waypoint in ipairs(waypoints) do
        local marker = Instance.new("Part")
        marker.Name = "WaypointMarker"
        marker.Anchored = true
        marker.CanCollide = false
        marker.Transparency = 0.5
        marker.BrickColor = BrickColor.new("Lapis") -- Slightly different color for markers
        marker.Size = Vector3.new(1, 1, 1)
        marker.CFrame = CFrame.new(waypoint.Position)
        marker.Parent = Workspace
        table.insert(pathVisualizationParts, marker)
    end
end


-- 🔎 Check if ATM is ready (ProximityPrompt.Enabled == true)
local function IsATMReady(atm)
    local prompt = atm:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt then
        return prompt.Enabled
    end
    return false
end

-- 🔍 Find the first available ATM
local function FindNearestReadyATM()
    local nearestATM = nil
    local shortestDist = math.huge
    for _, atm in pairs(ATMFolder:GetChildren()) do
        -- Check if it's a Model or BasePart before calculating position to prevent errors
        if not (atm:IsA("Model") or atm:IsA("BasePart")) then
            continue -- Skip objects that are not Models or Parts
        end

        local pos = atm:IsA("Model") and atm:GetModelCFrame().Position or atm.Position
        local dist = (pos - rootPart.Position).Magnitude
        -- print("[ATM] =>", atm:GetFullName(), " | Distance =", math.floor(dist), "| Ready:", IsATMReady(atm)) -- Debugging line
        
        if IsATMReady(atm) and dist < shortestDist then
            shortestDist = dist
            nearestATM = atm
        end
    end
    return nearestATM
end

-- 🧭 Move to ATM using Pathfinding and optionally TweenService or VehicleSeat
local function WalkToATM(atm)
    if not atm then return end
    moving = true
    currentATM = atm
    local targetPos = atm:IsA("Model") and atm:GetModelCFrame().Position or atm.Position

    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
        AgentCanClimb = true,
        WaypointSpacing = 4
    })

    path:ComputeAsync(rootPart.Position, targetPos)

    if path.Status == Enum.PathStatus.Success then
        local waypoints = path:GetWaypoints()
        DrawPath(waypoints) -- Draw the path visualization

        -- Check if the player is in a vehicle (VehicleSeat)
        local vehicleSeat = nil
        if humanoid.Seat and humanoid.Seat:IsA("VehicleSeat") then
            vehicleSeat = humanoid.Seat
            print("[✅ AutoFarmATM] Moving by vehicle to ATM =>", atm:GetFullName())
            -- Ensure PlatformStand is false if it was active from a previous run
            humanoid.PlatformStand = false
        else
            print("[✅ AutoFarmATM] Walking (humanoid:MoveTo()) to ATM =>", atm:GetFullName())
            -- For humanoid:MoveTo(), PlatformStand should generally be false
            humanoid.PlatformStand = false 
        end

        -- Store original WalkSpeed for humanoid if walking
        local originalWalkSpeed = humanoid.WalkSpeed
        if not vehicleSeat then
            -- Set desired WalkSpeed for walking character
            humanoid.WalkSpeed = 24 -- Default Roblox walkspeed, you can increase this up to ~32 for noticeable difference
            print(string.format("[AutoFarmATM] ตั้งค่า WalkSpeed เป็น %.1f", humanoid.WalkSpeed))
        end

        for i, waypoint in ipairs(waypoints) do
            -- During movement, check if ATM is still ready and if player is alive
            if not IsATMReady(currentATM) or not humanoid.Parent then
                print("[⚠️] ATM used or player died → Finding new ATM")
                if not vehicleSeat then
                    humanoid.WalkSpeed = originalWalkSpeed -- Revert WalkSpeed for walking
                end
                ClearPathVisualization() -- Clear path on interruption
                moving = false
                return
            end

            if vehicleSeat then
                -- Vehicle movement logic (remains unchanged)
                local vehicleModel = vehicleSeat.Parent -- Assuming VehicleSeat is directly under the vehicle model
                if not vehicleModel or not vehicleModel.PrimaryPart then
                    warn("[❌ AutoFarmATM] Vehicle model or PrimaryPart not found.")
                    moving = false
                    ClearPathVisualization()
                    return
                end
                
                local primaryPart = vehicleModel.PrimaryPart
                local lookAtPosition = waypoint.Position

                local loopStartTime = os.clock()
                local maxWaypointTime = 10 -- Max time to reach a waypoint for vehicle

                repeat
                    -- Re-check conditions inside the loop for responsiveness
                    if not IsATMReady(currentATM) or not humanoid.Parent then
                        print("[⚠️] ATM used or player died during vehicle movement → Finding new ATM")
                        vehicleSeat.Throttle = 0
                        vehicleSeat.Steer = 0
                        moving = false
                        ClearPathVisualization()
                        return
                    end

                    -- Calculate direction to waypoint
                    local direction = (lookAtPosition - primaryPart.Position).Unit
                    local dotProduct = primaryPart.CFrame.lookVector:Dot(direction)
                    
                    -- Calculate steering angle (simplified)
                    local rightVector = primaryPart.CFrame.rightVector
                    local angleDot = rightVector:Dot(direction)
                    
                    if dotProduct > 0.95 then -- Mostly facing waypoint
                        vehicleSeat.Steer = 0
                    elseif angleDot > 0 then -- Waypoint is to the right
                        vehicleSeat.Steer = 1
                    else -- Waypoint is to the left
                        vehicleSeat.Steer = -1
                    end

                    vehicleSeat.Throttle = 1 -- Full forward throttle

                    task.wait(0.1) -- Update every 0.1 seconds
                until (primaryPart.Position - waypoint.Position).Magnitude < waypoint.DistanceFromPrevious + 5 or os.clock() - loopStartTime > maxWaypointTime

                -- Stop vehicle at waypoint if needed or prepare for next
                vehicleSeat.Throttle = 0 -- Stop momentarily at waypoint to ensure proper turn
                vehicleSeat.Steer = 0
                task.wait(0.5) -- Small pause to allow vehicle to stabilize
                
            else
                -- Humanoid (walking) movement logic using humanoid:MoveTo()
                humanoid:MoveTo(waypoint.Position)
                
                -- Add timeout for MoveToFinished to prevent getting stuck
                local success, message = pcall(function()
                    humanoid.MoveToFinished:Wait(5) -- Wait up to 5 seconds for MoveTo to complete
                end)

                if not success or message == "timeout" then
                    warn("[❌ AutoFarmATM] MoveToFinished timeout or error: ", message)
                    humanoid:MoveTo(rootPart.Position) -- Stop current movement
                    humanoid.WalkSpeed = originalWalkSpeed -- Revert WalkSpeed
                    ClearPathVisualization() -- Clear path on timeout/error
                    moving = false
                    return
                end
            end -- End of if vehicleSeat / else
        end -- End of waypoint loop

        print("[✅ AutoFarmATM] Arrived at ATM:", atm:GetFullName())

        -- Revert WalkSpeed for humanoid if walking
        if not vehicleSeat then
            humanoid.WalkSpeed = originalWalkSpeed
        else
            vehicleSeat.Throttle = 0 -- Stop vehicle completely upon arrival
            vehicleSeat.Steer = 0
        end
        ClearPathVisualization() -- Clear path on successful arrival

        local prompt = currentATM:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt then
            print("[AutoFarmATM] Found ProximityPrompt on ATM, but requires button press or RemoteEvent to activate.")
            -- Example of simulating a ProximityPrompt button press (may not be reliable):
            -- UserInputService:SimulateKeyPress(Enum.KeyCode.E) -- If activation key is E
        end

    else
        warn("[❌ AutoFarmATM] Failed to compute path! Status:", path.Status.Name)
        if not vehicleSeat then
            humanoid.WalkSpeed = originalWalkSpeed -- Ensure WalkSpeed is reset if Pathfinding fails
        end
        ClearPathVisualization() -- Clear path on Pathfinding failure
    end
    moving = false
end

-- 🔁 Simple ATM farm loop: Select the first available ATM
while true do
    if not moving and humanoid.Parent then -- Check if player is alive
        local atm = FindNearestReadyATM()
        if atm then
            WalkToATM(atm)
        else
            warn("[AutoFarmATM] ❌ No ready ATM found")
        end
    elseif not humanoid.Parent then
        warn("[AutoFarmATM] Player died or Humanoid/Character missing. Stopping.")
        break -- Exit loop if player dies
    end
    task.wait(3)
end
