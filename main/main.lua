-- LocalScript: AutoFarmATM (StarterPlayerScripts)
-- กลับไปใช้แบบเดินไปยังตู้แรกที่พร้อม และเปลี่ยนเป้าหมายหากตู้ถูกใช้ไปก่อนถึง

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local PathfindingService = game:GetService("PathfindingService")
local UserInputService = game:GetService("UserInputService") -- Used for simulating key presses (may not always work)
local TweenService = game:GetService("TweenService") -- Added TweenService

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

-- Raycast parameters for ground detection
local raycastParams = RaycastParams.new()
-- Filter out the character's parts by getting all descendants of the character
raycastParams.FilterDescendantsInstances = {char}
raycastParams.FilterType = Enum.RaycastFilterType.Exclude

-- Function to get the Y-coordinate of the ground at a given X,Z position
local function getGroundY(position)
    -- Start ray slightly above the position to ensure it hits the ground
    local origin = Vector3.new(position.X, position.Y + 50, position.Z)
    local direction = Vector3.new(0, -100, 0) -- Cast downwards
    
    local raycastResult = workspace:Raycast(origin, direction, raycastParams)
    
    if raycastResult and raycastResult.Position then
        return raycastResult.Position.Y
    end
    -- Fallback: If no ground found, use the original Y.
    -- This might happen if the waypoint is off the map or in the air.
    warn("[AutoFarmATM] No ground found at position:", position)
    return position.Y 
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

        -- Check if the player is in a vehicle (VehicleSeat)
        local vehicleSeat = nil
        if humanoid.Seat and humanoid.Seat:IsA("VehicleSeat") then
            vehicleSeat = humanoid.Seat
            print("[✅ AutoFarmATM] Moving by vehicle to ATM =>", atm:GetFullName())
            -- Disable PlatformStand if it was active from a previous run or for some reason
            humanoid.PlatformStand = false
        else
            print("[✅ AutoFarmATM] Walking (TweenService) to ATM =>", atm:GetFullName())
            -- Set Humanoid to PlatformStand temporarily to manage physics during Tween
            humanoid.PlatformStand = true
        end

        for i, waypoint in ipairs(waypoints) do
            -- During movement, check if ATM is still ready and if player is alive
            if not IsATMReady(currentATM) or not humanoid.Parent then
                print("[⚠️] ATM used or player died → Finding new ATM")
                if not vehicleSeat then
                    humanoid.PlatformStand = false -- Revert PlatformStand for walking
                end
                moving = false
                return
            end

            if vehicleSeat then
                -- Vehicle movement logic
                local vehicleModel = vehicleSeat.Parent -- Assuming VehicleSeat is directly under the vehicle model
                if not vehicleModel or not vehicleModel.PrimaryPart then
                    warn("[❌ AutoFarmATM] Vehicle model or PrimaryPart not found.")
                    moving = false
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
                -- Humanoid (walking) movement logic using TweenService
                local startCFrame = rootPart.CFrame
                
                -- Get the ground Y at the current waypoint's X,Z position
                local groundY = getGroundY(waypoint.Position)
                -- Adjust the waypoint's Y position to be on the ground, considering HipHeight and a small offset
                local groundOffset = 0.5 -- Small offset to float slightly above ground, adjust as needed
                local adjustedWaypointPosition = Vector3.new(waypoint.Position.X, groundY + humanoid.HipHeight + groundOffset, waypoint.Position.Z)

                -- Calculate target CFrame, including rotation to face the next Waypoint
                -- The lookAtPosition should also be adjusted to ground level for natural looking
                local lookAtPosition = adjustedWaypointPosition 
                if i + 1 <= #waypoints then
                    local nextWaypointGroundY = getGroundY(waypoints[i+1].Position)
                    lookAtPosition = Vector3.new(waypoints[i+1].Position.X, nextWaypointGroundY + humanoid.HipHeight + groundOffset, waypoints[i+1].Position.Z)
                else
                    local finalTargetGroundY = getGroundY(targetPos)
                    lookAtPosition = Vector3.new(targetPos.X, finalTargetGroundY + humanoid.HipHeight + groundOffset, targetPos.Z)
                end

                -- Create target CFrame for movement and rotation
                local targetCFrame = CFrame.new(adjustedWaypointPosition, lookAtPosition)

                -- Calculate distance for Tween duration to maintain consistent speed
                local distance = (rootPart.Position - adjustedWaypointPosition).Magnitude -- Use adjusted position for distance
                local desiredSpeed = 25 -- Adjusted speed slightly lower to reduce teleport detection, adjust as needed
                local duration = distance / desiredSpeed 
                if duration < 0.1 then duration = 0.1 end -- Set minimum duration to prevent flickering

                local tweenInfo = TweenInfo.new(
                    duration,                   -- Time to take for Tween
                    Enum.EasingStyle.Linear,    -- Easing style (Linear is constant speed)
                    Enum.EasingDirection.Out,   -- Easing direction
                    0,                          -- Number of repeats
                    false,                      -- Does not reverse
                    0                           -- Delay before start
                )

                local tween = TweenService:Create(rootPart, tweenInfo, {CFrame = targetCFrame})
                tween:Play()
                
                -- Wait for Tween to complete or be interrupted (e.g., player dies or ATM not ready)
                local tweenFinished = false
                local connection
                connection = tween.Completed:Connect(function()
                    tweenFinished = true
                    connection:Disconnect()
                end)

                -- Loop to check conditions during Tween
                local loopStartTime = os.clock()
                while not tweenFinished and os.clock() - loopStartTime < duration + 0.5 do -- Add buffer time
                    if not IsATMReady(currentATM) or not humanoid.Parent then
                        print("[⚠️] ATM used or player died during Tween → Finding new ATM")
                        tween:Cancel() -- Cancel current Tween
                        humanoid.PlatformStand = false -- Revert PlatformStand
                        moving = false
                        if connection then connection:Disconnect() end
                        return
                    end
                    task.wait(0.05) -- Check every 0.05 seconds
                end
                if not tweenFinished then -- If Tween does not complete within allotted time (might be stuck)
                    warn("[❌ AutoFarmATM] Tween to Waypoint failed to complete in time")
                    tween:Cancel()
                    humanoid.PlatformStand = false
                    moving = false
                    if connection then connection:Disconnect() end
                    return
                end
            end -- End of if vehicleSeat / else
        end -- End of waypoint loop

        print("[✅ AutoFarmATM] Arrived at ATM:", atm:GetFullName())

        -- Revert Humanoid from PlatformStand if walking
        if not vehicleSeat then
            humanoid.PlatformStand = false
        else
            vehicleSeat.Throttle = 0 -- Stop vehicle completely upon arrival
            vehicleSeat.Steer = 0
        end

        local prompt = currentATM:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt then
            print("[AutoFarmATM] Found ProximityPrompt on ATM, but requires button press or RemoteEvent to activate.")
            -- Example of simulating a ProximityPrompt button press (may not be reliable):
            -- UserInputService:SimulateKeyPress(Enum.KeyCode.E) -- If activation key is E
        end

    else
        warn("[❌ AutoFarmATM] Failed to compute path! Status:", path.Status.Name)
        if not vehicleSeat then
            humanoid.PlatformStand = false -- Ensure PlatformStand is reset if Pathfinding fails
        end
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
