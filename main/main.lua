-- LocalScript: AutoFarmATM (StarterPlayerScripts)
-- กลับไปใช้แบบเดินไปยังตู้แรกที่พร้อม และเปลี่ยนเป้าหมายหากตู้ถูกใช้ไปก่อนถึง

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local PathfindingService = game:GetService("PathfindingService")
local UserInputService = game:GetService("UserInputService") -- ใช้สำหรับจำลองการกดปุ่ม (อาจไม่ทำงานเสมอไป)
local TweenService = game:GetService("TweenService") -- เพิ่ม TweenService

-- ตรวจสอบให้แน่ใจว่า LocalPlayer โหลดแล้ว
local player = Players.LocalPlayer
if not player then
    warn("[AutoFarmATM] LocalPlayer ไม่พร้อมใช้งาน!")
    return -- หยุดสคริปต์หาก LocalPlayer ไม่พร้อม
end

-- รอให้ Character และ Humanoid โหลดสมบูรณ์
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
    for _, atm in pairs(ATMFolder:GetChildren()) do
        -- ตรวจสอบว่าเป็น Model หรือ BasePart ก่อนคำนวณตำแหน่ง เพื่อป้องกันข้อผิดพลาด
        if not (atm:IsA("Model") or atm:IsA("BasePart")) then
            continue -- ข้ามวัตถุที่ไม่ใช่ Model หรือ Part
        end

        local pos = atm:IsA("Model") and atm:GetModelCFrame().Position or atm.Position
        local dist = (pos - rootPart.Position).Magnitude
        -- print("[ATM] =>", atm:GetFullName(), " | ระยะ =", math.floor(dist), "| พร้อมใช้งาน:", IsATMReady(atm)) -- บรรทัด Debugging
        
        if IsATMReady(atm) and dist < shortestDist then
            shortestDist = dist
            nearestATM = atm
        end
    end
    return nearestATM
end

