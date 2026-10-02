# บทกบ — บ้านกลางทุ่ง

เปิด `frog_chapter.tscn` ในโปรเจกต์ **ExitRoom** แล้วกด **F6** หรือเปิด `PlayFrog.cmd` บน Windows

ฉากนี้เป็นบทเล่นแยกในโปรเจกต์เดิม ไม่ได้เปลี่ยน `run/main_scene` หรือย้ายลำดับหมู่บ้าน / Backrooms / Room407 ของแคมเปญเก่า การเชื่อมแคมเปญทั้งหมดตามพล็อตใหม่ยังเป็นงานแยก

## ลำดับตาม STORY.md

รถเสียบนถนน → บ้านที่เปิดไฟกลางทุ่ง → กบยืนมองและหายไปที่รั้ว → กระดาษข้างหน้าต่าง → เสียงเคาะและกบนอกหน้าต่าง → ไฟดับ 2 วินาที → เครื่องจั๊มพ์แบตเตอรี่ในห้องนอน → เลข 407 และเสียงโทรศัพท์ใต้ผ้าห่ม → กลับรถโดยกบย้ายเมื่อพ้นสายตา → ต่อเครื่องจั๊มพ์ → เครื่องยนต์ติด → เสียงเข็มขัดจากเบาะข้าง → “Now you can stop looking.” → ภาพดำและ DON'T FOLLOW THE FROG

ไม่มีฉากต่อจากตอนจบนี้ และไม่ได้เพิ่มเรื่องบึง เทป ลูกแก้ว หรือกบเลียนเสียง

WASD เดิน, เมาส์มอง, Shift วิ่ง, E สำรวจ, F ไฟฉาย, Esc พักเกม กระดาษรอให้กดวางก่อนเริ่มเหตุการณ์ ไฟดับและการหันกล้องเป็นช่วงสั้น ไม่มีการโจมตีหรือเสียชีวิตจากกบ

## เก็บงานของเพื่อนไว้

ไม่แก้ `assets/models/enemy/frog.glb`, import settings, `scripts/frog_watcher.gd`, `scripts/frog_head_tracker.gd`, `scripts/frog_test.gd` หรือ `frog_test.tscn` ตัวควบคุมบทใหม่เรียก `appear_at`, `vanish`, `clear_scene_rules`, `relocate_when_unseen` และ `sit` ผ่านออบเจ็กต์เดิม ตั้ง `approach_enabled = false` เฉพาะกบที่สร้างในฉากนี้

ห้องนอนใช้สำเนา Room407 จากฉากเดิมก่อนเข้า SceneTree จึงไม่รันสคริปต์เนื้อเรื่องของห้องเดิม เก็บตำแหน่งเตียง ตู้ โต๊ะ และโคมไฟ เพิ่มรายละเอียดความทรงจำเฉพาะสำเนาในบ้านกลางทุ่ง โดยไม่เขียนทับต้นฉบับห้อง 407 รถและส่วนโถงบ้านเป็นทรง low-poly ที่สร้างสำหรับบทนี้

## หญ้า

ใช้ shader และ atlas ต้นฉบับจาก `Grass/assets/BinbunGrass/src/` โดยตรง สร้าง material ของฉากขึ้นใหม่เพื่อไม่ใช้ path `res://assets/BinbunGrass/...` ที่ติดมากับ demo จัดหญ้าเป็น MultiMesh 72 ชุด ลดการแสดงผลเมื่อไกลเกิน 62 เมตร เว้นทางเดิน ถนน และตัวบ้าน

แหล่งที่มา: [Godot Grass Shader — Binbun](https://binbun3d.itch.io/godot-grass), CC0 ตามหน้าเจ้าของผลงาน หญ้าต้นฉบับใน Grass ไม่ถูกแก้ไข

## ไฟล์และการตรวจ

- `frog_chapter.tscn` / `scripts/frog_chapter.gd`: ฉากเล่นและลำดับเหตุการณ์
- `frog_field_world.tscn`: สภาพแวดล้อมที่บันทึกไว้ เปิดจัดวางใน editor ได้
- `scripts/frog_field_world.gd` / `tools/build_frog_field.gd`: ตัวสร้างสภาพแวดล้อม **รันแล้วทับ frog_field_world.tscn** ไม่ควรรันหลังจัดฉากด้วยมือโดยไม่มีสำรอง
- `audio/frog_chapter/`: เสียงสังเคราะห์ต้นฉบับสำหรับบทนี้ สร้างซ้ำได้ด้วย `tools/build_frog_audio.py`
- `tests/frog_chapter.gd`: ลำดับเล่น, การตรวจเป้าหมาย, ช่องประตู, ไฟดับ, กบขณะมอง, การซ่อมรถและตอนจบ

```text
godot --headless --path . --script res://tests/frog_chapter.gd
godot --headless --path . --script res://tests/frog_watcher.gd
godot --path . --script res://tests/frog_chapter.gd --resolution 1280x720 -- --capture
```

ภาพทดสอบเก็บใน `.buildtmp/frog-*.png` ไม่มีระบบเซฟข้ามการปิดเกมในบทนี้
