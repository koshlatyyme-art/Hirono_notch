# NotchBuddy — план реализации

> **Для агентов-исполнителей:** ОБЯЗАТЕЛЬНЫЙ ПОД-НАВЫК: superpowers:subagent-driven-development (рекомендуется) или superpowers:executing-plans — выполнять задачу за задачей. Шаги отмечаются чекбоксами (`- [ ]`).

**Цель:** нативное macOS-приложение, в «ушах» челки которого живёт анимированный персонаж из `character.png` и хранится история последних 10 скопированных элементов.

**Архитектура:** SwiftPM-пакет: `NotchBuddyCore` — чистая логика (геометрия челки, буфер, пружины, позы, «мозг» персонажа), покрыта Swift Testing; `NotchBuddy` — тонкий AppKit/SwiftUI-клей (NSPanel над челкой, наблюдатель буфера, мониторы мыши, рендер куклы). Персонаж — 2.5D-кукла из слоёв, нарезанных из оригинального рендера одноразовыми Python-скриптами.

**Стек:** Swift 6.4 / SwiftUI / AppKit, macOS 15+, Swift Testing; Python 3.9 venv (Pillow, numpy, opencv-python-headless) только для нарезки.

**Спека:** `docs/superpowers/specs/2026-10-20-notch-buddy-design.md` — исполнитель читает её вместе с планом.

## Глобальные ограничения

