-- ========================================
-- Perfect AutoFarm - Anti-Noclip Bypass
-- เคลื่อนที่ข้ามสิ่งกีดขวางด้วยการยกตัวสูง
-- ========================================

-- ตั้งค่าเริ่มต้น
_G.AutoFarm = true              -- เปิด/ปิด AutoFarm
_G.Speed = 16                    -- ความเร็ว (1-50)
_G.WaitTime = 3                  -- เวลารอที่จุด (วินาที)
_G.ShowNotifications = true      -- แสดงการแจ้งเตือน
_G.FlyHeight = 50                -- ความสูงที่จะบินข้าม (ปรับได้)
_G.SafeMode = true               -- ใช้ระบบหลีกเลี่ยง Anti-Noclip
_G.CheckObstacles = true         -- ตรวจสอบสิ่งกีดขวาง
_G.SlowApproach = true           -- เข้าใกล้เป้าหมายช้าๆ

-- ตำแหน่งเป้าหมาย
_G.Targets = {
    Vector3.new(1224.875, 255.1919708251953, -559.2366943359375),
    -- เพิ่มตำแหน่งอื่นๆ ตรงนี้
}

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

-- Player
local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local rootPart = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")

-- Variables
local currentTargetIndex = 1
local moving = false

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
-- Ray Check Functions
-- ========================================

local function checkObstaclesBetween(startPos, endPos)
    if not _G.CheckObstacles then return false end
    
    local direction = (endPos - startPos)
    local distance = direction.Magnitude
    
    if distance < 0.1 then return false end
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {char}
    raycastParams.IgnoreWater = true
    
    local result = Workspace:Raycast(startPos, direction, raycastParams)
    
    return result ~= nil
end

local function findGroundBelow(position)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {char}
    
    local result = Workspace:Raycast(
        position + Vector3.new(0, 5, 0),
        Vector3.new(0, -1000, 0),
        raycastParams
    )
    
    if result then
        return result.Position.Y
    end
    
    return position.Y - 100
end

local function findCeilingAbove(position)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {char}
    
    local result = Workspace:Raycast(
        position,
        Vector3.new(0, 1000, 0),
        raycastParams
    )
    
    if result then
        return result.Position.Y
    end
    
    return position.Y + 1000
end

-- ========================================
-- Safe Movement Functions
-- ========================================

local function safeMove(targetPos)
    if not isCharacterValid() then return false end
    
    local startPos = rootPart.Position
    local distance = (targetPos - startPos).Magnitude
    
    if distance < 3 then return true end
    
    moving = true
    
    -- ตรวจสอบว่ามีสิ่งกีดขวางหรือไม่
    local hasObstacle = checkObstaclesBetween(startPos, targetPos)
    
    if hasObstacle and _G.SafeMode then
        notify("Navigation", "Obstacle detected, flying over...")
        
        -- Phase 1: ยกตัวขึ้นสูง
        local flyHeight = _G.FlyHeight
        local maxHeight = findCeilingAbove(startPos) - 10
        flyHeight = math.min(flyHeight, maxHeight - startPos.Y)
        
        local upPosition = Vector3.new(startPos.X, startPos.Y + flyHeight, startPos.Z)
        
        -- เคลื่อนที่ขึ้นด้านบน
        local upDuration = flyHeight / (_G.Speed * 0.5) -- ขึ้นช้าลงเพื่อความปลอดภัย
        local upStartTime = tick()
        
        while tick() - upStartTime < upDuration and _G.AutoFarm do
            if not isCharacterValid() then 
                moving = false
                return false 
            end
            
            local progress = (tick() - upStartTime) / upDuration
            local currentY = startPos.Y + (flyHeight * progress)
            
            rootPart.CFrame = CFrame.new(startPos.X, currentY, startPos.Z)
            RunService.Heartbeat:Wait()
        end
        
        -- Phase 2: เคลื่อนที่ไปยังเป้าหมาย (บนอากาศ)
        local airTarget = Vector3.new(targetPos.X, upPosition.Y, targetPos.Z)
        local airDistance = (airTarget - upPosition).Magnitude
        local airDuration = airDistance / _G.Speed
        local airStartTime = tick()
        
        while tick() - airStartTime < airDuration and _G.AutoFarm do
            if not isCharacterValid() then 
                moving = false
                return false 
            end
            
            local progress = (tick() - airStartTime) / airDuration
            local currentPos = upPosition:Lerp(airTarget, progress)
            
            -- หันหน้าไปทางเป้าหมาย
            local lookDirection = (airTarget - currentPos).Unit
            if lookDirection.Magnitude > 0 then
                rootPart.CFrame = CFrame.lookAt(currentPos, currentPos + lookDirection)
            else
                rootPart.CFrame = CFrame.new(currentPos)
            end
            
            RunService.Heartbeat:Wait()
        end
        
        -- Phase 3: ลงมาที่เป้าหมาย
        local groundY = findGroundBelow(targetPos) + 3
        local finalTarget = Vector3.new(targetPos.X, math.max(groundY, targetPos.Y), targetPos.Z)
        local downDistance = math.abs(airTarget.Y - finalTarget.Y)
        local downDuration = downDistance / (_G.Speed * 0.5) -- ลงช้าๆ
        local downStartTime = tick()
        
        if _G.SlowApproach then
            -- ลงมาช้าๆ เพื่อป้องกัน Anti-Noclip
            while tick() - downStartTime < downDuration and _G.AutoFarm do
                if not isCharacterValid() then 
                    moving = false
                    return false 
                end
                
                local progress = (tick() - downStartTime) / downDuration
                local currentY = airTarget.Y - (downDistance * progress)
                
                rootPart.CFrame = CFrame.new(targetPos.X, currentY, targetPos.Z)
                RunService.Heartbeat:Wait()
            end
        else
            -- ลงเร็ว
            rootPart.CFrame = CFrame.new(finalTarget)
        end
        
    else
        -- ไม่มีสิ่งกีดขวาง - เคลื่อนที่ตรงๆ
        local duration = distance / _G.Speed
        local startTime = tick()
        
        while tick() - startTime < duration and _G.AutoFarm do
            if not isCharacterValid() then 
                moving = false
                return false 
            end
            
            local progress = (tick() - startTime) / duration
            local newPos = startPos:Lerp(targetPos, progress)
            
            local lookDirection = (targetPos - newPos).Unit
            if lookDirection.Magnitude > 0 then
                rootPart.CFrame = CFrame.lookAt(newPos, newPos + lookDirection)
            else
                rootPart.CFrame = CFrame.new(newPos)
            end
            
            RunService.Heartbeat:Wait()
        end
    end
    
    moving = false
    return true
end
