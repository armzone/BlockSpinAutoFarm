--[[
    สคริปต์ AutoFarm ATM (แก้ไขและปรับปรุง)
    - แก้ไข Syntax Error ในฟังก์ชัน BindCharacter
    - ลูปที่ไม่จำเป็นในฟังก์ชัน WalkToATM ซึ่งส่งผลต่อประสิทธิภาพอย่างรุนแรงออกไป (อันนี้ไม่พบแต่ได้เพิ่มประสิทธิภาพแล้ว)
    - ปรับปรุงการทำงานให้เสถียรขึ้น
    - แก้ไขปัญหา NoPath โดยจะพยายาม MoveTo โดยตรงเสมอไม่ว่าระยะห่างเท่าไหร่
    - เพิ่มระบบ Manual Override
    - [ใหม่] เพิ่มตัวเลือกให้สามารถปรับ WalkSpeed เองได้
    - [สำคัญ] เพิ่มการโต้ตอบกับ ProximityPrompt
]]

--// Services
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager") -- จำเป็นสำหรับการจำลอง input

--// Configuration
_G.WalkSpeedOverride = nil -- กำหนดความเร็วแบบ manual ได้ที่นี่ เช่น _G.WalkSpeedOverride = 20 (ค่าเริ่มต้นคือ 16)
local ADJUST_SPEED_BY_FPS = true -- [ใหม่] ตั้งค่านี้เป็น false หากคุณต้องการปรับ WalkSpeed เอง
local INTERACT_DISTANCE = 8 -- ระยะห่างที่ถือว่าใกล้พอที่จะโต้ตอบกับ ATM
local OVERRIDE_TIMEOUT = 10 -- วินาทีที่ผู้เล่นต้องหยุดนิ่งก่อนที่ AutoFarm จะทำงานต่อ

--// Variables
local player = Players.LocalPlayer
local char, humanoid, rootPart
local humanoidConnection
local manualOverride = false
local lastManualMoveTime = tick() -- สำหรับ Manual Override
local lastPosition = Vector3.new(0,0,0)

local ATMFolder = Workspace:WaitForChild("Map"):WaitForChild("Props"):WaitForChild("ATMs")
local currentATM = nil
local moving = false

--// Debugging Helper
local function log(message)
    print("[AutoFarmATM] " .. message)
end

--// Functions

local function BindCharacter()
    char = player.Character or player.CharacterAdded:Wait()
    humanoid = char:WaitForChild("Humanoid")
    rootPart = char:WaitForChild("HumanoidRootPart")
    lastPosition = rootPart.Position -- Initialize lastPosition

    if humanoidConnection then
        humanoidConnection:Disconnect()
    end

    local lastFrame = tick()
    humanoidConnection = RunService.Heartbeat:Connect(function()
        if not humanoid or not humanoid.Parent or not rootPart or not rootPart.Parent then return end
        
        -- ตรวจจับ Manual Override
        if (rootPart.Position - lastPosition).Magnitude > 0.1 then -- ถ้ามีการเคลื่อนที่อย่างมีนัยสำคัญ
            lastManualMoveTime = tick()
            if not manualOverride then
                log("✅ ตรวจพบการเคลื่อนที่ของผู้เล่น, ปิด AutoFarm ชั่วคราว (Manual Override)")
            end
            manualOverride = true
        else
            if manualOverride and (tick() - lastManualMoveTime > OVERRIDE_TIMEOUT) then
                log("🤖 ผู้เล่นหยุดนิ่ง " .. OVERRIDE_TIMEOUT .. " วินาที, สคริปต์กลับมาทำงาน")
                manualOverride = false
            end
        end
        lastPosition = rootPart.Position

        -- [ใหม่] จะทำงานก็ต่อเมื่อ ADJUST_SPEED_BY_FPS เป็น true เท่านั้น
        if ADJUST_SPEED_BY_FPS then
            local now = tick()
            local delta = now - lastFrame
            lastFrame = now

            local estimatedFPS = math.clamp(1 / delta, 30, 144) -- ปรับช่วง FPS
            local autoSpeed = math.clamp(16 * (estimatedFPS / 60), 16, 26) -- ปรับช่วง WalkSpeed
            humanoid.WalkSpeed = _G.WalkSpeedOverride or autoSpeed
        elseif _G.WalkSpeedOverride then -- ถ้าไม่ปรับตาม FPS แต่มี override
            humanoid.WalkSpeed = _G.WalkSpeedOverride
        else -- ค่าเริ่มต้น
            humanoid.WalkSpeed = 16
        end
    end)
