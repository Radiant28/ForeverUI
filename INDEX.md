# ForeverUI — индекс кода

Карта аддона для работы с кодом: где что лежит и что править под задачу, чтобы не перечитывать весь аддон.
Номера строк нарочно не указаны, потому что они быстро устаревают. Ищите по именам функций и ключей (grep).
**Если меняете структуру, обновите этот файл.**

## Платформа и жёсткие правила

- Клиент WoW 3.3.5a (сборка 12340, `## Interface: 30300`), сервер Nozdor. Язык **строго Lua 5.1**: нет `goto`, нет `//` и битовых операторов (используйте `bit.band`), `#` только для последовательностей.
- Только API WotLK. **Запрещено**: `C_Timer`, `BackdropTemplate`/`BackdropTemplateMixin`, `FramePool`/`CreateFramePool`, новый `Settings` API, `SetColorTexture`, `SetAtlas`, `C_AddOns`, `SetShown(`, `CreateMaskTexture`, `C_NamePlate`.
  - Вместо `SetShown` используйте `ui.Widgets.SetVisible(region, bool)` или локальный хелпер `shown()`.
  - Рамки делаются через нативный `SetBackdrop` с текстурой `Interface\Buttons\WHITE8X8` и `edgeSize = 1`.
  - Таймеры делаются через `OnUpdate` на служебном фрейме.
- Защищённые фреймы в бою трогать нельзя. Отложите действие через `ui.RunOutOfCombat(token, fn)`: очередь выполнится по `PLAYER_REGEN_ENABLED`.
- Тексты всегда пишутся в двух языках: `ui.L("русский", "english")`. В модулях также встречается `ui.russian and "…" or "…"`.
- Каждый файл начинается с `local _, ui = ...`. Общее состояние хранится только в таблице аддона `ui`, глобалы не плодим. Исключение — имена фреймов `ForeverStockUI*`.
- Сохранённые данные:
  - `ForeverStockUIDB` — все модули, читается через `ui.Settings()`;
  - `ForeverUI_NameplatesDB` — неймплейты, отдельная таблица `cfg` в `ForeverUI_Nameplates.lua`.

## Тесты

На машине нет `lua.exe`. Тесты запускаются через Python `lupa` (LuaJIT 2.1, семантика Lua 5.1) из корня аддона:
```
python -c "import lupa.luajit21 as L,sys;r=L.LuaRuntime();r.execute('arg={}');r.eval('function(p) return assert(loadfile(p))() end')(sys.argv[1])" tests/Options.lua
```
- `tests/Options.lua` — мок WoW API. Грузит Core, Media и все схемы `Options/*`, строит каждую страницу и дёргает контролы. Проверяет запрещённые API в Core и в Options.
- `tests/Nameplates.lua` — неймплейты: схема, CVars, боксы, касты, ауры.
- В тестах модули подменены заглушками-рекордерами: `ui.UnitFrames`, `ui.CombatMeter` и другие. **Если добавили функцию в API модуля, которую вызывает схема, добавьте её и в заглушку** в `tests/Options.lua`.

## Порядок загрузки (ForeverUI.toc)

`Libs` (LibStub, CallbackHandler, LibSharedMedia) → `Core/Config` → `Core/Widgets` → `Core/OptionsFrame` → `Core/Compat` → `BundledMedia` → `Media` → модули → `Options/*`.
Схемы грузятся последними, поэтому функции модулей вызывают лениво: `call("Apply")` → `ui.Module.Apply()`. Модули сами публикуют API в `PLAYER_LOGIN` или при загрузке файла.

## Ядро (Core/)

