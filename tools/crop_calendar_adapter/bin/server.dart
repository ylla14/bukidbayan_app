import 'dart:convert';
import 'dart:io';

const _defaultPort = 8088;

void main() async {
  final port =
      int.tryParse(Platform.environment['ADAPTER_PORT'] ?? '') ?? _defaultPort;
  final records = await _loadRecords();
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);

  stdout.writeln('Crop calendar adapter listening on http://127.0.0.1:$port');
  stdout.writeln(
    'Example: http://127.0.0.1:$port/v1/crop-calendar?country=PHL&region=philippines&month=1',
  );

  await for (final request in server) {
    _applyCors(request.response);
    if (request.method == 'OPTIONS') {
      request.response
        ..statusCode = HttpStatus.noContent
        ..close();
      continue;
    }

    if (request.uri.path == '/health') {
      _writeJson(request.response, HttpStatus.ok, {
        'ok': true,
        'source': 'GEOGLAM/JRC',
        'records': records.length,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      });
      continue;
    }

    if (request.uri.path == '/v1/crop-calendar') {
      final country = (request.uri.queryParameters['country'] ?? 'PHL')
          .trim()
          .toUpperCase();
      final region = (request.uri.queryParameters['region'] ?? 'philippines')
          .trim()
          .toLowerCase();
      final month = int.tryParse(request.uri.queryParameters['month'] ?? '');

      final filtered = records
          .where((record) {
            if (country.isNotEmpty && record.country != country) return false;
            if (region.isNotEmpty && !_matchesRegion(record.regions, region)) {
              return false;
            }
            if (month == null) return true;
            return _isRelevantInMonth(record, month);
          })
          .toList(growable: false);

      _writeJson(
        request.response,
        HttpStatus.ok,
        filtered.map((record) => record.toApiMap()).toList(growable: false),
      );
      continue;
    }

    _writeJson(request.response, HttpStatus.notFound, {
      'error': 'not_found',
      'message': 'Use /v1/crop-calendar or /health',
    });
  }
}

void _applyCors(HttpResponse response) {
  response.headers
    ..set(HttpHeaders.accessControlAllowOriginHeader, '*')
    ..set(HttpHeaders.accessControlAllowMethodsHeader, 'GET, OPTIONS')
    ..set(HttpHeaders.accessControlAllowHeadersHeader, 'Content-Type');
}

bool _matchesRegion(List<String> regions, String target) {
  if (target.isEmpty) return true;
  return regions.any((r) => r.trim().toLowerCase() == target);
}

bool _isRelevantInMonth(_CropRecord record, int month) {
  if (month < 1 || month > 12) return true;
  if (record.seasons.contains('Year Round')) return true;
  if (record.plantingMonths.contains(month)) return true;
  if (record.harvestingMonths.contains(month)) return true;
  return false;
}

Future<List<_CropRecord>> _loadRecords() async {
  final jsonFile = _resolveDataFile();
  if (!await jsonFile.exists()) {
    stderr.writeln('Missing data file at: ${jsonFile.path}');
    return const [];
  }

  final decoded = jsonDecode(await jsonFile.readAsString());
  if (decoded is! List) return const [];

  final records = <_CropRecord>[];
  for (final item in decoded) {
    if (item is! Map<String, dynamic>) continue;
    final parsed = _CropRecord.fromMap(item);
    if (parsed == null) continue;
    records.add(parsed);
  }
  return records;
}

File _resolveDataFile() {
  final candidates = <File>[
    File.fromUri(Platform.script.resolve('../data/phl_crop_calendar.json')),
    File('tools/crop_calendar_adapter/data/phl_crop_calendar.json'),
    File('data/phl_crop_calendar.json'),
  ];
  for (final file in candidates) {
    if (file.existsSync()) return file;
  }
  return candidates.first;
}

void _writeJson(HttpResponse response, int statusCode, Object payload) {
  response
    ..statusCode = statusCode
    ..headers.contentType = ContentType.json
    ..write(jsonEncode(payload))
    ..close();
}

class _CropRecord {
  final String canonicalKey;
  final String name;
  final String country;
  final List<String> regions;
  final List<String> seasons;
  final List<int> plantingMonths;
  final List<int> harvestingMonths;
  final String? imageUrl;
  final String? plantingPhase;
  final String? harvestingPhase;
  final String? notes;
  final Map<String, dynamic> source;

  const _CropRecord({
    required this.canonicalKey,
    required this.name,
    required this.country,
    required this.regions,
    required this.seasons,
    required this.plantingMonths,
    required this.harvestingMonths,
    required this.imageUrl,
    required this.plantingPhase,
    required this.harvestingPhase,
    required this.notes,
    required this.source,
  });

  static _CropRecord? fromMap(Map<String, dynamic> map) {
    final canonicalKey = (map['canonicalKey'] ?? '').toString().trim();
    final name = (map['name'] ?? '').toString().trim();
    final country = (map['country'] ?? 'PHL').toString().trim().toUpperCase();
    if (canonicalKey.isEmpty || name.isEmpty) return null;

    return _CropRecord(
      canonicalKey: canonicalKey,
      name: name,
      country: country,
      regions: _asStrings(map['regions']),
      seasons: _asStrings(map['seasons']),
      plantingMonths: _asMonths(map['plantingMonths']),
      harvestingMonths: _asMonths(map['harvestingMonths']),
      imageUrl: _nullableText(map['imageUrl'] ?? map['image_url']),
      plantingPhase: _nullableText(map['plantingPhase']),
      harvestingPhase: _nullableText(map['harvestingPhase']),
      notes: _nullableText(map['notes']),
      source: (map['source'] is Map<String, dynamic>)
          ? map['source'] as Map<String, dynamic>
          : const <String, dynamic>{},
    );
  }

  Map<String, dynamic> toApiMap() {
    return {
      'canonicalKey': canonicalKey,
      'name': name,
      'regions': regions,
      'seasons': seasons,
      'plantingMonths': plantingMonths,
      'harvestingMonths': harvestingMonths,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (plantingPhase != null) 'plantingPhase': plantingPhase,
      if (harvestingPhase != null) 'harvestingPhase': harvestingPhase,
      if (notes != null) 'notes': notes,
      if (source.isNotEmpty) 'source': source,
    };
  }
}

List<String> _asStrings(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .map((item) => item.toString().trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
}

List<int> _asMonths(dynamic raw) {
  if (raw is! List) return const [];
  final values = <int>{};
  for (final value in raw) {
    final month = int.tryParse(value.toString());
    if (month == null || month < 1 || month > 12) continue;
    values.add(month);
  }
  final list = values.toList(growable: false)..sort();
  return list;
}

String? _nullableText(dynamic raw) {
  final value = raw?.toString().trim();
  if (value == null || value.isEmpty) return null;
  return value;
}
