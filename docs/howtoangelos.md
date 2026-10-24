# HOWTO AngelOS: Полный справочник и регламент для ИИ-агентов

> **Обязательно к исполнению (правило из `AGENTS.md`):** Перед внесением изменений в рабочий стол AngelOS (niri, quickshell, виджеты бара, сессия, анимации, хоткеи) ты ОБЯЗАН следовать этому документу. Не запускай поиск вслепую по диску — все пути и сценарии задокументированы ниже.

---

## 1. Архитектура рабочего стола

AngelOS состоит из следующих взаимодействующих компонентов:

1. **Window Manager:** `niri` — скроллируемый тайлинговый Wayland-композитор (`~/.config/niri/`).
2. **Desktop Shell:** `quickshell` — Qt Quick/QML интерфейс: статус-бар, док, оверлеи, лаунчер (`~/.config/quickshell/angelos/`).
3. **X11 Слой совместимости:** `xwayland-satellite` — запускается как отдельный сервис niri, привязан к сокету (обычно `:3`).
4. **Сессионное окружение:** `/run/user/1000/angelos/session.env` и `systemctl --user` — единая точка передачи переменных (`DISPLAY`, `WAYLAND_DISPLAY`, `PATH`).
5. **Хранилище настроек:** `~/.config/angelos/settings.json` и `save.json`.
6. **Дотфайлы (Git):** `~/.local/share/angelos/dotfiles/`.

---

## 2. Карта файлов: что где лежит

### 🪟 Niri (Оконный менеджер) — `~/.config/niri/`
Главный файл `config.kdl` инклюдит файлы из подпапки `cfg/`:
- `cfg/binds.kdl` — **Все горячие клавиши** (запуск софта, `Super+Space`, тайлинг, фокус, звук).
- `cfg/animations.kdl` — **Анимации** (кривые `spring`, переключение воркспейсов, открытие окон).
- `cfg/layout.kdl` — **Геометрия и тайлинг** (`gaps`, рамки окон, ширина колонок).
- `cfg/misc.kdl` — **Системные переменные окружения** (`environment { ... }`), пути `PATH`, бэкенды Qt/GTK.
- `angelos.kdl` — **Специфика AngelOS**: правила слоёв QuickShell (`layer-shell`), автозапуск фоновых демонов.

### 🖥️ QuickShell (Панели, бар, виджеты) — `~/.config/quickshell/angelos/`
- `plugins/<name>/` — **Виджеты и плагины панели**:
  - `manifest.json` — манифест плагина (`id`, `name`, `icon`).
  - `BarWidget.qml` — компонент кнопки/виджета в статус-баре.
  - `Main.qml` / `Panel.qml` — выпадающее окно/меню плагина по клику.
  - `scan.py` — бэкенд сбора данных (запускается через `--watch <сек>`, шлёт JSON в stdout).
- `modules/` — системные QML-модули и синглтоны (тема `Theme.qml`, звук, сеть, лаунчер).
- `scripts/` — системные скрипты:
  - `session-env.py` — автодетект живого Xwayland display и экспорт переменных сессии.
  - `volume`, `brightness`, `screenshot`.
- `widgets/` — базовые UI-компоненты (кнопки, переключатели, карточки).
- `shell.qml` — корневой файл QuickShell.

---

## 3. Сценарии типовых задач (Playbooks)

