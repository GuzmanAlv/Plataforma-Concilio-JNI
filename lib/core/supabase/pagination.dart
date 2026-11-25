import '../domain/json_fields.dart';

typedef JsonPageLoader = Future<List<JsonMap>> Function(int from, int to);

/// Loads all rows with a stable, unique order supplied by the caller.
/// Continues until an empty page, including when a server caps pages below 500.
Future<List<JsonMap>> loadAllRows(JsonPageLoader loadPage) async {
  const requestedPageSize = 500;
  final result = <JsonMap>[];
  var offset = 0;
  while (true) {
    final page = await loadPage(offset, offset + requestedPageSize - 1);
    if (page.isEmpty) return List.unmodifiable(result);
    result.addAll(page);
    offset += page.length;
  }
}
