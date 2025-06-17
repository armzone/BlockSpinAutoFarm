-- LocalScript: AutoFarmATM (StarterPlayerScripts)
-- เวอร์ชันไม่ใช้ loop: ตรวจสอบ ERROR ด้วย event ทันที

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local PathfindingService = game:GetService("PathfindingService")

local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local humanoid = char:WaitForChild("Humanoid")
local rootPart = char:WaitForChild("HumanoidRootPart")

local ATMFolder = Workspace:WaitForChild("Map"):WaitForChild("Props"):WaitForChild("ATMs")

local currentATM = nil
local atmConnection = nil

-- 🔎 ตรวจสอบว่า ATM มีข้อความ ERROR หรือไม่
local function IsATMError(atm)
    for _, part in pairs(atm:GetDescendants()) do
        if part:IsA("TextLabel") and string.find(string.upper(part.Text), "ERROR") then
            return true
        end
    end
    return false
end

-- 🔍 ค้นหา ATM ที่ใกล้ที่สุด (ที่ไม่ Error)
local function FindNearestATM()
    local nearestATM = nil
    local shortestDist = math.huge
    for _, atm in pairs(ATMFolder:GetChildren()) do
        if IsATMError(atm) then
            print("[⛔] ข้าม ATM ที่ Error:", atm:GetFullName())
            continue
        end
        local pos = atm:IsA("Model") and atm:GetModelCFrame().Position or atm.Position
        local dist = (pos - rootPart.Position).Magnitude
        if dist < shortestDist then
            shortestDist = dist
            nearestATM = atm
        end
    end
    return nearestATM
end

-- 🧭 เดินไปยัง ATM โดยใช้ Pathfinding
local function WalkToATM(atm)
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
        print("[✅ AutoFarmATM] Path คำนวณสำเร็จ เดินไปยัง ATM...")
        for _, waypoint in ipairs(path:GetWaypoints()) do
            humanoid:MoveTo(waypoint.Position)
            humanoid.MoveToFinished:Wait()
        end
        return true
    else
        warn("[❌ AutoFarmATM] ไม่สามารถคำนวณ path ได้! สถานะ:", path.Status.Name)
        return false
    end
end

-- 📡 ติดตามการเปลี่ยนข้อความบนหน้าจอ ATM เพื่อเปลี่ยนทันทีเมื่อเจอ ERROR
local function MonitorATMError(atm)
    if atmConnection then
        atmConnection:Disconnect()
        atmConnection = nil
    end
    for _, part in pairs(atm:GetDescendants()) do
        if part:IsA("TextLabel") and part.Text then
            atmConnection = part:GetPropertyChangedSignal("Text"):Connect(function()
                if string.find(string.upper(part.Text), "ERROR") then
                    warn("[⚠️ ATM] พบ ERROR ที่", atm:GetFullName())
                    local newATM = FindNearestATM()
                    if newATM and newATM ~= atm then
                        currentATM = newATM
                        WalkToATM(currentATM)
                        MonitorATMError(currentATM)
                    end
                end
            end)
            break
        end
    end
end

-- 🚀 เริ่มฟาร์ม ATM แบบ event-driven
currentATM = FindNearestATM()
if currentATM then
    WalkToATM(currentATM)
    MonitorATMError(currentATM)
else
    warn("[AutoFarmATM] ❌ ไม่พบ ATM ที่ใกล้ที่สุด")
end
