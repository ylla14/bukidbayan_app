/// One-time backfill script: translate all equipment docs that are missing
/// nameEn / nameTl / descriptionEn / descriptionTl.
///
/// Run from the project root:
///   dart run tool/backfill_translations.dart
///
/// The script paginates through every document in the `equipment` collection,
/// skips anything that already has a `nameEn` field, translates the rest via
/// MyMemory, and writes the four translation fields back with a Firestore
/// REST PATCH.
///
/// Rate-limit note: MyMemory allows ~50 000 chars/day with a registered email.
/// The default 300 ms inter-doc delay keeps throughput reasonable while
/// staying well within that budget for typical catalogue sizes.

// ignore_for_file: avoid_print
library;

import 'dart:convert';
import 'package:http/http.dart' as http;

// ── Config ──────────────────────────────────────────────────────────────────

const _projectId  = 'bukidbayan-capstoners';
const _email      = 'renzo_bautista@dlsu.edu.ph';
const _pageSize   = 100; // Firestore REST max is 300
const _delayMs    = 300; // ms between docs — tweak if you hit 429s

const _fsBase     = 'https://firestore.googleapis.com/v1'
                    '/projects/$_projectId/databases/(default)/documents';
const _mmBase     = 'https://api.mymemory.translated.net/get';

// ── Entry point ──────────────────────────────────────────────────────────────

Future<void> main() async {
  print('=== Equipment translation backfill ===');
  print('Project : $_projectId');
  print('Email   : $_email');
  print('Delay   : ${_delayMs}ms between documents\n');

  int total = 0, translated = 0, skipped = 0, failed = 0;
  String? pageToken;

  do {
    // ── Fetch a page of equipment docs ─────────────────────────────────────
    final queryParams = <String, String>{
      'pageSize': '$_pageSize',
      if (pageToken != null) 'pageToken': pageToken,
    };
    final listUri = Uri.parse('$_fsBase/equipment')
        .replace(queryParameters: queryParams);

    final listRes = await http.get(listUri);
    if (listRes.statusCode != 200) {
      print('ERROR: Could not list equipment (${listRes.statusCode})');
      print(listRes.body);
      break;
    }

    final body      = jsonDecode(listRes.body) as Map<String, dynamic>;
    final documents = (body['documents'] as List<dynamic>?) ?? [];
    pageToken       = body['nextPageToken'] as String?;

    if (documents.isEmpty) {
      print('No documents on this page — collection may be empty.');
      break;
    }

    print('── Page: ${documents.length} doc(s) ──');

    for (final rawDoc in documents) {
      total++;
      final doc    = rawDoc as Map<String, dynamic>;
      final fields = (doc['fields'] as Map<String, dynamic>?) ?? {};
      final name   = _str(fields['name']);

      // ── Skip if translation already present ───────────────────────────
      if (fields.containsKey('nameEn')) {
        skipped++;
        print('  [skip]  "$name"');
        continue;
      }

      final description = _str(fields['description']);
      print('  [run]   "$name"');

      // ── Translate 4 combinations in parallel ──────────────────────────
      try {
        final results = await Future.wait([
          _translate(name,        from: 'tl', to: 'en'), // nameEn
          _translate(name,        from: 'en', to: 'tl'), // nameTl
          _translate(description, from: 'tl', to: 'en'), // descriptionEn
          _translate(description, from: 'en', to: 'tl'), // descriptionTl
        ]);

        final translations = {
          'nameEn'       : results[0],
          'nameTl'       : results[1],
          'descriptionEn': results[2],
          'descriptionTl': results[3],
        };

        await _patchDoc(
          docResourceName: doc['name'] as String,
          fields: translations,
        );

        print('         EN="${results[0]}"  TL="${results[1]}"');
        translated++;

        // Brief pause to respect rate limits
        await Future.delayed(const Duration(milliseconds: _delayMs));
      } catch (e) {
        failed++;
        print('  [FAIL]  "$name" — $e');
      }
    }
  } while (pageToken != null);

  // ── Summary ───────────────────────────────────────────────────────────────
  print('\n=== Done ===');
  print('Total     : $total');
  print('Translated: $translated');
  print('Skipped   : $skipped (already had translations)');
  print('Failed    : $failed');

  if (failed > 0) {
    print('\nRe-run the script to retry failed documents '
        '(already-translated ones are automatically skipped).');
  }
}

// ── Protected terms ──────────────────────────────────────────────────────────

