# ForeverTextures: что перенесено, а что нет

Опись `ForeverTextures/` на 12.11.2026 (с 13.11.2026 папка лежит вне аддона: `Interface/ForeverTextures/`): 662 файлов. Используются в коде: 12. Лежат копией в `Art/Forever/`, но код их не подключает: 43. Не перенесены: 607.

Чтобы перенести файл, отметьте его или назовите папку: `[x]` в списке ниже.

## План интеграции (только визуал, без MPQ)

Всё делается из аддона: текстуры лежат в `Art/Forever/`, код меняет только картинки штатных элементов. Откат: `Interface/ForeverUI-Backup/2026-11-12-frames-micro/restore.ps1`.

### Партия 1 — сделано 12.11.2026
- [x] Рамки игрока и цели, свечение боя — `uiunitframec60` → `Art/CharacterFrames.tga`, `*-ChromeGlow.tga`
- [x] Значки: уровень, фракция, лидер, добыча, роли, анимация отдыха — `Art/Forever/UnitBadges.tga`, `Rest-Flipbook.tga`
- [x] Иконки микроменю, подкова коллекций — `Art/Micro-Color.blp`
- [x] Полосы Stat, Gradient, Swirl, Raid в выборе текстур — `Media/statusbar/Forever-*.tga`
- [x] Фон основной панели, грифоны и виверны — `Art/Forever/Bar-Panel.tga`, `ActionBar-Caps.tga`
- [x] Рамка ячеек всех панелей (и подсветка микроменю) — `uiactionbarframe2xc60` → `Art/Forever/Slot-Frame.tga` (`ui.ApplySlotEdge`)
- [x] Рамка и фон подсказок (GameTooltip, ItemRef, сравнение, карта, друзья) — `uiframetooltip*c60` → `Art/Forever/Tooltip-*.tga` (`Tooltip.lua`)
- [x] Кольцо миникарты в Classic — `uiminimapc60` → `Art/Forever/Minimap-Ring.tga` (радиус тот же, кнопки не сдвигаются)
- [x] Фон и рамка полосы опыта в Classic, рамка полосы репутации — `uiexperiencebarcamelot` → `Art/Forever/XP-Frame.tga`
- [x] Комбо-очки на цели — `uiroguecombopointsc60` → `Art/Forever/Combo-Points.tga`
- [x] Фон пустой ячейки сумки — `bagsitemslot2xc60` → `Art/Forever/Bag-Slot.tga`

### Партия 2 — сделано 12.11.2026
- [x] Рамки группы, боссов, питомца, фокуса, цели цели — уже с оправой Forever: они рисуются стилями `player`/`target` в масштабе (компактный спрайт `uipartyframec60` не нужен)
- [x] Руны рыцаря смерти — `uideathknightrunes` → `Art/Forever/Runes.tga` (хук `SetTexture` иконки руны)
- [x] Фоны талантов по веткам, свои и при осмотре — `talentbackground*`, `talentsclassbackgrounddeathknight*` → `Art/Forever/Talents/` (`CharacterSkin.lua`; таланты питомца штатные)
- [x] Штатные кнопки окон (UIPanelButtonTemplate) — `128-redbutton-*` → `Art/Forever/Panel-Button.tga` (при открытии окна из списка `CharacterSkin`)
- [x] Стрелки миникарты к цели и к трупу — `rotating-minimap*arrow` (если клиент поддерживает смену; стрелка игрока в 3.3.5 — модель)

### Нужна настройка по скриншотам
В 3.3.5 рамка окна нарисована в одной картинке вместе с содержимым (например, `UI-Character-General-TopLeft`), отдельно её не заменить. Металлическую рамку Forever можно только наложить поверх, и для каждого окна нужно вымерить отступы по скриншоту, иначе она ляжет мимо края.
- [ ] Металлическая рамка, заголовок и вкладки окон — `uiframemetal2xc60`, `uiframediamondmetal*`, `uiframetabsc60`
- [ ] Страницы книги заклинаний — `spellbookbackgroundpage*2xc60`, `spellbookelementsc60`
- [ ] Журнал заданий и трекер — `questlogbackground`, `questtrackerc60`
- [ ] Окна торговца, банка, добычи, почты, аукциона — `merchant`, `bankframe*`, `lootframe`, фоны
- [ ] Выпадающие списки, флажки, поиск — `commondropdownc60`, `minimalcheckboxc60`, `commonsearch`

### Не переносится
- Экраны входа и создания персонажа (`glues`, `charactercreate`) — аддон до них не дотягивается.
- Механики без аналога в 3.3.5: питомцы в бою, жилище, гейм-пад, охотник на демонов, помощник ротации, WoW Labs, титры.
- Маски (`06_Masks_And_FX/*mask*`) — в 3.3.5 нет масок текстур.
- `unknown/*` — неизвестное назначение.

## Используются в коде

- `01_Frames_And_Borders/hud/uiunitframe.tga` (1024x512) — корона лидера, флажок добычи
- `01_Frames_And_Borders/hud/uiunitframec60.tga` (1024x512) — рамки игрока и цели, подложка уровня, эмблемы фракций
- `01_Frames_And_Borders/hud/uiunitframerestingflipbook.tga` (512x512) — анимация отдыха
- `03_Bars_And_Gradients/bars/statbarfill.tga` (512x32) — полоса WoW Forever Stat
- `03_Bars_And_Gradients/castingbar/uicastingbar.tga` (512x256) — полоса WoW Forever Swirl
- `03_Bars_And_Gradients/common/commonstatbarc60.tga` (256x128) — полоса WoW Forever Gradient
- `03_Bars_And_Gradients/raidframe/raidframehpfill.tga` (32x32) — полоса WoW Forever Raid
- `04_Icons_And_Portraits/lfgframe/groupfinder-icon-role-micro-dps.tga` (16x16) — значок роли
- `04_Icons_And_Portraits/lfgframe/groupfinder-icon-role-micro-heal.tga` (16x16) — значок роли
- `04_Icons_And_Portraits/lfgframe/groupfinder-icon-role-micro-tank.tga` (16x16) — значок роли
- `07_HUD_And_Atlases/hud/uiactionbarc60.tga` (512x512) — грифоны и виверны панели
- `07_HUD_And_Atlases/hud/uimicromenuc602x.tga` (1024x512) — иконки микроменю

## Скопированы в Art/Forever, но не подключены

