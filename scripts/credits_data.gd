extends RefCounted
## One list of credits for the menu's credits page and the end roll after Level 06.
## Keep in step with ASSET_CREDITS.md and Room407/ASSET_CREDITS.md.

const CLOSING_LINE := "เรามักทิ้งบางสิ่งไว้ในแต่ละสถานที่เสมอ"

const TEAM := [
	"นายศรัณยู เจริญผล   673380532-1",
	"นายธันว์ สว่างศรี   673380078-7",
	"นายทีฆานนท์ อัศวะภูมิ   673380075-3",
]

const COURSE := "CP 410844  การพัฒนาเกมคอมพิวเตอร์\nComputer Game Development"
const ADVISOR := "ผศ.ดร.วชิราวุธ ธรรมวิเศษ"
const SCHOOL := "วิทยาลัยการคอมพิวเตอร์  มหาวิทยาลัยขอนแก่น"

# [heading, lines]
const SECTIONS := [
	["ภาพ ฉาก และโมเดล", [
		"PSX Forest Free · PSX Skyboxes Free — heyheythere (CC BY 4.0)",
		"Handpainted Fat Cat Statue — Stylized Station (CC BY 4.0)",
		"Low-poly Furnished Abandoned House — NeoKG (CC BY 4.0)",
		"Soviet Apartment Interior — My Name Is This",
		"Forgotten Bedroom — Vicious Potato Studios",
		"Boxes — PomidorkaStudios",
		"PSX Natural Ground Textures — CipriEnt",
		"Godot Grass Shader — Binbun (CC0)",
		"Wood and plaster textures — Poly Haven (CC0)",
		"Spider_free — ผู้สร้างไม่ระบุชื่อ",
		"Character animation — Mixamo",
	]],
	["ฟอนต์", [
		"Chakra Petch — Cadson Demak (SIL OFL)",
		"VT323 — Peter Hull (SIL OFL)",
		"Noto Sans Thai — Google (SIL OFL)",
	]],
	["เพลงและเสียง", [
		"Music and sound effects — Epidemic Sound",
		"Dry Grass Rustle — TheSupremeMuffinPooter (CC0)",
		"เสียงลม เสียงป่า และเสียงประกอบอื่น ๆ — ExitRoom",
	]],
]

const THANKS := "ขอบคุณที่เล่นจนจบ"

static func episode_lines() -> Array[String]:
	var lines: Array[String] = []
	for entry in Anthology.EPISODES:
		lines.append(entry.number+"   "+entry.title+"  ·  "+entry.thai)
	return lines

static func team_text() -> String:
	return "\n".join(TEAM)