- `swift-tools-version: 6.0`, `platforms: [.macOS(.v15)]`, Swift 6 language mode; никаких сторонних Swift-зависимостей.
- Без Metal-шейдеров (Metal Toolchain не установлен); 3D-поворот головы — `rotation3DEffect`.
- Никаких запросов «Универсального доступа»; единственный системный запрос — доступ к буферу (macOS 15.4+).
- Бандл: `build/NotchBuddy.app`, `CFBundleIdentifier = local.notchbuddy`, `LSUIElement = true`, `LSMinimumSystemVersion = 15.0`; подпись `codesign --force --sign "Apple Development"`.
- История: максимум **10**, только в памяти, новые сверху; дубль по содержимому поднимается наверх с сохранением `id`.
- Игнорировать буфер с типами `org.nspasteboard.ConcealedType`, `org.nspasteboard.TransientType`, `public.file-url`.
- Ссылка = строка без пробельных символов внутри, схема `http`/`https`, есть host.
- Сон: системное бездействие ≥ **300 с**. Случайные действия: каждые **15–40 с**. Внимание: курсор ближе **200pt** к центру персонажа.
- Ночь: **21:00 ≤ t < 07:00** локального времени.
- Раскрытие после **0,2 с** наведения на форму; сворачивание через **0,3 с** после ухода, **не во время перетаскивания**.
- Размеры: ухо **44pt**; аварийная челка **190×32pt**; раскрытая панель **520×270pt**; строка списка **40pt**; портрет в ухе ~**30pt** по высоте; персонаж в панели ~**100pt**.
- Весь пользовательский текст — по-русски.
- Простой CPU < **3%**; анимация 30 fps в свёрнутом виде, 60 fps в раскрытом, пауза при спящих дисплеях.
- Коммиты заканчиваются строкой `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. `git add` — только перечисленные в задаче пути.

## Фокус ревью

1. **Огромное содержимое буфера** (картинка 50 МБ, текст 5 МБ) — панель не подвисает: превью текста ≤ 300 символов (тест в задаче 3), миниатюра картинки — `CGImageSourceCreateThumbnailAtIndex` вне главного потока (задача 4).
2. **Смена экранов** (подключили монитор, закрыли крышку, сменили разрешение) — панель переезжает на экран с челкой или в аварийный режим (тест на экран с ненулевым origin в задаче 2 + подписка на `didChangeScreenParametersNotification`).
3. **Пробуждение Mac после сна** — гигантский `dt` не «взрывает» пружины (тест ограничения `dt` в задаче 5).
4. **Строки, похожие на ссылку** (многострочные, с пробелами, `ftp:`/`mailto:`) — это текст (тесты в задаче 3).
5. **Доступ к буферу запрещён** — персонаж всё равно реагирует на Cmd+C, в панели подсказка, без падений (тест трекера в задаче 3, ручная проверка в задаче 4).

---

## Структура файлов

```
.gitignore                          # .build/ build/ tools/rig/.venv/ .DS_Store
Package.swift
Assets/Character/                   # выход нарезки: body.png arm.png head.png antenna.png rig.json
tools/rig/requirements.txt          # Pillow, numpy, opencv-python-headless
tools/rig/riglib.py                 # загрузка rig.json, композит позы (общий для check/sheet)
tools/rig/cut.py                    # маски-полигоны + inpaint → Assets/Character/*
tools/rig/check.py                  # PSNR покоя + поиск дыр в крайних позах
tools/rig/sheet.py                  # лист поз → build/rig-sheet.png
scripts/Info.plist
scripts/build-app.sh
Sources/NotchBuddyCore/Notch/NotchGeometry.swift
Sources/NotchBuddyCore/Clipboard/ClipboardItem.swift
Sources/NotchBuddyCore/Clipboard/PasteboardSnapshot.swift
Sources/NotchBuddyCore/Clipboard/ClipboardHistory.swift
Sources/NotchBuddyCore/Clipboard/PasteboardChangeTracker.swift
Sources/NotchBuddyCore/Character/Rig.swift
Sources/NotchBuddyCore/Character/Pose.swift            # Pose, PoseTargets, LayerTransform, transforms(for:rig:)
Sources/NotchBuddyCore/Character/Spring.swift
Sources/NotchBuddyCore/Character/PoseAnimator.swift
Sources/NotchBuddyCore/Character/Reaction.swift
Sources/NotchBuddyCore/Character/BehaviorBrain.swift
Sources/NotchBuddyCore/Character/SeededRandom.swift
Sources/NotchBuddyCore/Character/NightSchedule.swift
Sources/NotchBuddy/AppDelegate.swift      # @main, accessory policy, сборка всего вместе
Sources/NotchBuddy/AppModel.swift         # @Observable @MainActor: история, isExpanded, isDragging, accessDenied
Sources/NotchBuddy/NotchPanel.swift       # NSPanel + FirstMouseHostingView
Sources/NotchBuddy/NotchController.swift  # позиционирование, мышь: проход кликов, наведение, drag-guard
Sources/NotchBuddy/NotchView.swift        # чёрная форма, уши, раскрытая панель
Sources/NotchBuddy/PasteboardWatcher.swift
Sources/NotchBuddy/ClipboardListView.swift  # список + ClipboardRow
Sources/NotchBuddy/CharacterAssets.swift  # rig.json + CGImage из Bundle.main
Sources/NotchBuddy/CharacterModel.swift   # @Observable: brain + animator + display link → pose
Sources/NotchBuddy/CharacterView.swift    # слои, свечения, «z»
Sources/NotchBuddy/InputMonitor.swift     # глобальные/локальные мониторы мыши, тик бездействия
Tests/NotchBuddyCoreTests/*Tests.swift
```

---

### Task 1: Репозиторий и риг персонажа (контрольная точка с пользователем)

**Файлы:**
- Создать: `.gitignore`, `tools/rig/requirements.txt`, `tools/rig/riglib.py`, `tools/rig/cut.py`, `tools/rig/check.py`, `tools/rig/sheet.py`, `Assets/Character/{body,arm,head,antenna}.png`, `Assets/Character/rig.json`
- Уже есть: `docs/superpowers/specs/2026-10-20-notch-buddy-design.md`, этот план

**Интерфейсы:**
- Производит: `Assets/Character/rig.json` строго по схеме ниже — её читают `Rig` (задача 5) и `riglib.py`.

```json
{
  "canvas": [466, 654],
  "frames": { "full": [0, 0, 466, 654], "portrait": [x, y, w, h] },
  "limits": { "body": 3, "head": 10, "headTurn": 20, "arm": 15, "antenna": 25 },
  "layers": [
    { "name": "body",    "file": "body.png",    "parent": null,   "pivot": [x, y] },
    { "name": "arm",     "file": "arm.png",     "parent": "body", "pivot": [x, y] },
    { "name": "head",    "file": "head.png",    "parent": "body", "pivot": [x, y] },
    { "name": "antenna", "file": "antenna.png", "parent": "head", "pivot": [x, y] }
  ],
  "glows": [
    { "name": "heart",     "parent": "body",    "center": [x, y], "radius": r, "color": "#FF7A2E", "night": 1.0 },
    { "name": "antenna",   "parent": "antenna", "center": [x, y], "radius": r, "color": "#FF8C3A", "night": 0.9 },
    { "name": "blueTube",  "parent": "head",    "center": [x, y], "radius": r, "color": "#3D7BFF", "night": 0.8 },
    { "name": "greenTube", "parent": "head",    "center": [x, y], "radius": r, "color": "#3DFF7A", "night": 0.35 }
  ]
}
```
Правила схемы: все координаты — пиксели холста (origin слева сверху); каждый PNG ровно размера `canvas` и выровнен по оригиналу (уменьшение 0,5× от 932×1307); порядок `layers` = порядок отрисовки (сзади вперёд, исполнитель может переставить); `limits` — градусы для нормализованных значений позы = ±1; pivot `body` — низ-центр фигуры; `portrait` — кадр «по плечи» (голова, антенна, инопланетянин), соотношение ≈ 1,15:1 (ш:в). Сердце — не слой, а свечение `heart` (вспышки и ночь).

- [ ] **Шаг 1: git и игнор**
  `git init` в `/Users/kaslatyj/Downloads/NOTCH`; `.gitignore` из структуры выше; `git add .gitignore docs/ character.png glow.jpeg CLAUDE.md && git commit -m "docs: NotchBuddy design and plan"`.
- [ ] **Шаг 2: окружение**
  `python3 -m venv tools/rig/.venv && tools/rig/.venv/bin/pip install -r tools/rig/requirements.txt`. Ожидается: `import cv2, PIL, numpy` без ошибок.
- [ ] **Шаг 3: `cut.py`**
  Силуэт — альфа-канал оригинала; границы частей — полигоны в полных координатах 932×1307, подобранные по картинке (смотреть кропы через Read). В нижних слоях закрашивать области, которые откроются при крайних углах (`cv2.inpaint`, `INPAINT_TELEA`, по RGB с расширенной альфой) — шарф/плечи под головой, бок под рукой, макушку под основанием антенны. Запись PNG и `rig.json` (уменьшение 0,5×, LANCZOS).
- [ ] **Шаг 4: `riglib.py` + `check.py`**
  `compose(rig, pose) -> RGBA` — плоская иерархия: для каждого слоя применить повороты цепочки предков вокруг их pivot (антенна: свой → head → body), сместить на `bounce`, отрисовать в порядке `layers`; поворот по Y для `headTurn` аппроксимировать горизонтальным сжатием головы на `cos(угла)` вокруг pivot. `check.py`: (а) PSNR композита покоя против уменьшенного оригинала по области alpha>0; (б) для поз {head ±1, arm ±1, antenna ±1, body ±1, sleep, комбинации head+1/arm-1 и head-1/arm+1}: прозрачные (alpha<128) пиксели, недостижимые заливкой от края холста, = «дыры».
- [ ] **Шаг 5: прогон проверок**
  Run: `tools/rig/.venv/bin/python -I tools/rig/check.py`
  Ожидается: `rest PSNR: NN.N dB OK` (≥ 40) и `holes: 0 in 10 poses OK`. Иначе — доработать маски/inpaint (шаг 3) и повторить.
- [ ] **Шаг 6: лист поз**
  `sheet.py` → `build/rig-sheet.png`: строки = покой, голова ±max, рука ±max, антенна ±max, прыжок, сон, ночь (затемнение до 35% с тоном `#4D5573` + аддитивные радиальные свечения из `glows`); колонки = кадр `portrait` высотой 60px, `full` высотой 200px, `full` высотой 600px. Посмотреть через Read; швы, ореолы, «отрезанные» края — исправлять до чистого вида.
- [ ] **Шаг 7: КОНТРОЛЬНАЯ ТОЧКА**
  Показать пользователю `build/rig-sheet.png` (полный путь) и получить явное «ок» по внешнему виду. Без «ок» к задаче 2 не переходить.
- [ ] **Шаг 8: коммит**
  `git add tools/rig/*.py tools/rig/requirements.txt Assets/Character && git commit -m "feat(rig): cut character into animatable layers"`

---

### Task 2: Каркас пакета, геометрия и окно челки

**Файлы:**
- Создать: `Package.swift`, `Sources/NotchBuddyCore/Notch/NotchGeometry.swift`, `Tests/NotchBuddyCoreTests/NotchGeometryTests.swift`, `Sources/NotchBuddy/{AppDelegate,AppModel,NotchPanel,NotchController,NotchView}.swift`, `scripts/Info.plist`, `scripts/build-app.sh`

**Интерфейсы:**
- Производит:
```swift
public struct NotchGeometry: Equatable, Sendable {
    public static let fallbackNotchSize = CGSize(width: 190, height: 32)
    public static let earWidth: CGFloat = 44
    public static let expandedSize = CGSize(width: 520, height: 270)
    public let notchRect: CGRect        // координаты экрана AppKit (origin снизу слева)
    public let isHardwareNotch: Bool
    public init(screenFrame: CGRect, safeAreaTop: CGFloat, auxiliaryTopLeft: CGRect?, auxiliaryTopRight: CGRect?)
    public func collapsedRect(showsRightEar: Bool) -> CGRect
    public var expandedRect: CGRect     // по центру челки, прижат к верху экрана
    public var panelFrame: CGRect       // union(expandedRect, collapsedRect(showsRightEar: true))
}
```
- `AppModel` (`@Observable @MainActor final class`): `var isExpanded = false`, `var isDragging = false` — дополняется в задачах 4–6.
- `NotchPanel: NSPanel` — `styleMask [.borderless, .nonactivatingPanel]`, `level = .statusBar + 1`, `collectionBehavior [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]`, прозрачный фон, без тени, `canBecomeKey == false`, `acceptsMouseMovedEvents = true`; контент — `FirstMouseHostingView<Content>: NSHostingView` с `acceptsFirstMouse(for:) -> true`.
- `NotchController` (`@MainActor`): выбирает экран `NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main`, ставит `panel.setFrame(geometry.panelFrame)`, пересчитывает по `NSApplication.didChangeScreenParametersNotification`; `ignoresMouseEvents = !currentShapeRect.contains(mouse)` (кроме `isDragging`).

- [ ] **Шаг 1: тесты геометрии** (`NotchGeometryTests`)
```swift
@Test func hardwareNotch() {
    let g = NotchGeometry(screenFrame: CGRect(x: 0, y: 0, width: 1728, height: 1117), safeAreaTop: 32,
                          auxiliaryTopLeft: CGRect(x: 0, y: 1085, width: 764, height: 32),
                          auxiliaryTopRight: CGRect(x: 964, y: 1085, width: 764, height: 32))
    #expect(g.isHardwareNotch)
    #expect(g.notchRect == CGRect(x: 764, y: 1085, width: 200, height: 32))
    #expect(g.collapsedRect(showsRightEar: true) == CGRect(x: 720, y: 1085, width: 288, height: 32))
    #expect(g.collapsedRect(showsRightEar: false) == CGRect(x: 720, y: 1085, width: 244, height: 32))
    #expect(g.expandedRect == CGRect(x: 604, y: 847, width: 520, height: 270))
}
@Test func fallbackWithoutNotch() {
    let g = NotchGeometry(screenFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080), safeAreaTop: 0,
                          auxiliaryTopLeft: nil, auxiliaryTopRight: nil)
    #expect(!g.isHardwareNotch)
    #expect(g.notchRect == CGRect(x: 865, y: 1048, width: 190, height: 32))
}
@Test func fallbackOnSecondaryScreen() {   // фокус ревью №2
    let g = NotchGeometry(screenFrame: CGRect(x: 1728, y: -200, width: 1920, height: 1080), safeAreaTop: 0,
                          auxiliaryTopLeft: nil, auxiliaryTopRight: nil)
    #expect(g.notchRect == CGRect(x: 2593, y: 848, width: 190, height: 32))
}
```
- [ ] **Шаг 2:** `swift test --filter NotchGeometryTests` → FAIL (нет типа).
- [ ] **Шаг 3:** `Package.swift` (таргеты `NotchBuddyCore`, `NotchBuddy` с зависимостью на Core, `NotchBuddyCoreTests`) и `NotchGeometry`.
- [ ] **Шаг 4:** `swift test --filter NotchGeometryTests` → PASS.
- [ ] **Шаг 5: окно и сборка.** `AppDelegate` (`@main`, `NSApp.setActivationPolicy(.accessory)`), `NotchPanel`, `NotchController`, `NotchView` (чёрная `UnevenRoundedRectangle`, нижние радиусы 10 свёрнуто / 18 раскрыто, `.spring(response: 0.35, dampingFraction: 0.8)`; пока пустые уши). `scripts/build-app.sh`: `swift build -c release` → `build/NotchBuddy.app/Contents/{MacOS/NotchBuddy, Info.plist, Resources/Character/*}` (копия `Assets/Character`) → `codesign --force --sign "Apple Development" build/NotchBuddy.app`. Записать в лог реальные `safeAreaInsets`/`auxiliaryTop*Area` этого Mac (`NSLog`) — пригодится для сверки.
- [ ] **Шаг 6: проверка**
  Run: `scripts/build-app.sh && open build/NotchBuddy.app && sleep 2 && screencapture -x -R 560,0,620,60 build/shot-collapsed.png`
  Ожидается: нет иконки в Dock; на скриншоте (смотреть через Read) чёрная форма шире аппаратной челки на два уха и сливается с ней. Клик по иконке меню-бара рядом с формой срабатывает (попросить пользователя проверить, если нельзя кликнуть самому).
- [ ] **Шаг 7:** `git add Package.swift Sources Tests scripts && git commit -m "feat: notch panel skeleton with geometry"`

---

### Task 3: Ядро буфера (TDD)

**Файлы:**
- Создать: `Sources/NotchBuddyCore/Clipboard/{ClipboardItem,PasteboardSnapshot,ClipboardHistory,PasteboardChangeTracker}.swift`
- Тесты: `Tests/NotchBuddyCoreTests/{PasteboardSnapshotTests,ClipboardHistoryTests,PasteboardChangeTrackerTests}.swift`

**Интерфейсы:**
```swift
public struct ClipboardItem: Identifiable, Equatable, Sendable {
    public enum Content: Equatable, Sendable { case text(String), link(URL), image(Data, uti: String) }
    public let id: UUID
    public let content: Content
    public var copiedAt: Date
    public var dedupKey: String { get }     // "t:" + текст | "l:" + absoluteString | "i:" + SHA256-hex (CryptoKit)
    public var previewText: String? { get } // text: пробельные серии → " ", не больше 300 символов + "…"; link: absoluteString; image: nil
}
public struct PasteboardSnapshot: Equatable, Sendable {
    public var types: [String]; public var string: String?; public var urlString: String?
    public var png: Data?; public var tiff: Data?
    public init(types: [String], string: String? = nil, urlString: String? = nil, png: Data? = nil, tiff: Data? = nil)
    public func classify() -> ClipboardItem.Content?
}
public struct ClipboardHistory: Sendable {
    public static let capacity = 10
    public private(set) var items: [ClipboardItem]       // новые первыми
    public init()
    @discardableResult public mutating func add(_ content: ClipboardItem.Content, at date: Date) -> ClipboardItem
    public mutating func promote(id: UUID, at date: Date)
    public mutating func clear()
}
public struct PasteboardChangeTracker: Sendable {
    public init(initialCount: Int)
    public mutating func observe(_ count: Int) -> Bool   // true = внешнее изменение
    public mutating func markOwnWrite(_ count: Int)
}
```
Порядок классификации (`classify`): (1) есть Concealed/Transient/`public.file-url` → `nil`; (2) `string` после trim непуста → `.link`, если это ссылка по правилу из ограничений, иначе `.text(исходная строка)`; (3) `png` → `.image(png, uti: "public.png")`; (4) `tiff` → `.image(tiff, uti: "public.tiff")`; (5) `urlString` — http(s)-ссылка → `.link`; (6) `nil`.

- [ ] **Шаг 1: тесты классификации** — по одному `@Test` на случай:
  - `["org.nspasteboard.ConcealedType","public.utf8-plain-text"]`, string `"hunter2"` → `nil`
  - `["org.nspasteboard.TransientType","public.utf8-plain-text"]`, `"x"` → `nil`
  - `["public.file-url","public.utf8-plain-text"]`, `"photo.png"` → `nil`
  - `["public.html","public.utf8-plain-text"]`, `"Hello\nworld"` → `.text("Hello\nworld")`
  - `["public.url","public.utf8-plain-text"]`, `" https://apple.com/mac "` → `.link(URL(string: "https://apple.com/mac")!)`
  - `"https://a.com\nhttps://b.com"` → `.text`; `"see https://a.com"` → `.text`; `"ftp://x.org"` → `.text`; `"mailto:a@b.c"` → `.text` (фокус ревью №4)
  - `["public.png"]`, png `Data([1,2,3])` → `.image(Data([1,2,3]), uti: "public.png")`
  - `["public.tiff","public.url"]`, tiff `Data([4])`, urlString `"https://x/y.jpg"`, string `nil` → `.image(Data([4]), uti: "public.tiff")`
  - есть и png, и tiff → png
  - `["public.rtf","public.utf8-plain-text","com.adobe.pdf","public.tiff"]`, `"Report"`, tiff → `.text("Report")`
  - `"  \n "`, без картинок → `nil`
  - `["public.url"]`, urlString `"https://a.com"` → `.link`
- [ ] **Шаг 2: тесты истории**
  - `newestFirst`: add text "a", потом "b" → `items.map(\.previewText) == ["b","a"]`
  - `capacityIsTen`: add "0"…"10" → `count == 10`, `first?.previewText == "10"`, нет "0"
  - `duplicateMovesToTopKeepingId`: add a (t0), b (t1), снова a (t2) → `count == 2`, `first.id == idA`, `first.copiedAt == t2`
  - `imageDedupByContent`: дважды `.image(Data([9]), uti: "public.png")` → `count == 1`
  - `promoteMovesToTop`: a, b; `promote(id: idA, at: t3)` → первый a, `copiedAt == t3`
  - `clearEmpties` → `items.isEmpty`
  - `hugeTextPreviewIsTruncated`: текст из 5 000 000 «x» → `previewText!.count == 301`, оканчивается на «…» (фокус ревью №1)
- [ ] **Шаг 3: тесты трекера** (фокус ревью №5: изменение замечается без чтения содержимого)
  - `init(initialCount: 1)`: `observe(1) == false`, `observe(2) == true`, `observe(2) == false`
  - `markOwnWrite(3)`: `observe(3) == false`, `observe(4) == true`
- [ ] **Шаг 4:** `swift test` → новые тесты FAIL.
- [ ] **Шаг 5:** реализовать четыре файла по интерфейсам выше.
- [ ] **Шаг 6:** `swift test` → все PASS.
- [ ] **Шаг 7:** `git add Sources/NotchBuddyCore/Clipboard Tests && git commit -m "feat(core): clipboard classification and session history"`

---

### Task 4: Буфер — наблюдатель и UI панели

**Файлы:**
- Создать: `Sources/NotchBuddy/PasteboardWatcher.swift`, `Sources/NotchBuddy/ClipboardListView.swift`
- Изменить: `AppModel.swift`, `NotchController.swift`, `NotchView.swift`, `AppDelegate.swift`

**Интерфейсы:**
- Использует: `ClipboardHistory`, `PasteboardSnapshot`, `PasteboardChangeTracker`, `NotchGeometry.collapsedRect(showsRightEar:)`.
- Производит:
```swift
@MainActor final class PasteboardWatcher {
    init(pasteboard: NSPasteboard = .general, onExternalChange: @escaping (ClipboardItem.Content?) -> Void)
    func start()                         // Timer 0,4 с; content == nil, если доступ запрещён или классификация дала nil
    func write(_ item: ClipboardItem)    // запись + tracker.markOwnWrite
    var isAccessDenied: Bool { get }     // macOS 15.4+: accessBehavior == .alwaysDeny
}
// AppModel добавляет:
var history: ClipboardHistory
var thumbnails: [UUID: NSImage]          // CGImageSourceCreateThumbnailAtIndex, max 128px, в Task.detached
var accessDenied: Bool
var justCopiedID: UUID?                  // отметка «Скопировано» на 1,2 с
```
Детали: снимок из `NSPasteboard` — `types.map(\.rawValue)`, `string(forType: .string)`, `string(forType: .URL)`, `data(forType: .png)`, `data(forType: .tiff)`. Запись: text → `setString`; link → `writeObjects([url as NSURL])` + `setString(absoluteString)`; image → `setData(data, forType: .init(uti))`. Строка: text — `previewText`, 2 строки, 12pt; link — SF Symbol `link`, host жирным + путь серым; image — миниатюра 32×32 + «Изображение · W×H». Пустое состояние: «Скопируйте что-нибудь — я запомню последние 10». Нет доступа: «Нет доступа к буферу. Разрешите вставку в Системных настройках → Конфиденциальность и безопасность». Правое ухо: `doc.on.clipboard` + число; скрыто при пустой истории. Drag: `.onDrag { model.isDragging = true; return provider }`; провайдеры — `NSItemProvider(object: string as NSString)` / `(object: url as NSURL)` / `(object: NSImage(data:)!)`. Конец drag: пока `isDragging`, таймер 0,1 с проверяет `NSEvent.pressedMouseButtons & 1 == 0` → `isDragging = false`. Наведение: глобальный + локальный монитор `.mouseMoved`; 0,2 с внутри формы → раскрыть; 0,3 с вне → свернуть, если не `isDragging`; во время drag `ignoresMouseEvents` не трогать.

- [ ] **Шаг 1:** реализовать `PasteboardWatcher`, расширить `AppModel`, связать в `AppDelegate`.
- [ ] **Шаг 2:** `ClipboardListView` (строки 40pt, `ScrollView`), счётчик в правом ухе, раскрытие/сворачивание и drag-guard в `NotchController`; раскрытая панель 520×270: слева место 120pt под персонажа (пока пусто), справа список.
- [ ] **Шаг 3:** отладочный аргумент `-NotchBuddyForceExpanded YES` (`UserDefaults.standard.bool(forKey: "NotchBuddyForceExpanded")`) держит панель раскрытой — для скриншотов.
- [ ] **Шаг 4: проверка (часть шагов — руками пользователя)**
  Run: `scripts/build-app.sh && open build/NotchBuddy.app`, затем `printf 'привет' | pbcopy` → системный запрос доступа: попросить пользователя ответить «Разрешать всегда». Далее: `printf 'https://apple.com' | pbcopy`; `screencapture -c -x -R 0,0,200,200`; `for i in $(seq 1 11); do printf "item $i" | pbcopy; sleep 0.6; done`.
  `osascript -e 'quit app "NotchBuddy"'; open build/NotchBuddy.app --args -NotchBuddyForceExpanded YES; sleep 2; screencapture -x -R 560,0,620,290 build/shot-expanded.png` → через Read: 10 строк, сверху «item 11», «item 1» вытеснен; ссылка и картинка оформлены по-своему.
  Пользователь: клик по строке → `pbpaste` печатает выбранное; перетащить картинку в Заметки и текст в TextEdit — вставляются, панель не закрылась во время перетаскивания; клики по меню-бару рядом проходят.
  Отказ в доступе (фокус ревью №5): пользователь переключает доступ на «Запретить» в Системных настройках → Cmd+C даёт реакцию/без падения, в панели подсказка.
- [ ] **Шаг 5:** `swift test` → PASS; `git add Sources scripts && git commit -m "feat: clipboard history panel with copy and drag-out"`

---

### Task 5: Персонаж — риг, пружины, отрисовка

**Файлы:**
- Создать: `Sources/NotchBuddyCore/Character/{Rig,Pose,Spring,PoseAnimator}.swift`, `Sources/NotchBuddy/{CharacterAssets,CharacterModel,CharacterView}.swift`
- Тесты: `Tests/NotchBuddyCoreTests/{RigTests,PoseTransformTests,SpringTests,PoseAnimatorTests}.swift`
- Изменить: `NotchView.swift` (портрет в левом ухе, персонаж целиком в панели)

**Интерфейсы:**
```swift
public struct Rig: Codable, Equatable, Sendable {      // зеркало rig.json из задачи 1
    public struct Layer: Codable, Equatable, Sendable { public var name, file: String; public var parent: String?; public var pivot: [Double] }
    public struct Glow: Codable, Equatable, Sendable { public var name, parent, color: String; public var center: [Double]; public var radius, night: Double }
    public var canvas: [Double]; public var frames: [String: [Double]]; public var limits: [String: Double]
    public var layers: [Layer]; public var glows: [Glow]
    public func chain(to layer: String) -> [Layer]      // от корня до слоя включительно
    public func unitPivot(of layer: String) -> CGPoint  // pivot / canvas, 0…1
}
public struct Pose: Equatable, Sendable {               // все поля нормализованы
    public var lean, headTilt, headTurn, arm, antenna: Double   // −1…1
    public var bounce, breath, sleep, night: Double             // 0…1
    public var heartGlow, antennaGlow: Double                   // 0…1
    public static let rest: Pose
}
public struct PoseTargets: Equatable, Sendable {
    public var lean = 0.0, headTilt = 0.0, headTurn = 0.0, sleep = 0.0
    public var wiggle = false
}
public struct LayerTransform: Equatable, Sendable {
    public var rotation: Double; public var turn: Double; public var offset: CGVector; public var scaleY: Double
}
public func transforms(for pose: Pose, rig: Rig) -> [String: LayerTransform]   // локальные, по имени слоя
public struct Spring: Sendable {
    public var value, velocity, target: Double
    public init(value: Double = 0, stiffness: Double = 120, damping: Double = 14)
    public mutating func step(dt: Double)   // полунеявный Эйлер; dt ограничен 1/20 с
    public mutating func impulse(_ dv: Double)
}
public struct PoseAnimator: Sendable {
    public init()
    public private(set) var pose: Pose
    public mutating func step(dt: Double, time: Double, targets: PoseTargets, night: Bool) -> Pose
}
```
Отображение позы (`transforms`): body.rotation = `lean·limits.body`, body.scaleY = `1 + 0,015·breath`, body.offset.dy = `−bounce·0,08·canvas.h`; head.rotation = `clamp(headTilt)·limits.head + sleep·0,8·limits.head`, head.turn = `headTurn·limits.headTurn`, head.offset.dy = `sleep·0,03·canvas.h`; arm.rotation = `clamp(arm)·limits.arm`; antenna.rotation = `clamp(antenna)·limits.antenna`. Дыхание: `breath = 0,5 + 0,5·sin(2π·time/4)`. Антенна — вторичное движение: каждый шаг получает импульс против скорости `headTilt` и `lean` (коэффициент подобрать на глаз).

Отрисовка (`CharacterView(rig:images:pose:frame:height:)`, `frame` — `"portrait"`/`"full"`): каждый слой — `Image(cgImage)` размером холста; к нему применяются локальные трансформации цепочки от самого слоя до корня (`rotationEffect(anchor: unitPivot)`, у головы ещё `rotation3DEffect(.degrees(turn), axis: (0,1,0), anchor: unitPivot, perspective: 0.5)`), затем `offset`; слои рисуются в порядке `rig.layers`; вид обрезается по кадру и масштабируется до `height`. Свечения — `RadialGradient` с `.blendMode(.plusLighter)` поверх, с теми же трансформациями родителя, яркость `max(night·glow.night, flash)`, где flash = `heartGlow` для heart и `antennaGlow` для antenna. Ночь: `colorMultiply` от белого к `#4D5573` пропорционально `night`. `CharacterModel` (`@Observable @MainActor`) крутит `PoseAnimator` от `NSScreen.displayLink(target:selector:)` (30 fps свёрнуто / 60 раскрыто) и публикует `pose`.

- [ ] **Шаг 1: тесты**
  - `RigTests`: декодирование JSON-образца из задачи 1 (встроить строкой); `chain(to: "antenna").map(\.name) == ["body","head","antenna"]`; `unitPivot(of: "head")` == pivot/canvas.
  - `PoseTransformTests`: `Pose.rest` → все rotation/turn 0, offset .zero, scaleY в [1, 1,015]; `lean = 1` → `body.rotation == limits["body"]`; `headTilt = 3` → `head.rotation == limits["head"]` (ограничение); `sleep = 1` → `head.offset.dy > 0`, `head.rotation > 0`; `arm = -1` → `arm.rotation == -limits["arm"]`.
  - `SpringTests`: target 1, шаги по 1/60 в течение 2 с → `|value − 1| < 0,01`; один шаг с `dt = 5` (сон Mac, фокус ревью №3) → `value` конечен и `|value| ≤ 2`; `impulse(5)` из покоя → значение уходит от 0 и за 3 с возвращается в `|value| < 0,01`.
  - `PoseAnimatorTests`: targets `lean = 1` → через 2 с `pose.lean > 0,95`; breath за 4 с проходит и < 0,1, и > 0,9; после скачка targets `headTilt` 0→1 `pose.antenna` отклоняется (`|antenna| > 0,05` в первые 0,5 с) и за 3 с успокаивается до `< 0,02`; `night: true` → через 5 с `pose.night > 0,95`.
- [ ] **Шаг 2:** `swift test` → новые FAIL.
- [ ] **Шаг 3:** реализовать `Rig`, `Pose`/`transforms`, `Spring`, `PoseAnimator`.
- [ ] **Шаг 4:** `swift test` → PASS.
- [ ] **Шаг 5:** `CharacterAssets` (читает `Bundle.main.resourceURL/Character/rig.json` и PNG через `CGImageSource`), `CharacterModel`, `CharacterView`; портрет в левом ухе (высота 30pt), целиком в панели (100pt). Отладочный аргумент `-NotchBuddyForceNight YES`.
- [ ] **Шаг 6: проверка**
  Run: `scripts/build-app.sh && open build/NotchBuddy.app --args -NotchBuddyForceExpanded YES; sleep 2; screencapture -x -R 560,0,620,290 build/shot-character.png`, затем то же с `-NotchBuddyForceNight YES`.
  Ожидается (через Read): портрет и фигура совпадают с листом поз из задачи 1, «дышат» (два скриншота с интервалом 2 с различаются), ночью — затемнение и свечения как на `glow.jpeg`.
- [ ] **Шаг 7:** `git add Sources Tests && git commit -m "feat: layered character rendering with spring animation"`

---

### Task 6: Поведение — мозг, реакции, ввод

**Файлы:**
- Создать: `Sources/NotchBuddyCore/Character/{BehaviorBrain,Reaction,SeededRandom}.swift`, `Sources/NotchBuddy/InputMonitor.swift`
- Тесты: `Tests/NotchBuddyCoreTests/{BehaviorBrainTests,PoseAnimatorReactionTests}.swift`
- Изменить: `PoseAnimator.swift` (+ `play`), `CharacterModel.swift`, `AppDelegate.swift`, `CharacterView.swift` (контекстное меню)

**Интерфейсы:**
```swift
public enum Reaction: String, Sendable, CaseIterable {
    case flinch, jump, catchCopy, stretch, shakeHead, alienWiggle, wake
    public var duration: TimeInterval { get }   // flinch 0,4; jump 1,0; catchCopy 0,8; stretch 1,2; shakeHead 1,2; alienWiggle 0,8; wake 0,6
}
public enum BehaviorState: Equatable, Sendable { case idle, attentive, tickled, sleeping }
public enum BrainEvent: Equatable, Sendable { case cursorMoved(CGPoint), click(CGPoint), copied }   // экранные координаты
public struct SeededRandom: RandomNumberGenerator, Sendable { public init(seed: UInt64) }        // SplitMix64
public struct BehaviorBrain: Sendable {
    public static let sleepAfter: TimeInterval = 300
    public static let attentionRadius: Double = 200
    public static let idleActionInterval: ClosedRange<TimeInterval> = 15...40
    public var characterRect: CGRect                    // экранный прямоугольник видимого персонажа
    public private(set) var state: BehaviorState
    public var targets: PoseTargets { get }
    public init(now: Date, seed: UInt64)
    public mutating func handle(_ event: BrainEvent, now: Date) -> Reaction?
    public mutating func tick(now: Date, systemIdle: TimeInterval) -> Reaction?
}
// PoseAnimator добавляет:
public mutating func play(_ reaction: Reaction)
```
Правила мозга: курсор внутри `characterRect` → `.tickled` (`targets.wiggle = true`); ближе `attentionRadius` к центру → `.attentive`; иначе `.idle`. `targets.headTurn = clamp(dx/300)`, `lean = clamp(dx/600)`, `headTilt = clamp(dx/500)·0,5·(1 − attention)`, где `dx` — горизонтальное смещение курсора от центра, `attention = clamp(1 − dist/attentionRadius, 0, 1)`. Клик внутри `characterRect` → `.jump`, снаружи → `.flinch`; `.copied` → `.catchCopy`. Во сне: `cursorMoved`/`click` → `.wake` и выход из сна; `.copied` → выход из сна и `.catchCopy`. `tick`: `systemIdle ≥ 300` → `.sleeping` (`targets.sleep = 1`, наклон/поворот 0), возвращает `nil`; не во сне и `now ≥ nextIdleAction` → случайное из `[.stretch, .shakeHead, .alienWiggle]`; после любой реакции `nextIdleAction = now + random(15…40)`.
Реакции в аниматоре: flinch — малый импульс bounce + вспышка antennaGlow; jump — большой bounce + heartGlow + 2 взмаха руки; catchCopy — рука вверх + heartGlow 0,7 + antennaGlow; stretch — headTilt −0,6 → +0,6; shakeHead — 3 качания headTurn ±0,8; alienWiggle — 4 колебания arm ±0,4; wake — небольшой bounce + antennaGlow. `wiggle` — непрерывные мелкие колебания arm/headTilt.

- [ ] **Шаг 1: тесты мозга** (`characterRect = CGRect(x: 700, y: 1085, width: 40, height: 32)`, `seed: 42`)
  - `startsIdle`; `cursorFarRight` (x 1700) → `targets.headTurn == 1`, `lean > 0`; `cursorFarLeft` → `headTurn == -1`; курсор в центре прямоугольника → `.tickled`, `wiggle`; курсор в 100pt → `.attentive`
  - `clickInsideJumps` → `.jump`; `clickOutsideFlinches` → `.flinch`; `copiedCatches` → `.catchCopy`
  - `sleepsAfter300s`: `tick(systemIdle: 299)` → не спит; `tick(systemIdle: 300)` → `.sleeping`, `targets.sleep == 1`
  - `cursorWakes`: из сна `handle(.cursorMoved)` → `.wake`, state ≠ `.sleeping`; `copiedWakesAndCatches` → `.catchCopy`
  - `idleActionsEvery15to40s`: тики раз в 1 с на 200 с (`systemIdle: 0`) → первое действие в [15, 40] с, промежутки между действиями в [15, 40], все из `[.stretch, .shakeHead, .alienWiggle]`
  - `noIdleActionsWhileSleeping`: заснуть, 200 тиков с `systemIdle ≥ 300` → все `nil`
- [ ] **Шаг 2: тесты реакций** (`PoseAnimatorReactionTests`): для каждой `Reaction.allCases` после `play` и шагов по 1/60 до `duration + 2 с` поза в пределах 0,05 от позы без реакции; `jump` → max `bounce > 0,5`; `catchCopy` → `heartGlow > 0,5` в первые 0,1 с; `flinch` → `antennaGlow > 0,5` в первые 0,1 с.
- [ ] **Шаг 3:** `swift test` → новые FAIL.
- [ ] **Шаг 4:** реализовать `SeededRandom`, `Reaction`, `BehaviorBrain`, `PoseAnimator.play`.
- [ ] **Шаг 5:** `swift test` → PASS.
- [ ] **Шаг 6: связка.** `InputMonitor`: глобальный и локальный мониторы `[.mouseMoved, .leftMouseDragged, .leftMouseDown, .rightMouseDown]` → `brain.handle`; таймер 1 с → `brain.tick(systemIdle: CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: CGEventType(rawValue: ~0)!))`; `PasteboardWatcher.onExternalChange` → `.copied`; реакции → `animator.play`; `characterRect` обновляется при смене свёрнуто/раскрыто и экрана. Контекстное меню персонажа: «Очистить историю», «Выйти».
- [ ] **Шаг 7: проверка (руками пользователя, по списку из спеки)**: курсор вдоль верха — наклоны/поворот; курсор на персонаже — ёрзает; клик в стороне — вздрагивание и мигание антенны; клик по персонажу — прыжок, сердце (в панели), взмах; Cmd+C — «ловит», счётчик +1; ~30 с покоя — случайное действие; правый клик → меню работает.
- [ ] **Шаг 8:** `git add Sources Tests && git commit -m "feat: character behavior brain and reactions"`

---

### Task 7: Ночь, сон, энергия

**Файлы:**
- Создать: `Sources/NotchBuddyCore/Character/NightSchedule.swift`, `Tests/NotchBuddyCoreTests/NightScheduleTests.swift`
- Изменить: `CharacterModel.swift`, `CharacterView.swift`

**Интерфейсы:**
```swift
public enum NightSchedule {
    public static func isNight(_ date: Date, calendar: Calendar = .current) -> Bool   // 21:00 ≤ t < 07:00
}
```
- [ ] **Шаг 1: тесты** (календарь с фиксированной TZ `Europe/Moscow`): 20:59 → false; 21:00 → true; 03:00 → true; 06:59 → true; 07:00 → false; 12:00 → false.
- [ ] **Шаг 2:** `swift test --filter NightScheduleTests` → FAIL; реализовать; → PASS.
- [ ] **Шаг 3:** `CharacterModel` передаёт `night: NightSchedule.isNight(now) || ForceNight` в аниматор; «z»: три `Text("z")`, всплывающие и тающие по циклу 2,4 с, прозрачность = `pose.sleep`, в обоих кадрах.
- [ ] **Шаг 4: энергия.** Частота display link: 60 fps раскрыто, 30 свёрнуто, 10 во сне при затихших пружинах (`|velocity| < 0,001` по всем каналам); `isPaused = true` по `NSWorkspace.screensDidSleepNotification`, снова `false` по `screensDidWakeNotification`; мониторы и таймеры не создают работы, пока ничего не меняется.
- [ ] **Шаг 5: проверка**
  Run: `scripts/build-app.sh && open build/NotchBuddy.app; sleep 60; ps -o %cpu= -p $(pgrep -x NotchBuddy)` → `< 3.0` (три замера с интервалом 10 с).
  Ночь: `-NotchBuddyForceNight YES` + скриншот → свечение. Сон: попросить пользователя не трогать Mac 5 минут → голова опущена, «z»; движение мыши — просыпается. Полноэкранное приложение и переключение Spaces — челка на месте.
- [ ] **Шаг 6:** `swift test` → все PASS; `git add Sources Tests && git commit -m "feat: night glow, sleep, and energy throttling"`

---

## Сквозная проверка (после задачи 7)
- `swift test` — всё зелёное.
- `scripts/build-app.sh && open build/NotchBuddy.app` — без иконки в Dock; единственный системный запрос — доступ к буферу; после «Разрешать всегда» и пересборки (`scripts/build-app.sh`) запрос не повторяется.
- Ручной сценарий из спеки целиком (курсор, клики, копирование текста/ссылки/картинки, клик по элементу + Cmd+V, перетаскивание картинки в Заметки, сон, «Выйти»).
