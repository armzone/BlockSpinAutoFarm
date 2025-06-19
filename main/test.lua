local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local PathfindingService = game:GetService("PathfindingService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local rootPart = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")

local ATMFolder = Workspace:WaitForChild("Map"):WaitForChild("Props"):WaitForChild("ATMs")
local moving = false
local speed = 25 -- studs per second (ปลอดภัยสำหรับ anticheat)

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

-- วาดจุด Waypoint
local function DrawWaypoint(pos)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(0, 255, 0)
	part.Size = Vector3.new(0.3, 0.3, 0.3)
	part.Position = Vector3.new(pos.X, rootPart.Position.Y + 0.5, pos.Z)
	part.Parent = Workspace
	Debris:AddItem(part, 4)
end

-- เดินด้วย TweenService ทีละ Waypoint
local function TweenTo(pos)
	local currentPos = rootPart.Position
	local flatTarget = Vector3.new(pos.X, currentPos.Y, pos.Z)
	local distance = (flatTarget - currentPos).Magnitude
	local duration = distance / speed

	if duration < 0.1 then duration = 0.1 end

	local targetCFrame = CFrame.new(currentPos, flatTarget)
	local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
	local tween = TweenService:Create(rootPart, tweenInfo, {CFrame = CFrame.new(flatTarget, flatTarget + targetCFrame.LookVector)})

	tween:Play()
	tween.Completed:Wait()
end

-- เดินไปยัง ATM
local function WalkToATM(atm)
	if not atm then return end
	moving = true

	local targetPos = atm:IsA("Model") and atm:GetModelCFrame().Position or atm.Position
	local path = PathfindingService:CreatePath()
	path:ComputeAsync(rootPart.Position, targetPos)

	if path.Status == Enum.PathStatus.Success then
		local waypoints = path:GetWaypoints()
		print(string.format("[DEBUG] เริ่มเดินไป ATM: %s (Waypoints: %d)", atm.Name, #waypoints))

		for i, wp in ipairs(waypoints) do
			if not IsATMReady(atm) then
				print("[DEBUG] ❌ ATM ถูกใช้ไประหว่างทาง → ยกเลิก")
				moving = false
				return
			end
			print(string.format("[DEBUG] → Waypoint %d (%.1f, %.1f, %.1f)", i, wp.Position.X, wp.Position.Y, wp.Position.Z))
			DrawWaypoint(wp.Position)
			TweenTo(wp.Position)
		end

		print("[✅ DEBUG] ถึง ATM แล้ว:", atm.Name)
	else
		warn("[❌ AutoFarmATM] ไม่สามารถคำนวณ Path ได้:", path.Status.Name)
	end

	moving = false
end

-- 🔁 ลูปหลัก
print("🔁 เริ่ม AutoFarmATM (TweenService แบบปลอดภัย)")
while true do
	if not moving and humanoid.Health > 0 then
		local atm = FindNearestReadyATM()
		if atm then
			WalkToATM(atm)
		end
	end
	task.wait(2.5)
end
