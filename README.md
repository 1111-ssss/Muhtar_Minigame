# Muhtar Minigame

Игра на Flutter + Flame: [`muhtar_minigame/`](muhtar_minigame/README.md).
MuhtarBuild — редактор карт и PNG-портретов персонажей: [`MUHTARBUILD.md`](MUHTARBUILD.md).

## Требования

- Flutter **3.47.7** с поддержкой Linux desktop (версия закреплена в
  `muhtar_minigame/.flutter-version`);
- Linux-пакеты Flutter desktop, `libmpv-dev`, `libepoxy-dev` или Docker.

Для Fedora установите системные зависимости до первого запуска:

```bash
sudo dnf install clang cmake ninja-build pkgconf-pkg-config gtk3-devel glib2-devel \
  mpv-devel libepoxy-devel alsa-lib-devel pulseaudio-libs-devel
pkg-config --modversion mpv
```

Для Debian/Ubuntu используются эквивалентные пакеты `libmpv-dev` и
`libepoxy-dev`; полный список уже есть в `Dockerfile`. Ошибка
`PkgConfig::mpv ... target was not found` означает, что `mpv.pc` не найден в
системном `pkg-config` path.

## Установка и запуск

Из корня репозитория:

```bash
make test                 # установит зависимости из локального кэша и запустит тесты
make run                  # запустит игру на Linux desktop
```

`make run` и `./RunGame` выполняют проверку GTK/GLib перед запуском и на Fedora
не используют устаревший `PKG_CONFIG_PATH` от Debian/Ubuntu. Если CMake уже
успел сохранить старый путь, обёртка удалит только кэш Flutter-сборки.

Если запускался прямой `flutter run` и появилась ошибка про
`/usr/lib/x86_64-linux-gnu/glib-2.0/include`, восстановите системные пакеты и
запустите игру через обёртку:

```bash
sudo dnf reinstall pkgconf-pkg-config glib2-devel gtk3-devel
cd muhtar_minigame
flutter clean
cd ..
./RunGame
```

Перед повторным запуском на Fedora можно проверить, что `pkg-config` больше не
возвращает Debian-путь:

```bash
pkg-config --variable=libdir glib-2.0
pkg-config --cflags gtk+-3.0
```

Результат должен ссылаться на `/usr/lib64`, а не на
`/usr/lib/x86_64-linux-gnu`. Если это не так, проверьте `PKG_CONFIG_PATH` и
`PKG_CONFIG_LIBDIR` или выполните `unset PKG_CONFIG_PATH PKG_CONFIG_LIBDIR`.

Для первой установки зависимостей с интернетом:

```bash
cd muhtar_minigame
flutter pub get
cd ..
```

MuhtarBuild запускается так:

```bash
cd muhtar_minigame
flutter run -d linux -t lib/muhtar_build.dart
```

## Проверки и сборка

```bash
make analyze
make format
make build
```

`make test` работает офлайн после `flutter pub get`: зависимости фиксированы в
`muhtar_minigame/pubspec.lock`. Агрегированный runtime-файл карт можно
перегенерировать из карт редактора командой `make publish-maps`.

## Новые сюжетные места

- В Донере Шаурмек появляется после перехода через «Коня»: сначала его нужно
  победить, затем у него открываются три мини-игры сборки шаурмы и магазин.
- Илья выдаёт задание на шаурму. После покупки появляется обязательный выбор —
  съесть её самому или отнести Илье; результат сохраняется в сейве и меняет его
  реплику.
- На ВБ сотрудник ПВЗ направляет за картошкой на Мост; находка подбирается
  через отдельный диалог и получает ответную реплику после доставки.
- На ВБ интерактивный проп запускает три локальных ролика подряд. Кнопки
  пропуска нет, а закрытие сбрасывает последовательность. После финального
  ролика сразу открывается скин «Картофля».

Ролики сюжетной сцены раздевалки лежат в
[`muhtar_minigame/assets/video/`](muhtar_minigame/assets/video/README.md).
Видеоплеер использует Flutter asset keys с URI `asset:///assets/video/...`, а не
абсолютные пути. Для воспроизведения подключены `media_kit`, `media_kit_video` и
`media_kit_libs_video`, включая Linux/Windows; при отсутствии MP4 игра
показывает graceful error и оставляет остальные сценарии доступными.

## Docker

Образ содержит закреплённый Flutter SDK, Linux-пакеты и собирает release-версию
игры с нуля:

```bash
docker build -t muhtar-minigame .
docker run --rm -it --net=host \
  -e DISPLAY=${DISPLAY:-:0} \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  muhtar-minigame
```

Для CI достаточно выполнить `docker build`; команда контейнера использует
`xvfb-run`, если у контейнера нет собственного дисплея.
