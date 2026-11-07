# 4. Store listing

The store page: the copy users read and the images beside it. Everything is
written here rather than typed into the Console, so the repo stays the source
and a character limit is checked before a paste, not after a rejection.

**Status for this app: Live.** The default (Thai) listing has been live since
8 October 2026. Only come back here when the wording or the images change.

Console path: **Grow users → Store presence → Store listings → Default store
listing**. Release notes are **not** part of the listing — they belong to an
individual release, so they are entered in
[6. Create the release](06-create-release.md); the text for them is kept here
beside the rest of the copy.

## Only Thai is configured in the Console

The release form offers a `<th>` block and nothing else, which means `en-US`
has not been added as a store listing language. The English copy below is
written and ready, but adding the locale is a decision rather than a paste: a
second locale has to be kept current on every release, and a stale translation
is worse than none.

## Checking the limits

Every field below is a fenced `text` block under a `### <field> (limit N)`
heading, and `tool/store/check_listing_limits.py` reads both the block and the
number in the heading. Adding a field needs no change to the script.

```sh
python3 tool/store/check_listing_limits.py
```

Run it after any edit. Play counts characters, not bytes, so a Thai character
and its tone mark each count as one.

## What goes where in the Console

| Play field        | Where it comes from                      |
| ----------------- | ---------------------------------------- |
| App name          | **App name** below, per locale           |
| Short description | **Short description**                    |
| Full description  | **Full description**                     |
| App icon          | `assets/icon-512.png`                    |
| Feature graphic   | `assets/feature-graphic.png`             |
| Phone screenshots | `assets/screenshots/01…08` in that order |
| 7-inch tablet screenshots  | `assets/screenshots-tablet-7/01…08` |
| 10-inch tablet screenshots | `assets/screenshots-tablet-10/01…08` |
| Chromebook screenshots     | `assets/screenshots-desktop/01…08`  |

Which screenshot is which screen, and why they are captured from the web build
rather than a device, is in [screenshots.md](screenshots.md). Regenerating the
images is [3. Store assets](03-store-assets.md).

---

## Thai copy — the default locale

User-facing copy, so this section is Thai on purpose; the folder's
English-only rule covers developer prose, not the words that ship to users.

### App name (limit 30)

```text
สวดมนต์ บทสวดไทย-บาลี ออฟไลน์
```

### Short description (limit 80)

```text
หนังสือสวดมนต์ไทย-บาลี พร้อมคำอ่านและคำแปล ใช้ได้ออฟไลน์ ไม่มีโฆษณา
```

### Full description (limit 4000)

