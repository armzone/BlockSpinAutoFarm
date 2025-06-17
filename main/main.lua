-- LocalScript: AutoFarmATM (StarterPlayerScripts)
-- กลับไปใช้แบบเดินไปยังตู้แรกที่พร้อม และเปลี่ยนเป้าหมายหากตู้ถูกใช้ไปก่อนถึง

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local PathfindingService = game:GetService("PathfindingService")
local UserInputService = game:GetService("UserInputService") -- ใช้สำหรับจำลองการกดปุ่ม (อาจไม่ทำงานเสมอไป)

-- แก้ไขจาก Players:GetLocalPlayer() เป็น Players.LocalPlayer
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

-- 🧭 เดินไปยัง ATM โดยใช้ Pathfinding
local function WalkToATM(atm)
    if not atm then return end
    moving = true
    currentATM = atm
    local targetPos = atm:IsA("Model") and atm:GetModelCFrame().Position or atm.Position

    -- เก็บค่า WalkSpeed เดิมไว้
    local originalWalkSpeed = humanoid.WalkSpeed
    -- กำหนดความเร็วใหม่ที่ต้องการ (เช่น 30 หรือค่าอื่น ๆ ที่คุณต้องการ)
    humanoid.WalkSpeed = 30 
    print(string.format("[AutoFarmATM] ตั้งค่า WalkSpeed เป็น %.1f", humanoid.WalkSpeed))

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
            -- ระหว่างเดิน เช็คว่า ATM ยังพร้อมอยู่หรือไม่ และว่าผู้เล่นยังมีชีวิตอยู่หรือไม่
            if not IsATMReady(currentATM) or not humanoid.Parent then
                print("[⚠️] ATM ถูกใช้ไปแล้วหรือผู้เล่นตาย → หาตู้ใหม่")
                humanoid:MoveTo(rootPart.Position) -- หยุดการเคลื่อนที่ปัจจุบัน
                humanoid.WalkSpeed = originalWalkSpeed -- คืนค่า WalkSpeed
                moving = false
                return
            end

            humanoid:MoveTo(waypoint.Position)
            -- เพิ่ม timeout เพื่อป้องกันการติดค้าง
            local success, message = pcall(function()
                humanoid.MoveToFinished:Wait(5) -- รอสูงสุด 5 วินาที
            end)

            if not success or message == "timeout" then
                warn("[❌ AutoFarmATM] MoveToFinished timeout หรือเกิดข้อผิดพลาด: ", message)
                humanoid:MoveTo(rootPart.Position) -- หยุดการเคลื่อนที่
                humanoid.WalkSpeed = originalWalkSpeed -- คืนค่า WalkSpeed
                moving = false
                return
            end
        end

        print("[✅ AutoFarmATM] ถึง ATM แล้ว:", atm:GetFullName())
        -- !!! สำคัญ: ส่วนนี้คือที่ต้องเพิ่มโค้ดสำหรับกระตุ้น ProximityPrompt !!!
        -- ใน LocalScript คุณไม่สามารถสั่งให้ ProximityPrompt ทำงานได้โดยตรงเหมือนผู้เล่นกดปุ่ม
        -- หากต้องการ "AutoFarm" อย่างสมบูรณ์ เกมของคุณจะต้องมี RemoteEvent
        -- บนเซิร์ฟเวอร์ที่ใช้สำหรับ "InteractWithATM" ซึ่งไคลเอนต์สามารถเรียกใช้ได้
        -- ตัวอย่างเช่น: game.ReplicatedStorage.RemoteEvents.InteractWithATM:FireServer(atm)
        -- หรือผู้เล่นจะต้องกดปุ่มเองเมื่อมาถึง

        local prompt = currentATM:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt then
            print("[AutoFarmATM] พบ ProximityPrompt บน ATM แต่ต้องมีการกดปุ่มหรือ RemoteEvent เพื่อกระตุ้น")
            -- ตัวอย่างการจำลองการกดปุ่ม ProximityPrompt (อาจไม่น่าเชื่อถือเสมอไป):
            -- UserInputService:SimulateKeyPress(Enum.KeyCode.E) -- หากปุ่มกระตุ้นคือ E
        end

    else
        warn("[❌ AutoFarmATM] ไม่สามารถคำนวณ path ได้! สถานะ:", path.Status.Name)
    end
    humanoid.WalkSpeed = originalWalkSpeed -- คืนค่า WalkSpeed เสมอเมื่อจบการเคลื่อนที่
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
