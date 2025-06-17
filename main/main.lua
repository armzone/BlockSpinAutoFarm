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
local function FindAvailableATM()
    for index, atm in pairs(ATMFolder:GetChildren()) do
        local pos = atm:IsA("Model") and atm:GetModelCFrame().Position or atm.Position
        print("[ATM ลำดับ " .. index .. "] =>", atm:GetFullName())
        if IsATMReady(atm) then
            print("[✅] เจอ ATM ที่พร้อมใช้งาน")
            return atm
        else
            print("[⛔] ATM ยังไม่พร้อมใช้งาน")
        end
    end
    return nil
end

-- 🧭 เดินไปยัง ATM โดยใช้ Pathfinding
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
        local atm = FindAvailableATM()
        if atm then
            WalkToATM(atm)
        else
            warn("[AutoFarmATM] ❌ ไม่พบ ATM ที่พร้อมใช้งาน")
        end
    end
    task.wait(3)
end
