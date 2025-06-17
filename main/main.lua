-- Hybrid MoveTo + Tween Boost
-- ใช้ Humanoid:MoveTo() ปกติ แต่แอบใส่ Tween เพิ่มความเร็วให้ RootPart วิ่งล้ำเล็กน้อย เพื่อเร่งความเร็วโดยไม่โดนตรวจจับ

local Players = game:GetService("Players")
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

local function BoostedMoveTo(position)
    local moveDone = false
    humanoid:MoveTo(position)

    local conn = humanoid.MoveToFinished:Connect(function()
        moveDone = true
    end)

    local tween = TweenService:Create(rootPart, TweenInfo.new(0.5, Enum.EasingStyle.Linear), {Position = position})
    tween:Play()

    local timeout = 4
    local start = os.clock()
    while not moveDone and os.clock() - start < timeout do
        task.wait(0.05)
    end

    conn:Disconnect()
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
    if path.Status ~= Enum.PathStatus.Success then
        warn("[MoveTween] Path ล้มเหลว:", path.Status.Name)
        moving = false
        return
    end

    for _, wp in ipairs(path:GetWaypoints()) do
        if not IsATMReady(currentATM) or not humanoid.Parent then
            moving = false
            return
        end
        BoostedMoveTo(wp.Position)
    end

    print("[MoveTween] ถึง ATM แล้ว")
    local prompt = currentATM:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt then
        print("[Prompt] พร้อมใช้งาน")
    end

    moving = false
end

while true do
    if not moving and humanoid.Parent then
        local atm = FindNearestReadyATM()
        if atm then WalkToATM(atm)
        else warn("[ATM] ไม่มี ATM พร้อมใช้งาน") end
    elseif not humanoid.Parent then
        warn("[ATM] ตัวละครตาย หยุดสคริปต์")
        break
    end
    task.wait(2.5)
end