/// Equipment terms that must never be translated. Must stay in sync with
/// TranslationService.doNotTranslate in lib/services/translation_service.dart.
/// Sorted longest-first so longer phrases are matched before shorter substrings.
const List<String> _doNotTranslate = [
  'Floating Tiller (Pagong)',
  'Hand Tractor (Kuliglig)',
  'Harvester (Halimaw)',
  'Rice Mill (Gilingan)',
  'Disc Harrow',
  'Disc Plough',
  'Disc Plow',
  'Hand Tool',
  'Implements',
  'Machine',
];

// ── Spam / bad-translation validation ────────────────────────────────────────

final _emailPattern =
    RegExp(r'[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}');
final _urlPattern =
    RegExp(r'https?://|www\.', caseSensitive: false);

const _spamKeywords = [
  'whatsapp', 'telegram', 'viber', 'online chat', 'call now',
  'contact us', 'click here', 'sign up', 'subscribe', 'buy now',
  'free trial',
];

bool _isValidTranslation(String original, String result) {
  if (_emailPattern.hasMatch(result)) return false;
  if (_urlPattern.hasMatch(result))   return false;
  final lower = result.toLowerCase();
  if (_spamKeywords.any((kw) => lower.contains(kw))) return false;
  if (result.length > original.length * 5 + 30) return false;
  return true;
}

// ── Placeholder helpers ───────────────────────────────────────────────────────

/// Swaps protected terms with `«Tn»` placeholders; originals stored in [bucket].
String _protect(String text, List<String> bucket) {
  var result = text;
  for (final term in _doNotTranslate) {
    final pattern = RegExp(RegExp.escape(term), caseSensitive: false);
    result = result.replaceAllMapped(pattern, (m) {
      final idx = bucket.length;
      bucket.add(m.group(0)!);
      return '«T$idx»';
    });
  }
  return result;
}

/// Restores `«Tn»` placeholders back to the originals in [bucket].
String _restore(String text, List<String> bucket) {
  var result = text;
  for (int i = 0; i < bucket.length; i++) {
    result = result.replaceAll('«T$i»', bucket[i]);
  }
  return result;
}

// ── Helpers ──────────────────────────────────────────────────────────────────

/// Extracts a plain String from a Firestore REST `stringValue` field wrapper.
String _str(dynamic field) {
  if (field is Map) return (field['stringValue'] as String?) ?? '';
  return '';
}

/// Translates [text] from [from] to [to] via MyMemory.
/// Protected terms are swapped out before the API call and restored after.
/// Returns the original [text] on any failure so the script stays resilient.
Future<String> _translate(
  String text, {
  required String from,
  required String to,
}) async {
  if (text.trim().isEmpty || from == to) return text;

  // Entire text is a protected term — skip API call.
  final lower = text.trim().toLowerCase();
  if (_doNotTranslate.any((t) => t.toLowerCase() == lower)) return text;

  final bucket    = <String>[];
  final protected = _protect(text, bucket);

  try {
    final uri = Uri.parse(_mmBase).replace(queryParameters: {
      'q'       : protected,
      'langpair': '$from|$to',
      'de'      : _email,
    });
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) {
      final json       = jsonDecode(res.body) as Map<String, dynamic>;
      final translated = json['responseData']?['translatedText'] as String?;
      if (translated != null && translated.isNotEmpty) {
        final restored = _restore(translated, bucket);
        if (_isValidTranslation(text, restored)) return restored;
        print('    [bad translation rejected] "$restored"');
      }
    }
  } catch (_) {/* fall through to return original */}
  return text;
}

/// PATCHes only the supplied [fields] on the Firestore document at
/// [docResourceName] (the full `name` value returned by the list API).
Future<void> _patchDoc({
  required String docResourceName,
  required Map<String, String> fields,
}) async {
  // Build updateMask query string — Firestore requires repeated fieldPaths keys
  final maskParams = fields.keys
      .map((k) => 'updateMask.fieldPaths=${Uri.encodeQueryComponent(k)}')
      .join('&');

  final url = 'https://firestore.googleapis.com/v1/$docResourceName'
      '?$maskParams';

  final body = jsonEncode({
    'fields': {
      for (final e in fields.entries)
        e.key: {'stringValue': e.value},
    },
  });

  final res = await http.patch(
    Uri.parse(url),
    headers: {'Content-Type': 'application/json'},
    body: body,
  );

  if (res.statusCode != 200) {
    throw Exception('PATCH failed (${res.statusCode}): ${res.body}');
  }
}