- [ ] `01_Frames_And_Borders/characterframe/char-paperdoll-horizontal.tga` (32x16) — Art/Forever/characterframe/char-paperdoll-horizontal.tga
- [ ] `01_Frames_And_Borders/characterframe/char-paperdoll-parts.tga` (256x128) — Art/Forever/characterframe/char-paperdoll-parts.tga
- [ ] `01_Frames_And_Borders/characterframe/char-paperdoll-vertical.tga` (16x32) — Art/Forever/characterframe/char-paperdoll-vertical.tga
- [ ] `01_Frames_And_Borders/paperdollinfoframe/paperdollinfopart1c60.tga` (1024x1024) — Art/Forever/paperdollinfoframe/paperdollinfopart1c60.tga
- [ ] `01_Frames_And_Borders/paperdollinfoframe/paperdollinfopart2c60.tga` (1024x1024) — Art/Forever/paperdollinfoframe/paperdollinfopart2c60.tga
- [ ] `01_Frames_And_Borders/paperdollinfoframe/paperdollsidebartabs.tga` (64x256) — Art/Forever/paperdollinfoframe/paperdollsidebartabs.tga
- [ ] `02_Backgrounds/dialogframe/uiframedialogboxbackgrounddark.tga` (64x64) — Art/Forever-DarkGround.tga
- [ ] `03_Bars_And_Gradients/bars/statbarfillblue.tga` (512x32) — Art/Forever/Bars_And_Gradients/bars/statbarfillblue.tga
- [ ] `03_Bars_And_Gradients/buttons/minimalscrollbarproportional.tga` (128x64) — Art/Forever/Bars_And_Gradients/buttons/minimalscrollbarproportional.tga
- [ ] `03_Bars_And_Gradients/buttons/minimalscrollbarproportionalc60.tga` (128x64) — Art/Forever/Bars_And_Gradients/buttons/minimalscrollbarproportionalc60.tga
- [ ] `03_Bars_And_Gradients/buttons/minimalscrollbarsmallproportionalc60.tga` (64x64) — Art/Forever/Bars_And_Gradients/buttons/minimalscrollbarsmallproportionalc60.tga
- [ ] `03_Bars_And_Gradients/buttons/minimalscrollbarsmallverticalc60.tga` (64x1024) — Art/Forever/Bars_And_Gradients/buttons/minimalscrollbarsmallverticalc60.tga
- [ ] `03_Bars_And_Gradients/buttons/minimalscrollbarverticalc60.tga` (64x1024) — Art/Forever/Bars_And_Gradients/buttons/minimalscrollbarverticalc60.tga
- [ ] `03_Bars_And_Gradients/buttons/minimalsliderbarc60-hd.tga` (128x512) — Art/Forever/Bars_And_Gradients/buttons/minimalsliderbarc60-hd.tga
- [ ] `03_Bars_And_Gradients/buttons/minimalsliderbarc60.tga` (32x128) — Art/Forever/Bars_And_Gradients/buttons/minimalsliderbarc60.tga
- [ ] `03_Bars_And_Gradients/credits/_creditsscreen-gradient-tile.tga` (16x256) — Art/Forever/Bars_And_Gradients/credits/_creditsscreen-gradient-tile.tga
- [ ] `03_Bars_And_Gradients/credits/creditsscreen-highlight.tga` (512x64) — Art/Forever/Bars_And_Gradients/credits/creditsscreen-highlight.tga
- [ ] `03_Bars_And_Gradients/editmode/editmodeuihighlightbackground.tga` (16x16) — Art/Forever/Bars_And_Gradients/editmode/editmodeuihighlightbackground.tga
- [ ] `03_Bars_And_Gradients/friendsframe/ui-friendsframe-highlightbar-blue.tga` (256x32) — Art/Forever/Bars_And_Gradients/friendsframe/ui-friendsframe-highlightbar-blue.tga
- [ ] `03_Bars_And_Gradients/hud/combatassistanthighlight.tga` (1024x512) — Art/Forever/Bars_And_Gradients/hud/combatassistanthighlight.tga
- [ ] `03_Bars_And_Gradients/icons/spell_shadow_animatedead.tga` (64x64) — Art/Forever/Bars_And_Gradients/icons/spell_shadow_animatedead.tga
- [ ] `03_Bars_And_Gradients/icons/spell_shadow_deathcoil.tga` (64x64) — Art/Forever/Bars_And_Gradients/icons/spell_shadow_deathcoil.tga
- [ ] `03_Bars_And_Gradients/icons/spell_shadow_metamorphosis.tga` (64x64) — Art/Forever/Bars_And_Gradients/icons/spell_shadow_metamorphosis.tga
- [ ] `03_Bars_And_Gradients/icons/spell_shadow_rainoffire.tga` (64x64) — Art/Forever/Bars_And_Gradients/icons/spell_shadow_rainoffire.tga
- [ ] `03_Bars_And_Gradients/icons/spell_shadow_shadowwordpain.tga` (64x64) — Art/Forever/Bars_And_Gradients/icons/spell_shadow_shadowwordpain.tga
- [ ] `03_Bars_And_Gradients/icons/spell_shadow_summonimp.tga` (64x64) — Art/Forever/Bars_And_Gradients/icons/spell_shadow_summonimp.tga
- [ ] `03_Bars_And_Gradients/lfgframe/groupfinder-highlightbar-blue.tga` (512x32) — Art/Forever/Bars_And_Gradients/lfgframe/groupfinder-highlightbar-blue.tga
- [ ] `03_Bars_And_Gradients/lfgframe/groupfinder-highlightbar-yellow.tga` (512x32) — Art/Forever/Bars_And_Gradients/lfgframe/groupfinder-highlightbar-yellow.tga
- [ ] `03_Bars_And_Gradients/mainmenubar/ui-mainmenubar-performancebar.tga` (32x64) — Art/Forever/Bars_And_Gradients/mainmenubar/ui-mainmenubar-performancebar.tga
- [ ] `03_Bars_And_Gradients/petbattles/battlebar-swappetshadow.tga` (256x256) — Art/Forever/Bars_And_Gradients/petbattles/battlebar-swappetshadow.tga
- [ ] `03_Bars_And_Gradients/pvp/honorfill.tga` (256x256) — Art/Forever/Bars_And_Gradients/pvp/honorfill.tga
- [ ] `03_Bars_And_Gradients/pvp/honorfillhalf.tga` (256x256) — Art/Forever/Bars_And_Gradients/pvp/honorfillhalf.tga
- [ ] `03_Bars_And_Gradients/raidframe/raidframedispelfill.tga` (32x32) — Art/Forever/Bars_And_Gradients/raidframe/raidframedispelfill.tga
- [ ] `03_Bars_And_Gradients/raidframe/raidframehpbgwhite.tga` (32x32) — Art/Forever/Bars_And_Gradients/raidframe/raidframehpbgwhite.tga
- [ ] `03_Bars_And_Gradients/shop/shop-list-rule.tga` (1024x16) — Art/Forever/Bars_And_Gradients/shop/shop-list-rule.tga
- [ ] `03_Bars_And_Gradients/store/perks-char-shadow.tga` (512x128) — Art/Forever/Bars_And_Gradients/store/perks-char-shadow.tga
- [ ] `03_Bars_And_Gradients/tabicons/spell_shadow_animatedead.tga` (128x128) — Art/Forever/Bars_And_Gradients/tabicons/spell_shadow_animatedead.tga
- [ ] `03_Bars_And_Gradients/tabicons/spell_shadow_deathcoil.tga` (128x128) — Art/Forever/Bars_And_Gradients/tabicons/spell_shadow_deathcoil.tga
- [ ] `03_Bars_And_Gradients/tabicons/spell_shadow_metamorphosis.tga` (128x128) — Art/Forever/Bars_And_Gradients/tabicons/spell_shadow_metamorphosis.tga
- [ ] `03_Bars_And_Gradients/tabicons/spell_shadow_rainoffire.tga` (128x128) — Art/Forever/Bars_And_Gradients/tabicons/spell_shadow_rainoffire.tga
- [ ] `03_Bars_And_Gradients/tabicons/spell_shadow_shadowwordpain.tga` (128x128) — Art/Forever/Bars_And_Gradients/tabicons/spell_shadow_shadowwordpain.tga
- [ ] `03_Bars_And_Gradients/tabicons/spell_shadow_summonimp.tga` (128x128) — Art/Forever/Bars_And_Gradients/tabicons/spell_shadow_summonimp.tga
- [ ] `03_Bars_And_Gradients/taxiframe/ui-taxi-icon-highlight.tga` (32x32) — Art/Forever/Bars_And_Gradients/taxiframe/ui-taxi-icon-highlight.tga

## Не перенесены

### 01_Frames_And_Borders

**01_Frames_And_Borders/bankframe** (3)
- [ ] `bankframe.tga` (256x256)
- [ ] `bankframepanelc60.tga` (512x64)
- [ ] `bankframevertical.tga` (128x256)

