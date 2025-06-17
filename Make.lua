--[[
 WorkSpec Extractor (Auto Copy) by ChatGPT
 นำไปวางใน LocalScript (เช่น StarterPlayerScripts) แล้วรันใน Roblox Studio
 มันจะคัดลอกข้อมูลสำคัญเกี่ยวกับ ATM, RemoteEvents, Tools, leaderstats ฯลฯ ไปยัง Clipboard ทันที
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()

local data = {}

-- 1. ค้นหา ATM
data.ATM_Locations = {}
for _, obj in pairs(Workspace:GetDescendants()) do
    if obj:IsA("Model") or obj:IsA("Part") then
        if string.lower(obj.Name):find("atm") then
            table.insert(data.ATM_Locations, obj:GetFullName())
        end
    end
end

-- 2. ค้นหา RemoteEvent / RemoteFunction
data.Remotes = {}
for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
    if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
        table.insert(data.Remotes, obj:GetFullName() .. " [" .. obj.ClassName .. "]")
    end
end

-- 3. Tools ใน Backpack
data.Tools = {}
for _, tool in pairs(LocalPlayer.Backpack:GetChildren()) do
    table.insert(data.Tools, tool.Name)
end

-- 4. Leaderstats
data.Leaderstats = {}
local stats = LocalPlayer:FindFirstChild("leaderstats")
if stats then
    for _, val in pairs(stats:GetChildren()) do
        table.insert(data.Leaderstats, val.Name .. " = " .. tostring(val.Value))
    end
else
    table.insert(data.Leaderstats, "ไม่พบ leaderstats")
end

-- 5. GUI ที่อาจเกี่ยวข้อง
data.GUI = {}
for _, gui in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
    if gui:IsA("TextButton") or gui:IsA("Frame") then
        if string.lower(gui.Name):find("atm") or string.lower(gui.Name):find("hack") then
            table.insert(data.GUI, gui:GetFullName())
        end
    end
end

-- 🔄 แปลงข้อมูลเป็น JSON และคัดลอก
local json = HttpService:JSONEncode(data)

if setclipboard then
    setclipboard(json)
    warn("[✅ WorkSpec Extractor]: ข้อมูลถูกคัดลอกไปยัง Clipboard แล้ว! กรุณาวาง (Ctrl+V) ส่งให้ ChatGPT")
else
    warn("[⚠️ ไม่สามารถคัดลอกอัตโนมัติได้] กรุณาก๊อปจาก Output แทน")
    print(json)
end
