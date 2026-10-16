# Muhtar Minigame

Игра на Flutter + Flame: [`muhtar_minigame/`](muhtar_minigame/README.md).
MuhtarBuild — редактор карт и PNG-портретов персонажей: [`MUHTARBUILD.md`](MUHTARBUILD.md).

## Требования

- Flutter **3.47.7** с поддержкой Linux desktop (версия закреплена в
  `muhtar_minigame/.flutter-version`);
- Linux-пакеты Flutter desktop, `libmpv-dev`, `libepoxy-dev` или Docker.

Для Fedora установите системные зависимости до первого `flutter run`:

```bash
sudo dnf install clang cmake ninja-build pkgconf-pkg-config gtk3-devel \
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
- На ВБ сотрудник ПВЗ выдаёт поиск картошки на Мосту и отдельную ответную
  реплику после доставки.
- На ВБ интерактивный проп запускает три локальных ролика подряд. Кнопки
  пропуска нет, а закрытие сбрасывает последовательность. После финального
  ролика сразу открывается скин «Картофля».

Перед запуском сюжетной сцены раздевалки положите файлы из пользовательской папки в
`muhtar_minigame/assets/video/` с именами, перечисленными в
[`assets/video/README.md`](muhtar_minigame/assets/video/README.md). Видеоплеер
использует Flutter asset keys с URI `asset:///assets/video/...`, а не абсолютные
пути. Для воспроизведения подключены `media_kit`, `media_kit_video` и
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