| Файл | Что внутри | Ключевые имена |
|---|---|---|
| `Core/Config.lua` | SavedVariables, реестр схем, дефолты, валидация, колбэки, боевая очередь | `ui.Settings`, `ui.RegisterOptions`, `ui.GetOption`/`SetOption`/`ResetOption`/`ResetModule`, `ui.GetDefault`, `ui.IsDefault`, `ui.IsModuleEnabled`, `ui.IsOptionAvailable`, `ui.OptionBinding`, `ui.RegisterCallback`/`Fire`, `ui.RunOutOfCombat`, `ui.CopyTable`, `ui.Groups`, `ui.OutlineValues`, `ui.Print` |
| `Core/Widgets.lua` | Фабрика контролов в плоском стиле. Токены цвета и отступов собраны в `ui.Style` (S) | `W.Skin`, `W.Text`, `W.Button`, `W.Toggle`, `W.Range`, `W.Select` (общий выпадающий список с поиском и превью), `W.Color` (+ `W.OpenColorPicker`), `W.Input`, `W.Header`, `W.Description`, `W.ActionButton`, `W.Scroll`, `W.Create` (диспетчер по `opt.type`), `W.fonts`, `W.SetVisible` |
| `Core/OptionsFrame.lua` | Окно `ForeverUIOptions` 860×580: сайдбар групп, поиск, ленивые страницы, сброс раздела, футер Reload и Edit Mode, категория в стандартном меню, команды `/fui` и `/foreverui` | `layoutSection` (раскладка секций и колонок, `custom`-опции), `refreshPage`, `buildPage`, `ui.OpenOptions(id)`, `ui.ToggleOptions`, `ui.ApplyOptionsWindowScale` |
| `Core/Compat.lua` | Старый API контролов для попапов с абсолютной раскладкой | `ui.Checkbox`, `ui.Slider`, `ui.MediaChoice`, `ui.Options` |
| `Media.lua`, `BundledMedia.lua` | Встроенные текстуры и шрифты, интеграция с LibSharedMedia | `ui.MediaPath(kind, sel, ignoreGlobal)`, `ui.MediaItems`, `ui.MediaPreview`, `ui.MediaLabel`, `ui.MediaDefault`, `ui.WatchMedia`, `ui.UnitBarFill`, `ui.bundledMedia` |

### Формат схемы (Options/*.lua)
```lua
ui.RegisterOptions("id", { title=, description=, icon=, group="general|frames|combat|items|social", order=,
    enable = "masterToggleKey",           -- главный выключатель модуля
    apply = fn,                           -- наследуется секциями и опциями
    sections = { { title=, description=, columns=2, apply=, depends=, protected=, options = {
        { "toggle"|"range"|"select"|"media"|"color"|"text"|"button", "key", "Подпись",
          default=, min=, max=, step=, suffix=, values=, kind= (для media), alpha=true (для color),
          depends = "key" | "!key" | function, apply = fn | false, reload = true, protected = true,
          tooltip=, hidden = fn, width = "full" },
        { "custom", build = function(parent, width, spec) ... return height end, refresh = fn },
    } } },
})
```
- Значения хранятся плоско в `ui.Settings()[key]`, ключи общие для всех модулей. **Проверяйте имя нового ключа на уникальность** grep'ом.
- `custom`-блоки строятся один раз. Если блок меняет высоту, держите его последней секцией страницы. Пример: `BuildWindowList` в `CombatMeter.lua`.

## Модули

