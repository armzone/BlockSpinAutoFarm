-- Tween โมเดล BMX ของผู้เล่นให้เคลื่อนที่ไปข้างหน้า โดยไม่ยุ่งกับ BMX ของคนอื่น

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

-- หาวัตถุที่ผู้เล่นนั่งอยู่ (เช่น VehicleSeat ภายใน BMX)
local seat = character:FindFirstChildWhichIsA("Seat", true) or character:FindFirstChildWhichIsA("VehicleSeat", true)
if not seat then
    warn("❌ ไม่พบ Seat ที่ผู้เล่นกำลังนั่งอยู่")
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

-- ตั้ง PrimaryPart หากยังไม่มี
if not bmx.PrimaryPart then
    local fallback = bmx:FindFirstChild("Chassis") or bmx:FindFirstChildWhichIsA("BasePart")
    if fallback then
        bmx.PrimaryPart = fallback
        print("🔗 ตั้ง PrimaryPart เป็น: " .. fallback.Name)
    else
        warn("❌ ไม่สามารถตั้ง PrimaryPart ได้")
        return
    end
end

-- ปลด Anchor ทุกชิ้นส่วนเพื่อให้ขยับได้จริง
for _, part in ipairs(bmx:GetDescendants()) do
    if part:IsA("BasePart") then
        part.Anchored = false
    end
end

-- สร้าง Tween ขยับไปข้างหน้า 60 studs
local startCFrame = bmx:GetPrimaryPartCFrame()
local endCFrame = startCFrame * CFrame.new(0, 0, -60)

local tweenValue = Instance.new("CFrameValue")
tweenValue.Value = startCFrame

local tween = TweenService:Create(tweenValue, TweenInfo.new(2, Enum.EasingStyle.Linear), { Value = endCFrame })

-- ทุกครั้งที่ค่าเปลี่ยน ให้อัปเดตตำแหน่งของโมเดลจริง
local conn = tweenValue:GetPropertyChangedSignal("Value"):Connect(function()
    bmx:SetPrimaryPartCFrame(tweenValue.Value)
end)

tween:Play()
tween.Completed:Connect(function()
    conn:Disconnect()
    tweenValue:Destroy()
    print("✅ Tween เสร็จสิ้นแล้ว")
end)
