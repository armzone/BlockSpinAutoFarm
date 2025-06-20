local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local rootPart = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")

-- ตัวแปรสถานะ
local moving = false
local isEnabled = true
local speed = 15
local maxRetries = 3
local retryDelay = 2

-- ตำแหน่งเป้าหมายหลายจุด (สามารถเพิ่มได้)
local targetPositions = {
    Vector3.new(1224.875, 255.1919708251953, -559.2366943359375),
    -- เพิ่มตำแหน่งอื่นๆ ได้ที่นี่
    -- Vector3.new(x, y, z),
}
local currentTargetIndex = 1

-- ฟังก์ชันตรวจสอบสถานะ Character
local function IsCharacterValid()
    return char and char.Parent and rootPart and rootPart.Parent and humanoid and humanoid.Health > 0
end

-- รีเซ็ต Character เมื่อ Respawn
local function OnCharacterAdded(newChar)
    char = newChar
    rootPart = char:WaitForChild("HumanoidRootPart")
    humanoid = char:WaitForChild("Humanoid")
    moving = false
    print("🔄 Character ใหม่โหลดแล้ว - รีเซ็ตระบบ")
end

player.CharacterAdded:Connect(OnCharacterAdded)

-- วาดเส้นด้วย Beam เพื่อแสดง Path (ปรับปรุงแล้ว)
local function DrawPathLine(fromPos, toPos, color)
    if not Workspace.Terrain then return end
    
    local att0 = Instance.new("Attachment")
    att0.Parent = Workspace.Terrain
    att0.WorldPosition = fromPos
    
    local att1 = Instance.new("Attachment")
    att1.Parent = Workspace.Terrain
    att1.WorldPosition = toPos
    
    local beam = Instance.new("Beam")
    beam.Attachment0 = att0
    beam.Attachment1 = att1
    beam.Width0 = 0.3
    beam.Width1 = 0.3
    beam.Color = ColorSequence.new(color or Color3.new(0, 1, 0))
    beam.FaceCamera = true
    beam.Transparency = NumberSequence.new(0.3)
    beam.Parent = att0
    
    -- ทำลายหลัง 20 วินาที
    Debris:AddItem(att0, 20)
    Debris:AddItem(att1, 20)
end

-- เคลื่อนที่ไปยังตำแหน่งด้วย CFrame (ปรับปรุงแล้ว)
local function MoveToPosition(targetPos, useFullY)
    if not IsCharacterValid() then return false end
    
    local done = false
    local connection
    local timeout = 30 -- หมดเวลา 30 วินาที
    local startTime = tick()
    
    connection = RunService.Heartbeat:Connect(function(dt)
        -- ตรวจสอบ timeout
        if tick() - startTime > timeout then
            warn("⏰ หมดเวลาในการเดิน - ยกเลิก")
            done = true
            connection:Disconnect()
            return
        end
        
        -- ตรวจสอบสถานะ Character
        if not IsCharacterValid() then
            done = true
            connection:Disconnect()
            return
        end
        
        local currentPos = rootPart.Position
        local fixedTarget
        
        -- ใช้ Y-axis ตาม waypoint หรือคงที่
        if useFullY then
            fixedTarget = targetPos
        else
            fixedTarget = Vector3.new(targetPos.X, currentPos.Y, targetPos.Z)
        end
        
        local direction = fixedTarget - currentPos
        local distance = direction.Magnitude
        
        if distance < 1.5 then
            done = true
            connection:Disconnect()
            return
        end
        
        local step = math.min(speed * dt, distance)
        local moveVector = direction.Unit * step
        
        -- ใช้ CFrame แบบปลอดภัย
        local success, err = pcall(function()
            if useFullY then
                rootPart.CFrame = CFrame.new(currentPos + moveVector)
            else
                rootPart.CFrame = rootPart.CFrame + Vector3.new(moveVector.X, 0, moveVector.Z)
            end
        end)
        
        if not success then
            warn("❌ ไม่สามารถเคลื่อนที่ได้:", err)
            done = true
            connection:Disconnect()
        end
    end)
    
    repeat task.wait(0.1) until done
    return IsCharacterValid()
end