**01_Frames_And_Borders/common** (7)
- [ ] `bluemenu-goldborder-horiz.tga` (64x128)
- [ ] `commonframedividerc60.tga` (16x64)
- [ ] `commoninsideframec60.tga` (128x128)
- [ ] `moneyframe.tga` (128x64)
- [ ] `ui-goldborder-!tile.tga` (128x128)
- [ ] `ui-goldborder-_tile.tga` (256x64)
- [ ] `ui-goldborder.tga` (256x128)

**01_Frames_And_Borders/dialogframe** (1)
- [ ] `uiframediamondmetalborder2xc60.tga` (256x256)

**01_Frames_And_Borders/framegeneral** (11)
- [ ] `uiframe.tga` (128x128)
- [ ] `uiframediamondmetal2xc60.tga` (256x1024)
- [ ] `uiframediamondmetalheader2xc60.tga` (256x512)
- [ ] `uiframediamondmetalvertical2xc60.tga` (512x128)
- [ ] `uiframehorizontal.tga` (256x128)
- [ ] `uiframemetal2xc60.tga` (1024x512)
- [ ] `uiframemetalhorizontal2xc60.tga` (256x512)
- [ ] `uiframemetalvertical2xc60.tga` (512x256)
- [ ] `uiframetabs.tga` (64x256)
- [ ] `uiframetabsc60.tga` (64x128)
- [ ] `uiframevertical.tga` (64x256)

**01_Frames_And_Borders/gamepad** (1)
- [ ] `gamepadmapframe.tga` (2048x2048)

**01_Frames_And_Borders/glues/common** (4)
- [ ] `uiframetooltipgluesc60-hd.tga` (128x512)
- [ ] `uiframetooltipgluesc60.tga` (32x128)
- [ ] `uiframetooltipgluesverticalc60-hd.tga` (256x64)
- [ ] `uiframetooltipgluesverticalc60.tga` (64x16)

**01_Frames_And_Borders/guildbankframe** (3)
- [ ] `corners.tga` (64x256)
- [ ] `horiztile.tga` (256x16)
- [ ] `verttile.tga` (16x256)

**01_Frames_And_Borders/guildframe** (1)
- [ ] `guildframe.tga` (1024x512)

**01_Frames_And_Borders/helpframe** (1)
- [ ] `cs_helptextures_tile.tga` (128x512)

**01_Frames_And_Borders/hud** (8)
- [ ] `groupfinder-eye-frame.tga` (64x64)
- [ ] `uiactionbarframe2xc60.tga` (128x128)
- [ ] `uidebuffframes.tga` (256x128)
- [ ] `uipartyframe.tga` (256x256)
- [ ] `uipartyframec60.tga` (256x256)
- [ ] `uiunitframeboss.tga` (256x256)
- [ ] `uiunitframebossc60.tga` (256x256)
- [ ] `uiunitframehorizontal.tga` (16x16)

**01_Frames_And_Borders/itemsocketingframe** (4)
- [ ] `sockets.tga` (512x256)
- [ ] `ui-itemsocketingframe-_tile.tga` (256x128)
- [ ] `ui-itemsocketingframe.tga` (256x256)
- [ ] `ui-itemsocketparchementframe-left.tga` (16x128)

**01_Frames_And_Borders/lootframe** (1)
- [ ] `lootframe.tga` (512x1024)

**01_Frames_And_Borders/macroframe** (2)
- [ ] `macropopupc60.tga` (256x256)
- [ ] `macropopupverticalc60.tga` (128x256)

**01_Frames_And_Borders/moneyframe** (1)
- [ ] `ui-moneyframe-border.tga` (128x32)

**01_Frames_And_Borders/professions** (6)
- [ ] `professions-skillbar-frame.tga` (512x32)
- [ ] `professions-slot-frame-blue.tga` (64x64)
- [ ] `professions-slot-frame-epic.tga` (64x64)
- [ ] `professions-slot-frame-green.tga` (64x64)
- [ ] `professions-slot-frame-legendary.tga` (64x64)
- [ ] `professions-slot-frame.tga` (64x64)

**01_Frames_And_Borders/questframe** (1)
- [ ] `questlogframe.tga` (512x512)

**01_Frames_And_Borders/raidframe** (3)
- [ ] `raidframe.tga` (256x128)
- [ ] `raidframehorizontal.tga` (16x64)
- [ ] `raidframevertical.tga` (64x32)

**01_Frames_And_Borders/tooltip** (1)
- [ ] `tooltiplabel.tga` (128x32)

**01_Frames_And_Borders/tooltips** (4)
- [ ] `uiframetooltipc60-hd.tga` (64x256)
- [ ] `uiframetooltipc60.tga` (16x64)
- [ ] `uiframetooltipverticalc60-hd.tga` (128x64)
- [ ] `uiframetooltipverticalc60.tga` (32x16)

### 02_Backgrounds

**02_Backgrounds/auctionframe** (3)
- [ ] `auctionhouse-background-categories.tga` (256x512)
- [ ] `auctionhouse-background-index.tga` (1024x512)
- [ ] `auctionhouse-background-sell-left.tga` (512x512)

**02_Backgrounds/bankframe** (1)
- [ ] `bankframebackgroundc60.tga` (256x256)

**02_Backgrounds/charactercreate** (2)
- [ ] `portrait-charactercreate-icon-alliancebg.tga` (128x128)
- [ ] `portrait-charactercreate-icon-hordebg.tga` (128x128)

**02_Backgrounds/credits** (3)
- [ ] `creditsscreenbackground0wowc60.tga` (512x512)
- [ ] `creditsscreenbackground1bc.tga` (512x512)
- [ ] `creditsscreenbackground2wotlk.tga` (512x512)

**02_Backgrounds/dialogframe** (1)
- [ ] `uiframedialogboxbackground.tga` (64x64)

**02_Backgrounds/editmode** (1)
- [ ] `editmodeuiselectedbackground.tga` (16x16)

**02_Backgrounds/framegeneral** (3)
- [ ] `ui-background-marble.tga` (256x256)
- [ ] `ui-background-rock.tga` (1024x1024)
- [ ] `uiframebackground.tga` (64x32)

**02_Backgrounds/gamepad** (1)
- [ ] `gamepadmapbackgroundtile.tga` (256x256)

**02_Backgrounds/glues/charactercreate** (1)
- [ ] `charactercreatestartingzonesexilesreach.tga` (1024x1024)

**02_Backgrounds/glues/characterselect** (1)
- [ ] `heavybronzeframebackgroundc60.tga` (1024x1024)

**02_Backgrounds/glyphes** (1)
- [ ] `glyphes-fond.tga` (1024x1024)

**02_Backgrounds/guildbankframe** (1)
- [ ] `guildvaultbg.tga` (256x256)

**02_Backgrounds/hud** (1)
- [ ] `uiminimapbackground.tga` (32x32)

**02_Backgrounds/lfgframe** (2)
- [ ] `groupfinder-background.tga` (512x512)
- [ ] `ui-lfg-bluebg.tga` (512x128)

**02_Backgrounds/mailframe** (1)
- [ ] `ui-mailframebg.tga` (512x512)

**02_Backgrounds/petstableframe** (3)
- [ ] `hunter-stable-bg-art_cunning.tga` (1024x1024)
- [ ] `hunter-stable-bg-art_ferocity.tga` (1024x1024)
- [ ] `hunter-stable-bg-art_tenacity.tga` (1024x1024)

