-- LocalScript: AutoFarmATM (StarterPlayerScripts)
-- ✅ ปรับปรุงใหม่: รองรับการตาย/รีเซ็ตตัวละคร
-- กลับไปใช้แบบเดินไปยังตู้แรกที่พร้อม และเปลี่ยนเป้าหมายหากตู้ถูกใช้ไปก่อนถึง

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local PathfindingService = game:GetService("PathfindingService")

local player = Players.LocalPlayer
local char, humanoid, rootPart

local function BindCharacter()
    char = player.Character or player.CharacterAdded:Wait()
    humanoid = char:WaitForChild("Humanoid")
    rootPart = char:WaitForChild("HumanoidRootPart")

    -- ⚙️ ปรับ WalkSpeed ตาม FPS เพื่อให้ลื่นไหล
    local heartbeat = game:GetService("RunService").Heartbeat
    local lastFrame = tick()

    heartbeat:Connect(function()
        local now = tick()
        local delta = now - lastFrame
        lastFrame = now

        -- ประมาณค่า FPS = 1 / delta
        local estimatedFPS = math.clamp(1 / delta, 30, 144)
        local speed = math.clamp(16 * (estimatedFPS / 60), 16, 26) -- คูณเพิ่มตาม FPS ปกติ
        humanoid.WalkSpeed = speed
    end)
end
BindCharacter()

-- ฟังชันเมื่อรีเซ็ต/ตาย
player.CharacterAdded:Connect(function()
    print("[⚠️] ตัวละครถูกรีเซ็ต → กำลังโหลดใหม่...")
    moving = false
    BindCharacter()
end)

local ATMFolder = Workspace:WaitForChild("Map"):WaitForChild("Props"):WaitForChild("ATMs")

local currentATM = nil
local moving = false

-- 🔎 ตรวจสอบว่า ATM พร้อมใช้งาน (ProximityPrompt.Enabled == true)
local function IsATMReady(atm)
    local prompt = atm:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt then
        return prompt.Enabled
    end
    return false
end

-- 🔍 ค้นหา ATM ตัวแรกที่พร้อมใช้งาน
local function FindNearestReadyATM()
    local nearestATM = nil
    local shortestDist = math.huge
    for index, atm in pairs(ATMFolder:GetChildren()) do
        local pos = atm:IsA("Model") and atm:GetModelCFrame().Position or atm.Position
        local dist = (pos - rootPart.Position).Magnitude
        print("[ATM ลำดับ " .. index .. "] =>", atm:GetFullName(), " | ระยะ =", math.floor(dist))
        if IsATMReady(atm) and dist < shortestDist then
            shortestDist = dist
            nearestATM = atm
        else
            print("[⛔] ATM ยังไม่พร้อมใช้งานหรือไกลกว่า")
        end
    end
    return nearestATM
end

-- 🧭 เดินไปยัง ATM โดยใช้ Pathfinding (สามารถทะลุสิ่งที่ CanCollide = false ได้)
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

    -- เคลียร์ obstacles ที่ทะลุได้
    for _, part in pairs(Workspace:GetDescendants()) do
        if part:IsA("BasePart") and not part.CanCollide then
            part.LocalTransparencyModifier = 0.9 -- debug
            part.CanQuery = false
        end
    end

    path:ComputeAsync(rootPart.Position, targetPos)
    if path.Status == Enum.PathStatus.Success then
        print("[✅ AutoFarmATM] เดินไปยัง ATM =>", atm:GetFullName())
        for _, waypoint in ipairs(path:GetWaypoints()) do
            -- ระหว่างเดิน เช็คว่า ATM ยังพร้อมอยู่หรือไม่
            if not IsATMReady(currentATM) then
                print("[⚠️] ATM ถูกใช้ไปแล้ว → หาตู้ใหม่")
                moving = false
                return
            end
            humanoid:MoveTo(waypoint.Position)
            humanoid.MoveToFinished:Wait()
        end
    else
        warn("[❌ AutoFarmATM] ไม่สามารถคำนวณ path ได้! สถานะ:", path.Status.Name)
    end
    moving = false
end

-- 🔁 ลูปฟาร์ม ATM แบบเรียบง่าย: เลือกตู้แรกที่พร้อม
while true do
    if not moving then
        local atm = FindNearestReadyATM()
        if atm then
            WalkToATM(atm)
        else
            warn("[AutoFarmATM] ❌ ไม่พบ ATM ที่พร้อมใช้งาน")
        end
    end
    task.wait(3)
end