-- เดินไปยังตำแหน่งที่กำหนดด้วย Pathfinding (ปรับปรุงแล้ว)
local function WalkToPosition(targetPos, retryCount)
    if not targetPos or not IsCharacterValid() then return false end
    
    retryCount = retryCount or 0
    moving = true
    
    print(string.format("[DEBUG] 🚶 เริ่มเดินไป: %s (ครั้งที่ %d)", tostring(targetPos), retryCount + 1))
    
    local success, path = pcall(function()
        return PathfindingService:CreatePath({
            AgentRadius = 2,
            AgentHeight = 5,
            AgentCanJump = true,
            AgentJumpHeight = 15,
            AgentCanClimb = true,
            WaypointSpacing = 4,
            Costs = {
                Water = 20,
                DangerousArea = math.huge
            }
        })
    end)
    
    if not success then
        warn("❌ ไม่สามารถสร้าง Path ได้:", path)
        moving = false
        return false
    end
    
    local computeSuccess, err = pcall(function()
        path:ComputeAsync(rootPart.Position, targetPos)
    end)
    
    if not computeSuccess then
        warn("❌ ไม่สามารถคำนวณ Path ได้:", err)
        moving = false
        return false
    end
    
    if path.Status == Enum.PathStatus.Success then
        local waypoints = path:GetWaypoints()
        print(string.format("[DEBUG] 🟢 พบเส้นทาง: %d waypoints", #waypoints))
        
        -- วาดเส้นทาง
        for i = 1, #waypoints - 1 do
            local color = waypoints[i].Action == Enum.PathWaypointAction.Jump and Color3.new(1, 1, 0) or Color3.new(0, 1, 0)
            DrawPathLine(waypoints[i].Position, waypoints[i + 1].Position, color)
        end
        
        -- เดินตาม waypoints
        for i, wp in ipairs(waypoints) do
            if not IsCharacterValid() or not isEnabled then
                moving = false
                return false
            end
            
            -- กระโดดถ้าจำเป็น
            if wp.Action == Enum.PathWaypointAction.Jump then
                print("🦘 กระโดด!")
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                task.wait(0.3)
            end
            
            local moveSuccess = MoveToPosition(wp.Position, true)
            if not moveSuccess then
                warn("❌ ไม่สามารถเดินไป waypoint ที่", i)
                break
            end
        end
        
        print(string.format("[DEBUG] ✅ ถึงตำแหน่ง: %s", tostring(targetPos)))
        moving = false
        return true
        
    else
        warn(string.format("[❌ AutoWalk] Pathfinding ล้มเหลว: %s", path.Status.Name))
        
        -- ลองใหม่ถ้ายังไม่ถึงจำนวนสูงสุด
        if retryCount < maxRetries then
            print(string.format("🔄 ลองใหม่ในอีก %d วินาที... (%d/%d)", retryDelay, retryCount + 1, maxRetries))
            task.wait(retryDelay)
            moving = false
            return WalkToPosition(targetPos, retryCount + 1)
        else
            warn("❌ ลองครบจำนวนแล้ว - ข้ามไปตำแหน่งถัดไป")
            moving = false
            return false
        end
    end
end

-- ระบบ AutoFarm แบบวนลูป
local function StartAutoFarm()
    print("🤖 เริ่มระบบ AutoFarm")
    
    while isEnabled do
        if not IsCharacterValid() then
            print("⏳ รอ Character โหลด...")
            task.wait(2)
            continue
        end
        
        if moving then
            task.wait(1)
            continue
        end
        
        local targetPos = targetPositions[currentTargetIndex]
        if targetPos then
            local success = WalkToPosition(targetPos)
            
            -- เปลี่ยนไปตำแหน่งถัดไป
            currentTargetIndex = currentTargetIndex + 1
            if currentTargetIndex > #targetPositions then
                currentTargetIndex = 1 -- วนกลับไปจุดแรก
            end
            
            if success then
                print("💤 พักผ่อน 3 วินาที...")
                task.wait(3)
            else
                print("💤 พักหลังล้มเหลว 5 วินาที...")
                task.wait(5)
            end
        else
            warn("❌ ไม่มีตำแหน่งเป้าหมาย")
            break
        end
        
        task.wait(1) -- ป้องกัน lag
    end
end

-- ฟังก์ชันควบคุม
local function ToggleAutoFarm()
    isEnabled = not isEnabled
    if isEnabled then
        print("✅ เปิดใช้งาน AutoFarm")
        task.spawn(StartAutoFarm)
    else
        print("⏹️ หยุด AutoFarm")
        moving = false
    end
end

-- Commands สำหรับควบคุม
game.Players.LocalPlayer.Chatted:Connect(function(message)
    local cmd = message:lower()
    if cmd == "/start" or cmd == "/เริ่ม" then
        if not isEnabled then ToggleAutoFarm() end
    elseif cmd == "/stop" or cmd == "/หยุด" then
        if isEnabled then ToggleAutoFarm() end
    elseif cmd == "/status" or cmd == "/สถานะ" then
        print(string.format("📊 สถานะ: %s | กำลังเคลื่อนที่: %s | ตำแหน่งปัจจุบัน: %d/%d", 
            isEnabled and "เปิด" or "ปิด", 
            moving and "ใช่" or "ไม่", 
            currentTargetIndex, 
            #targetPositions))
    elseif cmd == "/help" or cmd == "/ช่วยเหลือ" then
        print([[
🤖 คำสั่ง AutoFarm:
/start หรือ /เริ่ม - เริ่มระบบ
/stop หรือ /หยุด - หยุดระบบ  
/status หรือ /สถานะ - ดูสถานะ
/help หรือ /ช่วยเหลือ - ดูคำสั่ง
        ]])
    end
end)

-- เริ่มต้นระบบ
task.wait(2) -- รอโหลดฉากให้เสร็จ
print("🎮 ระบบ AutoWalk พร้อมใช้งาน!")
print("💬 พิมพ์ /help หรือ /ช่วยเหลือ เพื่อดูคำสั่ง")
print("🚀 พิมพ์ /start หรือ /เริ่ม เพื่อเริ่มต้น")

-- เริ่มอัตโนมัติ (ถ้าต้องการ)
-- ToggleAutoFarm()