**02_Backgrounds/professions** (18)
- [ ] `professionbackgroundart.tga` (1024x1024)
- [ ] `professioncardbackgroundalchemyc60.tga` (1024x1024)
- [ ] `professioncardbackgroundblacksmithingc60.tga` (1024x1024)
- [ ] `professioncardbackgroundcookingc60.tga` (512x512)
- [ ] `professioncardbackgroundenchantingc60.tga` (1024x1024)
- [ ] `professioncardbackgroundengineeringc60.tga` (1024x1024)
- [ ] `professioncardbackgroundfirstaidc60.tga` (512x512)
- [ ] `professioncardbackgroundgenericc60.tga` (1024x512)
- [ ] `professioncardbackgroundherbalismc60.tga` (1024x1024)
- [ ] `professioncardbackgroundleatherworkingc60.tga` (1024x1024)
- [ ] `professioncardbackgroundminingc60.tga` (1024x1024)
- [ ] `professioncardbackgroundskinningc60.tga` (1024x1024)
- [ ] `professioncardbackgroundtailoringc60.tga` (1024x1024)
- [ ] `professionoverviewbackgroundc60.tga` (1024x1024)
- [ ] `professions-background-summarylist.tga` (512x1024)
- [ ] `professions-skillbar-bg.tga` (512x32)
- [ ] `professions-slot-bg.tga` (64x64)
- [ ] `professiontrainerbackgroundc60.tga` (1024x1024)

**02_Backgrounds/questframe** (3)
- [ ] `questbackgroundparchment.tga` (1024x1024)
- [ ] `questlogbackground.tga` (1024x512)
- [ ] `questlogbackground2x.tga` (1024x512)

**02_Backgrounds/spellbook** (2)
- [ ] `spellbookbackgroundpageleft2xc60.tga` (1024x1024)
- [ ] `spellbookbackgroundpageright2xc60.tga` (1024x1024)

**02_Backgrounds/talentframe** (10)
- [ ] `talentbackgrounddruid.tga` (1024x1024)
- [ ] `talentbackgroundhunter.tga` (1024x1024)
- [ ] `talentbackgroundmage.tga` (1024x1024)
- [ ] `talentbackgroundpaladin.tga` (1024x1024)
- [ ] `talentbackgroundpriest.tga` (1024x1024)
- [ ] `talentbackgroundrogue.tga` (1024x1024)
- [ ] `talentbackgroundwarlock.tga` (1024x1024)
- [ ] `talentbackgroundwarrior.tga` (1024x1024)
- [ ] `talentsclassbackgrounddeathknight1.tga` (1024x1024)
- [ ] `talentsclassbackgrounddeathknight2.tga` (1024x512)

**02_Backgrounds/talentframes** (1)
- [ ] `talentbackgroundshaman.tga` (1024x1024)

**02_Backgrounds/tooltips** (1)
- [ ] `uiframetooltipbackgroundc60.tga` (64x64)

### 04_Icons_And_Portraits

**04_Icons_And_Portraits/charactercreate** (50)
- [ ] `bouton-classicon-deathknight.tga` (128x128)
- [ ] `bouton-classicon-druid.tga` (128x128)
- [ ] `bouton-classicon-hunter.tga` (128x128)
- [ ] `bouton-classicon-mage.tga` (128x128)
- [ ] `bouton-classicon-paladin.tga` (128x128)
- [ ] `bouton-classicon-priest.tga` (128x128)
- [ ] `bouton-classicon-rogue.tga` (128x128)
- [ ] `bouton-classicon-shaman.tga` (128x128)
- [ ] `bouton-classicon-warlock.tga` (128x128)
- [ ] `bouton-classicon-warrior.tga` (128x128)
- [ ] `bouton-raceicon128-bloodelf-female.tga` (128x128)
- [ ] `bouton-raceicon128-bloodelf-male.tga` (128x128)
- [ ] `bouton-raceicon128-draenei-female.tga` (128x128)
- [ ] `bouton-raceicon128-draenei-male.tga` (128x128)
- [ ] `bouton-raceicon128-dwarf-female.tga` (128x128)
- [ ] `bouton-raceicon128-dwarf-male.tga` (128x128)
- [ ] `bouton-raceicon128-gnome-female.tga` (128x128)
- [ ] `bouton-raceicon128-gnome-male.tga` (128x128)
- [ ] `bouton-raceicon128-human-female.tga` (128x128)
- [ ] `bouton-raceicon128-human-male.tga` (128x128)
- [ ] `bouton-raceicon128-nightelf-female.tga` (128x128)
- [ ] `bouton-raceicon128-nightelf-male.tga` (128x128)
- [ ] `bouton-raceicon128-orc-female.tga` (128x128)
- [ ] `bouton-raceicon128-orc-male.tga` (128x128)
- [ ] `bouton-raceicon128-tauren-female.tga` (128x128)
- [ ] `bouton-raceicon128-tauren-male.tga` (128x128)
- [ ] `bouton-raceicon128-troll-female.tga` (128x128)
- [ ] `bouton-raceicon128-troll-male.tga` (128x128)
- [ ] `bouton-raceicon128-undead-female.tga` (128x128)
- [ ] `bouton-raceicon128-undead-male.tga` (128x128)
- [ ] `portrait-raceicon128-bloodelf-female.tga` (128x128)
- [ ] `portrait-raceicon128-bloodelf-male.tga` (128x128)
- [ ] `portrait-raceicon128-draenei-female.tga` (128x128)
- [ ] `portrait-raceicon128-draenei-male.tga` (128x128)
- [ ] `portrait-raceicon128-dwarf-female.tga` (128x128)
- [ ] `portrait-raceicon128-dwarf-male.tga` (128x128)
- [ ] `portrait-raceicon128-gnome-female.tga` (128x128)
- [ ] `portrait-raceicon128-gnome-male.tga` (128x128)
- [ ] `portrait-raceicon128-human-female.tga` (128x128)
- [ ] `portrait-raceicon128-human-male.tga` (128x128)
- [ ] `portrait-raceicon128-nightelf-female.tga` (128x128)
- [ ] `portrait-raceicon128-nightelf-male.tga` (128x128)
- [ ] `portrait-raceicon128-orc-female.tga` (128x128)
- [ ] `portrait-raceicon128-orc-male.tga` (128x128)
- [ ] `portrait-raceicon128-tauren-female.tga` (128x128)
- [ ] `portrait-raceicon128-tauren-male.tga` (128x128)
- [ ] `portrait-raceicon128-troll-female.tga` (128x128)
- [ ] `portrait-raceicon128-troll-male.tga` (128x128)
- [ ] `portrait-raceicon128-undead-female.tga` (128x128)
- [ ] `portrait-raceicon128-undead-male.tga` (128x128)

**04_Icons_And_Portraits/common** (9)
- [ ] `common-icon-backarrow-disable.tga` (256x256)
- [ ] `common-icon-backarrow.tga` (256x256)
- [ ] `common-icon-forwardarrow-disable.tga` (256x256)
- [ ] `common-icon-forwardarrow.tga` (256x256)
- [ ] `common-icon-rotateleft.tga` (128x128)
- [ ] `common-icon-rotateright.tga` (128x128)
- [ ] `common-icon-undo.tga` (256x256)
- [ ] `commonicons.tga` (2048x1024)
- [ ] `whiteiconframe.tga` (64x64)

**04_Icons_And_Portraits/friendsframe** (2)
- [ ] `battlenet-portrait-hd.tga` (128x128)
- [ ] `battlenet-portrait.tga` (64x64)

