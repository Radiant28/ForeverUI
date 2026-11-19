# ForeverUI

**Fan-made World of Warcraft 3.3.5a (WotLK / Nozdor) UI Suite**

[Русский](#foreverui-ru) · [English](#foreverui-en) · [Лицензия и отказ от ответственности / License & Disclaimer](#license-and-disclaimer)

---

<a id="foreverui-ru"></a>
## 🇷🇺 Русский

**ForeverUI** — комплексный фанатский аддон интерфейса для клиента **World of Warcraft 3.3.5a** (сборка `12340`, `## Interface: 30300`, адаптирован под сервер **Nozdor**) в стилистике **WoW: Forever** с поддержкой классической и **Retail**-раскладок.

> [!IMPORTANT]
> **Отказ от ответственности:** ForeverUI является **неофициальным фанатским некоммерческим проектом**. Аддон не связан с **Blizzard Entertainment** или администрацией сервера **Nozdor / WoW: Forever**, не спонсируется и не поддерживается ими. Подробнее см. раздел [«Лицензия и отказ от ответственности»](#license-and-disclaimer).

### Основные возможности

- **Мастер установки (`/fui install`, `/fui copy`):** пошаговая настройка под роль (Танк, Лекарь, ДД ближнего/дальнего боя), выбор раскладки (Classic / Retail), авто-масштаб, включение модулей, настройка чата и хранение отдельных профилей для каждого персонажа и набора талантов.
- **Edit Mode:** перемещение и масштабирование элементов интерфейса, настройка сетки (число ячеек и рядов) для панелей действий, питомца, тотемов, баффов и дебаффов, скрытие отдельных фреймов.
- **Рамки юнитов, каст-бары и неймплейты (`/wfn`):** рескин стандартных рамок в бронзовой оправе WoW Forever или в стиле Retail, реакция цели, полосы заклинаний, настраиваемые неймплейты с угрозой, аурами и кастами.
- **Скины окон (`/fuiframe`, `/fuiskin`):** оформление игровых окон (персонаж, таланты, книга заклинаний, профессии, сумки, банк, банк гильдии, торговец, почта, карта, коллекции, магазин и др.) в стиле WoW Forever.
- **Панель ресурсов персонажа (`/fuiprd`):** отображение здоровья, маны/энергии/ярости/рун, тотемов, серии приёмов, осколков души, проков и баффов под персонажем.
- **Фреймы группы и рейда (`/fuiraid`) + Click-Casting:** индикаторы в стиле Cell, белый список баффов, исключения дебаффов, подсветка рассеивания, рамки наведения и цели, индикатор питья, рост группы от центра, привязка заклинаний на клики и клавиши.
- **Cooldown Manager (`/fcdm`) и бой:** гибкие группы перезарядок, баффов, полос и напоминаний с авто-адаптацией под ветку талантов и режимами панелей; баннер низкой маны хила (`/fuimana`), счётчик урона/лечения/угрозы, всплывающий текст боя (`/nd`).
- **Сумки, сортировка и профессии:**
  - Единая сумка и банк с поиском, уровнем предметов, подсветкой непригодных вещей и списком валют.
  - Сортировщик сумок, банка и банка гильдии (`/fuisort`) с поддержкой профессиональных и ремесленных сумок.
  - Помощник наложения чар и ювелирного дела (`/fuienchant`): кнопки быстрого распыления и просеивания руды, пакетное переналожение чар.
  - Автопродажа серого хлама у торговца (`/fujunk`), карточки добычи и счётчики бросков.
- **Удобства:** быстрая привязка клавиш на панелях (`/fuibind` или кнопка **Remap** в главном меню), вкладки и иконки лута в чате, ID заклинаний в подсказках, миникарта с панелью кнопок аддонов, эффекты курсора, монитор FPS/пинга.

### Установка

1. Скачайте актуальный архив `ForeverUI.zip` со страницы [Releases](https://github.com/Radiant28/ForeverUI/releases).
2. Распакуйте папку `ForeverUI` в каталог игры:
   ```text
   <Папка с WoW>\Interface\AddOns\ForeverUI\
   ```
   Убедитесь, что внутри лежит файл `ForeverUI.toc` (а не вложенная папка `ForeverUI\ForeverUI\`).
3. Перезапустите клиент игры (для подгрузки новых `.tga`/`.blp` текстур после обновления требуется полный перезапуск клиента).

### Основные команды чата

| Команда | Назначение |
|---|---|
| `/fui` / `/foreverui` | Открыть окно настроек |
| `/fui install` | Запустить мастер первоначальной настройки |
| `/fui copy` | Скопировать настройки с другого персонажа |
| `/fcdm` / `/fcdm test` | Открыть / переключить тест Cooldown Manager |
| `/fuisort` | Сортировка сумок (`bank`, `deposit`, `withdraw`, `guild`, `stop`, `scan`) |
| `/fuienchant` | Помощник наложения чар / просеивания (`reset` для сброса) |
| `/fuiprd` | Настройки/тест панели ресурсов (`test`, `reset`) |
| `/fuiraid` | Диагностика фреймов группы и рейда |
| `/fuimana` | Диагностика/тест оповещения о мане хила (`test`) |
| `/fuibind` | Режим быстрой привязки клавиш к панелям действий |
| `/fuikeys [on\|off]` | Переключить панель подсказок Click-Casting |
| `/fujunk` | Продать серые предметы |
| `/wfn` | Команды неймплейтов |

---

<a id="foreverui-en"></a>
## 🇬🇧 English

**ForeverUI** is a comprehensive fan-made UI suite for **World of Warcraft 3.3.5a** (build `12340`, `## Interface: 30300`, tailored for the **Nozdor** server), styled after **WoW: Forever** with support for both **Classic** and **Retail** layouts.

> [!IMPORTANT]
> **Disclaimer:** ForeverUI is an **unofficial, non-commercial, fan-made addon**. It is not affiliated with, endorsed by, or sponsored by **Blizzard Entertainment** or the **Nozdor / WoW: Forever** team. See [License & Disclaimer](#license-and-disclaimer) for full legal details.

### Key Features

- **Setup Wizard (`/fui install`, `/fui copy`):** Guided first-run configuration by role (Tank, Healer, Melee DPS, Ranged DPS), layout style (Classic / Retail), auto UI scaling, module toggles, chat setup, and per-character / per-talent-spec profiles.
- **Edit Mode:** Drag-and-scale layout editor with custom grid sizing (slots & rows) for action bars, pet/totem bars, buff/debuff grids, and per-frame visibility toggles.
- **Unit Frames, Cast Bars & Nameplates (`/wfn`):** WoW Forever bronze-trimmed or Retail-styled unit frames, target reaction accents, custom cast bars, and feature-rich nameplates with threat, casts, and auras.
- **Window Skins (`/fuiframe`, `/fuiskin`):** Unified WoW Forever window framing across 40+ game frames (character, talents, spellbook, professions, bags, bank, guild bank, merchant, mail, world map, collections, store, etc.).
- **Personal Resource Display (`/fuiprd`):** Health, power, energy/5s ticks, runes, totems, combo points, soul shards, and smart proc/buff tracking beneath your character.
- **Party & Raid Frames (`/fuiraid`) + Click-Casting:** Cell-inspired indicators, buff whitelist, debuff exclusions, dispel highlights, hover/target frames, drink indicator, center growth, and click/keybind casting.
- **Cooldown Manager (`/fcdm`) & Combat:** Spec-adaptive cooldown/buff/bar/reminder trackers with zone-based modes and sound alerts; Healer Low Mana banner (`/fuimana`), Combat Meter, and Floating Combat Text (`/nd`).
- **Bags, Sorting & Professions:**
  - All-in-one bags and bank with search, item level labels, unusable item tinting, and a footer currency drawer.
  - Bag, Bank, and Guild Bank Sorter (`/fuisort`) with profession and custom crafting bag support.
  - Enchanting & Prospecting helper (`/fuienchant`): one-click disenchant/prospect overlay buttons and repeat re-enchanting.
  - Auto-sell grey items (`/fujunk`), styled loot cards, and group loot roll counters.
- **Quality of Life:** Hover keybinder (`/fuibind` or **Remap** in the game menu), auto chat tabs & loot icons, Spell IDs in tooltips, minimap & addon button bar, cursor trails, and FPS/latency monitor.

### Installation

1. Download the latest `ForeverUI.zip` from [Releases](https://github.com/Radiant28/ForeverUI/releases).
2. Extract the `ForeverUI` folder into your WoW AddOns directory:
   ```text
   <WoW Folder>\Interface\AddOns\ForeverUI\
   ```
   Make sure `ForeverUI.toc` is located directly inside `Interface\AddOns\ForeverUI\` (not nested as `ForeverUI\ForeverUI\`).
3. Restart the game client completely after installing or updating so newly added `.tga`/`.blp` textures are loaded by the 3.3.5a client.

### Testing (Development)

The addon uses Lua 5.1 semantics and includes an automated test suite in `tests/` runnable via Python `lupa` (`LuaJIT 2.1`):

```powershell
Get-ChildItem tests/*.lua | ForEach-Object {
    python -c "import lupa.luajit21 as L,sys;r=L.LuaRuntime();r.execute('arg={}');r.eval('function(p) return assert(loadfile(p))() end')(sys.argv[1])" $_.FullName
}
```

---

<a id="license-and-disclaimer"></a>
## ⚖️ Лицензия и отказ от ответственности / License & Disclaimer

### Русский

1. **Фанатский некоммерческий статус:**
   - ForeverUI — это **любительская (фанатская) модификация интерфейса**, созданная исключительно для личного и некоммерческого использования игроками.
   - Проект **не является официальным продуктом** Blizzard Entertainment, Inc. или сервера Nozdor / WoW: Forever.
   - Аддон распространяется **абсолютно бесплатно**; продажа аддона, его исходного кода или включённых графических ресурсов запрещена.

2. **Права на графику и торговые марки (Assets & Trademarks):**
   - Все оригинальные игровые текстуры, иконки, модели, звуки и торговые марки (*World of Warcraft*, *Wrath of the Lich King* и др.) принадлежат **Blizzard Entertainment, Inc.** и используются в рамках фанатских модификаций игры без претензий на право собственности.
   - Сторонние текстуры и библиотеки, включённые в состав аддона (включая ресурсы из **DragonUI** (лицензия MIT), **LibStub**, **CallbackHandler-1.0**, **LibSharedMedia-3.0**, **CursorUZ**, **MidUI**, **pretty_actionbar**, наборы иконок ролей из **Cell** / **MattUI** / **MiirGui** и шрифты/текстуры **SharedMedia**), сохраняют права и лицензии своих оригинальных авторов. Подробный перечень источников приведён в файле [Art/CREDITS.md](Art/CREDITS.md).
   - По первому обоснованному обращению правообладателя любой спорный ресурс будет незамедлительно удалён из репозитория.

3. **Лицензия на исходный код аддона (Lua):**
   - Оригинальный Lua-код, написанный для ForeverUI, распространяется по лицензии **MIT** (только в части собственного кода автора; действие лицензии MIT **не распространяется** на ассеты Blizzard Entertainment и сторонние ресурсы/библиотеки, перечисленные в [Art/CREDITS.md](Art/CREDITS.md) и `Libs/`).
   - Программное обеспечение предоставляется **«КАК ЕСТЬ» (AS IS)**, без каких-либо явных или подразумеваемых гарантий. Автор не несёт ответственности за любые сбои, потерю данных или последствия использования модификации.

---

### English

1. **Fan-Made & Non-Commercial Status:**
   - ForeverUI is an **unofficial, fan-made, non-commercial UI addon** created strictly for personal and community gameplay use.
   - This project is **not affiliated with, endorsed, sponsored, or approved by** Blizzard Entertainment, Inc. or the Nozdor / WoW: Forever project.
   - This addon is distributed **free of charge**. Selling or monetizing this addon or any of its bundled assets is strictly prohibited.

2. **Third-Party Assets & Trademarks:**
   - *World of Warcraft*, *Wrath of the Lich King*, and all original game artwork, icons, UI textures, and trademarks are the property of **Blizzard Entertainment, Inc.** No ownership of Blizzard intellectual property is claimed.
   - Third-party artwork and embedded libraries (including assets from **DragonUI** (MIT), **LibStub**, **CallbackHandler-1.0**, **LibSharedMedia-3.0**, **CursorUZ**, **MidUI**, **pretty_actionbar**, role icon sets from **Cell** / **MattUI** / **MiirGui**, and **SharedMedia** packs) remain the property of their respective authors under their original licenses. See [Art/CREDITS.md](Art/CREDITS.md) for full attribution.
   - If you are a copyright holder and believe any asset should be removed or attributed differently, please open an issue or contact the repository maintainer and it will be addressed promptly.

3. **Source Code License (Lua):**
   - Original Lua code authored for ForeverUI is provided under the **MIT License** (applicable solely to original ForeverUI code; **excluding** Blizzard Entertainment artwork and third-party libraries/assets listed in [Art/CREDITS.md](Art/CREDITS.md) and `Libs/`).
   - THE SOFTWARE IS PROVIDED **"AS IS"**, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY CLAIM, DAMAGES, OR OTHER LIABILITY ARISING FROM THE USE OF THIS ADDON.
