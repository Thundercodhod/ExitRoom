# EXITROOM — An Anthology of Quiet Horrors

เกมรวมเรื่องจิตวิทยาสยองขวัญ 5 Episode กับด่านเดินอิสระอีก 1 ด่าน ในโปรเจกต์ Godot เดียว EPISODE 01–04 แต่ละตอนมีตัวละคร เรื่อง และตอนจบของตัวเอง เลือกเล่นตามลำดับใดก็ได้ ส่วน EPISODE 05 และด่าน 06 เล่าต่อจากเรื่องของภาคินใน EPISODE 04 และจะเปิดให้เล่นตามลำดับ

## เปิดเกม

เปิด `project.godot` ในโฟลเดอร์ ExitRoom ด้วย Godot 4.7 ขึ้นไป รอ import แล้วกด **F5** หรือเปิด `Play.cmd` จะเข้าสู่เมนูใหม่

เปิด `main_menu.tscn` เพื่อดูเมนูโดยตรง แล้วกด F6 ในหน้าเมนูมีเลือก Episode, ตั้งค่า, เครดิต และออกจากเกม

| ตอน | เรื่อง | ฉาก |
| --- | --- | --- |
| 01 | The Last Visit — บ้านที่ยังรอ | `levels/01_last_visit/prologue_village.tscn` |
| 02 | After Hours — กะสุดท้าย | `levels/02_after_hours/backrooms_level.tscn` |
| 03 | Room 407 — ห้องที่ไม่มีใครเช่า | `levels/03_room407/main.tscn` |
| 04 | The Passenger — ผู้โดยสาร | `levels/04_passenger/frog_chapter.tscn` |
| 05 | Realization — การตกตะกอน (ต่อจาก 04, เปิดหลังเล่น 04 จบ) | `levels/05_realization/forest_chapter.tscn` |
| 06 | Dream Field — ทุ่งในฝัน (เดินอิสระ ต่อจาก 05, เปิดหลังเล่น 05 จบ) | `levels/06_dream_field/dream_field.tscn` |

**ด่าน 06** เป็นฉากอิสระยามพระอาทิตย์ตกตามภาพอ้างอิง มีทุ่ง เนิน รูปปั้นแมว ต้นไม้ หิน ดอกไม้ และทะเลสาบ เปิด `levels/06_dream_field/dream_field.tscn` แล้วกด **F6** ได้เลย หรือเลือก **06 / DREAM FIELD** จากเมนู (เปิดให้เล่นหลังจบ EPISODE 05 ซึ่งมีปุ่มไปตอนต่อไปให้ที่หน้าจบ) ใช้ WASD เดิน, Shift วิ่ง, Ctrl ย่อตัว, Space กระโดด และ Esc พัก เข้าใกล้รูปปั้นแมว มองไปที่ตัวแมว แล้วกด **E** ภาพจะมืดลงและขึ้นเครดิตท้ายเกม (ชื่อทีม รายวิชา และเครดิต asset กดค้าง Space/E/คลิกเพื่อเร่ง หรือ Esc เพื่อข้าม) แล้วจึงกลับเมนู ด่านนี้ไม่มีภารกิจ

ฉากโลกและรูปปั้นแยกอยู่ที่ `levels/06_dream_field/scenes/world.tscn` และ `cat_statue.tscn` ปรับตำแหน่ง/แสงใน Godot ได้ตามปกติ `tools/build_dream_valley.gd` เป็นตัวสร้างเฉพาะฉากใหม่นี้; อย่ารันหากต้องการเก็บการจัดฉากที่แก้ด้วยมือไว้

เนื้อเรื่อง EPISODE 01–04 อยู่ใน [STORY.md](docs/STORY.md) ส่วน EPISODE 05 อยู่ใน [FOREST_CHAPTER.md](docs/FOREST_CHAPTER.md) เมื่อจบตอน เลือกกลับเมนูหรือเล่นตอนเดิมอีกครั้งได้ ส่วนตอนที่มีเรื่องต่อ (04 → 05 → 06) หน้าจบจะมีปุ่มไปตอนต่อไปเพิ่มมาให้ `PlayFrog.cmd` และ `levels/03_room407/Play.cmd` ยังใช้เปิดตอนนั้นโดยตรงได้

