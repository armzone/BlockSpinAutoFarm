-- LocalScript: AutoFarmATM (StarterPlayerScripts)
-- กลับไปใช้แบบเดินไปยังตู้แรกที่พร้อม และเปลี่ยนเป้าหมายหากตู้ถูกใช้ไปก่อนถึง

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local PathfindingService = game:GetService("PathfindingService")

local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local humanoid = char:WaitForChild("Humanoid")
local rootPart = char:WaitForChild("HumanoidRootPart")

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

    -- ปรับให้ PathfindingService มองข้ามสิ่งที่ทะลุได้
    local originalCanQuery = {}
    for _, part in pairs(Workspace:GetDescendants()) do
        if part:IsA("BasePart") and not part.CanCollide then
            originalCanQuery[part] = part.CanQuery
            part.CanQuery = false
        end
    end

    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
        AgentCanClimb = true,
        WaypointSpacing = 4
    })

    path:ComputeAsync(rootPart.Position, targetPos)
    if path.Status == Enum.PathStatus.Success then
        print("[✅ AutoFarmATM] เดินไปยัง ATM =>", atm:GetFullName())
        for _, waypoint in ipairs(path:GetWaypoints()) do
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

    -- คืนค่า CanQuery เดิมให้วัตถุที่ทะลุได้
    for part, canQuery in pairs(originalCanQuery) do
        if part and part:IsDescendantOf(workspace) then
            part.CanQuery = canQuery
        end
    end

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
