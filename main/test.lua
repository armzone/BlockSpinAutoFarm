-- LocalScript: AutoFarmATM_CFrame (StarterPlayerScripts)
-- ใช้ Pathfinding + เคลื่อนที่ด้วย CFrame และ Delta Time เพื่อให้ความเร็วคงที่ทุก FPS

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local humanoid = char:WaitForChild("Humanoid")
local rootPart = char:WaitForChild("HumanoidRootPart")

local ATMFolder = Workspace:WaitForChild("Map"):WaitForChild("Props"):WaitForChild("ATMs")

local currentATM = nil
local moving = false
local speed = 80 -- studs per second

-- ตรวจสอบว่า ATM พร้อมใช้งาน
local function IsATMReady(atm)
    local prompt = atm:FindFirstChildWhichIsA("ProximityPrompt", true)
    return prompt and prompt.Enabled or false
end

-- ค้นหา ATM ที่ใกล้และพร้อมใช้งานที่สุด
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

-- เคลื่อนที่ด้วย CFrame ตามความเร็วที่คงที่ (ไม่สน FPS)
local function MoveToPositionViaCFrame(targetPosition)
    return task.spawn(function()
        local connection
        connection = RunService.Heartbeat:Connect(function(dt)
            local direction = (targetPosition - rootPart.Position)
            local distance = direction.Magnitude
            if distance < 1 then
                connection:Disconnect()
                return
            end
            local moveDelta = math.min(speed * dt, distance)
            local moveVector = direction.Unit * moveDelta
            rootPart.CFrame = CFrame.new(rootPart.Position + moveVector, targetPosition)
        end)
    end)
end

-- นำทางไปยัง ATM โดยใช้ Pathfinding + CFrame
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

    if path.Status ~= Enum.PathStatus.Success then
        warn("[❌ AutoFarmATM] Pathfinding ล้มเหลว")
        moving = false
        return
    end

    for _, waypoint in ipairs(path:GetWaypoints()) do
        if not IsATMReady(currentATM) or not humanoid.Parent then
            print("[⚠️] ATM ใช้ไปแล้ว หรือผู้เล่นตาย")
            moving = false
            return
        end
        MoveToPositionViaCFrame(waypoint.Position)
        repeat task.wait() until (rootPart.Position - waypoint.Position).Magnitude < 1
    end

    print("[✅ AutoFarmATM] ถึง ATM แล้ว")
    moving = false
end

-- ลูปหลัก
while true do
    if not moving and humanoid.Parent then
        local atm = FindNearestReadyATM()
        if atm then
            WalkToATM(atm)
        else
            warn("[AutoFarmATM] ❌ ไม่พบ ATM ที่พร้อมใช้งาน")
        end
    elseif not humanoid.Parent then
        warn("[AutoFarmATM] ผู้เล่นตายหรือ Humanoid หายไป")
        break
    end
    task.wait(2.5)
end