-- 🧭 เดินไปยัง ATM โดยใช้ Pathfinding และ TweenService
local function WalkToATM(atm)
    if not atm then return end
    moving = true
    currentATM = atm
    local targetPos = atm:IsA("Model") and atm:GetModelCFrame().Position or atm.Position

    -- ไม่ต้องปรับ WalkSpeed เนื่องจากเราจะใช้ TweenService ในการเคลื่อนที่โดยตรง
    -- local originalWalkSpeed = humanoid.WalkSpeed
    -- humanoid.WalkSpeed = 30
    -- print(string.format("[AutoFarmATM] ตั้งค่า WalkSpeed เป็น %.1f", humanoid.WalkSpeed))

    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
        AgentCanClimb = true,
        WaypointSpacing = 4
    })

    path:ComputeAsync(rootPart.Position, targetPos)

    if path.Status == Enum.PathStatus.Success then
        print("[✅ AutoFarmATM] เดินไปยัง ATM โดยใช้ TweenService =>", atm:GetFullName())

        -- ตั้งค่า Humanoid ให้เป็น PlatformStand ชั่วคราวเพื่อจัดการเรื่องฟิสิกส์ระหว่าง Tween
        -- สิ่งนี้จะทำให้ตัวละครไม่ถูกแรงโน้มถ่วงหรือการเคลื่อนที่ภายใน Humanoid รบกวน
        humanoid.PlatformStand = true
        
        local waypoints = path:GetWaypoints()
        for i, waypoint in ipairs(waypoints) do
            -- ระหว่างเดิน เช็คว่า ATM ยังพร้อมอยู่หรือไม่ และว่าผู้เล่นยังมีชีวิตอยู่หรือไม่
            if not IsATMReady(currentATM) or not humanoid.Parent then
                print("[⚠️] ATM ถูกใช้ไปแล้วหรือผู้เล่นตาย → หาตู้ใหม่")
                humanoid.PlatformStand = false -- คืนค่า PlatformStand
                moving = false
                return
            end

            local startCFrame = rootPart.CFrame
            
            -- คำนวณ CFrame เป้าหมาย รวมถึงการหมุนตัวให้หันไปทาง Waypoint ถัดไป
            local lookAtPosition = waypoint.Position
            if i + 1 <= #waypoints then
                -- หากไม่ใช่ Waypoint สุดท้าย ให้หันหน้าไปทาง Waypoint ถัดไป
                lookAtPosition = waypoints[i+1].Position 
            else
                -- หากเป็น Waypoint สุดท้าย ให้หันหน้าไปทางเป้าหมาย ATM สุดท้าย
                lookAtPosition = targetPos 
            end

            -- สร้าง CFrame เป้าหมายสำหรับการเคลื่อนที่และการหมุนตัว
            -- การใช้ CFrame.new(position, lookAt) จะจัดการการหมุนตัวให้หันไปทาง lookAt
            local targetCFrame = CFrame.new(waypoint.Position, lookAtPosition)

            -- คำนวณระยะทางเพื่อกำหนดระยะเวลา Tween ให้ความเร็วคงที่
            local distance = (rootPart.Position - waypoint.Position).Magnitude
            local desiredSpeed = 100 -- กำหนดความเร็ว (studs per second)
            local duration = distance / desiredSpeed 
            if duration < 0.1 then duration = 0.1 end -- กำหนดระยะเวลาขั้นต่ำเพื่อป้องกันการกระพริบ

            local tweenInfo = TweenInfo.new(
                duration,                   -- เวลาที่ใช้ในการ Tween
                Enum.EasingStyle.Linear,    -- รูปแบบการเร่ง/ลดความเร็ว (Linear คือความเร็วคงที่)
                Enum.EasingDirection.Out,   -- ทิศทางการเร่ง/ลดความเร็ว
                0,                          -- จำนวนครั้งที่ทำซ้ำ
                false,                      -- ไม่ย้อนกลับ
                0                           -- หน่วงเวลาก่อนเริ่ม
            )

            local tween = TweenService:Create(rootPart, tweenInfo, {CFrame = targetCFrame})
            tween:Play()
            
            -- รอให้ Tween จบ หรือถูกขัดจังหวะ (เช่น ผู้เล่นตาย หรือ ATM ไม่พร้อม)
            local tweenFinished = false
            local connection
            connection = tween.Completed:Connect(function()
                tweenFinished = true
                connection:Disconnect()
            end)

            -- Loop ตรวจสอบเงื่อนไขระหว่าง Tween
            local loopStartTime = os.clock()
            while not tweenFinished and os.clock() - loopStartTime < duration + 0.5 do -- เพิ่มเวลาเผื่อเล็กน้อย
                if not IsATMReady(currentATM) or not humanoid.Parent then
                    print("[⚠️] ATM ถูกใช้ไปแล้วหรือผู้เล่นตายระหว่าง Tween → หาตู้ใหม่")
                    tween:Cancel() -- ยกเลิก Tween ปัจจุบัน
                    humanoid.PlatformStand = false -- คืนค่า PlatformStand
                    moving = false
                    if connection then connection:Disconnect() end
                    return
                end
                task.wait(0.05) -- ตรวจสอบทุก 0.05 วินาที
            end
            if not tweenFinished then -- ถ้า Tween ไม่จบภายในเวลาที่กำหนด (อาจค้าง)
                warn("[❌ AutoFarmATM] Tween ถึง Waypoint ไม่สำเร็จภายในเวลาที่กำหนด")
                tween:Cancel()
                humanoid.PlatformStand = false
                moving = false
                if connection then connection:Disconnect() end
                return
            end
        end

        print("[✅ AutoFarmATM] ถึง ATM แล้ว:", atm:GetFullName())

        -- คืนค่า Humanoid จาก PlatformStand เมื่อการเคลื่อนที่เสร็จสิ้น
        humanoid.PlatformStand = false

        local prompt = currentATM:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt then
            print("[AutoFarmATM] พบ ProximityPrompt บน ATM แต่ต้องมีการกดปุ่มหรือ RemoteEvent เพื่อกระตุ้น")
            -- ตัวอย่างการจำลองการกดปุ่ม ProximityPrompt (อาจไม่น่าเชื่อถือเสมอไป):
            -- UserInputService:SimulateKeyPress(Enum.KeyCode.E) -- หากปุ่มกระตุ้นคือ E
        end

    else
        warn("[❌ AutoFarmATM] ไม่สามารถคำนวณ path ได้! สถานะ:", path.Status.Name)
        humanoid.PlatformStand = false -- ตรวจสอบให้แน่ใจว่า PlatformStand ถูกรีเซ็ตหาก Pathfinding ล้มเหลว
    end
    moving = false
end

-- 🔁 ลูปฟาร์ม ATM แบบเรียบง่าย: เลือกตู้แรกที่พร้อม
while true do
    if not moving and humanoid.Parent then -- ตรวจสอบว่าผู้เล่นยังมีชีวิตอยู่
        local atm = FindNearestReadyATM()
        if atm then
            WalkToATM(atm)
        else
            warn("[AutoFarmATM] ❌ ไม่พบ ATM ที่พร้อมใช้งาน")
        end
    elseif not humanoid.Parent then
        warn("[AutoFarmATM] ผู้เล่นเสียชีวิต หรือ Humanoid/Character หายไป หยุดการทำงาน")
        break -- ออกจากลูปเมื่อผู้เล่นตาย
    end
    task.wait(3)
end
