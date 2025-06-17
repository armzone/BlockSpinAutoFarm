-- เพิ่มความเร็ว BMX โดยใช้ BodyVelocity คงอยู่ตลอดเวลา (loop) + รองรับ AutoFarmATM

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:FindFirstChildOfClass("Humanoid")
if not humanoid then
    warn("❌ ไม่พบ Humanoid ของผู้เล่น")
    return
end

-- ฟังก์ชันให้ออกจากรถก่อนนำทาง ATM
local function DismountIfSeated()
    if humanoid.SeatPart then
        print("[🚲] ผู้เล่นอยู่บนพาหนะ → ลงก่อนเดินหา ATM")
        humanoid.Sit = false
        task.wait(0.3)
    end
end

-- เรียกใช้ตอนเริ่มเพื่อเตรียมความเร็วหากอยู่บนรถ
local function TryBoostBMX()
    -- ค้นหา VehicleSeat ที่ผู้เล่นกำลังนั่งอยู่
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

    -- ไล่ขึ้นไปหา Model ที่เป็น BMX โดยเช็กจาก Vehicles
    local bmx = seat:FindFirstAncestorWhichIsA("Model")
    while bmx and bmx.Parent ~= Workspace:FindFirstChild("Vehicles") do
        bmx = bmx.Parent
    end

    if not bmx or not bmx:IsA("Model") then
        warn("❌ ไม่พบโมเดล BMX ของผู้เล่นภายใต้ Vehicles")
        return
    end

    print("✅ พบ BMX ของผู้เล่น: " .. bmx.Name)

    -- ปลด Anchor
    for _, part in ipairs(bmx:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored = false
        end
    end

    -- หาชิ้นส่วนหลักเพื่อใส่ BodyVelocity (ใช้ DriverSeat เป็นตัวหลัก)
    local mainPart = bmx:FindFirstChild("DriverSeat") or bmx.PrimaryPart or bmx:FindFirstChildWhichIsA("BasePart")
    if not mainPart then
        warn("❌ ไม่พบชิ้นส่วนหลักเพื่อใช้เพิ่มความเร็ว")
        return
    end

    -- สร้างหรืออัปเดต BodyVelocity ต่อเนื่องทุกเฟรม
    local bv = mainPart:FindFirstChild("BMXForce") or Instance.new("BodyVelocity")
    bv.Name = "BMXForce"
    bv.MaxForce = Vector3.new(1e5, 0, 1e5)
    bv.Parent = mainPart

    -- ใช้ RunService เพื่อปรับ Velocity ทุกเฟรม
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

-- เรียกใช้งานทั้งหมด
TryBoostBMX()

-- ให้ฟังก์ชันลงจากรถพร้อมใช้งานกับระบบ AutoFarmATM
_G.DismountIfSeated = DismountIfSeated