## ควบคุมและการตั้งค่า

- WASD เดิน / เมาส์มอง / Shift วิ่ง / E สำรวจ / F ไฟฉาย / V สลับมุมกล้อง (EP04–05)
- แถบ stamina เป็นคลื่นเสียงตรงขอบล่างของจอ ขาวคือเหลือเต็ม พอวิ่งจะกลายเป็นดำไล่จากขวาไปซ้าย หยุดวิ่งแล้วค่อย ๆ ฟื้น (EP01, 02, 04, 05)
- Esc เปิดเมนูพักของตอน / F1 เปิดเมนูพักร่วมพร้อมกลับหน้าเลือก Episode
- บทพูดใช้ Chakra Petch รองรับภาษาไทย มีแถบพื้นหลังและค่อยแสดงข้อความ
- ตั้งค่าเสียงรวม เสียงบรรยากาศ เพลง เสียงประกอบ เต็มหน้าจอ ลดการเคลื่อนไหวกล้อง และแสดงบทพูดทันทีได้
- สลับเต็มหน้าจอด้วยปุ่มตั้งค่า, F11 หรือ Alt+Enter ขนาดหน้าต่างเดิมจะกลับมาเมื่อปิดเต็มหน้าจอ ปุ่มแสดงสถานะจริงและบันทึกหลังระบบเปลี่ยนสำเร็จ
- ทดสอบเต็มหน้าจอด้วย `Play.cmd` ซึ่งเปิดเกมแยกหน้าต่าง หากเล่นผ่านช่อง Game ใน Godot ให้ปิด **Embed Game on Next Play** ก่อนรัน เพราะ Godot ไม่รองรับการเปลี่ยนโหมดหน้าต่างขณะฝังเกมใน editor การตั้งค่าท้องถิ่นของโปรเจกต์นี้ปิด embedding ไว้แล้ว แต่ editor ที่เปิดอยู่ก่อนแก้อาจต้องเปิดโปรเจกต์ใหม่
- เก็บการตั้งค่าและรายชื่อตอนที่เล่นจบไว้ใน `user://anthology.cfg` ยังไม่มีเซฟตำแหน่งกลางตอน การเปิดตอนใหม่เริ่มจากต้นเรื่อง

มีเฟดดำเมื่อเลือกตอน เริ่มเล่นจากบทนำ เล่นซ้ำ จบตอน และกลับเมนู ระหว่างเปลี่ยนจะกันการกดซ้ำและหยุดตัวละครชั่วคราว ห้อง 407 ขึ้นเวลาเมื่อข้ามคืน ส่วนตอนกบเฟดช่วงเปลี่ยนไปนั่งในรถ โดยยังคงจังหวะไฟดับและตอนจบเดิม

บทของ EPISODE 01–04 ปรับเป็นคำเล่าของคนที่เจอเหตุการณ์ มีเหตุผลการเดินทาง/เข้าพัก/ทำงานและบทสนทนาภาษาพูด อ่านฉบับรวมได้ใน [STORY.md](docs/STORY.md)

## ไฟล์สำคัญ

ผังโฟลเดอร์และวิธี deploy ล่าสุด: [PROJECT_LAYOUT.md](docs/PROJECT_LAYOUT.md). คลัง source asset และฉากทดลองที่ไม่ได้ใช้ย้ายออกไปไว้ใน `../ExitRoom_SourceLibrary/2026-10-09/` แล้ว; GitHub เก็บเฉพาะไฟล์สำหรับเกมกับเครื่องมือตรวจงานที่จำเป็น

