local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local rootPart = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")

local ATMFolder = Workspace:WaitForChild("Map"):WaitForChild("Props"):WaitForChild("ATMs")
local moving = false
local speed = 5

-- ตรวจสอบว่า ATM พร้อมใช้งาน
local function IsATMReady(atm)
	local prompt = atm:FindFirstChildWhichIsA("ProximityPrompt", true)
	local result = prompt and prompt.Enabled
	print(string.format("[DEBUG] ตรวจสอบ ATM %s → %s", atm.Name, result and "✅ พร้อม" or "❌ ไม่พร้อม"))
	return result
end

-- ค้นหา ATM ใกล้สุด
local function FindNearestReadyATM()
	local nearestATM, shortestDist = nil, math.huge
	for _, atm in pairs(ATMFolder:GetChildren()) do
		local pos = atm:IsA("Model") and atm:GetModelCFrame().Position or atm.Position
		local dist = (rootPart.Position - pos).Magnitude
		if IsATMReady(atm) and dist < shortestDist then
			shortestDist = dist
			nearestATM = atm
		end
	end
	if nearestATM then
		print(string.format("[DEBUG] พบ ATM ที่ใกล้สุด: %s (ระยะ %.1f)", nearestATM.Name, shortestDist))
	end
	return nearestATM
end

-- สร้างเส้นนำทาง
local function DrawWaypoint(pos)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(0, 255, 0)
	p.Size = Vector3.new(0.3, 0.3, 0.3)
	p.Position = Vector3.new(pos.X, rootPart.Position.Y + 0.5, pos.Z)
	p.Parent = Workspace
	Debris:AddItem(p, 5)
end

-- เดินไปยัง Waypoint ทีละจุด (ด้วย Heartbeat)
local function MoveToPosition(targetPos)
	local done = false
	local connection

	connection = RunService.Heartbeat:Connect(function(dt)
		local currentPos = rootPart.Position
		local fixedTarget = Vector3.new(targetPos.X, currentPos.Y, targetPos.Z)
		local direction = fixedTarget - currentPos
		local distance = direction.Magnitude
		if distance < 1 then
			done = true
			connection:Disconnect()
			return
		end
		local step = math.min(speed * dt, distance)
		local moveVector = direction.Unit * step
		rootPart.CFrame = rootPart.CFrame + Vector3.new(moveVector.X, 0, moveVector.Z)
	end)

	repeat task.wait() until done
end

-- ไปยัง ATM
local function WalkToATM(atm)
	if not atm then return end
	moving = true

	local targetPos = atm:IsA("Model") and atm:GetModelCFrame().Position or atm.Position
	local path = PathfindingService:CreatePath()
	path:ComputeAsync(rootPart.Position, targetPos)

	if path.Status == Enum.PathStatus.Success then
		local waypoints = path:GetWaypoints()
		print(string.format("[DEBUG] เริ่มเคลื่อนที่ไปยัง ATM: %s (Waypoints = %d)", atm.Name, #waypoints))

		for i, wp in ipairs(waypoints) do
			print(string.format("[DEBUG] → Waypoint %d | ตำแหน่ง: (%.1f, %.1f, %.1f)", i, wp.Position.X, wp.Position.Y, wp.Position.Z))
			DrawWaypoint(wp.Position)
			if not IsATMReady(atm) then
				print("[DEBUG] ❌ ATM ถูกใช้ไประหว่างทาง → ยกเลิก")
				moving = false
				return
			end
			MoveToPosition(wp.Position)
		end

		print("[DEBUG] ✅ ถึงเป้าหมาย ATM:", atm.Name)
	else
		warn("[❌ AutoFarmATM] Pathfinding ล้มเหลว:", path.Status.Name)
	end

	moving = false
end

-- 🔁 ลูปหลัก
print("🔁 เริ่ม AutoFarmATM (CFrame + Heartbeat)")
while true do
	if not moving and humanoid.Health > 0 then
		local atm = FindNearestReadyATM()
		if atm then
			WalkToATM(atm)
		end
	end
	task.wait(2.5)
end
