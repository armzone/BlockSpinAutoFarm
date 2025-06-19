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
local speed = 60 -- studs per second

-- 🔎 ตรวจสอบ ATM ว่าพร้อมใช้งาน
local function IsATMReady(atm)
	local prompt = atm:FindFirstChildWhichIsA("ProximityPrompt", true)
	return prompt and prompt.Enabled
end

-- 🔍 ค้นหา ATM ที่ใกล้ที่สุด
local function FindNearestReadyATM()
	local closest, dist = nil, math.huge
	for _, atm in pairs(ATMFolder:GetChildren()) do
		local pos = atm:IsA("Model") and atm:GetModelCFrame().Position or atm.Position
		local d = (rootPart.Position - pos).Magnitude
		if IsATMReady(atm) and d < dist then
			closest, dist = atm, d
		end
	end
	return closest
end

-- 🖌️ สร้างเส้นนำทาง (Neon)
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

-- 🧭 เดินด้วย CFrame ไปยัง ATM
local function WalkToATM(atm)
	if not atm then return end
	moving = true

	local targetPos = atm:IsA("Model") and atm:GetModelCFrame().Position or atm.Position
	local path = PathfindingService:CreatePath()
	path:ComputeAsync(rootPart.Position, targetPos)

	if path.Status == Enum.PathStatus.Success then
		local waypoints = path:GetWaypoints()
		DrawPath(waypoints)

		for _, wp in ipairs(waypoints) do
			local reached = false
			RunService:BindToRenderStep("MoveToATM", Enum.RenderPriority.Character.Value, function(dt)
				if not moving then return end
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
				task.wait()
			end

			RunService:UnbindFromRenderStep("MoveToATM")

			if not IsATMReady(atm) then
				print("⚠️ ATM ถูกใช้ไปแล้ว → ยกเลิก")
				break
			end
		end
	end

	moving = false
end

-- 🔁 ลูปฟาร์ม
while true do
	if not moving and humanoid.Health > 0 then
		local atm = FindNearestReadyATM()
		if atm then
			WalkToATM(atm)
		else
			warn("❌ ไม่มี ATM ที่พร้อมใช้งาน")
		end
	end
	task.wait(2)
end
