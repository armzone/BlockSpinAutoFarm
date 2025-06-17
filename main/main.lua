-- AutoFarmATM with UI & Path Line (StarterPlayerScripts)
-- เริ่มต้นระบบ Auto Farm ATM พร้อมเส้นนำทางด้วย Humanoid:MoveTo()

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local PathfindingService = game:GetService("PathfindingService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
if not player then return end

local char = player.Character or player.CharacterAdded:Wait()
local humanoid = char:WaitForChild("Humanoid")
local rootPart = char:WaitForChild("HumanoidRootPart")

local ATMFolder = Workspace:WaitForChild("Map"):WaitForChild("Props"):WaitForChild("ATMs")
local moving = false
local currentATM = nil

-- UI Toggle Control
local AutoFarmEnabled = true

-- Draw path line (Debug)
local function DrawPath(waypoints)
    for _, item in pairs(Workspace:GetChildren()) do
        if item.Name == "_DebugPathLine" then item:Destroy() end
    end
    for i = 1, #waypoints - 1 do
        local part = Instance.new("Part")
        part.Name = "_DebugPathLine"
        part.Anchored = true
        part.CanCollide = false
        part.Transparency = 0.6
        part.Color = Color3.fromRGB(0, 170, 255)
        part.Size = Vector3.new(0.15, 0.15, (waypoints[i].Position - waypoints[i+1].Position).Magnitude)
        part.CFrame = CFrame.new(waypoints[i].Position, waypoints[i+1].Position) * CFrame.new(0, 0, -part.Size.Z / 2)
        part.Parent = Workspace
    end
end

local function IsATMReady(atm)
    local prompt = atm:FindFirstChildWhichIsA("ProximityPrompt", true)
    return prompt and prompt.Enabled
end

local function FindNearestReadyATM()
    local closest, minDist = nil, math.huge
    for _, atm in pairs(ATMFolder:GetChildren()) do
        if not (atm:IsA("Model") or atm:IsA("BasePart")) then continue end
        local pos = atm:IsA("Model") and atm:GetModelCFrame().Position or atm.Position
        local dist = (pos - rootPart.Position).Magnitude
        if IsATMReady(atm) and dist < minDist then
            closest, minDist = atm, dist
        end
    end
    return closest
end

local function WalkToATM(atm)
    if not atm then return end
    moving = true
    currentATM = atm
    local goalPos = atm:IsA("Model") and atm:GetModelCFrame().Position or atm.Position

    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
        AgentCanClimb = true
    })
    path:ComputeAsync(rootPart.Position, goalPos)

    if path.Status == Enum.PathStatus.Success then
        local waypoints = path:GetWaypoints()
        DrawPath(waypoints)
        for _, waypoint in ipairs(waypoints) do
            if not IsATMReady(currentATM) or not humanoid.Parent then moving = false return end
            humanoid:MoveTo(waypoint.Position)
            local finished = false
            local conn
            conn = humanoid.MoveToFinished:Connect(function()
                finished = true
            end)
            local startTime = os.clock()
            while not finished and os.clock() - startTime < 5 do
                if not IsATMReady(currentATM) then
                    humanoid:MoveTo(rootPart.Position)
                    moving = false
                    if conn then conn:Disconnect() end
                    return
                end
                task.wait(0.1)
            end
            if conn then conn:Disconnect() end
        end
        local prompt = currentATM:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt then pcall(function() fireproximityprompt(prompt) end) end
    end
    moving = false
end

-- Loop
while true do
    if AutoFarmEnabled and not moving and humanoid and humanoid.Parent then
        local atm = FindNearestReadyATM()
        if atm then WalkToATM(atm) else warn("[AutoFarmATM] ❌ ไม่มี ATM ที่พร้อมใช้งาน") end
    end
    task.wait(3)
end
