-- เพิ่มความเร็ว BMX โดยใช้ BodyVelocity คงอยู่ตลอดเวลา (loop) + รองรับ AutoFarmATM + เพิ่มระบบนำทาง ATM

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:FindFirstChildOfClass("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")
if not humanoid then
    warn("❌ ไม่พบ Humanoid ของผู้เล่น")
    return
end

local ATMFolder = Workspace:WaitForChild("Map"):WaitForChild("Props"):WaitForChild("ATMs")
local currentATM = nil
local moving = false

-- ฟังก์ชันให้ออกจากรถก่อนนำทาง ATM
local function DismountIfSeated()
    if humanoid.SeatPart then
        print("[🚲] ผู้เล่นอยู่บนพาหนะ → ลงก่อนเดินหา ATM")
        humanoid.Sit = false
        task.wait(0.3)
    end
end

-- ฟังก์ชันให้นั่งกลับขึ้น BMX หลังจากคำนวณเส้นทางแล้ว
local function TryMountBackToBMX()
    for _, seat in ipairs(Workspace:GetDescendants()) do
        if seat:IsA("VehicleSeat") and seat:IsDescendantOf(Workspace:FindFirstChild("Vehicles")) and not seat.Occupant then
            if (seat.Position - rootPart.Position).Magnitude <= 15 then
                print("[🚲] กำลังนั่งกลับขึ้น BMX...")
                rootPart.CFrame = seat.CFrame + Vector3.new(0, 5, 0)
                task.wait(0.2)
                humanoid.Sit = true
                return
            end
        end
    end
end

-- เรียกใช้ตอนเริ่มเพื่อเตรียมความเร็วหากอยู่บนรถ
local function TryBoostBMX()
    local seat = nil
    for _, s in ipairs(Workspace:GetDescendants()) do
        if s:IsA("VehicleSeat") and s.Occupant == humanoid then
            seat = s
            break
        end
    end

    if not seat then
        warn("❌ ไม่พบ VehicleSeat ที่ผู้เล่นกำลังนั่งอยู่ (Occupant)")
        return
    end

    local bmx = seat:FindFirstAncestorWhichIsA("Model")
    while bmx and bmx.Parent ~= Workspace:FindFirstChild("Vehicles") do
        bmx = bmx.Parent
    end

    if not bmx or not bmx:IsA("Model") then
        warn("❌ ไม่พบโมเดล BMX ของผู้เล่นภายใต้ Vehicles")
        return
    end

    print("✅ พบ BMX ของผู้เล่น: " .. bmx.Name)

    for _, part in ipairs(bmx:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored = false
        end
    end

    local mainPart = bmx:FindFirstChild("DriverSeat") or bmx.PrimaryPart or bmx:FindFirstChildWhichIsA("BasePart")
    if not mainPart then
        warn("❌ ไม่พบชิ้นส่วนหลักเพื่อใช้เพิ่มความเร็ว")
        return
    end

    local bv = mainPart:FindFirstChild("BMXForce") or Instance.new("BodyVelocity")
    bv.Name = "BMXForce"
    bv.MaxForce = Vector3.new(1e5, 0, 1e5)
    bv.Parent = mainPart

    RunService.Heartbeat:Connect(function()
        if not mainPart or not mainPart:IsDescendantOf(Workspace) then return end
        if humanoid.SeatPart == seat then
            bv.Velocity = mainPart.CFrame.LookVector * 120
        else
            bv.Velocity = Vector3.zero
        end
    end)

    print("🚀 เพิ่มความเร็ว BMX ด้วย BodyVelocity (ต่อเนื่อง) สำเร็จ")
end

-- 🔍 ค้นหา ATM ตัวแรกที่พร้อมใช้งาน
local function IsATMReady(atm)
    local prompt = atm:FindFirstChildWhichIsA("ProximityPrompt", true)
    return prompt and prompt.Enabled or false
end

local function FindNearestReadyATM()
    local nearestATM = nil
    local shortestDist = math.huge
    for _, atm in pairs(ATMFolder:GetChildren()) do
        if not (atm:IsA("Model") or atm:IsA("BasePart")) then continue end
        local pos = atm:IsA("Model") and atm:GetModelCFrame().Position or atm.Position
        local dist = (pos - rootPart.Position).Magnitude
        if IsATMReady(atm) and dist < shortestDist then
            shortestDist = dist
            nearestATM = atm
        end
    end
    return nearestATM
end

-- 🧭 นำทางตัวละครไปยัง ATM ด้วย Pathfinding
local function NavigateToATM(atm)
    if not atm then return end
    currentATM = atm
    DismountIfSeated()
    moving = true

    local targetPos = atm:IsA("Model") and atm:GetModelCFrame().Position or atm.Position
    local path = PathfindingService:CreatePath()
    path:ComputeAsync(rootPart.Position, targetPos)

    if path.Status ~= Enum.PathStatus.Success then
        warn("[❌] ล้มเหลวในการนำทาง ATM")
        moving = false
        return
    end

    for _, waypoint in ipairs(path:GetWaypoints()) do
        humanoid:MoveTo(waypoint.Position)
        local success = humanoid.MoveToFinished:Wait()
        if not success or not IsATMReady(atm) then
            print("[⚠️] เป้าหมายไม่พร้อมหรือยกเลิกระหว่างทาง")
            moving = false
            return
        end
    end

    print("[✅] ถึงตำแหน่ง ATM แล้ว")
    TryMountBackToBMX()
    moving = false
end

-- 🔁 ลูปหลักตรวจสอบและเคลื่อนที่
TryBoostBMX()
_G.DismountIfSeated = DismountIfSeated

while true do
    if not moving and humanoid.Parent then
        local atm = FindNearestReadyATM()
        if atm then
            NavigateToATM(atm)
        else
            warn("[AutoFarmATM] ❌ ไม่พบ ATM ที่พร้อมใช้งาน")
        end
    end
    task.wait(3)
end
