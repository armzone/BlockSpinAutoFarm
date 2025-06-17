-- main.lua
-- โหลดและใช้งาน ATMNavigator จาก GitHub แบบ Plug-and-Play
-- ใช้ผ่าน loadstring(game:HttpGet("..."))()

-- โหลด ATMNavigator Module
local ATMNavigator = loadstring(game:HttpGet("https://raw.githubusercontent.com/armzone/BlockSpinAutoFarm/main/Modules/ATMNavigator.lua"))()

-- รอโหลดตัวละคร
local player = game:GetService("Players").LocalPlayer
repeat wait() until player.Character
wait(1)

-- ค้นหา ATM ที่ใกล้ที่สุดและแสดงใน Output
local atm = ATMNavigator:FindNearestATM()
if atm then
    print("[BlockSpinAutoFarm] 🏧 ATM ที่ใกล้ที่สุดคือ:", atm:GetFullName())
else
    warn("[BlockSpinAutoFarm] ❌ ไม่พบ ATM ในระยะทำการ")
end