**04_Icons_And_Portraits/glues** (39)
- [ ] `charactercreate-icon-alliance.tga` (256x256)
- [ ] `charactercreate-icon-dice.tga` (256x256)
- [ ] `charactercreate-icon-horde.tga` (256x256)
- [ ] `classicon-deathknight.tga` (128x128)
- [ ] `classicon-druid.tga` (128x128)
- [ ] `classicon-hunter.tga` (128x128)
- [ ] `classicon-mage.tga` (128x128)
- [ ] `classicon-paladin.tga` (128x128)
- [ ] `classicon-priest.tga` (128x128)
- [ ] `classicon-rogue.tga` (128x128)
- [ ] `classicon-shaman.tga` (128x128)
- [ ] `classicon-warlock.tga` (128x128)
- [ ] `classicon-warrior.tga` (128x128)
- [ ] `glues-characterselect-icon-appearancechange-2x.tga` (128x128)
- [ ] `glues-characterselect-icon-appearancechange-hover-2x.tga` (128x128)
- [ ] `glues-characterselect-icon-factionchange-2x.tga` (128x128)
- [ ] `glues-characterselect-icon-factionchange-hover-2x.tga` (128x128)
- [ ] `glues-characterselect-icon-racechange-2x.tga` (128x128)
- [ ] `glues-characterselect-icon-racechange-hover-2x.tga` (128x128)
- [ ] `raceicon128-bloodelf-female.tga` (128x128)
- [ ] `raceicon128-bloodelf-male.tga` (128x128)
- [ ] `raceicon128-draenei-female.tga` (128x128)
- [ ] `raceicon128-draenei-male.tga` (128x128)
- [ ] `raceicon128-dwarf-female.tga` (128x128)
- [ ] `raceicon128-dwarf-male.tga` (128x128)
- [ ] `raceicon128-gnome-female.tga` (128x128)
- [ ] `raceicon128-gnome-male.tga` (128x128)
- [ ] `raceicon128-human-female.tga` (128x128)
- [ ] `raceicon128-human-male.tga` (128x128)
- [ ] `raceicon128-nightelf-female.tga` (128x128)
- [ ] `raceicon128-nightelf-male.tga` (128x128)
- [ ] `raceicon128-orc-female.tga` (128x128)
- [ ] `raceicon128-orc-male.tga` (128x128)
- [ ] `raceicon128-tauren-female.tga` (128x128)
- [ ] `raceicon128-tauren-male.tga` (128x128)
- [ ] `raceicon128-troll-female.tga` (128x128)
- [ ] `raceicon128-troll-male.tga` (128x128)
- [ ] `raceicon128-undead-female.tga` (128x128)
- [ ] `raceicon128-undead-male.tga` (128x128)

**04_Icons_And_Portraits/guildframe** (2)
- [ ] `guildemblems_01.tga` (256x256)
- [ ] `guildemblemslg_01.tga` (1024x1024)

**04_Icons_And_Portraits/icons** (72)
- [ ] `ability_backstab.tga` (64x64)
- [ ] `ability_dualwieldspecialization.tga` (64x64)
- [ ] `ability_hunter_beasttaming.tga` (64x64)
- [ ] `ability_hunter_swiftstrike.tga` (64x64)
- [ ] `ability_marksmanship.tga` (64x64)
- [ ] `ability_racial_bearform.tga` (64x64)
- [ ] `ability_racial_jackofalltrades.tga` (64x64)
- [ ] `ability_racial_packhobgoblin.tga` (64x64)
- [ ] `ability_rogue_eviscerate.tga` (64x64)
- [ ] `ability_stealth.tga` (64x64)
- [ ] `ability_warrior_innerrage.tga` (64x64)
- [ ] `achievement_general_stayclassy.tga` (64x64)
- [ ] `achievement_guildperk_everybodysfriend.tga` (64x64)
- [ ] `achievement_guildperk_honorablemention.tga` (64x64)
- [ ] `achievement_guildperk_mobilebanking.tga` (64x64)
- [ ] `classicon_deathknight.tga` (64x64)
- [ ] `classicon_druid.tga` (64x64)
- [ ] `classicon_hunter.tga` (64x64)
- [ ] `classicon_mage.tga` (64x64)
- [ ] `classicon_paladin.tga` (64x64)
- [ ] `classicon_priest.tga` (64x64)
- [ ] `classicon_rogue.tga` (64x64)
- [ ] `classicon_shaman.tga` (64x64)
- [ ] `classicon_warlock.tga` (64x64)
- [ ] `classicon_warrior.tga` (64x64)
- [ ] `inv_helmet_08.tga` (64x64)
- [ ] `inv_inscription_tradeskill01.tga` (64x64)
- [ ] `inv_misc_book_09.tga` (64x64)
- [ ] `inv_misc_food_15.tga` (64x64)
- [ ] `inv_misc_gem_01.tga` (64x64)
- [ ] `inv_misc_scrollunrolled01.tga` (64x64)
- [ ] `inv_shield_06.tga` (64x64)
- [ ] `inv_sidetab_bank_c60.tga` (64x64)
- [ ] `inv_sidetab_currency_c60.tga` (64x64)
- [ ] `inv_sidetab_honor_alliance_c60.tga` (64x64)
- [ ] `inv_sidetab_honor_horde_c60.tga` (64x64)
- [ ] `inv_sidetab_professions_c60-rond.tga` (128x128)
- [ ] `inv_sidetab_professions_c60.tga` (64x64)
- [ ] `inv_sidetab_reputation2_c60.tga` (64x64)
- [ ] `inv_sidetab_stats_c60.tga` (64x64)
- [ ] `mountjournalportrait.tga` (64x64)
- [ ] `petjournalportrait.tga` (64x64)
- [ ] `pvpcurrency-honor-alliance.tga` (64x64)
- [ ] `pvpcurrency-honor-horde.tga` (64x64)
- [ ] `spell_deathknight_bloodpresence.tga` (64x64)
- [ ] `spell_deathknight_frostpresence.tga` (64x64)
- [ ] `spell_deathknight_unholypresence.tga` (64x64)
- [ ] `spell_fire_firebolt02.tga` (64x64)
- [ ] `spell_frost_frostbolt02.tga` (64x64)
- [ ] `spell_holy_auraoflight.tga` (64x64)
- [ ] `spell_holy_devotionaura.tga` (64x64)
- [ ] `spell_holy_guardianspirit.tga` (64x64)
- [ ] `spell_holy_holybolt.tga` (64x64)
- [ ] `spell_holy_magicalsentry.tga` (64x64)
- [ ] `spell_holy_sealofsacrifice.tga` (64x64)
- [ ] `spell_holy_wordfortitude.tga` (64x64)
- [ ] `spell_nature_healingtouch.tga` (64x64)
- [ ] `spell_nature_lightning.tga` (64x64)
- [ ] `spell_nature_lightningshield.tga` (64x64)
- [ ] `spell_nature_magicimmunity.tga` (64x64)
- [ ] `spell_nature_starfall.tga` (64x64)
- [ ] `trade_alchemy.tga` (64x64)
- [ ] `trade_archaeology_chestoftinyglassanimals.tga` (64x64)
- [ ] `trade_blacksmithing.tga` (64x64)
- [ ] `trade_engineering.tga` (64x64)
- [ ] `trade_engraving.tga` (64x64)
- [ ] `trade_leatherworking.tga` (64x64)
- [ ] `trade_mining.tga` (64x64)
- [ ] `trade_tailoring.tga` (64x64)
- [ ] `ui-hud-actionbar-bag.tga` (256x256)
- [ ] `ui_chat.tga` (64x64)
- [ ] `xp_icon.tga` (64x64)

**04_Icons_And_Portraits/lfgframe** (14)
- [ ] `groupfinder-icon-class-deathknight.tga` (32x32)
- [ ] `groupfinder-icon-class-druid.tga` (32x32)
- [ ] `groupfinder-icon-class-hunter.tga` (32x32)
- [ ] `groupfinder-icon-class-mage.tga` (32x32)
- [ ] `groupfinder-icon-class-paladin.tga` (32x32)
- [ ] `groupfinder-icon-class-priest.tga` (32x32)
- [ ] `groupfinder-icon-class-rogue.tga` (32x32)
- [ ] `groupfinder-icon-class-shaman.tga` (32x32)
- [ ] `groupfinder-icon-class-warlock.tga` (32x32)
- [ ] `groupfinder-icon-class-warrior.tga` (32x32)
- [ ] `roleicons.tga` (64x32)
- [ ] `ui-lfg-roleicon-dps-micro-groupfinder.tga` (32x32)
- [ ] `ui-lfg-roleicon-healer-micro-groupfinder.tga` (32x32)
- [ ] `ui-lfg-roleicon-tank-micro-groupfinder.tga` (32x32)

