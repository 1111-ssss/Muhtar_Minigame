import 'package:flutter/foundation.dart';

/// Фазы полноэкранного перехода между локациями.
enum LocationTransitionPhase {
  idle,
  fadeOut,
  titleDrop,
  titleHold,
  titleExit,
  fadeIn,
}

/// Состояние перехода, которое читают UI-оверлеи.
@immutable
class LocationTransitionState {
  const LocationTransitionState({required this.phase, this.locationName = ''});

  const LocationTransitionState.idle()
    : phase = LocationTransitionPhase.idle,
      locationName = '';

  final LocationTransitionPhase phase;
  final String locationName;
}