| Модуль (id схемы) | Код | Схема | API (`ui.*`) | Что внутри |
|---|---|---|---|---|
| Рамки юнитов (`unitframes`) | `ForeverUI.lua` | `Options/UnitFrames.lua` | `ui.UnitFrames {ApplyHealthColor, ApplyBarFill, ApplyPanelMedia, ApplyColors, ApplyVisibility}` | Реcкин штатных Player, Target, Focus, ToT, Pet, Party, Boss, Arena и Raid pullout |
| Неймплейты (`nameplates`) | `ForeverUI_Nameplates.lua` (ядро, `cfg`), `ForeverUI_NameplateStyle.lua` (рамки, боксы, каст), `ForeverUI_NameplateBoxes.lua` (публичный API боксов), `ForeverUI_NameplateOptions.lua` (схема и превью) | внутри `ForeverUI_NameplateOptions.lua` | `ui.wfn` (`wfn.*`), `/wfn` | Собственный стиль неймплейтов, угроза, касты, ауры, превью |
| Edit Mode (`editmode`) | `EditMode.lua` | `Options/EditMode.lua` | `ui.RegisterEditFrame(frame, label, category, slider, legacy)`, `ui.RefreshEditLayout`, `ui.EditMode {Open, Apply}` | Перемещение и масштаб фреймов, сетка, привязка. Позиции хранятся в `settings.editLayout[frameName]` |
| Каст-бары (`castbar`) | `CastBarOptions.lua` | `Options/CastBar.lua` | `ui.CastBar {stock, Apply}` | Скин каст-баров игрока, питомца, цели, фокуса, боссов и арены |
| Панели действий (`actionbars`) | `StockPanels.lua` | `Options/ActionBars.lua` | `ui.ActionBars {Apply}`, `ui.ApplyGryphons`, `ui.ApplySlotEdge` | Грифоны, цвет арта, рамки слотов, рамка полосы опыта |
| Микроменю (`micromenu`) | `MicroMenu.lua` | `Options/MicroMenu.lua` | `ui.MicroMenu {ApplyColors}` | Иконки микроменю из атласа |
| Миникарта и кнопки аддонов (`minimap`, `addonbar`) | `Minimap.lua` | `Options/Minimap.lua` | `ui.Minimap {Layout}` | Кольцо миникарты, баффы и панель кнопок аддонов. Через LibDBIcon хук `Refresh`/`Register` |
| Урон, лечение, угроза (`meter`) | `CombatMeterData.lua` (сбор из combat log, история боёв), `CombatMeter.lua` (окна) | `Options/CombatMeter.lua` | `ui.CombatMeterData`, `ui.CombatMeterLimits`, `ui.CombatMeter {Apply, ResetWidth, ResetDamageRows, ResetHealingRows, BuildPreview, BuildWindowList, Create, Remove, RemoveAll, Count}` | Произвольное число окон (до 10), стыковка пар окон, режимы из таблицы `modes` (урон, DPS, лечение, HPS, угроза) |
| Всплывающий текст боя (`combattext`) | `CombatText.lua` (порт NiceDamage) | `Options/CombatText.lua` | `ui.CombatText {defaults, switches, sliders, schools, Apply, Test, active}`, `/nd` | Цифры урона над целями и неймплейтами |
| Производительность (`performance`) | `Performance.lua` | `Options/Performance.lua` | `ui.Performance {Apply}` | Счётчик FPS и пинга с порогами цвета |
| Курсор (`cursor`) | `Cursor.lua`, `CursorOptions.lua` (команды `/cursoruz`, `/midcursor`) | `Options/Cursor.lua` | `ui.cursor {Apply, Normalize, Reset, ToggleSettings}` | Обводка и шлейф курсора |
| Сумки и банк (`bags`) | `Bags.lua` | `Options/Bags.lua` | `ui.Bags {Relayout, Refresh}` | Объединённая сумка: сетка, группировка, уровень предметов, подсветка редкости и квестов |
| Подписи экипировки (`labels`) | `Equipment.lua` | `Options/Equipment.lua` | `ui.ItemLabels`, `ui.ApplyItemLabel`, `ui.ItemLabelStyle`, `ui.SetDurabilityLabel`, `ui.ToggleItemLabelEditor` | Уровень предмета и прочность на слотах персонажа и в сумках |
| Торговец (`merchant`) | `Merchant.lua` | `Options/Merchant.lua` | `ui.Merchant {Apply}`, `/fujunk` | Продажа хлама, раскладка окна торговца |
| Чат и лут (`chat`, `loot`) | `Chat.lua`, `Loot.lua`, `LootRolls.lua` | `Options/Chat.lua` (обе схемы) | `ui.Chat {Apply}` | Окна чата (группа, гильдия, лут), скин окна добычи, анимация, роллы |
| Общие (`general`) | — | `Options/General.lua` | — | Масштаб окна настроек, сброс всего |

## ForeverUI.lua (рамки юнитов): где что
- Таблицы стилей: `player`, `target` (бронзовая оправа из `Art/CharacterFrames.tga`), `large`, `small`, `secondary`, `arena`, `dragons`.
  - Поля: `chrome`, `portrait`, `name`, `nameSlot`, `nameFill`, `health`, `power`, `level`.
  - Координаты прорезей сняты с текстуры в пикселях с масштабом 0.4. Заливки заходят на 2 px под оправу.