**04_Icons_And_Portraits/minimap** (4)
- [ ] `ROTATING-MINIMAPGROUPARROW.tga` (64x64)
- [ ] `rotating-minimaparrow.tga` (64x64)
- [ ] `rotating-minimapcorpsearrow.tga` (64x64)
- [ ] `rotating-minimapguidearrow.tga` (64x64)

**04_Icons_And_Portraits/professions** (3)
- [ ] `professions-icon-skill-high.tga` (16x16)
- [ ] `professions-icon-skill-low.tga` (16x16)
- [ ] `professions-icon-skill-medium.tga` (16x16)

**04_Icons_And_Portraits/questframe** (1)
- [ ] `ui-questlog-bookicon.tga` (64x64)

**04_Icons_And_Portraits/spellbook** (2)
- [ ] `glyphiconspellbook.tga` (32x32)
- [ ] `portrait.tga` (128x128)

**04_Icons_And_Portraits/tabicons** (62)
- [ ] `ability_backstab.tga` (128x128)
- [ ] `ability_dualwieldspecialization.tga` (128x128)
- [ ] `ability_hunter_beasttaming.tga` (128x128)
- [ ] `ability_hunter_swiftstrike.tga` (128x128)
- [ ] `ability_marksmanship.tga` (128x128)
- [ ] `ability_racial_bearform.tga` (128x128)
- [ ] `ability_racial_jackofalltrades.tga` (128x128)
- [ ] `ability_racial_packhobgoblin.tga` (128x128)
- [ ] `ability_rogue_eviscerate.tga` (128x128)
- [ ] `ability_stealth.tga` (128x128)
- [ ] `ability_warrior_innerrage.tga` (128x128)
- [ ] `achievement_general_stayclassy.tga` (128x128)
- [ ] `achievement_guildperk_mobilebanking.tga` (128x128)
- [ ] `classicon_deathknight.tga` (128x128)
- [ ] `classicon_druid.tga` (128x128)
- [ ] `classicon_hunter.tga` (128x128)
- [ ] `classicon_mage.tga` (128x128)
- [ ] `classicon_paladin.tga` (128x128)
- [ ] `classicon_priest.tga` (128x128)
- [ ] `classicon_rogue.tga` (128x128)
- [ ] `classicon_shaman.tga` (128x128)
- [ ] `classicon_warlock.tga` (128x128)
- [ ] `classicon_warrior.tga` (128x128)
- [ ] `inv_helmet_08.tga` (128x128)
- [ ] `inv_inscription_tradeskill01.tga` (128x128)
- [ ] `inv_misc_food_15.tga` (128x128)
- [ ] `inv_misc_gem_01.tga` (128x128)
- [ ] `inv_shield_06.tga` (128x128)
- [ ] `inv_sidetab_bank_c60.tga` (128x128)
- [ ] `inv_sidetab_currency_c60.tga` (128x128)
- [ ] `inv_sidetab_honor_alliance_c60.tga` (128x128)
- [ ] `inv_sidetab_honor_horde_c60.tga` (128x128)
- [ ] `inv_sidetab_professions_c60.tga` (128x128)
- [ ] `inv_sidetab_reputation2_c60.tga` (128x128)
- [ ] `inv_sidetab_stats_c60.tga` (128x128)
- [ ] `mountjournalportrait.tga` (128x128)
- [ ] `petjournalportrait.tga` (128x128)
- [ ] `spell_deathknight_bloodpresence.tga` (128x128)
- [ ] `spell_deathknight_frostpresence.tga` (128x128)
- [ ] `spell_deathknight_unholypresence.tga` (128x128)
- [ ] `spell_fire_firebolt02.tga` (128x128)
- [ ] `spell_frost_frostbolt02.tga` (128x128)
- [ ] `spell_holy_auraoflight.tga` (128x128)
- [ ] `spell_holy_devotionaura.tga` (128x128)
- [ ] `spell_holy_guardianspirit.tga` (128x128)
- [ ] `spell_holy_holybolt.tga` (128x128)
- [ ] `spell_holy_magicalsentry.tga` (128x128)
- [ ] `spell_holy_sealofsacrifice.tga` (128x128)
- [ ] `spell_holy_wordfortitude.tga` (128x128)
- [ ] `spell_nature_healingtouch.tga` (128x128)
- [ ] `spell_nature_lightning.tga` (128x128)
- [ ] `spell_nature_lightningshield.tga` (128x128)
- [ ] `spell_nature_magicimmunity.tga` (128x128)
- [ ] `spell_nature_starfall.tga` (128x128)
- [ ] `trade_alchemy.tga` (128x128)
- [ ] `trade_archaeology_chestoftinyglassanimals.tga` (128x128)
- [ ] `trade_blacksmithing.tga` (128x128)
- [ ] `trade_engineering.tga` (128x128)
- [ ] `trade_engraving.tga` (128x128)
- [ ] `trade_leatherworking.tga` (128x128)
- [ ] `trade_mining.tga` (128x128)
- [ ] `trade_tailoring.tga` (128x128)

**04_Icons_And_Portraits/talentframe** (1)
- [ ] `talentsarrowline.tga` (16x128)

**04_Icons_And_Portraits/talents** (10)
- [ ] `portrait_deathknight.tga` (128x128)
- [ ] `portrait_druid.tga` (128x128)
- [ ] `portrait_hunter.tga` (128x128)
- [ ] `portrait_mage.tga` (128x128)
- [ ] `portrait_paladin.tga` (128x128)
- [ ] `portrait_priest.tga` (128x128)
- [ ] `portrait_rogue.tga` (128x128)
- [ ] `portrait_shaman.tga` (128x128)
- [ ] `portrait_warlock.tga` (128x128)
- [ ] `portrait_warrior.tga` (128x128)

**04_Icons_And_Portraits/taxiframe** (3)
- [ ] `ui-taxi-icon-green.tga` (16x16)
- [ ] `ui-taxi-icon-nub.tga` (16x16)
- [ ] `ui-taxi-icon-white.tga` (16x16)

### 05_Buttons_And_Controls

**05_Buttons_And_Controls/buttons** (34)
- [ ] `128-redbutton-arrowdown-c60.tga` (256x128)
- [ ] `128-redbutton-arrowdown-disabled-c60.tga` (256x128)
- [ ] `128-redbutton-arrowdown-highlight.tga` (256x128)
- [ ] `128-redbutton-arrowdown-pressed-c60.tga` (256x128)
- [ ] `128-redbutton-arrowupglow-c60.tga` (256x128)
- [ ] `128-redbutton-arrowupglow-disabled-c60.tga` (256x128)
- [ ] `128-redbutton-arrowupglow-highlight.tga` (256x128)
- [ ] `128-redbutton-arrowupglow-pressed-c60.tga` (256x128)
- [ ] `128-redbutton-delete-c60.tga` (128x128)
- [ ] `128-redbutton-delete-disabled-c60.tga` (128x128)
- [ ] `128-redbutton-delete-highlight.tga` (128x128)
- [ ] `128-redbutton-delete-pressed-c60.tga` (128x128)
- [ ] `128-redbutton-exit-c60.tga` (256x128)
- [ ] `128-redbutton-exit-disabled-c60.tga` (256x128)
- [ ] `128-redbutton-exit-highlight.tga` (256x128)
- [ ] `128-redbutton-exit-pressed-c60.tga` (256x128)
- [ ] `128-redbutton-highlight.tga` (512x128)
- [ ] `128-redbutton-left-c60.tga` (128x128)
- [ ] `128-redbutton-left-disabled-c60.tga` (128x128)
- [ ] `128-redbutton-left-pressed-c60.tga` (128x128)
- [ ] `128-redbutton-right-c60.tga` (512x128)
- [ ] `128-redbutton-right-disabled-c60.tga` (512x128)
- [ ] `128-redbutton-right-pressed-c60.tga` (512x128)
- [ ] `128redbuttonpart2.tga` (1024x512)
- [ ] `128redbuttonpart2c60.tga` (512x512)
- [ ] `_128-redbutton-center-c60.tga` (128x128)
- [ ] `_128-redbutton-center-disabled-c60.tga` (128x128)
- [ ] `_128-redbutton-center-pressed-c60.tga` (128x128)
- [ ] `redbuttonsc60.tga` (256x128)
- [ ] `squarebuttontextures.tga` (64x64)
- [ ] `ui-refreshbutton.tga` (16x16)
- [ ] `ui-silver-button-select.tga` (128x32)
- [ ] `ui-squarebutton-down.tga` (32x32)
- [ ] `ui-squarebutton-up.tga` (32x32)

