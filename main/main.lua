-- main.lua
-- โหลดโมดูลจาก GitHub และทำงานอัตโนมัติผ่าน loadstring()

-- โหลด ATMNavigator
local ATMNavigator = loadstring(game:HttpGet("https://raw.githubusercontent.com/armzone/BlockSpinAutoFarm/main/Modules/ATMNavigator.lua"))()

-- โหลด ATMPathfinder
local ATMPathfinder = loadstring(game:HttpGet("https://raw.githubusercontent.com/armzone/BlockSpinAutoFarm/main/Modules/ATMPathfinder.lua"))()

-- รอโหลดตัวละคร
local player = game:GetService("Players").LocalPlayer
repeat wait() until player.Character
wait(1)

-- 🔍 ค้นหา ATM ที่ใกล้ที่สุด
local atm = ATMNavigator:FindNearestATM()
if atm then
    print("[AutoFarm] ✅ เจอ ATM:", atm:GetFullName())
    
    -- 🧭 เดินไปยัง ATM
    local walked = ATMPathfinder:WalkToATM(atm)
    if walked then
        print("[AutoFarm] 🚶 ถึง ATM แล้ว!")
    end
else
    warn("[AutoFarm] ❌ ไม่พบ ATM")
end