end

local function IsATMReady(atm)
    if not atm or not atm.Parent then return false end
    local prompt = atm:FindFirstChildWhichIsA("ProximityPrompt", true)
    return prompt and prompt.Enabled and prompt.ActionText ~= "Used" -- อาจมีข้อความ "Used" เมื่อไม่พร้อมใช้
end

local function FindNearestReadyATM()
    local nearestATM = nil
    local shortestDist = math.huge
    
    if not rootPart then return nil end

    for _, atm in ipairs(ATMFolder:GetChildren()) do
        if atm:IsA("BasePart") or atm:IsA("Model") then
            -- พยายามหาจุดที่ใกล้ที่สุดสำหรับ ATM (ใช้ ProximityPrompt.Parent.Position ก่อน)
            local pos = atm:FindFirstChildWhichIsA("ProximityPrompt", true) and atm:FindFirstChildWhichIsA("ProximityPrompt", true).Parent.Position or (atm:IsA("Model") and atm:GetPivot().Position or atm.Position)
            local dist = (pos - rootPart.Position).Magnitude
            
            if IsATMReady(atm) and dist < shortestDist then
                shortestDist = dist
                nearestATM = atm
            else
                -- ลบข้อความที่ไม่จำเป็นออก เพื่อให้แสดงเฉพาะ ATM ที่พร้อมใช้งาน
                -- print("[⛔] ATM ยังไม่พร้อมใช้งานหรือไกลกว่า")
            end
        end
    end

    if nearestATM then
        log("✅ พบ ATM ที่พร้อมใช้งาน: " .. nearestATM:GetFullName() .. " | ระยะ: " .. math.floor(shortestDist))
    else
        log("🔍 ไม่พบ ATM ที่พร้อมใช้งาน, กำลังรอ...") -- เพิ่ม log หากไม่พบ ATM เลย
    end
    return nearestATM
end

local function InteractWithATM(atm)
    local prompt = atm:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt and prompt.Enabled then
        log("🚀 กำลังโต้ตอบกับ ATM: " .. atm:GetFullName())
        
        -- เรียกใช้ ProximityPrompt โดยตรง (วิธีที่ปลอดภัยและมีประสิทธิภาพที่สุดสำหรับสคริปต์ Local)
        prompt:InputHoldEnd() -- จำลองการกดปุ่มจนจบ
        
        -- รอให้ ProximityPrompt ปิดหรือถูกใช้ไป
        local timeout = 5 -- รอนานสุด 5 วินาที
        local startTick = tick()
        repeat
            task.wait(0.1)
        until not prompt.Enabled or (tick() - startTick > timeout)

        if not prompt.Enabled then
            log("💰 โต้ตอบสำเร็จ! ATM ถูกใช้แล้ว.")
            return true
        else
            log("⚠️ การโต้ตอบกับ ATM ล้มเหลวหรือหมดเวลา.")
            return false
        end
    end
    log("❌ ATM ไม่พร้อมสำหรับการโต้ตอบ.")
    return false
end

