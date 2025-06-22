local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local rootPart = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")

-- ตัวแปรสถานะ
local moving = false
local isEnabled = true
local speed = 15
local walkSpeed = 16 -- ความเร็วเดิน Humanoid
local maxRetries = 3
local retryDelay = 2

-- ตำแหน่งเป้าหมายหลายจุด (สามารถเพิ่มได้)
local targetPositions = {
    Vector3.new(1224.875, 255.1919708251953, -559.2366943359375),
    -- เพิ่มตำแหน่งอื่นๆ ได้ที่นี่
    -- Vector3.new(x, y, z),
}
local currentTargetIndex = 1

-- ฟังก์ชันตรวจสอบสถานะ Character
local function IsCharacterValid()
    return char and char.Parent and rootPart and rootPart.Parent and humanoid and humanoid.Health > 0
end

-- รีเซ็ต Character เมื่อ Respawn
local function OnCharacterAdded(newChar)
    char = newChar
    rootPart = char:WaitForChild("HumanoidRootPart")
    humanoid = char:WaitForChild("Humanoid")
    moving = false
    print("🔄 Character ใหม่โหลดแล้ว - รีเซ็ตระบบ")
end

player.CharacterAdded:Connect(OnCharacterAdded)

-- วาดเส้นด้วย Beam เพื่อแสดง Path (ปรับปรุงแล้ว)
local activeBeams = {}
local function ClearAllBeams()
    for _, beam in pairs(activeBeams) do
        if beam and beam.Parent then
            beam:Destroy()
        end
    end
    activeBeams = {}
end

local function DrawPathLine(fromPos, toPos, color)
    if not Workspace.Terrain then return end
    
    local att0 = Instance.new("Attachment")
    att0.Parent = Workspace.Terrain
    att0.WorldPosition = fromPos
    
    local att1 = Instance.new("Attachment")
    att1.Parent = Workspace.Terrain
    att1.WorldPosition = toPos
    
    local beam = Instance.new("Beam")
    beam.Attachment0 = att0
    beam.Attachment1 = att1
    beam.Width0 = 0.5
    beam.Width1 = 0.5
    beam.Color = ColorSequence.new(color or Color3.new(0, 1, 0))
    beam.FaceCamera = true
    beam.Transparency = NumberSequence.new(0.2)
    beam.LightEmission = 0.5
    beam.Parent = att0
    
    -- เก็บไว้ใน array เพื่อจัดการ
    table.insert(activeBeams, att0)
    table.insert(activeBeams, att1)
    
    -- ทำลายหลัง 60 วินาที (เพิ่มเวลา)
    Debris:AddItem(att0, 60)
    Debris:AddItem(att1, 60)
end

-- เคลื่อนที่ไปยังตำแหน่งด้วย CFrame (ปรับปรุงแล้ว)
local function MoveToPosition(targetPos, useFullY)
    if not IsCharacterValid() then return false end
    
    local done = false
    local connection
    local timeout = 30 -- หมดเวลา 30 วินาที
    local startTime = tick()
    
    print(string.format("[DEBUG] 🎯 เดินไป: %s", tostring(targetPos)))
    
    connection = RunService.Heartbeat:Connect(function(dt)
        -- ตรวจสอบ timeout
        if tick() - startTime > timeout then
            warn("⏰ หมดเวลาในการเดิน - ยกเลิก")
            done = true
            connection:Disconnect()
            return
        end
        
        -- ตรวจสอบสถานะ Character
        if not IsCharacterValid() then
            done = true
            connection:Disconnect()
            return
        end
        
        local currentPos = rootPart.Position
        local fixedTarget
        
        -- ใช้ Y-axis ตาม waypoint หรือคงที่
        if useFullY then
            fixedTarget = targetPos
        else
            fixedTarget = Vector3.new(targetPos.X, currentPos.Y, targetPos.Z)
        end
        
        local direction = fixedTarget - currentPos
        local distance = direction.Magnitude
        
        -- ลดระยะทางที่ต้องการให้ใกล้ขึ้น
        if distance < 3 then
            print(string.format("[DEBUG] ✅ ถึงแล้ว! ระยะ: %.2f", distance))
            done = true
            connection:Disconnect()
            return
        end
        
        local step = math.min(speed * dt, distance)
        local moveVector = direction.Unit * step
        
        -- Debug ข้อมูล
        if math.floor(tick()) % 2 == 0 and (tick() - math.floor(tick())) < 0.1 then
            print(string.format("[DEBUG] 📍 ระยะ: %.2f | ความเร็ว: %.2f", distance, step/dt))
        end
        
        -- ใช้ CFrame แบบปลอดภัย
        local success, err = pcall(function()
            if useFullY then
                rootPart.CFrame = CFrame.new(currentPos + moveVector)
            else
                rootPart.CFrame = rootPart.CFrame + Vector3.new(moveVector.X, 0, moveVector.Z)
            end
        end)
        
        if not success then
            warn("❌ ไม่สามารถเคลื่อนที่ได้:", err)
            done = true
            connection:Disconnect()
        end
    end)
    
    repeat task.wait(0.1) until done
    return IsCharacterValid()
