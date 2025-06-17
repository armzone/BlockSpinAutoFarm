--[[
    สคริปต์ AutoFarm ATM (แก้ไขและปรับปรุง)
    - แก้ไข Syntax Error ในฟังก์ชัน BindCharacter
    - ลูปที่ไม่จำเป็นในฟังก์ชัน WalkToATM ซึ่งส่งผลต่อประสิทธิภาพอย่างรุนแรงออกไป
    - ปรับปรุงการทำงานให้เสถียรขึ้น
    - [แก้ไข NoPath] ปรับ AgentRadius และ AgentHeight ให้เหมาะสมกับขนาดตัวละครมาตรฐาน
    - [แก้ไข NoPath] ปรับตำแหน่งเป้าหมายให้สูงขึ้นเล็กน้อยเพื่อป้องกันการติดพื้น
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

--// Functions

-- ฟังก์ชันสำหรับผูกตัวแปรเข้ากับตัวละคร
local function BindCharacter()
    char = player.Character or player.CharacterAdded:Wait()
    humanoid = char:WaitForChild("Humanoid")
    rootPart = char:WaitForChild("HumanoidRootPart")

    -- ⚙️ ปรับ WalkSpeed ตาม FPS เพื่อให้ลื่นไหล
    if humanoidConnection then
        humanoidConnection:Disconnect()
    end

    local lastFrame = tick()
    humanoidConnection = RunService.Heartbeat:Connect(function()
        if not humanoid or not humanoid.Parent then return end
        
        local now = tick()
        local delta = now - lastFrame
        lastFrame = now

        -- คำนวณ FPS โดยประมาณและจำกัดค่าระหว่าง 30 ถึง 144
        local estimatedFPS = math.clamp(1 / delta, 30, 144)
        -- ปรับความเร็วในการเดินตาม FPS (ค่าพื้นฐาน 16 ที่ 60 FPS)
        local speed = math.clamp(16 * (estimatedFPS / 60), 16, 26)
        humanoid.WalkSpeed = speed
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
    
    if not rootPart then return nil end -- ป้องกัน error หาก rootPart ยังไม่พร้อม

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
    
    -- [แก้ไข NoPath] ปรับตำแหน่งเป้าหมายให้สูงขึ้น 3 studs เพื่อให้แน่ใจว่าไม่ได้อยู่ใต้พื้น
    local targetPos = (atm:IsA("Model") and atm:GetPivot().Position or atm.Position) + Vector3.new(0, 3, 0)

    -- [แก้ไข NoPath] สร้าง Path object ด้วยขนาด Agent ที่เหมาะสมขึ้น
    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
        AgentCanClimb = true,
        WaypointSpacing = 4
    })

    -- คำนวณเส้นทาง
    path:ComputeAsync(rootPart.Position, targetPos)

    if path.Status == Enum.PathStatus.Success then
        print("[AutoFarmATM] 🚶 กำลังเดินไปยัง ATM =>", atm:GetFullName())
        local waypoints = path:GetWaypoints()
        
        for i, waypoint in ipairs(waypoints) do
            -- ระหว่างเดิน เช็คว่า ATM ยังพร้อมอยู่หรือไม่
            if not IsATMReady(currentATM) then
                print("[AutoFarmATM] ⚠️ ATM ถูกใช้ไปแล้ว, กำลังค้นหาตู้ใหม่...")
                moving = false
                return -- ออกจากฟังก์ชันเพื่อหาตู้ใหม่ในลูปหลัก
            end

            humanoid:MoveTo(waypoint.Position)
            
            -- ถ้าเป็นจุดสุดท้าย ให้รอจนกว่าจะถึงจริงๆ
            if i == #waypoints then
                humanoid.MoveToFinished:Wait(2)
            end
        end
        print("[AutoFarmATM] ✨ ถึงที่หมายแล้ว!")
    else
        warn("[AutoFarmATM] ❌ ไม่สามารถคำนวณเส้นทางได้! สถานะ:", path.Status.Name)
    end
    
    moving = false
end

--// Event Connections

-- ฟังชันเมื่อตัวละครเกิด/รีเซ็ต
player.CharacterAdded:Connect(function(newChar)
    print("[AutoFarmATM] ⚠️ ตัวละครถูกรีเซ็ต, กำลังโหลดใหม่...")
    moving = false
    -- รอให้ตัวละครโหลดสมบูรณ์
    newChar:WaitForChild("Humanoid")
    newChar:WaitForChild("HumanoidRootPart")
    
    BindCharacter()
    task.wait(1) -- รอสักครู่เพื่อให้ทุกอย่างพร้อม
    
    local atm = FindNearestReadyATM()
    if atm then
        WalkToATM(atm)
    else
        warn("[AutoFarmATM] ❌ ไม่พบ ATM ที่พร้อมใช้งานหลังจากการรีเซ็ต")
    end
end)

--// Main Loop

BindCharacter() -- เรียกครั้งแรกเมื่อสคริปต์เริ่มทำงาน

while task.wait(3) do
    if not moving and humanoid and rootPart then
        local atm = FindNearestReadyATM()
        if atm then
            WalkToATM(atm)
        end
    end
end