local function WalkToATM(atm)
    if not atm or not humanoid or not rootPart then return end
    
    moving = true
    currentATM = atm
    
    -- กำหนดตำแหน่งเป้าหมายให้เป็นตำแหน่งของ ProximityPrompt.Parent ถ้ามี มิฉะนั้นใช้ตำแหน่งของ ATM
    local targetPosition = atm:FindFirstChildWhichIsA("ProximityPrompt", true) and atm:FindFirstChildWhichIsA("ProximityPrompt", true).Parent.Position or (atm:IsA("Model") and atm:GetPivot().Position or atm.Position) + Vector3.new(0, 1.5, 0)

    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
        AgentCanClimb = true,
        WaypointSpacing = 4
    })
    path:ComputeAsync(rootPart.Position, targetPosition)

    if path.Status == Enum.PathStatus.Success then
        log("🚶 กำลังเดินไปยัง ATM => " .. atm:GetFullName() .. " ด้วย Pathfinding.")
        local waypoints = path:GetWaypoints()
        
        for i, waypoint in ipairs(waypoints) do
            if not IsATMReady(currentATM) then
                log("⚠️ ATM ถูกใช้ไปแล้ว, หยุดเดินและหาตู้ใหม่.")
                moving = false
                return
            end

            humanoid:MoveTo(waypoint.Position)
            local arrived = false
            local timeout = 8 -- Max wait time for each waypoint
            local startWait = tick()
            repeat
                RunService.Heartbeat:Wait() -- รอ 1 เฟรม
                if (rootPart.Position - waypoint.Position).Magnitude < INTERACT_DISTANCE then -- ถ้าเข้าใกล้พอสำหรับ waypoint นี้
                    arrived = true
                end
            until arrived or (tick() - startWait > timeout)

            if not arrived then
                log("⚠️ การเคลื่อนที่ล้มเหลวที่ waypoint #" .. i .. ", อาจติดขัด.")
                -- ไม่มีการ return ตรงนี้ เพื่อให้ยังคงพยายามไปต่อใน waypoint ถัดไปหรือใช้ MoveTo โดยตรง
            end
        end
        log("✨ ถึงที่หมายแล้วด้วย Pathfinding!")

        -- ถึงที่หมายแล้ว ลองโต้ตอบ
        InteractWithATM(atm)
    else
        warn("[AutoFarmATM] ❌ ไม่สามารถคำนวณเส้นทางได้! สถานะ:", path.Status.Name)
        log("⚠️ Pathfinding ล้มเหลว, จะพยายาม MoveTo โดยตรงไปยัง ATM ไม่ว่าระยะทางเท่าไหร่.")
        
        moving = true -- ยังคงถือว่ากำลังเคลื่อนที่
        humanoid:MoveTo(targetPosition)
        local success = humanoid.MoveToFinished:Wait(15) -- เพิ่มเวลา Wait เนื่องจากระยะทางอาจไกล
        
        if success then
            log("✨ MoveTo โดยตรงสำเร็จ!")
            -- ตรวจสอบระยะห่างอีกครั้งเมื่อถึงที่หมาย เพื่อให้แน่ใจว่าพร้อมโต้ตอบ
            if (rootPart.Position - targetPosition).Magnitude < INTERACT_DISTANCE * 1.5 then 
                InteractWithATM(atm)
            else
                log("⚠️ ถึงเป้าหมายโดยประมาณ แต่ยังไม่ใกล้พอที่จะโต้ตอบ.") 
                -- ไม่ต้องสั่งให้หา ATM ใหม่ทันที ปล่อยให้ Main Loop ตัดสินใจใหม่
            end
        else
            log("❌ MoveTo โดยตรงล้มเหลวหรือไม่ถึงเป้าหมายภายในเวลาที่กำหนด.") 
            -- ไม่ต้องสั่งให้หา ATM ใหม่ทันที ปล่อยให้ Main Loop ตัดสินใจใหม่
        end
    end
    
    moving = false -- เมื่อฟังก์ชันนี้ทำงานเสร็จ Main Loop จะเรียก FindNearestReadyATM อีกครั้ง
end

--// Event Connections

player.CharacterAdded:Connect(function(newChar)
    log("⚠️ ตัวละครถูกรีเซ็ต, กำลังโหลดใหม่...")
    moving = false
    manualOverride = false
    lastManualMoveTime = tick() -- Reset manual override timer
    
    newChar:WaitForChild("Humanoid")
    newChar:WaitForChild("HumanoidRootPart")
    
    BindCharacter()
    task.wait(1) -- ให้เวลาโหลด
end)

--// Main Loop

BindCharacter() -- เรียกครั้งแรกเมื่อสคริปต์เริ่มต้น

while task.wait(0.5) do -- ลด delay ในการวนลูปหลัก
    if manualOverride then
        -- ถ้ามีการ override โดยผู้เล่น ให้ข้ามการทำงานหลัก
        continue 
    end

    if not moving and humanoid and rootPart then
        local atm = FindNearestReadyATM()
        if atm then
            WalkToATM(atm)
        else
            -- log("🔍 ไม่พบ ATM ที่พร้อมใช้งาน, กำลังรอ...") -- FindNearestReadyATM จะ log ให้เองแล้ว
        end
    end
end