```text
สวดมนต์ — หนังสือสวดมนต์ไทย-บาลี ที่เปิดใช้ได้ทุกที่ ไม่ต้องต่ออินเทอร์เน็ต

บทสวดทั้งหมดติดมากับตัวแอปตั้งแต่ติดตั้ง จึงเปิดสวดได้ทันทีแม้อยู่ในวัด บนรถ หรือที่ที่ไม่มีสัญญาณ ไม่มีโฆษณา ไม่ต้องสมัครสมาชิก และไม่มีการเก็บข้อมูลส่วนตัว

■ บทสวดที่ใช้เป็นประจำ
• ทำวัตรเช้า ทำวัตรเย็น บททั่วไป บทสวดพิเศษ บทอนุโมทนา เจริญพระพุทธมนต์ และบทธรรมคำสอน
• แต่ละบทมีเนื้อบทคำอ่านภาษาไทย พร้อมคำอ่านบาลีอักษรโรมันและคำแปลในบทที่มีข้อมูล
• ปักหมุดหมวดหรือบทที่สวดบ่อยไว้หน้าแรก จัดหน้าแรกได้ตามที่ตัวเองใช้จริง

■ อ่านง่ายตามแบบที่ท่านสวด
• เปิด-ปิดคำอ่านบาลีและคำแปลได้ทุกบท เลือกแสดงแทรกใต้บรรทัดหรือแยกไว้ท้ายบท
• ปรับขนาดตัวอักษร สีตัวอักษร ระยะห่างบรรทัด การจัดหน้า และธีมสว่าง/มืด
• คำที่ผู้นำสวดว่าคนเดียวแสดงต่างจากบทที่สวดพร้อมกัน เหมือนหนังสือสวดมนต์
• โหมดเต็มจอ และหน้าจอไม่ดับระหว่างสวด

■ สองโหมดการอ่าน
• ปัดซ้าย-ขวาทีละบท หรืออ่านแนวยาวต่อเนื่องทั้งหมวดรวดเดียวจบ
• ลากต่อที่ท้ายหน้าเพื่อไปหมวดถัดไปได้เลย ไม่ต้องย้อนกลับไปเลือกใหม่
• เลื่อนหน้าอัตโนมัติด้วยปุ่ม ▶ ปรับความเร็วได้ 10 ระดับ จบบทแล้วข้ามไปบทถัดไปให้เอง
• จำตำแหน่งที่อ่านค้างไว้ กลับมาต่อได้ตรงจุดเดิมจากหน้าแรก

■ ค้นหาและบันทึกไว้ใช้เอง
• ค้นหาจากชื่อบทและเนื้อบท พร้อมไฮไลต์คำที่ตรง พิมพ์ araham ก็เจอ Arahaṃ
• บันทึกบทที่ใช้บ่อยไว้ในรายการบทที่บันทึก
• เพิ่มบทที่ท่านสวดเพิ่มเข้าไปต่อท้ายหมวดได้ โดยหมวดยังได้รับการแก้ไขเนื้อหาจากรุ่นใหม่ตามปกติ

■ ชุดสวดของฉัน
• จัดชุดบทสวดเอง เรียงลำดับได้ แล้วสวดต่อเนื่องทั้งชุด เช่น ชุดสวดก่อนนอน
• ส่งชุดสวดให้เครื่องอื่นด้วย QR หรือคัดลอกเป็นโค้ดส่งทางแชท — ไม่ต้องใช้อินเทอร์เน็ต

■ เครื่องมือช่วยปฏิบัติ
• จับเวลานั่งสมาธิ 1–180 นาที หน้าจอไม่ดับ ครบเวลาแล้วเตือนด้วยเสียงระฆังหรือการสั่น
• เลือกเสียงธรรมชาติคลอระหว่างนั่งสมาธิ — สายน้ำในป่า สายฝน นกในป่า หรือคลื่นทะเล
• ตัวนับรอบสวดแบบแผ่นลอยในหน้าอ่าน ตั้งเป้า 9 / 27 / 108 รอบ หรือกำหนดเอง
• วงแหวนเป้าหมายรายวันหน้าแรก นับเวลาที่สวดมนต์และนั่งสมาธิรวมกัน
• ตั้งเวลาเตือนได้ 4 ช่วง เช้า กลางวัน เย็น ก่อนนอน เลือกวันในสัปดาห์ของแต่ละช่วงได้

■ ออฟไลน์และเป็นส่วนตัว
• ใช้งานได้เต็มรูปแบบโดยไม่ต้องต่ออินเทอร์เน็ต ไม่มีบัญชีผู้ใช้ ไม่มีโฆษณา ไม่มีการติดตามผู้ใช้
• บทที่บันทึก ชุดสวด และการตั้งค่าทั้งหมดเก็บอยู่ในเครื่องของท่านเท่านั้น
• ขอสิทธิ์กล้องเฉพาะตอนสแกน QR ชุดสวดเท่านั้น ไม่มีการบันทึกหรือส่งภาพออกจากเครื่อง
• รองรับทั้งภาษาไทยและภาษาอังกฤษ โดยตั้งค่าเริ่มต้นเป็นภาษาไทยเสมอ

■ เกี่ยวกับเนื้อหาบทสวด
เนื้อหาบทสวดอ้างอิงจากหนังสือสวดมนต์มาตรฐานที่ใช้แพร่หลายทั่วไป หากพบข้อผิดพลาดของเนื้อหา โปรดแจ้งผ่านเมนู “แจ้งบทสวดผิด” ในหน้าอ่าน เพื่อให้แก้ไขในรุ่นถัดไป และโปรดเทียบกับหนังสือสวดมนต์ฉบับที่ท่านใช้เป็นหลัก

คำแปลภาษาอังกฤษเป็นฉบับไม่เป็นทางการ จัดทำขึ้นเพื่อความเข้าใจเท่านั้น โปรดเทียบกับฉบับแปลที่ท่านเชื่อถือ
```

### Release notes for 1.0.0 (limit 500)

```text
รุ่นแรกของ สวดมนต์ — หนังสือสวดมนต์ไทย-บาลี ใช้งานได้ออฟไลน์ทั้งหมด

• บทสวดที่ใช้เป็นประจำ ทั้งทำวัตรเช้า ทำวัตรเย็น และหมวดอื่น ๆ
• เปิด-ปิดคำอ่านบาลีและคำแปลได้ทุกบท แทรกใต้บรรทัดหรือแยกท้ายบท
• อ่านทีละบทหรือแนวยาวต่อเนื่องทั้งหมวด พร้อมเลื่อนหน้าอัตโนมัติ
• จัดชุดสวดของตัวเอง และส่งให้เครื่องอื่นด้วย QR โดยไม่ต้องใช้อินเทอร์เน็ต
• จับเวลานั่งสมาธิพร้อมเสียงธรรมชาติ ตัวนับรอบสวด เป้าหมายรายวัน และเตือนทำวัตรเช้า-เย็น
```

---

## English copy — the `en-US` locale

The same four fields for the `en-US` store locale. This is a parallel listing,
not a translation exercise: the app ships an English UI, but the prayers
themselves are Thai and Pali, and the copy has to say so plainly rather than
imply an English prayer book.

### App name (limit 30)

```text
Chanting — Thai Prayer Book
```

### Short description (limit 80)

```text
Offline Thai-Pali chanting book with romanized Pali and translations. No ads.
```

### Full description (limit 4000)

