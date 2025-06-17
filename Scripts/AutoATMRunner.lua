-- LocalScript: AutoATMRunner
-- ทดสอบการเรียกใช้ ATMNavigator เพื่อหาตำแหน่ง ATM ที่ใกล้ที่สุด

local ATMNavigator = require(script:WaitForChild("ATMNavigator"))

-- รอโหลดตัวละคร
repeat wait() until game.Players.LocalPlayer.Character
wait(2)

local atm = ATMNavigator:FindNearestATM()
if atm then
    print("[AutoATM] ATM ที่ใกล้ที่สุดคือ:", atm:GetFullName())
else
    warn("[AutoATM] ไม่พบ ATM")
end
