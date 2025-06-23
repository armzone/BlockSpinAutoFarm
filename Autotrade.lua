-- ========================================
-- Perfect AutoFarm with Advanced Navigation
-- ควบคุมผ่าน _G | ระบบนำทางสมบูรณ์แบบ
-- ========================================

-- ตั้งค่าเริ่มต้น
_G.AutoFarm = true              -- เปิด/ปิด AutoFarm
_G.Speed = 20                    -- ความเร็ว (1-50)
_G.Mode = "Hybrid"               -- โหมด: "CFrame", "Pathfinding", "Hybrid"
_G.WaitTime = 3                  -- เวลารอที่จุด (วินาที)
_G.ShowNotifications = true      -- แสดงการแจ้งเตือน
_G.SafeMode = true              -- โหมดปลอดภัย
_G.ShowPath = true             -- แสดงเส้นทาง (Beam)
_G.GroundCheck = true           -- ตรวจสอบพื้น
_G.ObstacleAvoidance = true     -- หลีกเลี่ยงสิ่งกีดขวาง
_G.StuckDetection = true        -- ตรวจจับการติดขัด
_G.PathOptimization = true      -- ปรับปรุงเส้นทาง

-- ตำแหน่งเป้าหมาย
_G.Targets = {
    Vector3.new(1224.875, 255.1919708251953, -559.2366943359375),
    -- เพิ่มตำแหน่งอื่นๆ ตรงนี้
}

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

-- Player
local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local rootPart = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")

-- Variables
local currentTargetIndex = 1
local moving = false
local activeBeams = {}
local stuckDetection = {
    lastPosition = nil,
    stuckTime = 0,
    threshold = 5,
    minMovement = 2
}

-- ========================================
-- Utility Functions
-- ========================================

local function notify(title, text)
    if _G.ShowNotifications then
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = title,
                Text = text,
                Duration = 3
            })
        end)
    end
end

local function isCharacterValid()
    return char and char.Parent and rootPart and rootPart.Parent and humanoid and humanoid.Health > 0
end

-- ========================================
-- Visual Functions
-- ========================================

local function clearBeams()
    for _, beam in pairs(activeBeams) do
        if beam and beam.Parent then
            beam:Destroy()
        end
    end
    activeBeams = {}
end

local function createBeam(startPos, endPos, color)
    if not _G.ShowPath then return end
    
    pcall(function()
        local att0 = Instance.new("Attachment")
        att0.Parent = Workspace.Terrain
        att0.WorldPosition = startPos
        
        local att1 = Instance.new("Attachment")
        att1.Parent = Workspace.Terrain
        att1.WorldPosition = endPos
        
        local beam = Instance.new("Beam")
        beam.Attachment0 = att0
        beam.Attachment1 = att1
        beam.Width0 = 0.5
        beam.Width1 = 0.5
        beam.Color = ColorSequence.new(color or Color3.new(0, 1, 0))
        beam.FaceCamera = true
        beam.Transparency = NumberSequence.new(0.3)
        beam.LightEmission = 0.8
        beam.Parent = att0
        
        table.insert(activeBeams, att0)
        table.insert(activeBeams, att1)
        
        Debris:AddItem(att0, 30)
        Debris:AddItem(att1, 30)
    end)
end

-- ========================================
-- Safety Functions
-- ========================================

local function findGroundPosition(position)
    if not _G.GroundCheck then return position end
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {char}
    
    local startPos = position + Vector3.new(0, 50, 0)
    local direction = Vector3.new(0, -100, 0)
    
    local success, raycastResult = pcall(function()
        return Workspace:Raycast(startPos, direction, raycastParams)
    end)
    
    if success and raycastResult then
        return raycastResult.Position + Vector3.new(0, 3, 0)
    end
    
    return position
end

local function checkObstacles(startPos, endPos)
    if not _G.ObstacleAvoidance then return true end
    
    local direction = endPos - startPos
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {char}
    
    local success, result = pcall(function()
        return Workspace:Raycast(startPos, direction, raycastParams)
    end)
    
    return not (success and result)
