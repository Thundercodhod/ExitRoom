# ExitRoom

เกมต้นแบบมุมมองบุคคลที่สามใน Godot 4.7.2

ลำดับเกมคือ **สวน (lobby) → Backrooms (ด่านแรก) → กลับสวนเมื่อออกจากด่านสำเร็จ** ไม่มีด่านบ้านผี

![Garden lobby](preview-lobby.png)

![Backrooms level one](preview-backrooms.png)

## เปิดเล่น

เมื่อนำโปรเจกต์ลงเครื่องครั้งแรก ให้เปิด `project.godot` ใน Godot และรอให้นำเข้าโมเดลเสร็จ แล้วกด F5 หลังจากนั้นใช้ `Play.cmd` เพื่อเปิดเล่นได้

ที่ lobby เลือก **เดินเล่นในสวน** เพื่อควบคุม Hazmat หรือเลือก **เริ่มด่าน 1 / BACKROOMS** เพื่อเข้าเล่นทันที เดินไปที่ป้ายในสวนแล้วกด E ก็เริ่มด่านได้

ใน Backrooms เดินหาไฟทางออกสีเขียว กด E เพื่อกลับสวน

- WASD: เดิน
- เมาส์: หมุนกล้อง
- Shift: วิ่ง
- F: เปิด/ปิดไฟฉาย
- E: ใช้งานป้ายเริ่มด่านหรือทางออก
- Esc: เมนู/พัก

Hazmat ใช้ `3Dmodel_import/backrooms_rigged_hazmat.glb` เป็นตัวละครชั่วคราวระหว่างรอโมเดลจริง สวนใช้ `assets/garden_fountain_toothless.glb` และด่านแรกใช้ `3Dmodel_import/original_backrooms.glb`

เมนูใช้ฟอนต์สำรองที่มาพร้อม Godot จึงไม่ต้องติดตั้งฟอนต์เพิ่มเติม