**05_Buttons_And_Controls/common** (6)
- [ ] `common-button-square-gray-down-c60.tga` (256x256)
- [ ] `common-button-square-gray-up-c60.tga` (256x256)
- [ ] `commonbuttonlistc60.tga` (512x512)
- [ ] `commonbuttonsdropdown.tga` (64x64)
- [ ] `commonbuttontertiaryc60.tga` (256x256)
- [ ] `commongraybuttonentryboxc60.tga` (1024x1024)

**05_Buttons_And_Controls/credits** (4)
- [ ] `creditsscreen-assets-buttons-fastforward.tga` (256x256)
- [ ] `creditsscreen-assets-buttons-pause.tga` (256x256)
- [ ] `creditsscreen-assets-buttons-play.tga` (256x256)
- [ ] `creditsscreen-assets-buttons-rewind.tga` (256x256)

**05_Buttons_And_Controls/dialogframe** (1)
- [ ] `colorpicker.tga` (64x256)

**05_Buttons_And_Controls/glues** (3)
- [ ] `charactercreate-customize-palette-glow.tga` (128x32)
- [ ] `charactercreate-customize-palette-selected.tga` (128x64)
- [ ] `charactercreate-customize-palette.tga` (128x32)

**05_Buttons_And_Controls/glues/common** (2)
- [ ] `cinematicbuttonsatlas.tga` (1024x512)
- [ ] `cinematicbuttonslargeatlas.tga` (1024x1024)

**05_Buttons_And_Controls/hud** (1)
- [ ] `combatassistantsinglebutton2x.tga` (1024x1024)

**05_Buttons_And_Controls/lfgframe** (5)
- [ ] `groupfinder-button-cover.tga` (512x64)
- [ ] `groupfinder-button-custom-pve.tga` (512x64)
- [ ] `groupfinder-button-dungeons.tga` (512x64)
- [ ] `groupfinder-button-questing.tga` (512x64)
- [ ] `groupfinder-button-raids-warlords.tga` (512x64)

### 06_Masks_And_FX

**06_Masks_And_FX/castingbar** (1)
- [ ] `uicastingbarfx.tga` (1024x512)

**06_Masks_And_FX/characterframe** (1)
- [ ] `tempportraitalphamask.tga` (128x128)

**06_Masks_And_FX/common** (7)
- [ ] `commonsidetabmask2xc60.tga` (110x120)
- [ ] `commonstatbarmaskc60.tga` (67x29)
- [ ] `shadowoverlay-bottom.tga` (8x64)
- [ ] `shadowoverlay-corner.tga` (64x64)
- [ ] `shadowoverlay-left.tga` (64x8)
- [ ] `shadowoverlay-right.tga` (64x8)
- [ ] `shadowoverlay-top.tga` (8x64)

**06_Masks_And_FX/glyphes** (1)
- [ ] `glyphes-lueurs.tga` (1024x1024)

**06_Masks_And_FX/hud** (7)
- [ ] `combatassistantsinglebuttonmask.tga` (64x64)
- [ ] `uiactionbarfx.tga` (1024x512)
- [ ] `uiactionbarfxcastendmaskx2.tga` (128x128)
- [ ] `uiactionbariconframemask.tga` (64x64)
- [ ] `uiactionbarinterruptmask.tga` (64x64)
- [ ] `uiactionbartargetingmask.tga` (64x64)
- [ ] `uiminimapmaskgeneralc60.tga` (256x256)

**06_Masks_And_FX/masks** (1)
- [ ] `squaremask.tga` (64x64)

**06_Masks_And_FX/playerframe** (2)
- [ ] `classoverlaydeathknightrunes.tga` (128x128)
- [ ] `classoverlaydeathknightrunesfill.tga` (128x128)

**06_Masks_And_FX/professions** (1)
- [ ] `professionsfxgearaugmentationmask.tga` (512x512)

### 07_HUD_And_Atlases

**07_HUD_And_Atlases/auctionframe** (1)
- [ ] `auctionhouse.tga` (1024x1024)

**07_HUD_And_Atlases/battlefieldframe** (1)
- [ ] `battlefieldminimap.tga` (256x256)

**07_HUD_And_Atlases/buttons** (1)
- [ ] `ui-common-mousehilight.tga` (32x32)

**07_HUD_And_Atlases/characterframe** (1)
- [ ] `equipmentmanager.tga` (32x32)

**07_HUD_And_Atlases/characterselection** (2)
- [ ] `timerunningglues.tga` (2048x2048)
- [ ] `timerunningglueslegion.tga` (2048x1024)

**07_HUD_And_Atlases/classtrainerframe** (1)
- [ ] `trainertextures.tga` (512x512)

**07_HUD_And_Atlases/collections** (1)
- [ ] `uicampcollection.tga` (1024x512)

**07_HUD_And_Atlases/common** (13)
- [ ] `bluemenu-main.tga` (256x1024)
- [ ] `bluemenu-vert.tga` (128x128)
- [ ] `commoncoinbox.tga` (32x128)
- [ ] `commoncurrencybox.tga` (32x128)
- [ ] `commondropdown.tga` (512x256)
- [ ] `commondropdownc60.tga` (512x128)
- [ ] `commonforms.tga` (512x256)
- [ ] `commonsearch.tga` (256x128)
- [ ] `commonsidetabc60.tga` (128x128)
- [ ] `minimalcheckbox-hd.tga` (256x256)
- [ ] `minimalcheckbox.tga` (64x64)
- [ ] `minimalcheckboxc60.tga` (32x32)
- [ ] `search.tga` (512x128)

**07_HUD_And_Atlases/containerframe** (4)
- [ ] `bags.tga` (512x256)
- [ ] `bagsitembankslot2xc60.tga` (64x64)
- [ ] `bagsitemslot2xc60.tga` (64x64)
- [ ] `bagslots2x.tga` (512x128)

**07_HUD_And_Atlases/credits** (7)
- [ ] `creditsscreen-keyart-0-c60-1.tga` (1024x1024)
- [ ] `creditsscreen-keyart-0-c60-2.tga` (512x1024)
- [ ] `creditsscreen-keyart-1-1.tga` (1024x1024)
- [ ] `creditsscreen-keyart-1-2.tga` (512x1024)
- [ ] `creditsscreen-keyart-2-1.tga` (1024x1024)
- [ ] `creditsscreen-keyart-2-2.tga` (512x1024)
- [ ] `creditsscreen-selected.tga` (512x64)

**07_HUD_And_Atlases/editmode** (2)
- [ ] `editmodeui.tga` (32x256)
- [ ] `editmodeuivertical.tga` (128x16)