end

local function checkStuck()
    if not _G.StuckDetection or not moving then return false end
    
    local currentPos = rootPart.Position
    
    if stuckDetection.lastPosition then
        local movement = (currentPos - stuckDetection.lastPosition).Magnitude
        
        if movement < stuckDetection.minMovement then
            stuckDetection.stuckTime = stuckDetection.stuckTime + 1
        else
            stuckDetection.stuckTime = 0
        end
        
        if stuckDetection.stuckTime >= stuckDetection.threshold then
            -- Anti-stuck actions
            if humanoid then
                humanoid.Jump = true
                task.wait(0.5)
                
                -- Try to move in random direction
                local randomDir = Vector3.new(
                    math.random(-5, 5),
                    0,
                    math.random(-5, 5)
                )
                humanoid:MoveTo(currentPos + randomDir)
                task.wait(1)
            end
            
            stuckDetection.stuckTime = 0
            return true
        end
    end
    
    stuckDetection.lastPosition = currentPos
    return false
end

-- ========================================
-- Advanced Movement Functions
-- ========================================

local function smoothCFrameMove(targetPos)
    if not isCharacterValid() then return false end
    
    targetPos = findGroundPosition(targetPos)
    local startPos = rootPart.Position
    local distance = (targetPos - startPos).Magnitude
    
    if distance < 3 then return true end
    
    -- Check for obstacles
    if not checkObstacles(startPos, targetPos) then
        return false -- Let pathfinding handle it
    end
    
    -- Smooth movement
    local duration = distance / _G.Speed
    local startTime = tick()
    
    createBeam(startPos, targetPos, Color3.new(0, 1, 1))
    
    while tick() - startTime < duration and _G.AutoFarm do
        if not isCharacterValid() then return false end
        
        local progress = (tick() - startTime) / duration
        local newPos = startPos:Lerp(targetPos, progress)
        newPos = findGroundPosition(newPos)
        
        -- Look direction
        local lookDir = (targetPos - newPos).Unit
        rootPart.CFrame = CFrame.lookAt(newPos, newPos + lookDir)
        
        -- Check stuck
        if checkStuck() then
            notify("Navigation", "Unstuck activated!")
            return false
        end
        
        task.wait()
    end
    
    return true
end

