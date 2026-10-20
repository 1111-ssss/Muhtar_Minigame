FLUTTER ?= flutter

.PHONY: test analyze format run build publish-maps

test:
	$(FLUTTER) pub get --offline
	$(FLUTTER) test

analyze:
	$(FLUTTER) pub get --offline
	$(FLUTTER) analyze

format:
	dart format lib test tool

run:
	FLUTTER_BIN="$(FLUTTER)" "$(CURDIR)/../RunGame"

build:
	$(FLUTTER) pub get --offline
	$(FLUTTER) build linux --release

publish-maps:
	dart run tool/publish_locations.dart