**07_HUD_And_Atlases/friendsframe** (1)
- [ ] `socialqueuingtoast.tga` (512x64)

**07_HUD_And_Atlases/glues** (4)
- [ ] `charactercreate-vignette-bottom.tga` (8x1024)
- [ ] `charactercreate-vignette-sides-widescreen.tga` (128x8)
- [ ] `charactercreate-vignette-sides.tga` (1024x8)
- [ ] `charactercreate-vignette-top.tga` (8x512)

**07_HUD_And_Atlases/glues/charactercreate** (1)
- [ ] `charactercreate.tga` (1024x1024)

**07_HUD_And_Atlases/glues/characterselect** (4)
- [ ] `uicharacterselectglues.tga` (1024x1024)
- [ ] `uicharacterselectglues2x.tga` (2048x2048)
- [ ] `uicharacterselectglues2xc60.tga` (2048x1024)
- [ ] `uicharacterselectgluesc60.tga` (1024x512)

**07_HUD_And_Atlases/guildframe** (1)
- [ ] `communities.tga` (1024x512)

**07_HUD_And_Atlases/helpframe** (3)
- [ ] `cs_helptextures.tga` (512x128)
- [ ] `helptip.tga` (128x32)
- [ ] `newplayerexperienceparts.tga` (2048x1024)

**07_HUD_And_Atlases/housing** (1)
- [ ] `housinguiadvancedmodescale.tga` (256x128)

**07_HUD_And_Atlases/hud** (14)
- [ ] `uiactionbar.tga` (256x1024)
- [ ] `uiactionbar2xc60.tga` (1024x1024)
- [ ] `uiactionbarverticalc60.tga` (128x32)
- [ ] `uicalendar.tga` (256x256)
- [ ] `uideathknightrunes.tga` (512x256)
- [ ] `uidevourerdemonhunterresourcebars.tga` (256x128)
- [ ] `uiexperiencebarcamelot.tga` (1024x256)
- [ ] `uimicromenu2x.tga` (1024x512)
- [ ] `uiminimap.tga` (512x512)
- [ ] `uiminimapc60.tga` (512x512)
- [ ] `uiminimapvertical.tga` (64x16)
- [ ] `uiroguecombopointsc60.tga` (512x256)
- [ ] `uirotationhelper.tga` (512x1024)
- [ ] `uiwowlabsactionbar.tga` (2048x2048)

**07_HUD_And_Atlases/lfgframe** (7)
- [ ] `groupfinder-waitdot.tga` (32x32)
- [ ] `ui-lfg-declinemark-raid.tga` (64x64)
- [ ] `ui-lfg-declinemark.tga` (64x64)
- [ ] `ui-lfg-pendingmark-raid.tga` (64x64)
- [ ] `ui-lfg-pendingmark.tga` (64x64)
- [ ] `ui-lfg-readymark-raid.tga` (64x64)
- [ ] `ui-lfg-readymark.tga` (64x64)

**07_HUD_And_Atlases/merchantframe** (1)
- [ ] `merchant.tga` (512x256)

**07_HUD_And_Atlases/optionsframe** (2)
- [ ] `options.tga` (1024x1024)
- [ ] `optionsc60.tga` (1024x1024)

**07_HUD_And_Atlases/professions** (38)
- [ ] `professions-recipe-header-collapse.tga` (32x16)
- [ ] `professions-recipe-header-expand.tga` (32x16)
- [ ] `professions-recipe-header-left.tga` (16x32)
- [ ] `professions-recipe-header-middle.tga` (8x32)
- [ ] `professions-recipe-header-right.tga` (16x32)
- [ ] `professions_recipe_active.tga` (512x32)
- [ ] `professions_recipe_hover.tga` (512x32)
- [ ] `professionsbookc60.tga` (512x128)
- [ ] `professionsfxgearaugmentation.tga` (1024x1024)
- [ ] `skillbar_fill_flipbook_alchemy_c60.tga` (1024x64)
- [ ] `skillbar_fill_flipbook_blacksmithing.tga` (1024x64)
- [ ] `skillbar_fill_flipbook_cooking.tga` (1024x64)
- [ ] `skillbar_fill_flipbook_defaultblue.tga` (1024x64)
- [ ] `skillbar_fill_flipbook_enchanting_c60.tga` (1024x64)
- [ ] `skillbar_fill_flipbook_engineering.tga` (1024x64)
- [ ] `skillbar_fill_flipbook_firstaid_c60.tga` (1024x64)
- [ ] `skillbar_fill_flipbook_fishing.tga` (1024x64)
- [ ] `skillbar_fill_flipbook_herbalism.tga` (1024x64)
- [ ] `skillbar_fill_flipbook_inscription.tga` (1024x64)
- [ ] `skillbar_fill_flipbook_jewelcrafting.tga` (1024x64)
- [ ] `skillbar_fill_flipbook_leatherworking.tga` (1024x64)
- [ ] `skillbar_fill_flipbook_mining.tga` (1024x64)
- [ ] `skillbar_fill_flipbook_skinning_c60.tga` (1024x64)
- [ ] `skillbar_fill_flipbook_tailoring.tga` (1024x64)
- [ ] `skillbar_flare_alchemy_c60.tga` (64x64)
- [ ] `skillbar_flare_blacksmithing.tga` (64x64)
- [ ] `skillbar_flare_cooking.tga` (64x64)
- [ ] `skillbar_flare_enchanting_c60.tga` (64x64)
- [ ] `skillbar_flare_engineering.tga` (64x64)
- [ ] `skillbar_flare_firstaid_c60.tga` (64x64)
- [ ] `skillbar_flare_fishing.tga` (64x64)
- [ ] `skillbar_flare_herbalism.tga` (64x64)
- [ ] `skillbar_flare_inscription.tga` (64x64)
- [ ] `skillbar_flare_jewelcrafting.tga` (64x64)
- [ ] `skillbar_flare_leatherworking.tga` (64x64)
- [ ] `skillbar_flare_mining.tga` (64x64)
- [ ] `skillbar_flare_skinning_c60.tga` (64x64)
- [ ] `skillbar_flare_tailoring.tga` (64x64)

**07_HUD_And_Atlases/pvpframe** (5)
- [ ] `honor-dishonored-alliance.tga` (128x128)
- [ ] `honor-dishonored-horde.tga` (128x128)
- [ ] `pvpmegaqueue.tga` (512x1024)
- [ ] `pvpqueue-sidebar-honorbar-fill.tga` (128x128)
- [ ] `uicharacterinfohonorc60.tga` (512x512)

**07_HUD_And_Atlases/questframe** (2)
- [ ] `questmaplogatlas.tga` (1024x512)
- [ ] `questtrackerc60.tga` (512x256)

**07_HUD_And_Atlases/quickkeybind** (1)
- [ ] `quickkeybindui.tga` (1024x512)

**07_HUD_And_Atlases/spellbook** (3)
- [ ] `spellbookelements.tga` (1024x1024)
- [ ] `spellbookelementsc60.tga` (256x256)
- [ ] `spellbooktabsc60.tga` (64x128)

**07_HUD_And_Atlases/talentframe** (2)
- [ ] `talents.tga` (1024x512)
- [ ] `talentsc60.tga` (1024x1024)

**07_HUD_And_Atlases/taxiframe** (3)
- [ ] `taximap-1463.tga` (512x512)
- [ ] `taximap1-classic.tga` (512x512)
- [ ] `ui-taxi-line.tga` (32x32)

**07_HUD_And_Atlases/unknown** (5)
- [ ] `8183023.tga` (512x1024)
- [ ] `8203429-hd.tga` (1024x512)
- [ ] `8203429.tga` (256x128)
- [ ] `8203433.tga` (512x512)
- [ ] `8216674.tga` (2048x2048)