end

-- เดินไปยังตำแหน่งที่กำหนดด้วย Pathfinding (ปรับปรุงแล้ว)
local function WalkToPosition(targetPos, retryCount)
    if not targetPos or not IsCharacterValid() then return false end
    
    retryCount = retryCount or 0
    moving = true
    
    print(string.format("[DEBUG] 🚶 เริ่มเดินไป: %s (ครั้งที่ %d)", tostring(targetPos), retryCount + 1))
    
    -- ลบเส้นเก่าก่อน
    ClearAllBeams()
    
    local success, path = pcall(function()
        return PathfindingService:CreatePath({
            AgentRadius = 2,
            AgentHeight = 5,
            AgentCanJump = true,
            AgentJumpHeight = 15,
            AgentCanClimb = true,
            WaypointSpacing = 8, -- เพิ่มระยะห่าง waypoint
            Costs = {
                Water = 20,
                DangerousArea = math.huge
            }
        })
    end)
    
    if not success then
        warn("❌ ไม่สามารถสร้าง Path ได้:", path)
        moving = false
        return false
    end
    
    local computeSuccess, err = pcall(function()
        path:ComputeAsync(rootPart.Position, targetPos)
    end)
    
    if not computeSuccess then
        warn("❌ ไม่สามารถคำนวณ Path ได้:", err)
        moving = false
        return false
    end
    
    if path.Status == Enum.PathStatus.Success then
        local waypoints = path:GetWaypoints()
        print(string.format("[DEBUG] 🟢 พบเส้นทาง: %d waypoints", #waypoints))
        
        -- วาดเส้นทางทั้งหมด
        for i = 1, #waypoints - 1 do
            local color = waypoints[i].Action == Enum.PathWaypointAction.Jump and Color3.new(1, 1, 0) or Color3.new(0, 1, 0)
            DrawPathLine(waypoints[i].Position, waypoints[i + 1].Position, color)
        end
        
        -- เดินตาม waypoints
        for i, wp in ipairs(waypoints) do
            if not IsCharacterValid() or not isEnabled then
                moving = false
                return false
            end
            
            print(string.format("[DEBUG] 📍 Waypoint %d/%d: %s", i, #waypoints, tostring(wp.Position)))
            
            -- กระโดดถ้าจำเป็น
            if wp.Action == Enum.PathWaypointAction.Jump then
                print("🦘 กระโดด!")
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                task.wait(0.5) -- รอกระโดดให้เสร็จ
            end
            
            -- ใช้ Humanoid.MoveTo แทน CFrame สำหรับการเดินที่เป็นธรรมชาติ
            local moveSuccess = false
            local attempts = 0
            
            while not moveSuccess and attempts < 3 do
                attempts = attempts + 1
                
                -- ลองใช้ Humanoid.MoveTo ก่อน
                humanoid:MoveTo(wp.Position)
                local moveStart = tick()
                
                -- รอจนกว่าจะถึง waypoint ห또ือหมดเวลา
                while IsCharacterValid() and isEnabled do
                    local currentPos = rootPart.Position
                    local distance = (wp.Position - currentPos).Magnitude
                    
                    if distance < 4 then
                        moveSuccess = true
                        break
                    end
                    
                    if tick() - moveStart > 10 then -- หมดเวลา 10 วินาที
                        print("⏰ หมดเวลา MoveTo - ลองใช้ CFrame")
                        moveSuccess = MoveToPosition(wp.Position, true)
                        break
                    end
                    
                    task.wait(0.1)
                end
                
                if not moveSuccess then
                    print(string.format("🔄 ลองใหม่ waypoint %d (ครั้งที่ %d)", i, attempts))
                    task.wait(1)
                end
            end
            
            if not moveSuccess then
                warn(string.format("❌ ไม่สามารถไปถึง waypoint %d", i))
                -- ลองต่อ waypoint ถัดไป
                continue
            end
        end
        
        print(string.format("[DEBUG] ✅ ถึงตำแหน่ง: %s", tostring(targetPos)))
        moving = false
        return true
        
    else
        warn(string.format("[❌ AutoWalk] Pathfinding ล้มเหลว: %s", path.Status.Name))
        
        -- ลองใหม่ถ้ายังไม่ถึงจำนวนสูงสุด
        if retryCount < maxRetries then
            print(string.format("🔄 ลองใหม่ในอีก %d วินาที... (%d/%d)", retryDelay, retryCount + 1, maxRetries))
            task.wait(retryDelay)
            moving = false
            return WalkToPosition(targetPos, retryCount + 1)
        else
            warn("❌ ลองครบจำนวนแล้ว - ข้ามไปตำแหน่งถัดไป")
            moving = false
            return false
        end
    end
end

-- ระบบ AutoFarm แบบวนลูป
local function StartAutoFarm()
    print("🤖 เริ่มระบบ AutoFarm")
    
    while isEnabled do
        if not IsCharacterValid() then
            print("⏳ รอ Character โหลด...")
            task.wait(2)
            continue
        end
        
        if moving then
            task.wait(1)
            continue
        end
        
        local targetPos = targetPositions[currentTargetIndex]
        if targetPos then
            local success = WalkToPosition(targetPos)
            
            -- เปลี่ยนไปตำแหน่งถัดไป
            currentTargetIndex = currentTargetIndex + 1
            if currentTargetIndex > #targetPositions then
                currentTargetIndex = 1 -- วนกลับไปจุดแรก
            end
            
            if success then
                print("💤 พักผ่อน 3 วินาที...")
                task.wait(3)
            else
                print("💤 พักหลังล้มเหลว 5 วินาที...")
                task.wait(5)
            end
        else
            warn("❌ ไม่มีตำแหน่งเป้าหมาย")
            break
        end
        
        task.wait(1) -- ป้องกัน lag
    end
end

-- ฟังก์ชันตั้งค่าความเร็ว
local function SetWalkSpeed(newSpeed)
    walkSpeed = math.clamp(newSpeed, 1, 50)
    speed = walkSpeed -- อัพเดท speed สำหรับ CFrame movement
    
    if IsCharacterValid() then
        humanoid.WalkSpeed = walkSpeed
        print(string.format("⚡ ตั้งความเร็วเป็น: %.1f", walkSpeed))
    end
end

-- ฟังก์ชันควบคุม
local function ToggleAutoFarm()
    isEnabled = not isEnabled
    if isEnabled then
        print("✅ เปิดใช้งาน AutoFarm")
        task.spawn(StartAutoFarm)
    else
        print("⏹️ หยุด AutoFarm")
        moving = false
    end
end

-- สร้าง UI สำหรับควบคุม
local function CreateAutoFarmGUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AutoFarmGUI"
    screenGui.Parent = player:WaitForChild("PlayerGui")
    screenGui.ResetOnSpawn = false
    
    -- Main Frame
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 280, 0, 280)
    mainFrame.Position = UDim2.new(0, 20, 0, 20)
    mainFrame.BackgroundColor3 = Color3.new(0, 0, 0)
    mainFrame.BackgroundTransparency = 0.3
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    
    -- Corner Radius
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = mainFrame
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 30)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "🤖 AutoFarm Control"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold
    title.Parent = mainFrame
    
    -- Status Label
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "StatusLabel"
    statusLabel.Size = UDim2.new(1, -20, 0, 25)
    statusLabel.Position = UDim2.new(0, 10, 0, 35)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "📊 สถานะ: ปิด"
    statusLabel.TextColor3 = Color3.new(0.8, 0.8, 0.8)
    statusLabel.TextScaled = true
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Parent = mainFrame
    
    -- Target Label
    local targetLabel = Instance.new("TextLabel")
    targetLabel.Name = "TargetLabel"
    targetLabel.Size = UDim2.new(1, -20, 0, 25)
    targetLabel.Position = UDim2.new(0, 10, 0, 65)
    targetLabel.BackgroundTransparency = 1
    targetLabel.Text = "🎯 ตำแหน่ง: 1/1"
    targetLabel.TextColor3 = Color3.new(0.8, 0.8, 0.8)
    targetLabel.TextScaled = true
    targetLabel.Font = Enum.Font.Gotham
    targetLabel.TextXAlignment = Enum.TextXAlignment.Left
    targetLabel.Parent = mainFrame
    
    -- Speed Settings Label
    local speedLabel = Instance.new("TextLabel")
    speedLabel.Name = "SpeedLabel"
    speedLabel.Size = UDim2.new(1, -20, 0, 20)
    speedLabel.Position = UDim2.new(0, 10, 0, 95)
    speedLabel.BackgroundTransparency = 1
    speedLabel.Text = string.format("⚡ ความเร็ว: %.1f", walkSpeed)
    speedLabel.TextColor3 = Color3.new(0.8, 0.8, 0.8)
    speedLabel.TextScaled = true
    speedLabel.Font = Enum.Font.Gotham
    speedLabel.TextXAlignment = Enum.TextXAlignment.Left
    speedLabel.Parent = mainFrame
    
    -- Speed Slider Background
    local sliderBg = Instance.new("Frame")
    sliderBg.Name = "SliderBackground"
    sliderBg.Size = UDim2.new(1, -40, 0, 8)
    sliderBg.Position = UDim2.new(0, 20, 0, 120)
    sliderBg.BackgroundColor3 = Color3.new(0.3, 0.3, 0.3)
    sliderBg.BorderSizePixel = 0
    sliderBg.Parent = mainFrame
    
    local sliderCorner = Instance.new("UICorner")
    sliderCorner.CornerRadius = UDim.new(0, 4)
    sliderCorner.Parent = sliderBg
    
    -- Speed Slider Fill
    local sliderFill = Instance.new("Frame")
    sliderFill.Name = "SliderFill"
    sliderFill.Size = UDim2.new(walkSpeed / 50, 0, 1, 0) -- Max speed 50
    sliderFill.Position = UDim2.new(0, 0, 0, 0)
    sliderFill.BackgroundColor3 = Color3.new(0, 0.8, 1)
    sliderFill.BorderSizePixel = 0
    sliderFill.Parent = sliderBg
    
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 4)
    fillCorner.Parent = sliderFill
    
    -- Speed Slider Knob
    local sliderKnob = Instance.new("Frame")
    sliderKnob.Name = "SliderKnob"
    sliderKnob.Size = UDim2.new(0, 16, 0, 16)
    sliderKnob.Position = UDim2.new(walkSpeed / 50, -8, 0.5, -8)
    sliderKnob.BackgroundColor3 = Color3.new(1, 1, 1)
    sliderKnob.BorderSizePixel = 0
    sliderKnob.Parent = sliderBg
    
    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = sliderKnob
    
    -- Speed Preset Buttons
    local speedButtonsFrame = Instance.new("Frame")
    speedButtonsFrame.Name = "SpeedButtons"
    speedButtonsFrame.Size = UDim2.new(1, -20, 0, 25)
    speedButtonsFrame.Position = UDim2.new(0, 10, 0, 140)
    speedButtonsFrame.BackgroundTransparency = 1
    speedButtonsFrame.Parent = mainFrame
    
    local function createSpeedButton(text, speedValue, position)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 45, 1, 0)
        btn.Position = UDim2.new(0, position, 0, 0)
        btn.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
        btn.Text = text
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.TextScaled = true
        btn.Font = Enum.Font.Gotham
        btn.BorderSizePixel = 0
        btn.Parent = speedButtonsFrame
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 4)
        btnCorner.Parent = btn
        
        btn.MouseButton1Click:Connect(function()
            SetWalkSpeed(speedValue)
            UpdateSpeedUI()
        end)
        
        return btn
    end
    
    createSpeedButton("ช้า", 8, 0)
    createSpeedButton("ปกติ", 16, 55)
    createSpeedButton("เร็ว", 25, 110)
    createSpeedButton("รวดเร็ว", 35, 165)
    createSpeedButton("สุดๆ", 50, 220)
    
    -- Start/Stop Button
    local toggleButton = Instance.new("TextButton")
    toggleButton.Name = "ToggleButton"
    toggleButton.Size = UDim2.new(1, -20, 0, 35)
    toggleButton.Position = UDim2.new(0, 10, 0, 180)
    toggleButton.BackgroundColor3 = Color3.new(0, 0.6, 0)
    toggleButton.Text = "▶️ เริ่มระบบ"
    toggleButton.TextColor3 = Color3.new(1, 1, 1)
    toggleButton.TextScaled = true
    toggleButton.Font = Enum.Font.GothamBold
    toggleButton.BorderSizePixel = 0
    toggleButton.Parent = mainFrame
    
    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(0, 6)
    toggleCorner.Parent = toggleButton
    
    -- Status Button
    local statusButton = Instance.new("TextButton")
    statusButton.Name = "StatusButton"
    statusButton.Size = UDim2.new(1, -20, 0, 25)
    statusButton.Position = UDim2.new(0, 10, 0, 225)
    statusButton.BackgroundColor3 = Color3.new(0, 0.4, 0.8)
    statusButton.Text = "📊 อัพเดทสถานะ"
    statusButton.TextColor3 = Color3.new(1, 1, 1)
    statusButton.TextScaled = true
    statusButton.Font = Enum.Font.Gotham
    statusButton.BorderSizePixel = 0
    statusButton.Parent = mainFrame
    
    local statusCorner = Instance.new("UICorner")
    statusCorner.CornerRadius = UDim.new(0, 4)
    statusCorner.Parent = statusButton
    
    -- Toggle minimized state
    local isMinimized = false
    local originalSize = mainFrame.Size
    
    -- Double click to minimize
    title.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local currentTime = tick()
            if title:GetAttribute("LastClick") and (currentTime - title:GetAttribute("LastClick")) < 0.5 then
                -- Double click detected
                isMinimized = not isMinimized
                if isMinimized then
                    mainFrame:TweenSize(UDim2.new(0, 280, 0, 35), "Out", "Quad", 0.3, true)
                    title.Text = "🤖 AutoFarm (คลิกเพื่อขยาย)"
                else
                    mainFrame:TweenSize(originalSize, "Out", "Quad", 0.3, true)
                    title.Text = "🤖 AutoFarm Control"
                end
            end
            title:SetAttribute("LastClick", currentTime)
        end
    end)
    
    -- Speed Slider Functions
    local function UpdateSpeedUI()
        speedLabel.Text = string.format("⚡ ความเร็ว: %.1f", walkSpeed)
        sliderFill.Size = UDim2.new(walkSpeed / 50, 0, 1, 0)
        sliderKnob.Position = UDim2.new(walkSpeed / 50, -8, 0.5, -8)
    end
    
    -- Speed Slider Interaction
    local dragging = false
    local function updateSlider(input)
        local relativeX = (input.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X
        relativeX = math.clamp(relativeX, 0, 1)
        local newSpeed = math.floor(relativeX * 50 * 10) / 10 -- Round to 1 decimal
        newSpeed = math.max(1, newSpeed) -- Minimum speed 1
        SetWalkSpeed(newSpeed)
        UpdateSpeedUI()
    end
    
    sliderBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            updateSlider(input)
        end
    end)
    
    sliderBg.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            updateSlider(input)
        end
    end)
    
    sliderBg.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    
    -- Update UI function
    local function UpdateUI()
        if isMinimized then return end
        
        statusLabel.Text = string.format("📊 สถานะ: %s %s", 
            isEnabled and "🟢 เปิด" or "🔴 ปิด",
            moving and "(กำลังเดิน)" or ""
        )
        targetLabel.Text = string.format("🎯 ตำแหน่ง: %d/%d", currentTargetIndex, #targetPositions)
        UpdateSpeedUI()
        
        if isEnabled then
            toggleButton.BackgroundColor3 = Color3.new(0.8, 0, 0)
            toggleButton.Text = "⏹️ หยุดระบบ"
        else
            toggleButton.BackgroundColor3 = Color3.new(0, 0.6, 0)
            toggleButton.Text = "▶️ เริ่มระบบ"
        end
    end
    
    -- Button Events
    toggleButton.MouseButton1Click:Connect(function()
        ToggleAutoFarm()
        UpdateUI()
    end)
    
    statusButton.MouseButton1Click:Connect(function()
        UpdateUI()
        -- Visual feedback
        statusButton.BackgroundColor3 = Color3.new(0, 0.6, 1)
        task.wait(0.1)
        statusButton.BackgroundColor3 = Color3.new(0, 0.4, 0.8)
    end)
    
    -- Auto update every 2 seconds
    task.spawn(function()
        while screenGui.Parent do
            UpdateUI()
            task.wait(2)
        end
    end)
    
    -- Initial UI update
    UpdateUI()
    print("🎮 สร้าง AutoFarm GUI เรียบร้อย! (ดับเบิลคลิกชื่อเพื่อย่อ/ขยาย)")
end

-- เริ่มต้นระบบ
task.wait(2) -- รอโหลดฉากให้เสร็จ
print("🎮 ระบบ AutoWalk พร้อมใช้งาน!")

-- ตั้งค่าความเร็วเริ่มต้น
SetWalkSpeed(walkSpeed)

CreateAutoFarmGUI()

-- เริ่มอัตโนมัติ (ถ้าต้องการ)
-- ToggleAutoFarm()
