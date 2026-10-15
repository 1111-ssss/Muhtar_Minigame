import 'package:flutter/services.dart';

import '../build/build_models.dart';
import '../domain/locations.dart';

/// Read the editor's published snapshot before creating the game world.
class LocationAssets {
  static const assetPath = 'assets/maps/locations.json';

  static Future<void> load({AssetBundle? bundle}) async {
    final source = await (bundle ?? rootBundle).loadString(assetPath);
    final maps = decodeBuildMaps(source);
    final errors = validateBuildMaps(maps);
    if (errors.isNotEmpty) throw FormatException(errors.join('\n'));
    Locations.replaceOverrides(maps.map((map) => map.toLocation()));
  }
}