```text
Chanting is an offline Thai and Pali prayer book. Every prayer is bundled inside the app, so it opens in a temple, on a bus, or anywhere with no signal. No ads, no account, no data collection.

Note on language: the chanting text is Thai and Pali. The app interface is available in Thai and English, and English meanings are provided for many prayers, but this is a Thai chanting book — not an English one.

■ The prayers you chant regularly
• Morning and evening chanting services, general prayers, special chants, blessing and rejoicing verses, and Dhamma teachings
• Each prayer carries the Thai reading text, with romanized Pali and a translation where they exist
• Pin the categories or single prayers you use most to the home screen and arrange it the way you actually chant

■ Reading the way you chant
• Turn romanized Pali and the translation on or off per prayer, inline under each line or as a block at the end
• Adjust text size, text color, line spacing, alignment, and light or dark theme
• A line the leader chants alone is set apart from what everyone chants together, the way a printed book does it
• Fullscreen reading, and the screen stays awake while you chant

■ Two reading modes
• Swipe left and right one prayer at a time, or read the whole category as one continuous page
• Drag past the end of a page to move straight on to the next category
• Auto-scroll with a ▶ button, ten speeds, moving on to the next prayer by itself
• Your position is remembered — come back to exactly where you stopped

■ Search and keep your own
• Search titles and prayer text with match highlighting; typing araham finds Arahaṃ, so Pali is searchable from a normal keyboard
• Save the prayers you use often
• Append your own prayers to a shipped category, which keeps receiving corrections in later releases

■ Your own prayer sets
• Build ordered sets, such as a bedtime routine, and chant a whole set continuously
• Send a set to another phone by QR code or as a text code — with no internet and no server

■ Practice tools
• Meditation timer from 1 to 180 minutes; the screen stays on and the end is marked by a singing bowl or vibration
• A floating mala counter on the reading screen, with targets of 9, 27, 108, or your own
• A daily goal ring that counts the minutes you chant and meditate
• Optional nature sounds under a sitting: forest stream, rain, forest birds, sea waves
• Reminders for four times of day — morning, midday, evening and bedtime — each at a time and on the days of the week you choose

■ Offline and private
• Fully usable with no internet connection, no user account, no ads, no tracking
• Saved prayers, prayer sets, and settings stay on your device
• The camera permission is used only to scan a prayer-set QR code; no image is stored or sent

■ About the content
The prayer text follows standard Thai chanting books in common use. If you find a mistake, please report it from the "report an error" menu on the reading screen so it can be fixed in the next release, and check against the edition you follow.

English meanings are unofficial and are provided for understanding only. Please compare them with a translation you trust.
```

### Release notes for 1.0.0 (limit 500)

```text
First release of Chanting — an offline Buddhist prayer book.

• Morning and evening chanting services and other categories
• Romanized Pali and translations, inline or at the end of a prayer
• Swipe per prayer or read a whole category continuously, with auto-scroll
• Your own prayer sets, shared by QR code without an internet connection
• Meditation timer with nature sounds, mala counter, daily goal, and reminders
```

---

## Notes for whoever submits this

### The copy above is ahead of the live listing

The Thai "เครื่องมือช่วยปฏิบัติ" list was corrected on 7 November 2026 and
**the Console has not been updated yet** — the live Thai page is still the
previous wording. Three things changed, and the live page is wrong about the
first until someone pastes this in:

- `• นับวันที่สวดต่อเนื่อง เห็นความสม่ำเสมอของตัวเองย้อนหลัง` is gone. That was
  the chanting streak, removed from the app in October 2026 along with its
  `/stats` page, so the live listing advertises a feature the app does not
  have. It is replaced by the daily goal ring, which is what the English list
  described all along.
- The nature sounds were in the English list and not the Thai one.
- **Both** lists said reminders were morning and evening. There are four slots
  — morning, midday, evening and bedtime — each with its own days of the week,
  since September 2026.

Paste the Thai full description into **Grow users → Store presence → Store
listings**. No new build is needed: this is listing copy, not the binary. The
English copy is written but its locale is not configured, so nothing to paste
for it yet.

### Thai

- The full description mentions the categories by name but **no prayer count**. The
  book is edited between releases, so a number here would go stale silently; the
  category names change far less often. If a count is ever added, it has to be
  re-checked against `assets/data/prayers-th.json` on every release.
- The last block is the content note [4. Store listing](04-store-listing.md) asks
  for, and it is deliberately worded like the app's own About screen
  (`aboutDescription`, `aboutTranslationNote` in `lib/l10n/app_th.arb`). If the
  About text is reworded, reword it here too.
- "ไม่มีการเก็บข้อมูลส่วนตัว" and the camera sentence must stay consistent with the
  Data safety form — see `05-app-content-forms.md`. A listing that claims more privacy than
  the form declares is a policy violation, not a marketing choice.

### English

- Play uses one set of screenshots for every locale unless per-locale images are
  uploaded. We upload one set, captured with the Thai UI, because the prayers are
  Thai in every edition — an English UI over Thai prayer text would look less like
  the app than the Thai UI does.
- The language paragraph near the top is deliberate. Without it, "Thai Prayer Book"
  in English reads to some installers as a book of prayers translated into English,
  and the first review after that is a one-star review about the language.
