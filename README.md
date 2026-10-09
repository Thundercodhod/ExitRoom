# EXITROOM — An Anthology of Quiet Horrors

เกมรวมเรื่องจิตวิทยาสยองขวัญ 4 Episode ในโปรเจกต์ Godot เดียว แต่ละตอนมีตัวละคร เรื่อง และตอนจบของตัวเอง เลือกเล่นตามลำดับใดก็ได้

## เปิดเกม

เปิด `project.godot` ในโฟลเดอร์ ExitRoom ด้วย Godot 4.7 ขึ้นไป รอ import แล้วกด **F5** หรือเปิด `Play.cmd` จะเข้าสู่เมนูใหม่

เปิด `main_menu.tscn` เพื่อดูเมนูโดยตรง แล้วกด F6 ในหน้าเมนูมีเลือก Episode, ตั้งค่า, เครดิต และออกจากเกม

| ตอน | เรื่อง | ฉาก |
| --- | --- | --- |
| 01 | The Last Visit — บ้านที่ยังรอ | `prologue_village.tscn` |
| 02 | After Hours — กะสุดท้าย | `backrooms_level.tscn` |
| 03 | Room 407 — ห้องที่ไม่มีใครเช่า | `Room407/main.tscn` |
| 04 | The Passenger — ผู้โดยสาร | `frog_chapter.tscn` |

เนื้อเรื่องฉบับปัจจุบันอยู่ใน [STORY.md](STORY.md) ไม่มีการส่งจากตอนหนึ่งไปอีกตอนโดยอัตโนมัติ เมื่อจบจะเลือกกลับเมนูหรือเล่นตอนเดิมอีกครั้งได้ `PlayFrog.cmd` และ `Room407/Play.cmd` ยังใช้เปิดตอนนั้นโดยตรงได้

## ควบคุมและการตั้งค่า

- WASD เดิน / เมาส์มอง / Shift วิ่ง / E สำรวจ / F ไฟฉาย
- Esc เปิดเมนูพักของตอน / F1 เปิดเมนูพักร่วมพร้อมกลับหน้าเลือก Episode
- บทพูดใช้ Chakra Petch รองรับภาษาไทย มีแถบพื้นหลังและค่อยแสดงข้อความ
- ตั้งค่าเสียงรวม เสียงบรรยากาศ เสียงประกอบ เต็มหน้าจอ ลดการเคลื่อนไหวกล้อง และแสดงบทพูดทันทีได้
- สลับเต็มหน้าจอด้วยปุ่มตั้งค่า, F11 หรือ Alt+Enter ขนาดหน้าต่างเดิมจะกลับมาเมื่อปิดเต็มหน้าจอ ปุ่มแสดงสถานะจริงและบันทึกหลังระบบเปลี่ยนสำเร็จ
- ทดสอบเต็มหน้าจอด้วย `Play.cmd` ซึ่งเปิดเกมแยกหน้าต่าง หากเล่นผ่านช่อง Game ใน Godot ให้ปิด **Embed Game on Next Play** ก่อนรัน เพราะ Godot ไม่รองรับการเปลี่ยนโหมดหน้าต่างขณะฝังเกมใน editor การตั้งค่าท้องถิ่นของโปรเจกต์นี้ปิด embedding ไว้แล้ว แต่ editor ที่เปิดอยู่ก่อนแก้อาจต้องเปิดโปรเจกต์ใหม่
- เก็บการตั้งค่าและรายชื่อตอนที่เล่นจบไว้ใน `user://anthology.cfg` ยังไม่มีเซฟตำแหน่งกลางตอน การเปิดตอนใหม่เริ่มจากต้นเรื่อง

มีเฟดดำเมื่อเลือกตอน เริ่มเล่นจากบทนำ เล่นซ้ำ จบตอน และกลับเมนู ระหว่างเปลี่ยนจะกันการกดซ้ำและหยุดตัวละครชั่วคราว ห้อง 407 ขึ้นเวลาเมื่อข้ามคืน ส่วนตอนกบเฟดช่วงเปลี่ยนไปนั่งในรถ โดยยังคงจังหวะไฟดับและตอนจบเดิม

บททั้ง 4 ตอนปรับเป็นคำเล่าของคนที่เจอเหตุการณ์ มีเหตุผลการเดินทาง/เข้าพัก/ทำงานและบทสนทนาภาษาพูด อ่านฉบับรวมได้ใน `STORY.md`

## ไฟล์สำคัญ

ผังโฟลเดอร์และวิธี deploy ล่าสุด: [PROJECT_LAYOUT.md](PROJECT_LAYOUT.md). คลัง source asset และฉากทดลองที่ไม่ได้ใช้ย้ายออกไปไว้ใน `../ExitRoom_SourceLibrary/2026-10-09/` แล้ว; GitHub เก็บเฉพาะไฟล์สำหรับเกมกับเครื่องมือตรวจงานที่จำเป็น

- `main_menu.tscn`, `scripts/main_menu.gd`: เมนู 3D และหน้าเลือกตอน
- `scripts/anthology.gd`: รายชื่อตอน การตั้งค่า เสียง และหน้าจบ
- `scripts/anthology_style.gd`, `ui/fonts/`, `ui/menu_film.gdshader`: รูปแบบเมนู ฟอนต์ และเอฟเฟกต์ภาพ
- `ui/previews/`: ภาพฉากจริงของแต่ละตอนสำหรับหน้าเลือกเรื่อง
- `audio/anthology/`: เสียงประกอบเพิ่มเติมที่สังเคราะห์สำหรับโปรเจกต์นี้
- สคริปต์เรื่อง: `scripts/prologue.gd`, `scripts/backrooms_level.gd`, `Room407/scripts/story.gd`, `scripts/frog_chapter.gd`

โมเดลและระบบกบเดิมไม่เปลี่ยน และไม่รันตัวสร้างฉากทับการจัดวางเดิม รายละเอียดสินทรัพย์อยู่ใน `ASSET_CREDITS.md` และ `Room407/ASSET_CREDITS.md`

## ตรวจงาน

```text
godot --headless --path . --script res://tests/anthology_flow.gd
godot --headless --path . --script res://tests/episode_village_backrooms.gd
godot --headless --path . --script res://tests/frog_chapter.gd
godot --headless --path . --script res://tests/frog_watcher.gd
godot --path . --script res://tests/display_transitions.gd --resolution 1280x720
```

`tests/campaign_flow.gd` ใช้ชุดทดสอบ anthology ใหม่แทนเส้นทางเชื่อมเรื่องแบบเก่า ภาพตรวจเมนูเก็บใน `.buildtmp/menu-*.png` และหน้าบทนำใน `.buildtmp/intro-*.png`

ใช้ `tools/capture_anthology.gd` กับ renderer จริงเพื่อสร้างภาพตัวอย่าง และส่ง `-- --menus` เพื่อถ่ายหน้าเมนู `tools/build_anthology_audio.py` สร้างเสียงใหม่ได้ ส่วนตัวสร้างฉากเก่าไม่จำเป็นต่อการเปิดเล่น

รายละเอียดข้อจำกัดการฝังเกมของเอนจิน: https://docs.godotengine.org/en/stable/tutorials/editor/game_embedding.html
