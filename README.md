# Muhtar Minigame

Игра на Flutter + Flame: [`muhtar_minigame/`](muhtar_minigame/README.md).
MuhtarBuild — редактор карт и PNG-портретов персонажей: [`MUHTARBUILD.md`](MUHTARBUILD.md).

## Требования

- Flutter **3.47.7** с поддержкой Linux desktop (версия закреплена в
  `muhtar_minigame/.flutter-version`);
- Linux-пакеты Flutter desktop или Docker.

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
