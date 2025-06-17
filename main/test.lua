-- สคริปต์ทดสอบ TrySetBMXSpeed + Tween ความเร็ว + Tween เคลื่อนไปข้างหน้า

local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local function TrySetBMXSpeed()
    print("📦 [BMX Debug] เริ่มค้นหา BMX...")

    local vehiclesFolder = Workspace:FindFirstChild("Vehicles")
    if not vehiclesFolder then
        warn("❌ ไม่พบโฟลเดอร์ Vehicles ใน Workspace")
        return
    end

    local bmxModel = vehiclesFolder:GetChildren()[5]
    if not (bmxModel and bmxModel:IsA("Model")) then
        warn("❌ ไม่พบ BMX ที่ตำแหน่ง index 5 หรือไม่ใช่ Model")
        return
    end

    print("✅ พบ BMX ชื่อ:", bmxModel.Name)

    local seat = bmxModel:FindFirstChild("DriverSeat", true)
    if seat and seat:IsA("VehicleSeat") then
        print("✅ พบ VehicleSeat:", seat.Name)
        print("🕹️ Occupant:", seat.Occupant and seat.Occupant.Name or "ไม่มี")

        local original = seat.MaxSpeed
        print("🔧 MaxSpeed เดิม:", original)

        -- ลอง tween ความเร็วขึ้นทีละน้อย (สำหรับกรณี MaxSpeed ไม่ตอบสนอง)
        local tweenInfo = TweenInfo.new(2, Enum.EasingStyle.Linear)
        local goal = { MaxSpeed = 100 }

        local success, tween = pcall(function()
            return TweenService:Create(seat, tweenInfo, goal)
        end)

        if success and tween then
            tween:Play()
            print("🚴‍♂️ Tween กำลังปรับ MaxSpeed → 100")
            tween.Completed:Wait()
            print("✅ MaxSpeed หลัง Tween:", seat.MaxSpeed)
        else
            warn("❌ ไม่สามารถสร้าง Tween สำหรับ MaxSpeed")
        end

        -- 🚀 Tween ตัว BMX ให้เคลื่อนที่ไปข้างหน้า
        local root = bmxModel.PrimaryPart or bmxModel:FindFirstChild("PrimaryPart") or seat
        if root then
            print("➡️ Tween ตัว BMX ไปข้างหน้า 50 studs")
            local moveGoal = { CFrame = root.CFrame * CFrame.new(0, 0, -50) }
            local moveTween = TweenService:Create(root, TweenInfo.new(2, Enum.EasingStyle.Linear), moveGoal)
            moveTween:Play()
        else
            warn("❌ ไม่พบ PrimaryPart สำหรับการเคลื่อนย้าย BMX")
        end

        if seat.MaxSpeed == original then
            warn("⚠️ MaxSpeed ไม่เปลี่ยน อาจมีระบบบังคับจากเซิร์ฟเวอร์")
        else
            print("🎉 MaxSpeed ปรับสำเร็จ!")
        end
    else
        warn("❌ ไม่พบ VehicleSeat ใน BMX")
    end
end

-- เรียกทันทีเมื่อโหลดสคริปต์
TrySetBMXSpeed()