### 📌 Сценарий 1: Пользователь просит изменить скорость / резкость переключения окон или воркспейсов
1. Открой [`~/.config/niri/cfg/animations.kdl`](file:///home/cune/.config/niri/cfg/animations.kdl).
2. Найди блоки `workspace-switch`, `horizontal-view-movement` или `window-open`.
3. Настрой физику `spring`:
   - `damping-ratio` (демпфирование: 1.0 — без отскока, < 1.0 — с пружинистым отскоком).
   - `stiffness` (жёсткость пружины: больше = резче/быстрее, 300–800 — плавно, >1200 — резко).
   - Либо кривую `easing`: `cubic-bezier`, `duration-ms`.
4. **Обязательно проверь синтаксис:** `niri validate`.
5. Примени: `niri msg action reload-config`.

### 📌 Сценарий 2: Пользователь просит добавить хоткей или изменить запуск программы
1. Открой [`~/.config/niri/cfg/binds.kdl`](file:///home/cune/.config/niri/cfg/binds.kdl).
2. Добавь привязку, например:
   ```kdl
   Mod+Shift+T { spawn "alacritty"; }
   ```
3. Если команда использует бинарник из `~/.cargo/bin` или `~/.local/bin`, убедись, что путь есть в [`cfg/misc.kdl`](file:///home/cune/.config/niri/cfg/misc.kdl).
4. Проверь: `niri validate`.
5. Примени: `niri msg action reload-config`.

### 📌 Сценарий 3: Пользователь просит добавить новый виджет или кнопку в бар
1. Посмотри эталонный плагин: [`plugins/slow-scroll/`](file:///home/cune/.config/quickshell/angelos/plugins/slow-scroll/) или [`plugins/speedtest/`](file:///home/cune/.config/quickshell/angelos/plugins/speedtest/).
2. Создай директорию `~/.config/quickshell/angelos/plugins/<plugin-id>/`.
3. Создай `manifest.json`:
   ```json
   {
     "id": "my-feature",
     "name": "My Feature",
     "version": "1.0.0",
     "entryPoint": "BarWidget.qml",
     "icon": "my-icon"
   }
   ```
4. Создай `BarWidget.qml`:
   - Используй цветовую палитру AngelOS (см. раздел Дизайн).
   - Обработка клика: `onClicked: { ... }`.
5. Добавь ID плагина в `~/.config/angelos/settings.json` в массив `"activePlugins"` (если требуется авто-активация).
6. Перезапусти QuickShell:
   ```bash
   systemctl --user restart quickshell
   ```

### 📌 Сценарий 4: Приложения не запускаются через лаунчер (`Super+Space`), но запускаются в терминале
1. **Проверь дисплей X11:**
   - Посмотри активные сокеты: `ls -la /tmp/.X11-unix/`.
   - Если есть мёртвые сокеты (`X2`), удали их.
   - Запусти авто-детект: `python3 ~/.config/quickshell/angelos/scripts/session-env.py`.
2. **Проверь PATH:**
   - Убедись, что `~/.cargo/bin` и `~/.local/bin` экспортированы в `systemctl --user`:
     ```bash
     systemctl --user import-environment PATH DISPLAY WAYLAND_DISPLAY
     ```
3. **Проверь .desktop файл:**
   - Если приложение не видит свой бинарник, укажи абсолютный путь в `Exec=` (например, `/home/cune/.cargo/bin/lemonstudio %f`).

### 📌 Сценарий 5: Виджет Antigravity Companion завис или показывает устаревшие лимиты
1. Внутренний язык-сервер `agy` при перезапуске слушает случайный HTTP-порт.
2. Сканер [`plugins/antigravity-companion/scan.py`](file:///home/cune/.config/quickshell/angelos/plugins/antigravity-companion/scan.py) автоматически ищет живой порт через `ss -tlnp` и сохраняет в `~/.cache/angelos/antigravity-ls.json`.
3. Запусти разово проверку:
   ```bash
   python3 ~/.config/quickshell/angelos/plugins/antigravity-companion/scan.py
   ```
   Убедись, что поле `limitsAt` соответствует текущему времени.
4. Если хук `sync.py` вызывает ошибки в `cli.log`, помни: для события `PostToolUse` хук должен возвращать пустой JSON `{}` (не `{"injectSteps": []}`).

---

## 4. Строгие правила дизайна (userskills/design)

Любой создаваемый UI обязан строго следовать дизайн-системе пользователя `cune`:

| Элемент | Значение |
|---|---|
| **Фон верх** | `#222225` |
| **Фон низ** | `#151517` |
| **Серый основной (текст)** | `#8C8C91` |
| **Серый глубокий (карточки)** | `#3A3A3F` |
| **Разделители/обводка** | Белый `@ 6-10%` |
| **Единственный акцентный цвет** | `#E8443A` (строго 1 мелкая деталь: точка, маркер, бейдж) |

- **~95% ахроматично (монохром).** Никаких вторых/третьих цветов, радуг, цветных плашек.
- **Иконки:** squircle (скругление 20–22%), вертикальный градиент `#222225` → `#151517`, внутренняя обводка белым @ 6%.
- Никаких веб-технологий (Electron/HTML) там, где используется нативный стек (QML, Rust, KDL).

---

## 5. Контрольный список верификации перед завершением задачи

Перед тем как сообщить пользователю, что задача готова:

- [ ] **Niri:** выполнен `niri validate` без ошибок синтаксиса KDL.
- [ ] **Niri:** отправлен сигнал `niri msg action reload-config`.
- [ ] **Python/QML:** проверен синтаксис изменённых скриптов (`python3 -m py_compile <file>`).
- [ ] **QuickShell:** сервис работает без крашей (`systemctl --user is-active quickshell`).
- [ ] **Дотфайлы:** изменения синхронизированы в `~/.local/share/angelos/dotfiles` (при необходимости).
- [ ] **Дизайн:** цвета проверены по таблице палитры.
