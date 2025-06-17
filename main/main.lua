--[[
    สคริปต์ AutoFarm ATM (แก้ไขและปรับปรุง)
    - แก้ไข Syntax Error ในฟังก์ชัน BindCharacter
    - ลูปที่ไม่จำเป็นในฟังก์ชัน WalkToATM ซึ่งส่งผลต่อประสิทธิภาพอย่างรุนแรงออกไป
    - ปรับปรุงการทำงานให้เสถียรขึ้น
    - แก้ไขปัญหา NoPath
    - เพิ่มระบบ Manual Override
    - [ใหม่] เพิ่มตัวเลือกให้สามารถปรับ WalkSpeed เองได้
]]

--// Services
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")

--// Configuration
_G.WalkSpeedOverride = nil -- กำหนดความเร็วแบบ manual ได้ที่นี่ เช่น _G.WalkSpeedOverride = 20
local ADJUST_SPEED_BY_FPS = true -- [ใหม่] ตั้งค่านี้เป็น false หากคุณต้องการปรับ WalkSpeed เอง

--// Variables
local player = Players.LocalPlayer
local char, humanoid, rootPart
local humanoidConnection

local ATMFolder = Workspace:WaitForChild("Map"):WaitForChild("Props"):WaitForChild("ATMs")
local currentATM = nil
local moving = false

local manualOverride = false
local lastManualMoveTime = 0
local OVERRIDE_TIMEOUT = 5 

--// Functions

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
        
        -- [ใหม่] จะทำงานก็ต่อเมื่อ ADJUST_SPEED_BY_FPS เป็น true เท่านั้น
        if ADJUST_SPEED_BY_FPS then
            local now = tick()
            local delta = now - lastFrame
            lastFrame = now

            local estimatedFPS = math.clamp(1 / delta, 30, 144)
            local autoSpeed = math.clamp(16 * (estimatedFPS / 60), 16, 26)
            humanoid.WalkSpeed = _G.WalkSpeedOverride or autoSpeed
        end

        if not moving and humanoid.MoveDirection.Magnitude > 0 then
            if not manualOverride then
                print("[AutoFarmATM] 🎮 ผู้เล่นควบคุมเอง, สคริปต์หยุดทำงานชั่วคราว")
            end
            manualOverride = true
            lastManualMoveTime = tick()
        end
    end)
end

local function IsATMReady(atm)
    if not atm or not atm.Parent then return false end
    local prompt = atm:FindFirstChildWhichIsA("ProximityPrompt", true)
    return prompt and prompt.Enabled
end

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

local function WalkToATM(atm)
    if not atm or not humanoid or not rootPart then return end
    
    moving = true
    currentATM = atm
    
    local basePart = atm:FindFirstChild("Area") or atm:FindFirstChildWhichIsA("BasePart", true)
    local targetPos = basePart and basePart.Position or ((atm:IsA("Model") and atm:GetPivot().Position or atm.Position) + Vector3.new(0, 1.5, 0))

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
            
            local success = humanoid.MoveToFinished:Wait(8)
            if not success then
                print("[AutoFarmATM] 🎮 การเคลื่อนที่ถูกขัดจังหวะโดยผู้เล่น, หยุดทำงานชั่วคราว")
                manualOverride = true
                lastManualMoveTime = tick()
                moving = false
                return
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
    manualOverride = false
    
    newChar:WaitForChild("Humanoid")
    newChar:WaitForChild("HumanoidRootPart")
    
    BindCharacter()
    task.wait(1)
end)

--// Main Loop

BindCharacter()

while task.wait(1) do
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