- `chromeGlows` — ореолы боя и угрозы по форме оправы: `Art/Player-ChromeGlow.tga`, `Art/Target-ChromeGlow.tga`.
- `apply(frame, style, originX, originY, scale, flip)` — главный реcкин одного фрейма, состояние хранится в `skins[frame]`.
- `applyStock()` — какие фреймы каким стилем и в каком масштабе (ветка `ufChromeAll`).
- Хуки на штатные функции: `PlayerFrame_UpdateStatus`, `UnitFrame_UpdateThreatIndicator` (функция `updateAggro`), `TargetFrame_CheckClassification` (дракон), `PartyMemberFrame_*`, `RaidPullout_Update`.
- `applyColors`, `applyVisibility`, `applyPanelMedia`, `applyBarFill` — live-apply функции для схемы.
- Штатные текстуры статуса клиент пульсирует каждый кадр, поэтому их прячут через `SetTexture(nil)`, а не через `SetAlpha`.

## CombatMeter.lua: где что
- `modes` — режимы окна. Первое поле: 1 урон, 2 лечение, `THREAT` = 3 угроза. `demo` — данные для превью в Edit Mode.
- `buildFrame(key)` — построение фрейма `ForeverStockUI<key>Meter`.
- `setupWindow` — привязка к `settings.combatMeters[key]` и `settings.editLayout[name]`.
- `createMeter(mode)` и `removeMeter(key)` — жизненный цикл окна. Удалённые фреймы уходят в `pool` и переиспользуются.
- Порядок окон хранится в `settings.combatMeters.order`, стыковка — в `settings.combatMeters.docks[dockedKey] = {anchorKey, side}`.
- Стыковка: `attach`, `undock`, `snapWindow`, `resizeDock`. Пара окон хранится в `window.pair = {docked, anchor, side}`.
- Угроза: `collectThreat` и `threatUnit` через `UnitDetailedThreatSituation` по `target`, а если цели нет — по `focus`.

## Ассеты
- `Art/` — текстуры аддона (TGA и BLP). Атласы: `CharacterFrames.tga` (оправы рамок), `DamageMeter.tga` (спрайты измерителя, координаты в таблице `sprites`), `CastBar-Atlas.tga`. Подпапки `ActionBar`, `Cursor`, `Map`, `MidCast`, `Nameplates`. Авторство — в `Art/CREDITS.md`.
- `Media/` (`background`, `border`, `fonts`, `statusbar`) — медиа для выпадающих списков, регистрируются в `BundledMedia.lua`.
- Размеры TGA должны быть степенью двойки, иначе клиент 3.3.5 их не покажет.

## Типовые задачи
- **Новая настройка:**
  1. Добавьте строку в схему нужного `Options/<Модуль>.lua` с `default` и `apply = call("ApplyX")`.
  2. В коде модуля читайте значение через `ui.Settings()[key]` или локальный `setting(key, fallback)`.
  3. Если нужна новая функция API модуля, добавьте её в `ui.<Модуль>` и в заглушку в `tests/Options.lua`.
- **Новый модуль:**
  1. Создайте файл модуля и файл `Options/<Имя>.lua` с `enable = "<ключ>"`, чтобы модуль можно было полностью выключить.
  2. Добавьте оба файла в `ForeverUI.toc`: модуль в секцию модулей, схему в конец.
- **Новый перемещаемый фрейм:** у фрейма должно быть имя. Вызовите `ui.RegisterEditFrame(frame, label, "<id схемы>")`. Флаги записи `entry`: `docked`, `moving`, `removed`, а также колбэки `onDragStart`/`onDragStop`/`changeScale`.
- **Действие с защищёнными фреймами из настроек:** оберните в `ui.RunOutOfCombat(token, fn)` или пометьте опцию `protected = true`.
- **Перед коммитом:** прогоните оба теста.
