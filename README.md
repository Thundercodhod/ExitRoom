# ExitRoom

โปรเจกต์เกมสยองขวัญ 3D ที่สร้างด้วย Godot 4 มีฉากหมู่บ้าน บ้านยาย สวนล็อบบี้ Backrooms และโรงเรียนร้าง พร้อมภาพแบบ low-poly/PSX มุมมองบุคคลที่หนึ่ง แสงสลัว หมอก และ shader ภาพพิกเซลเบลอ

Repository นี้เป็น **Public** เพื่อให้เพื่อน clone และทดสอบเกมได้ง่าย

## โปรเจกต์ใน Repository

### ExitRoom

เกมหลักของโปรเจกต์ เปิดไฟล์ project.godot ที่โฟลเดอร์รากด้วย Godot 4 แล้วกด Play หรือใช้ Play.cmd

ลำดับต้นแบบคือ หมู่บ้าน → บ้านยาย → สวนล็อบบี้ → Backrooms → โรงเรียนร้าง โดยใช้ Hazmat เป็นตัวละครชั่วคราว

### Room407

เกมทดลองอีกเกมหนึ่งที่แยกจาก ExitRoom โดยสมบูรณ์ เปิดไฟล์ Room407/project.godot เป็นโปรเจกต์ Godot แยกต่างหาก ไม่ควรเปิดทั้งสองโฟลเดอร์เป็นโปรเจกต์เดียวกัน

## การควบคุม

- WASD เดิน
- เมาส์ หมุนกล้อง
- Shift วิ่ง
- Space กระโดด
- F เปิด/ปิดไฟฉาย
- E ใช้งานประตู ป้าย และทางออก
- Esc เปิดเมนู

ทุกฉากใช้แสงมืด หมอก และ shader assets/shaders/retro_horror.gdshader เพื่อสร้างภาพพิกเซลเบลอ เกรน และขอบภาพมืด

## เปิดเล่นจากเครื่อง

1. ติดตั้ง Godot 4
2. Clone repository นี้
3. เปิดโฟลเดอร์ ExitRoom หรือ Room407 แยกกันใน Godot
4. รอให้ Godot import โมเดลและ texture เสร็จ
5. กด Play หรือใช้ไฟล์ .cmd ของโปรเจกต์นั้น

## GitHub Pages

มี workflow Deploy web build สำหรับสร้างเว็บ export ของเกม โดยต้องให้ workflow ในแท็บ Actions ทำงานสำเร็จก่อนจึงจะเปิดได้ที่:

https://thundercodhod.github.io/ExitRoom/

หากเห็นหน้า 404 ให้ตรวจ workflow ล่าสุด และตรวจที่ Settings → Pages ว่า Source เป็น GitHub Actions

## Asset และเครดิต

ไฟล์ asset ที่มีเงื่อนไขการใช้งานหรือยังไม่มีข้อมูลผู้สร้างไม่ควรอัปโหลดเพิ่มใน repository สาธารณะ ให้เก็บไว้ในเครื่องตาม ASSET_CREDITS.md แทน

ไฟล์ .godot, .import, log และ preview ชั่วคราวถูกกันออกจาก Git เพื่อให้ clone และ build ได้สะอาดขึ้น

## โครงสร้างสำคัญ

    ExitRoom/
    ├─ project.godot
    ├─ Room407/
    │  └─ project.godot
    ├─ assets/
    ├─ scenes/
    ├─ scripts/
    └─ .github/workflows/
