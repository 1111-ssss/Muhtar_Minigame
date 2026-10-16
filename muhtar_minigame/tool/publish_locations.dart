import 'dart:convert';
import 'dart:io';

/// Publishes the editor's individual map files into the runtime asset.
///
/// Keeping this small command in the repository makes the generated aggregate
/// reproducible after changing a map in `muhtar_build/maps/`.
void main() {
  const order = [
    'meadow',
    'forest',
    'ruins',
    'horse',
    'doner',
    'kopeechka',
    'cheburechnaya',
  ];
  final mapDirectory = Directory('muhtar_build/maps');
  final byId = <String, Map<String, dynamic>>{};
  for (final file in mapDirectory.listSync().whereType<File>().where(
    (file) => file.path.endsWith('.json'),
  )) {
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map) continue;
    final map = Map<String, dynamic>.from(decoded);
    final id = map['id'];
    if (id is String) byId[id] = map;
  }

  final maps = [
    for (final id in order)
      if (byId.containsKey(id)) byId[id],
  ];
  final output = const JsonEncoder.withIndent(
    '  ',
  ).convert({'format': 1, 'locations': maps});
  File('assets/maps/locations.json').writeAsStringSync('$output\n');
}