- `main_menu.tscn`, `scripts/main_menu.gd`: เมนู 3D และหน้าเลือกตอน
- `scripts/anthology.gd`: รายชื่อตอน การตั้งค่า เสียง และหน้าจบ
- `scripts/anthology_style.gd`, `ui/fonts/`, `ui/menu_film.gdshader`: รูปแบบเมนู ฟอนต์ และเอฟเฟกต์ภาพ
- `ui/previews/`: ภาพฉากจริงของแต่ละตอนสำหรับหน้าเลือกเรื่อง
- `audio/anthology/`: เสียงประกอบเพิ่มเติมที่สังเคราะห์สำหรับโปรเจกต์นี้
- `levels/`: แต่ละด่านอยู่ในโฟลเดอร์ของตัวเอง (ฉาก, `scripts/`, `assets/`, `audio/`)
- สคริปต์เรื่อง: `levels/01_last_visit/scripts/prologue.gd`, `levels/02_after_hours/scripts/backrooms_level.gd`, `levels/03_room407/scripts/story.gd`, `levels/04_passenger/scripts/frog_chapter.gd`, `levels/05_realization/scripts/forest_chapter.gd`, `levels/06_dream_field/scripts/dream_field.gd`
- `scripts/player.gd`, `scripts/stamina_wave.gd`: ผู้เล่นที่ใช้ร่วมกันและแถบ stamina
- `scripts/credits_data.gd`, `scripts/end_credits.gd`: รายชื่อเครดิตที่ใช้ทั้งหน้าเครดิตในเมนูและเครดิตท้ายเกม
- `tools/itch_upload.sh`: export เวอร์ชันเว็บ ตรวจไฟล์ แล้วอัปโหลดขึ้น itch.io

โมเดลและระบบกบเดิมไม่เปลี่ยน และไม่รันตัวสร้างฉากทับการจัดวางเดิม รายละเอียดสินทรัพย์อยู่ใน `ASSET_CREDITS.md` และ `levels/03_room407/ASSET_CREDITS.md`

## การใช้ AI ในการพัฒนา

โปรเจกต์นี้ใช้ AI ช่วยเขียนโค้ด ได้แก่ **Claude** (Anthropic) และ **Codex** (OpenAI) โดยเขียนตามแผนของโปรเจกต์ที่ทีมกำหนด

- **ทีมผู้สร้างเป็นคนกำหนด:** เนื้อเรื่อง การออกแบบด่าน ลำดับ event บทพูด และการเลือก asset
- **AI เขียนโค้ดตามแผนนั้น:** ก่อนลงมือแต่ละงาน AI เสนอแผนให้ทีมตรวจและอนุมัติก่อน แล้วค่อยเขียนโค้ด
- **บทพูดภาษาไทย:** ทีมเป็นคนเขียนหรือเกลาเองก่อนใส่ในเกม
- **ตรวจงานทุกครั้ง:** ทุกการเปลี่ยนแปลงผ่านเทสอัตโนมัติในหัวข้อ "ตรวจงาน" ด้านล่าง ทีมเล่นทดสอบเอง และรีวิวผ่าน Pull Request ก่อน merge
- **asset:** มาจากแหล่งที่ระบุไว้ใน `ASSET_CREDITS.md`

## ตรวจงาน

```text
godot --headless --path . --script res://tests/anthology_flow.gd
godot --headless --path . --script res://tests/episode_village_backrooms.gd
godot --headless --path . --script res://tests/frog_chapter.gd
godot --headless --path . --script res://tests/frog_watcher.gd
godot --headless --path . --script res://tests/forest_loop.gd
godot --headless --path . --script res://tests/spider_enemy.gd
godot --headless --path . --script res://tools/verify_release.gd
godot --path . --script res://tests/dream_field.gd
godot --path . --script res://tests/display_transitions.gd --resolution 1280x720
```

`tests/dream_field.gd` และ `tests/display_transitions.gd` ต้องรันแบบเปิดหน้าต่าง (ไม่ใส่ `--headless`) เพราะทดสอบการกดปุ่มและหน้าต่างจริง

`tests/campaign_flow.gd` ใช้ชุดทดสอบ anthology ใหม่แทนเส้นทางเชื่อมเรื่องแบบเก่า ภาพตรวจเมนูเก็บใน `.buildtmp/menu-*.png` และหน้าบทนำใน `.buildtmp/intro-*.png`

ใช้ `tools/capture_anthology.gd` กับ renderer จริงเพื่อสร้างภาพตัวอย่าง และส่ง `-- --menus` เพื่อถ่ายหน้าเมนู `tools/build_anthology_audio.py` สร้างเสียงใหม่ได้ ส่วนตัวสร้างฉากเก่าไม่จำเป็นต่อการเปิดเล่น

รายละเอียดข้อจำกัดการฝังเกมของเอนจิน: https://docs.godotengine.org/en/stable/tutorials/editor/game_embedding.html