local function pathfindingMove(targetPos)
    if not isCharacterValid() then return false end
    
    -- Create path
    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
        AgentJumpHeight = 50,
        AgentMaxSlope = 89,
        WaypointSpacing = 8,
        Costs = {
            Water = 20,
            Grass = 1,
            Sand = 2,
            Rock = 5
        }
    })
    
    -- Compute path
    local success, errorMsg = pcall(function()
        path:ComputeAsync(rootPart.Position, targetPos)
    end)
    
    if not success or path.Status ~= Enum.PathStatus.Success then
        return false
    end
    
    local waypoints = path:GetWaypoints()
    
    -- Optimize path
    if _G.PathOptimization and #waypoints > 3 then
        local optimized = {waypoints[1]}
        
        for i = 2, #waypoints - 1 do
            local prevPoint = optimized[#optimized].Position
            local nextPoint = waypoints[i + 1].Position
            
            if not checkObstacles(prevPoint, nextPoint) then
                table.insert(optimized, waypoints[i])
            end
        end
        
        table.insert(optimized, waypoints[#waypoints])
        waypoints = optimized
    end
    
    -- Draw path
    for i = 1, #waypoints - 1 do
        local color = Color3.new(0, 1, 0) -- Green
        if waypoints[i].Action == Enum.PathWaypointAction.Jump then
            color = Color3.new(1, 1, 0) -- Yellow for jumps
        end
        createBeam(waypoints[i].Position, waypoints[i + 1].Position, color)
    end
    
    -- Follow waypoints
    humanoid.WalkSpeed = _G.Speed
    
    for i, waypoint in ipairs(waypoints) do
        if not _G.AutoFarm or not isCharacterValid() then
            humanoid.WalkSpeed = 16
            return false
        end
        
        -- Handle jump waypoints
        if waypoint.Action == Enum.PathWaypointAction.Jump then
            humanoid.Jump = true
        end
        
        -- Move to waypoint
        humanoid:MoveTo(waypoint.Position)
        
        -- Wait for arrival with timeout
        local timeout = tick() + 10
        local reached = false
        
        while not reached and tick() < timeout and _G.AutoFarm do
            local distance = (rootPart.Position - waypoint.Position).Magnitude
            if distance < 5 then
                reached = true
            end
            
            -- Check stuck
            if checkStuck() then
                notify("Navigation", "Detected stuck, trying to recover...")
                break
            end
            
            task.wait(0.1)
        end
        
        if not reached then
            humanoid.WalkSpeed = 16
            return false
        end
    end
    
    humanoid.WalkSpeed = 16
    return true
end

local function moveToTarget(targetPos)
    if not targetPos or not isCharacterValid() then return false end
    
    moving = true
    local success = false
    
    -- Reset stuck detection
    stuckDetection.lastPosition = nil
    stuckDetection.stuckTime = 0
    
    -- Choose movement method based on mode
    if _G.Mode == "CFrame" then
        success = smoothCFrameMove(targetPos)
    elseif _G.Mode == "Pathfinding" then
        success = pathfindingMove(targetPos)
    else -- Hybrid
        -- Try pathfinding first
        success = pathfindingMove(targetPos)
        
        -- Fallback to CFrame if pathfinding fails
        if not success and _G.AutoFarm then
            notify("Navigation", "Pathfinding failed, using CFrame...")
            success = smoothCFrameMove(targetPos)
        end
    end
    
    moving = false
    return success
end

-- ========================================
-- Main AutoFarm Function
-- ========================================

local function startAutoFarm()
    notify("AutoFarm", "Started! Mode: " .. _G.Mode)
    
    -- Stats
    local startTime = tick()
    local successCount = 0
    local failCount = 0
    
    while _G.AutoFarm do
        -- Check character
        if not isCharacterValid() then
            notify("AutoFarm", "Waiting for character...")
            repeat task.wait(1) until isCharacterValid() or not _G.AutoFarm
            if not _G.AutoFarm then break end
        end
        
        -- Check targets
        if not _G.Targets or #_G.Targets == 0 then
            notify("AutoFarm", "No targets set!")
            _G.AutoFarm = false
            break
        end
        
        -- Get next target
        local target = _G.Targets[currentTargetIndex]
        
        -- Show target info
        if _G.ShowNotifications then
            notify("Target", string.format("%d/%d", currentTargetIndex, #_G.Targets))
        end
        
        -- Move to target
        local success = moveToTarget(target)
        
        if success then
            successCount = successCount + 1
            
            -- Wait at target
            local waitTime = _G.WaitTime or 3
            local waited = 0
            while waited < waitTime and _G.AutoFarm do
                task.wait(0.5)
                waited = waited + 0.5
            end
            
            -- Next target
            currentTargetIndex = currentTargetIndex % #_G.Targets + 1
        else
            failCount = failCount + 1
            notify("Navigation", "Failed to reach target, retrying...")
            
            -- Wait before retry
            task.wait(5)
        end
        
        -- Clear old beams
        if #activeBeams > 50 then
            clearBeams()
        end
        
        task.wait(0.1)
    end
    
    -- Show final stats
    local runtime = math.floor((tick() - startTime) / 60)
    notify("AutoFarm Stopped", string.format("Runtime: %d min | Success: %d | Fail: %d", runtime, successCount, failCount))
    
    clearBeams()
end

-- ========================================
-- Character Respawn Handler
-- ========================================

player.CharacterAdded:Connect(function(newChar)
    char = newChar
    rootPart = char:WaitForChild("HumanoidRootPart")
    humanoid = char:WaitForChild("Humanoid")
    moving = false
    
    -- Resume if was running
    if _G.AutoFarm then
        task.wait(2)
        startAutoFarm()
    end
end)

-- ========================================
-- Main Control Loop
-- ========================================

task.spawn(function()
    local wasEnabled = false
    
    while true do
        if _G.AutoFarm and not wasEnabled then
            -- Just enabled
            wasEnabled = true
            task.spawn(startAutoFarm)
        elseif not _G.AutoFarm and wasEnabled then
            -- Just disabled
            wasEnabled = false
            moving = false
            clearBeams()
        end
        
        task.wait(0.5)
    end
end)

-- ========================================
-- Helper Functions
-- ========================================

-- เพิ่มตำแหน่งปัจจุบัน
_G.AddCurrentPosition = function()
    if isCharacterValid() then
        table.insert(_G.Targets, rootPart.Position)
        notify("Target Added", "Total targets: " .. #_G.Targets)
        return true
    end
    return false
end

-- ล้างตำแหน่ง
_G.ClearTargets = function()
    _G.Targets = {}
    currentTargetIndex = 1
    notify("Targets Cleared", "All targets removed")
end

-- ดูสถานะ
_G.GetStatus = function()
    return {
        Enabled = _G.AutoFarm,
        Mode = _G.Mode,
        Speed = _G.Speed,
        Targets = #_G.Targets,
        CurrentTarget = currentTargetIndex,
        Moving = moving,
        SafeMode = _G.SafeMode,
        ShowPath = _G.ShowPath
    }
end

-- Toggle AutoFarm
_G.Toggle = function()
    _G.AutoFarm = not _G.AutoFarm
end

-- ========================================
-- Instructions
-- ========================================

print([[
✅ Perfect AutoFarm with Advanced Navigation Loaded!

📝 วิธีใช้พื้นฐาน:
  _G.AutoFarm = true      -- เปิด
  _G.AutoFarm = false     -- ปิด
  _G.Toggle()             -- สลับเปิด/ปิด
  
⚙️ การตั้งค่าหลัก:
  _G.Speed = 20           -- ความเร็ว (1-50)
  _G.Mode = "Hybrid"      -- โหมด: "CFrame", "Pathfinding", "Hybrid"
  _G.WaitTime = 5         -- เวลารอที่จุด (วินาที)
  
🛡️ การตั้งค่าความปลอดภัย:
  _G.SafeMode = true           -- โหมดปลอดภัย
  _G.GroundCheck = true        -- ตรวจสอบพื้น
  _G.ObstacleAvoidance = true  -- หลีกเลี่ยงสิ่งกีดขวาง
  _G.StuckDetection = true     -- ตรวจจับการติดขัด
  _G.PathOptimization = true   -- ปรับปรุงเส้นทาง
  
👁️ การแสดงผล:
  _G.ShowNotifications = true  -- แจ้งเตือน
  _G.ShowPath = true          -- แสดงเส้นทาง Beam
  
📍 จัดการตำแหน่ง:
  _G.Targets = {Vector3.new(x,y,z), ...}  -- ตั้งตำแหน่ง
  _G.AddCurrentPosition()                  -- เพิ่มตำแหน่งปัจจุบัน
  _G.ClearTargets()                        -- ล้างตำแหน่งทั้งหมด
  
📊 ดูสถานะ:
  print(_G.GetStatus())   -- แสดงสถานะทั้งหมด

💡 ตัวอย่างการใช้งาน:
  -- Quick Start
  _G.Mode = "Hybrid"
  _G.Speed = 25
  _G.ShowPath = true
  _G.AutoFarm = true
  
  -- Safe Mode
  _G.SafeMode = true
  _G.GroundCheck = true
  _G.StuckDetection = true
  _G.Speed = 16
  _G.AutoFarm = true
]])

-- แจ้งเตือนว่าโหลดเสร็จ
notify("AutoFarm Ready", "Use _G.AutoFarm = true to start")
