-- ModuleScript: ATMNavigator
-- ทำหน้าที่ค้นหา ATM ที่ใกล้ที่สุดจากตำแหน่งผู้เล่น

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local rootPart = char:WaitForChild("HumanoidRootPart")

-- ATM Folder: Workspace.Map.Props.ATMs
local ATMFolder = Workspace:WaitForChild("Map"):WaitForChild("Props"):WaitForChild("ATMs")

local ATMNavigator = {}

-- 🔍 ค้นหา ATM ที่ใกล้ที่สุด
function ATMNavigator:FindNearestATM()
    local nearestATM = nil
    local shortestDist = math.huge
    for _, atm in pairs(ATMFolder:GetChildren()) do
        if atm:IsA("Model") or atm:IsA("Part") then
            local pos = atm:IsA("Model") and atm:GetModelCFrame().Position or atm.Position
            local dist = (pos - rootPart.Position).Magnitude
            if dist < shortestDist then
                shortestDist = dist
                nearestATM = atm
            end
        end
    end
    return nearestATM
end

return ATMNavigator
