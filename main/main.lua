-- Tween Walk Hybrid (ล้มก่อน Tween เพื่อหลบระบบตรวจจับ)
-- ใช้ Humanoid:ChangeState(Enum.HumanoidStateType.Physics) ให้ตัวละครล้มก่อน แล้ว Tween RootPart

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local PathfindingService = game:GetService("PathfindingService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local humanoid = char:WaitForChild("Humanoid")
local rootPart = char:WaitForChild("HumanoidRootPart")

local currentATM = nil
local moving = false

local function IsATMReady(atm)
    local prompt = atm:FindFirstChildWhichIsA("ProximityPrompt", true)
    return prompt and prompt.Enabled
end

local function FindNearestReadyATM()
    local nearestATM = nil
    local shortestDist = math.huge
    for _, atm in pairs(CollectionService:GetTagged("ATM")) do
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

local function FallAndTween(position, speed)
    humanoid:ChangeState(Enum.HumanoidStateType.Physics) -- 🧍‍♂️ ทำให้ล้มก่อน

    local adjustedY = math.max(position.Y, Workspace.FallenPartsDestroyHeight + 5) + 3
    local goal = Vector3.new(position.X, adjustedY, position.Z)
    local distance = (rootPart.Position - goal).Magnitude
    local duration = distance / speed
    if duration < 0.2 then duration = 0.2 end

    rootPart.Anchored = true
    local tween = TweenService:Create(rootPart, TweenInfo.new(duration, Enum.EasingStyle.Linear), {Position = goal})
    tween:Play()
    tween.Completed:Wait()
    rootPart.Anchored = false

    humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) -- 🔄 กลับมาลุก
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
        print("[Tween+Fall] เดินไป ATM →", atm:GetFullName())
        for _, wp in ipairs(path:GetWaypoints()) do
            if not IsATMReady(currentATM) or not humanoid.Parent then
                moving = false
                return
            end
            FallAndTween(wp.Position, 35)
        end
        print("[Tween+Fall] ถึง ATM แล้ว")
        local prompt = currentATM:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt then
            print("[Prompt] พร้อมใช้งาน")
        end
    else
        warn("[Tween+Fall] Path ล้มเหลว:", path.Status.Name)
    end
    moving = false
end

while true do
    if not moving and humanoid.Parent then
        local atm = FindNearestReadyATM()
        if atm then WalkToATM(atm)
        else warn("[ATM] ไม่มีตู้ที่พร้อมใช้งาน") end
    elseif not humanoid.Parent then
        warn("[ATM] ตัวละครตาย หยุดสคริปต์")
        break
    end
    task.wait(2.5)
end
