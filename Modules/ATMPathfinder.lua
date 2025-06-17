-- ModuleScript: ATMPathfinder
-- ทำหน้าที่เดินไปยัง ATM โดยใช้ PathfindingService พร้อมตรวจสอบ error

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local humanoid = char:WaitForChild("Humanoid")
local rootPart = char:WaitForChild("HumanoidRootPart")

local ATMPathfinder = {}

-- 🧭 เดินไปยัง ATM โดยใช้ Pathfinding
function ATMPathfinder:WalkToATM(atm)
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
        print("[✅ ATMPathfinder] Path คำนวณสำเร็จ กำลังเดินไปยัง ATM...")
        for _, waypoint in ipairs(path:GetWaypoints()) do
            humanoid:MoveTo(waypoint.Position)
            humanoid.MoveToFinished:Wait()
        end
        return true
    else
        warn("[❌ ATMPathfinder] ไม่สามารถคำนวณ path ได้! สถานะ: ", path.Status.Name)
        return false
    end
end

return ATMPathfinder
