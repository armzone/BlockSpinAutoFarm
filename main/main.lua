--[[
    สคริปต์ AutoFarm ATM (แก้ไขและปรับปรุง)
    - แก้ไข Syntax Error ในฟังก์ชัน BindCharacter
    - ลูปที่ไม่จำเป็นในฟังก์ชัน WalkToATM ซึ่งส่งผลต่อประสิทธิภาพอย่างรุนแรงออกไป
    - ปรับปรุงการทำงานให้เสถียรขึ้น
    - แก้ไขปัญหา NoPath
    - [ใหม่] เพิ่มระบบ Manual Override: สคริปต์จะหยุดทำงานชั่วคราวเมื่อผู้เล่นควบคุมตัวละครเอง และจะกลับมาทำงานต่อเมื่อผู้เล่นหยุดนิ่ง
]]

--// Services
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")

--// Variables
local player = Players.LocalPlayer
local char, humanoid, rootPart
local humanoidConnection

local ATMFolder = Workspace:WaitForChild("Map"):WaitForChild("Props"):WaitForChild("ATMs")
local currentATM = nil
local moving = false

-- [ใหม่] ตัวแปรสำหรับจัดการ Manual Override
local manualOverride = false
local lastManualMoveTime = 0
local OVERRIDE_TIMEOUT = 5 -- จำนวนวินาทีที่ต้องหยุดนิ่ง ก่อนที่สคริปต์จะกลับมาทำงาน

--// Functions

-- ฟังก์ชันสำหรับผูกตัวแปรเข้ากับตัวละคร
local function BindCharacter()
    char = player.Character or player.CharacterAdded:Wait()
    humanoid = char:WaitForChild("Humanoid")
    rootPart = char:WaitForChild("HumanoidRootPart")

    if humanoidConnection then
        humanoidConnection:Disconnect()
    end

    local lastFrame = tick()
    humanoidConnection = RunService.Heartbeat:Connect(function()
        if not humanoid or not humanoid.Parent then return end
        
        local now = tick()
        local delta = now - lastFrame
        lastFrame = now

        local estimatedFPS = math.clamp(1 / delta, 30, 144)
        local speed = math.clamp(16 * (estimatedFPS / 60), 16, 26)
        humanoid.WalkSpeed = speed

        -- [ใหม่] ตรวจจับการเคลื่อนที่จากผู้เล่น (เมื่อสคริปต์ไม่ได้ทำงาน)
        if not moving and humanoid.MoveDirection.Magnitude > 0 then
            if not manualOverride then
                print("[AutoFarmATM] 🎮 ผู้เล่นควบคุมเอง, สคริปต์หยุดทำงานชั่วคราว")
            end
            manualOverride = true
            lastManualMoveTime = tick()
        end
    end)
end

-- 🔎 ตรวจสอบว่า ATM พร้อมใช้งานหรือไม่ (เช็คจาก ProximityPrompt)
local function IsATMReady(atm)
    if not atm or not atm.Parent then return false end
    local prompt = atm:FindFirstChildWhichIsA("ProximityPrompt", true)
    return prompt and prompt.Enabled
end

-- 🔍 ค้นหา ATM ที่ใกล้ที่สุดและพร้อมใช้งาน
local function FindNearestReadyATM()
    local nearestATM = nil
    local shortestDist = math.huge
    
    if not rootPart then return nil end

    for _, atm in ipairs(ATMFolder:GetChildren()) do
        if atm:IsA("BasePart") or atm:IsA("Model") then
            local pos = atm:IsA("Model") and atm:GetPivot().Position or atm.Position
            local dist = (pos - rootPart.Position).Magnitude
            
            if IsATMReady(atm) and dist < shortestDist then
                shortestDist = dist
                nearestATM = atm
            end
        end
    end

    if nearestATM then
        print("[AutoFarmATM] ✅ พบ ATM ที่พร้อมใช้งาน: " .. nearestATM:GetFullName() .. " | ระยะ: " .. math.floor(shortestDist))
    end
    return nearestATM
end

-- 🧭 เดินไปยัง ATM โดยใช้ PathfindingService
local function WalkToATM(atm)
    if not atm or not humanoid or not rootPart then return end
    
    moving = true
    currentATM = atm
    
    local targetPos = (atm:IsA("Model") and atm:GetPivot().Position or atm.Position) + Vector3.new(0, 3, 0)

    local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, AgentCanClimb = true, WaypointSpacing = 4 })
    path:ComputeAsync(rootPart.Position, targetPos)

    if path.Status == Enum.PathStatus.Success then
        print("[AutoFarmATM] 🚶 กำลังเดินไปยัง ATM =>", atm:GetFullName())
        local waypoints = path:GetWaypoints()
        
        for i, waypoint in ipairs(waypoints) do
            if not IsATMReady(currentATM) then
                print("[AutoFarmATM] ⚠️ ATM ถูกใช้ไปแล้ว, กำลังค้นหาตู้ใหม่...")
                moving = false
                return
            end

            humanoid:MoveTo(waypoint.Position)
            
            -- [ใหม่] รอให้เดินถึงจุดหมาย และเช็คว่าถูกขัดจังหวะหรือไม่
            local success = humanoid.MoveToFinished:Wait(8) -- รอสูงสุด 8 วินาทีต่อจุด
            if not success then
                print("[AutoFarmATM] 🎮 การเคลื่อนที่ถูกขัดจังหวะโดยผู้เล่น, หยุดทำงานชั่วคราว")
                manualOverride = true
                lastManualMoveTime = tick()
                moving = false
                return -- ออกจากฟังก์ชันเดินทันที
            end
        end
        print("[AutoFarmATM] ✨ ถึงที่หมายแล้ว!")
    else
        warn("[AutoFarmATM] ❌ ไม่สามารถคำนวณเส้นทางได้! สถานะ:", path.Status.Name)
    end
    
    moving = false
end

--// Event Connections

player.CharacterAdded:Connect(function(newChar)
    print("[AutoFarmATM] ⚠️ ตัวละครถูกรีเซ็ต, กำลังโหลดใหม่...")
    moving = false
    manualOverride = false -- รีเซ็ตสถานะเมื่อตัวละครตาย
    
    newChar:WaitForChild("Humanoid")
    newChar:WaitForChild("HumanoidRootPart")
    
    BindCharacter()
    task.wait(1)
end)

--// Main Loop

BindCharacter()

while task.wait(1) do
    -- [ใหม่] เช็คว่าควรจะกลับมาทำงานจาก Manual Override หรือยัง
    if manualOverride and (tick() - lastManualMoveTime > OVERRIDE_TIMEOUT) then
        print("[AutoFarmATM] 🤖 ผู้เล่นหยุดนิ่ง " .. OVERRIDE_TIMEOUT .. " วินาที, สคริปต์กลับมาทำงาน")
        manualOverride = false
    end

    if not moving and not manualOverride and humanoid and rootPart then
        local atm = FindNearestReadyATM()
        if atm then
            WalkToATM(atm)
        end
    end
end
