-- LocalScript: AutoFarmATM (StarterPlayerScripts)
-- กลับไปใช้แบบเดินไปยังตู้แรกที่พร้อม และเปลี่ยนเป้าหมายหากตู้ถูกใช้ไปก่อนถึง

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local PathfindingService = game:GetService("PathfindingService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
if not player then
    warn("[AutoFarmATM] LocalPlayer ไม่พร้อมใช้งาน!")
    return
end

local char = player.Character or player.CharacterAdded:Wait()
local humanoid = char:WaitForChild("Humanoid")
local rootPart = char:WaitForChild("HumanoidRootPart")

local currentATM = nil
local moving = false

local function IsATMReady(atm)
    local prompt = atm:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt then
        return prompt.Enabled
    end
    return false
end

local function FindNearestReadyATM()
    local nearestATM = nil
    local shortestDist = math.huge
    local taggedATMs = CollectionService:GetTagged("ATM")

    for _, atm in pairs(taggedATMs) do
        if not (atm:IsA("Model") or atm:IsA("BasePart")) then
            continue
        end

        local pos = atm:IsA("Model") and atm:GetModelCFrame().Position or atm.Position
        local dist = (pos - rootPart.Position).Magnitude

        if IsATMReady(atm) and dist < shortestDist then
            shortestDist = dist
            nearestATM = atm
        end
    end
    return nearestATM
end

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
        print("[✅ AutoFarmATM] เดินไปยัง ATM โดยใช้ TweenService =>", atm:GetFullName())

        humanoid.PlatformStand = true
        local waypoints = path:GetWaypoints()

        for i, waypoint in ipairs(waypoints) do
            if not IsATMReady(currentATM) or not humanoid.Parent then
                print("[⚠️] ATM ถูกใช้ไปแล้วหรือผู้เล่นตาย → หาตู้ใหม่")
                humanoid.PlatformStand = false
                moving = false
                return
            end

            local lookAtPosition = (i + 1 <= #waypoints) and waypoints[i+1].Position or targetPos
            local targetCFrame = CFrame.new(waypoint.Position, lookAtPosition)

            local distance = (rootPart.Position - waypoint.Position).Magnitude
            local desiredSpeed = 100
            local duration = distance / desiredSpeed 
            if duration < 0.1 then duration = 0.1 end

            local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, 0)
            local tween = TweenService:Create(rootPart, tweenInfo, {CFrame = targetCFrame})
            tween:Play()

            local tweenFinished = false
            local connection
            connection = tween.Completed:Connect(function()
                tweenFinished = true
                connection:Disconnect()
            end)

            local loopStartTime = os.clock()
            while not tweenFinished and os.clock() - loopStartTime < duration + 0.5 do
                if not IsATMReady(currentATM) or not humanoid.Parent then
                    print("[⚠️] ATM ถูกใช้ไปแล้วหรือผู้เล่นตายระหว่าง Tween → หาตู้ใหม่")
                    tween:Cancel()
                    humanoid.PlatformStand = false
                    moving = false
                    if connection then connection:Disconnect() end
                    return
                end
                task.wait(0.05)
            end

            if not tweenFinished then
                warn("[❌ AutoFarmATM] Tween ถึง Waypoint ไม่สำเร็จภายในเวลาที่กำหนด")
                tween:Cancel()
                humanoid.PlatformStand = false
                moving = false
                if connection then connection:Disconnect() end
                return
            end
        end

        print("[✅ AutoFarmATM] ถึง ATM แล้ว:", atm:GetFullName())
        humanoid.PlatformStand = false

        local prompt = currentATM:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt then
            print("[AutoFarmATM] พบ ProximityPrompt บน ATM แต่ต้องมีการกดปุ่มหรือ RemoteEvent เพื่อกระตุ้น")
        end

    else
        warn("[❌ AutoFarmATM] ไม่สามารถคำนวณ path ได้! สถานะ:", path.Status.Name)
        humanoid.PlatformStand = false
    end
    moving = false
end

while true do
    if not moving and humanoid.Parent then
        local atm = FindNearestReadyATM()
        if atm then
            WalkToATM(atm)
        else
            warn("[AutoFarmATM] ❌ ไม่พบ ATM ที่พร้อมใช้งาน")
        end
    elseif not humanoid.Parent then
        warn("[AutoFarmATM] ผู้เล่นเสียชีวิต หรือ Humanoid/Character หายไป หยุดการทำงาน")
        break
    end
    task.wait(3)
end
