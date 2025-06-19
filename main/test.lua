local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local rootPart = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")

local ATMFolder = Workspace:WaitForChild("Map"):WaitForChild("Props"):WaitForChild("ATMs")

local moving = false
local speed = 60 -- studs/second

-- 🔎 ตรวจสอบว่า ATM พร้อมใช้งาน
local function IsATMReady(atm)
	local prompt = atm:FindFirstChildWhichIsA("ProximityPrompt", true)
	local result = prompt and prompt.Enabled
	print(string.format("[DEBUG] ตรวจสอบ ATM %s → %s", atm.Name, result and "✅ พร้อม" or "❌ ไม่พร้อม"))
	return result
end

-- 🔍 ค้นหา ATM ที่ใกล้ที่สุด
local function FindNearestReadyATM()
	local nearestATM = nil
	local shortestDist = math.huge
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
	else
		print("[DEBUG] ❌ ไม่พบ ATM ที่พร้อมใช้งาน")
	end
	return nearestATM
end

-- 🖌️ วาดจุดนำทาง
local function DrawPath(waypoints)
	for _, wp in ipairs(waypoints) do
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.Material = Enum.Material.Neon
		part.Color = Color3.fromRGB(0, 255, 0)
		part.Size = Vector3.new(0.3, 0.3, 0.3)
		part.CFrame = CFrame.new(Vector3.new(wp.Position.X, rootPart.Position.Y, wp.Position.Z))
		part.Parent = Workspace
		game.Debris:AddItem(part, 3)
	end
end

-- 🧭 เคลื่อนที่ไปยัง ATM ทีละ Waypoint
local function WalkToATM(atm)
	if not atm then return end
	moving = true
	local targetPos = atm:IsA("Model") and atm:GetModelCFrame().Position or atm.Position

	local path = PathfindingService:CreatePath()
	path:ComputeAsync(rootPart.Position, targetPos)

	if path.Status == Enum.PathStatus.Success then
		local waypoints = path:GetWaypoints()
		DrawPath(waypoints)
		print(string.format("[DEBUG] เริ่มเคลื่อนที่ไปยัง ATM: %s (Waypoints = %d)", atm.Name, #waypoints))

		for i, wp in ipairs(waypoints) do
			print(string.format("[DEBUG] → Waypoint %d | ตำแหน่ง: (%.1f, %.1f, %.1f)", i, wp.Position.X, wp.Position.Y, wp.Position.Z))

			local reached = false
			RunService:BindToRenderStep("MoveToATM", Enum.RenderPriority.Character.Value, function(dt)
				local dir = (wp.Position - rootPart.Position)
				local dist = dir.Magnitude
				if dist < 1 then
					reached = true
					return
				end
				local move = dir.Unit * speed * dt
				if move.Magnitude > dist then move = dir end
				rootPart.CFrame = rootPart.CFrame + Vector3.new(move.X, 0, move.Z)
			end)

			while not reached and moving do
				if not IsATMReady(atm) or humanoid.Health <= 0 then
					print("[DEBUG] ❌ หยุดเดิน เพราะ ATM ไม่พร้อม หรือผู้เล่นตาย")
					RunService:UnbindFromRenderStep("MoveToATM")
					moving = false
					return
				end
				task.wait()
			end
			RunService:UnbindFromRenderStep("MoveToATM")
		end

		print(string.format("[DEBUG] ✅ ถึงจุดหมาย ATM: %s", atm.Name))
	else
		print("[DEBUG] ❌ Pathfinding ล้มเหลว:", path.Status.Name)
	end

	moving = false
end

-- 🔁 ลูปหลัก
while true do
	if not moving and humanoid.Health > 0 then
		local atm = FindNearestReadyATM()
		if atm then
			WalkToATM(atm)
		end
	end
	task.wait(2)
end
