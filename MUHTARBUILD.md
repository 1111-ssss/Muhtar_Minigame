# MuhtarBuild

Локальный инструмент разработки Muhtar Minigame. Находится в том же Flutter-проекте,
но запускается отдельно от игры и не трогает игровой прогресс.

В проверенном рабочем каталоге старый редактор не найден. Эта реализация использует
существующие модели локаций и PNG-портреты, не заменяя Flutter/Flame другим стеком.

## Запуск

Из корня `MuhtarMinigame/`:

```bash
./MuhtarBuild
```

Или из `muhtar_minigame/`:

```bash
flutter pub get
MUHTAR_BUILD=1 flutter run -d linux -t lib/muhtar_build.dart
```

Скрипт устанавливает правильный рабочий каталог. Можно указать SDK через
`FLUTTER_BIN=/path/to/flutter ./MuhtarBuild`, устройство — через
`MUHTAR_BUILD_DEVICE=windows` (скрипт требует bash). Редактор рассчитан на desktop,
не на браузер.

Для Linux нужны зависимости Flutter desktop: clang, CMake, Ninja, pkg-config и
GTK/GLib development libraries. На Debian/Ubuntu установите их так:

```bash
sudo apt-get update
sudo apt-get install --reinstall clang cmake ninja-build pkg-config libgtk-3-dev libglib2.0-dev
flutter clean
./MuhtarBuild
```

На Fedora используйте `dnf`:

```bash
sudo dnf install clang cmake ninja-build pkgconf-pkg-config gtk3-devel glib2-devel
cd muhtar_minigame
flutter clean
cd ..
./MuhtarBuild
```

Если пакеты уже были установлены, но каталог GLib всё ещё отсутствует:

```bash
sudo dnf reinstall glib2-devel gtk3-devel
```

MuhtarBuild автоматически использует Fedora-каталоги `/usr/lib64/pkgconfig` и
игнорирует устаревший `PKG_CONFIG_PATH` из другой Linux-системы. Поэтому после
установки пакетов достаточно снова выполнить `./MuhtarBuild`. Если нужно проверить
настройку вручную:

```bash
pkg-config --variable=libdir glib-2.0
pkg-config --cflags gtk+-3.0
```

На Fedora результат должен ссылаться на `/usr/lib64`, а не на
`/usr/lib/x86_64-linux-gnu`. Если команда всё ещё показывает Debian-путь, проверьте
переменные `PKG_CONFIG_PATH` и `PKG_CONFIG_LIBDIR`, затем выполните:

```bash
unset PKG_CONFIG_PATH PKG_CONFIG_LIBDIR
sudo dnf reinstall pkgconf-pkg-config glib2-devel gtk3-devel
```

Особенно важен каталог `glib-2.0/include` с `glibconfig.h`. Если CMake сообщает,
что отсутствует `/usr/lib/x86_64-linux-gnu/glib-2.0/include` или Fedora-путь
`/usr/lib64/glib-2.0/include`, это не ошибка карт или MuhtarBuild: повреждена или
неполна системная установка GLib development package (`libglib2.0-dev` на Debian/
Ubuntu или `glib2-devel` на Fedora). Скрипт теперь проверяет этот путь заранее и
выводит команду восстановления для найденного дистрибутива.

## Windows

Для запуска на Windows используйте файл из корня репозитория:

```bat
MuhtarBuild.bat
```

Нужны Flutter с включённой Windows Desktop поддержкой и Visual Studio с workload
**Desktop development with C++**. Если `flutter` не находится в `PATH`, укажите
путь к исполняемому скрипту Flutter:

```bat
set FLUTTER_BIN=C:\src\flutter\bin\flutter.bat
MuhtarBuild.bat
```

BAT-файл запускает тот же `lib/muhtar_build.dart`, что и Linux-скрипт, и передаёт
в Flutter устройство `windows`. Аргументы командной строки также передаются дальше.
Для создания автономной Windows-сборки выполните из `muhtar_minigame`:

```bat
flutter build windows --release -t lib\muhtar_build.dart
```

Готовый `.exe` появится в `build\windows\x64\runner\Release\`. Скомпилированный
`.exe` не добавлен в репозиторий, потому что его нужно собирать на Windows с
установленным Visual Studio toolchain.

## Карты

1. Откройте вкладку **Карты** и выберите одну из шести игровых локаций либо создайте новую.
2. Выберите кисть и тип тайла. Левая кнопка рисует; режим перемещения позволяет
   двигать и масштабировать изометрическую сетку.
3. Инструмент **Перемещение** переносит перетаскиванием игрока, объект, врага, NPC
   или переход на другую клетку. Размер объектов сохраняется; переход переносит
   тайл `4` вместе с собой. Для перемещения самой карты включите **Перемещение карты**.
4. Инструменты игрока, объектов, врагов, NPC и переходов размещают соответствующие
   сущности. Инспектор выбранной клетки позволяет менять их параметры и удалять их.
5. Для перехода задайте ID целевой карты и координаты прибытия. Тайлу выхода
   соответствует код `4`; перед применением проверяются цель, координаты и проходимость.
6. **Сохранить черновик** записывает текущую карту в
   `muhtar_minigame/muhtar_build/maps/<id>.json`. Незавершённый черновик можно сохранить,
   но нельзя применить к игре до исправления ошибок.
7. **Применить к игре** проверяет и сохраняет все карты, включая изменения в памяти,
   затем записывает `muhtar_minigame/assets/maps/locations.json`.
8. Полностью остановите игру и заново выполните `flutter run -d linux` из
   `muhtar_minigame/`. Hot reload недостаточно: JSON загружается при старте.

Есть отмена/повтор действий, отображение сетки и коллизий, JSON-инспектор всех полей,
импорт и экспорт JSON по пути к файлу. JSON одной карты содержит `id`, `name`, `tiles`,
`spawn`, `enemies`, `npcs`, `additionalNpcs`, `exits`, `props`, `outsideTile` и
`outsideGroundRegions`. Размер карты — до 128×128 тайлов.

Встроенные карты остаются в `lib/domain/locations.dart`. Опубликованный JSON заменяет
их по ID, не меняя Dart-исходники. Поэтому сохраняйте прежние ID сюжетных карт и
объектов: задания и сейвы ссылаются на них. Новая карта становится доступной после
добавления перехода из существующей локации. Создание NPC размещает его на карте,
но не создаёт диалог, задание или новый архетип врага.

Предпросмотр карты — редактируемая схема тайлов и маркеров, а не полный игровой
рендер с процедурными деревьями и персонажами.
