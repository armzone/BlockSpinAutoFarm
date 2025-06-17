-- LocalScript: AutoFarmATM (StarterPlayerScripts)
-- เวอร์ชันแยก ATM อย่างชัดเจน และตรวจสอบตลอดเวลาว่ามี ATM ใหม่ที่ใกล้กว่าหรือไม่

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

-- 🔎 ตรวจสอบว่า ATM มีข้อความ ERROR หรือไม่
local function IsATMError(atm)
    for _, gui in pairs(atm:GetDescendants()) do
        if gui:IsA("TextLabel") then
            local raw = string.upper(gui.Text or "")
            print("[ตรวจ ATM] =>", gui:GetFullName(), "Text =", raw)
            if string.find(raw, "ERROR") then
                return true
            end
        end
    end
    return false
end

-- 🔍 ค้นหา ATM ที่ใกล้ที่สุด (ที่ไม่ Error)
local function FindNearestATM()
    local nearestATM = nil
    local shortestDist = math.huge
    for index, atm in pairs(ATMFolder:GetChildren()) do
        local pos = atm:IsA("Model") and atm:GetModelCFrame().Position or atm.Position
        local dist = (pos - rootPart.Position).Magnitude
        print("[ATM ลำดับ " .. index .. "] =>", atm:GetFullName(), " | ระยะ =", math.floor(dist))

        if not IsATMError(atm) and dist < shortestDist then
            shortestDist = dist
            nearestATM = atm
        else
            print("[⛔] ข้าม ATM ที่ Error หรือไกลกว่า")
        end
    end
    return nearestATM
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
            -- ระหว่างเดิน ให้เช็คว่ามีตู้ใหม่ที่ใกล้กว่าไหม
            local newATM = FindNearestATM()
            if newATM and newATM ~= currentATM then
                local newPos = newATM:IsA("Model") and newATM:GetModelCFrame().Position or newATM.Position
                local distNew = (newPos - rootPart.Position).Magnitude
                local distCur = (targetPos - rootPart.Position).Magnitude
                if distNew + 2 < distCur then -- ถ้าใหม่ใกล้กว่ามาก
                    print("[🔁] เจอ ATM ใหม่ที่ใกล้กว่า → เปลี่ยนเป้าหมาย")
                    WalkToATM(newATM)
                    return
                end
            end
            humanoid:MoveTo(waypoint.Position)
            humanoid.MoveToFinished:Wait()
        end
    else
        warn("[❌ AutoFarmATM] ไม่สามารถคำนวณ path ได้! สถานะ:", path.Status.Name)
    end
    moving = false
end

-- 🔁 ลูปฟาร์ม ATM แบบตรวจสอบอย่างต่อเนื่อง
while true do
    if not moving then
        local atm = FindNearestATM()
        if atm then
            WalkToATM(atm)
        else
            warn("[AutoFarmATM] ❌ ไม่พบ ATM ที่ใกล้ที่สุด")
        end
    end
    task.wait(3)
end
