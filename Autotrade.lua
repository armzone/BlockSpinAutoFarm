-- ========================================
-- Perfect AutoFarm - CFrame Only Version
-- ควบคุมผ่าน _G | เรียบง่าย รวดเร็ว
-- ========================================

-- ตั้งค่าเริ่มต้น
_G.AutoFarm = true              -- เปิด/ปิด AutoFarm
_G.Speed = 16                    -- ความเร็ว (1-50)
_G.WaitTime = 3                  -- เวลารอที่จุด (วินาที)
_G.ShowNotifications = true      -- แสดงการแจ้งเตือน
_G.SmoothMovement = true         -- เคลื่อนที่แบบนุ่มนวล (false = teleport)
_G.HeightOffset = 3              -- ความสูงจากพื้น

-- ตำแหน่งเป้าหมาย
_G.Targets = {
    Vector3.new(1224.875, 255.1919708251953, -559.2366943359375),
    -- เพิ่มตำแหน่งอื่นๆ ตรงนี้
}

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

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
-- CFrame Movement
-- ========================================

local function cframeMove(targetPos)
    if not isCharacterValid() then return false end
    
    -- Add height offset
    targetPos = targetPos + Vector3.new(0, _G.HeightOffset, 0)
    
    local startPos = rootPart.Position
    local distance = (targetPos - startPos).Magnitude
    
    -- If already close enough
    if distance < 3 then return true end
    
    moving = true
    
    if _G.SmoothMovement then
        -- Smooth movement
        local duration = distance / _G.Speed
        local startTime = tick()
        
        while tick() - startTime < duration and _G.AutoFarm do
            if not isCharacterValid() then 
                moving = false
                return false 
            end
            
            local elapsed = tick() - startTime
            local progress = math.min(elapsed / duration, 1)
            
            -- Lerp position
            local newPos = startPos:Lerp(targetPos, progress)
            
            -- Create CFrame with look direction
            local lookDirection = (targetPos - newPos).Unit
            if lookDirection.Magnitude > 0 then
                rootPart.CFrame = CFrame.lookAt(newPos, newPos + lookDirection)
            else
                rootPart.CFrame = CFrame.new(newPos)
            end
            
            -- Small wait for smooth movement
            RunService.Heartbeat:Wait()
        end
    else
        -- Instant teleport
        rootPart.CFrame = CFrame.new(targetPos)
    end
    
    moving = false
    return true
end

-- ========================================
-- Main AutoFarm Function
-- ========================================

local function startAutoFarm()
    notify("AutoFarm", "Started! (CFrame Mode)")
    
    -- Stats
    local startTime = tick()
    local loops = 0
    
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
        
        -- Move to target
        local success = cframeMove(target)
        
        if success then
            loops = loops + 1
            
            -- Wait at target
            local waited = 0
            while waited < _G.WaitTime and _G.AutoFarm do
                task.wait(0.5)
                waited = waited + 0.5
            end
            
            -- Next target
            currentTargetIndex = currentTargetIndex % #_G.Targets + 1
            
            -- Show progress occasionally
            if loops % 10 == 0 and _G.ShowNotifications then
                local runtime = math.floor((tick() - startTime) / 60)
                notify("Progress", string.format("Loops: %d | Time: %d min", loops, runtime))
            end
        else
            -- Failed, wait before retry
            task.wait(2)
        end
        
        task.wait(0.1)
    end
    
    -- Show final stats
    local runtime = math.floor((tick() - startTime) / 60)
    notify("AutoFarm Stopped", string.format("Total loops: %d | Runtime: %d min", loops, runtime))
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

-- รีเซ็ตไปจุดแรก
_G.ResetToFirst = function()
    currentTargetIndex = 1
    notify("Reset", "Back to first target")
end

-- ดูสถานะ
_G.GetStatus = function()
    return {
        Enabled = _G.AutoFarm,
        Speed = _G.Speed,
        Targets = #_G.Targets,
        CurrentTarget = currentTargetIndex,
        Moving = moving,
        SmoothMovement = _G.SmoothMovement
    }
end

-- Toggle AutoFarm
_G.Toggle = function()
    _G.AutoFarm = not _G.AutoFarm
end

-- Quick Teleport to target
_G.TeleportToTarget = function(index)
    if _G.Targets[index] and isCharacterValid() then
        rootPart.CFrame = CFrame.new(_G.Targets[index] + Vector3.new(0, _G.HeightOffset, 0))
        notify("Teleport", "Teleported to target " .. index)
        currentTargetIndex = index
    end
end

-- ========================================
-- Instructions
-- ========================================

print([[
✅ Perfect AutoFarm CFrame Only - Loaded!

📝 วิธีใช้พื้นฐาน:
  _G.AutoFarm = true      -- เปิด
  _G.AutoFarm = false     -- ปิด
  _G.Toggle()             -- สลับเปิด/ปิด
  
⚙️ การตั้งค่า:
  _G.Speed = 20                -- ความเร็ว (1-50)
  _G.WaitTime = 5              -- เวลารอที่จุด (วินาที)
  _G.SmoothMovement = true     -- true = เคลื่อนที่นุ่มนวล, false = teleport
  _G.HeightOffset = 3          -- ความสูงจากพื้น
  _G.ShowNotifications = true  -- แสดงการแจ้งเตือน
  
📍 จัดการตำแหน่ง:
  _G.Targets = {Vector3.new(x,y,z), ...}  -- ตั้งตำแหน่ง
  _G.AddCurrentPosition()                  -- เพิ่มตำแหน่งปัจจุบัน
  _G.ClearTargets()                        -- ล้างตำแหน่งทั้งหมด
  _G.ResetToFirst()                        -- กลับไปจุดแรก
  
🚀 ฟังก์ชันพิเศษ:
  _G.TeleportToTarget(1)   -- Teleport ไปยัง Target ที่ระบุ
  print(_G.GetStatus())    -- ดูสถานะทั้งหมด

💡 ตัวอย่างการใช้งาน:
  -- Smooth Movement
  _G.Speed = 25
  _G.SmoothMovement = true
  _G.AutoFarm = true
  
  -- Instant Teleport
  _G.SmoothMovement = false
  _G.WaitTime = 5
  _G.AutoFarm = true
]])

-- แจ้งเตือนว่าโหลดเสร็จ
notify("CFrame AutoFarm", "Ready! Use _G.AutoFarm = true")
