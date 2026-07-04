import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class TranslationService {
  static const _base  = 'https://api.mymemory.translated.net/get';
  static const _email = 'renzo_bautista@dlsu.edu.ph';

  /// Terms that must never be translated — preserved verbatim in both EN and TL.
  /// Sorted longest-first so longer phrases are matched before shorter substrings.
  static const List<String> doNotTranslate = [
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

  // ── Spam / bad-translation patterns ─────────────────────────────────────────

  static final _emailPattern =
      RegExp(r'[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}');
  static final _urlPattern =
      RegExp(r'https?://|www\.', caseSensitive: false);

  /// Keywords that reliably indicate a spam / off-topic TM hit from MyMemory.
  static const _spamKeywords = [
    'whatsapp',
    'telegram',
    'viber',
    'online chat',
    'call now',
    'contact us',
    'click here',
    'sign up',
    'subscribe',
    'buy now',
    'free trial',
  ];

  /// Returns false if [result] looks like a spam or garbage translation.
  ///
  /// Checks (in order):
  ///   1. Contains an e-mail address
  ///   2. Contains a URL
  ///   3. Contains known spam keywords
  ///   4. Is more than 5× longer than [original] (with a 30-char buffer)
  static bool _isValidTranslation(String original, String result) {
    if (_emailPattern.hasMatch(result)) return false;
    if (_urlPattern.hasMatch(result))   return false;

    final lower = result.toLowerCase();
    if (_spamKeywords.any((kw) => lower.contains(kw))) return false;

    if (result.length > original.length * 5 + 30) return false;

    return true;
  }

  // ── Placeholder helpers ──────────────────────────────────────────────────────

  /// Replaces every occurrence of a protected term in [text] with a `«Tn»`
  /// placeholder. Originals are stored in [bucket] (indexed by n).
  static String _protect(String text, List<String> bucket) {
    var result = text;
    for (final term in doNotTranslate) {
      final pattern = RegExp(RegExp.escape(term), caseSensitive: false);
      result = result.replaceAllMapped(pattern, (m) {
        final idx = bucket.length;
        bucket.add(m.group(0)!);
        return '«T$idx»';
      });
    }
    return result;
  }

  /// Restores `«Tn»` placeholders back to the originals stored in [bucket].
  static String _restore(String text, List<String> bucket) {
    var result = text;
    for (int i = 0; i < bucket.length; i++) {
      result = result.replaceAll('«T$i»', bucket[i]);
    }
    return result;
  }

  // ── Core translate ───────────────────────────────────────────────────────────

  /// Translates [text] from [from] to [to] language code.
  /// Protected terms are swapped out before the API call and restored after.
  /// Bad / spam translations are rejected and the original [text] is returned.
  static Future<String> translate(
    String text, {
    required String from,
    required String to,
  }) async {
    if (text.trim().isEmpty || from == to) return text;

    // Entire text is a protected term — skip the API entirely.
    final lower = text.trim().toLowerCase();
    if (doNotTranslate.any((t) => t.toLowerCase() == lower)) return text;

    final bucket    = <String>[];
    final protected = _protect(text, bucket);

    try {
      final uri = Uri.parse(_base).replace(queryParameters: {
        'q'       : protected,
        'langpair': '$from|$to',
        'de'      : _email,
      });
      final response =
          await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final json       = jsonDecode(response.body) as Map<String, dynamic>;
        final translated =
            json['responseData']?['translatedText'] as String?;
        if (translated != null && translated.isNotEmpty) {
          final restored = _restore(translated, bucket);
          if (_isValidTranslation(text, restored)) return restored;
          debugPrint('TranslationService: rejected bad translation '
              '"$restored" for "$text"');
        }
      }
    } catch (e) {
      debugPrint('TranslationService: $e');
    }
    return text; // graceful fallback — show original
  }

  // ── Batch helper ─────────────────────────────────────────────────────────────

  /// Generates all four translation fields for an equipment listing.
  /// Runs all four API calls in parallel to minimise wait time.
  /// Returns keys: nameEn, nameTl, descriptionEn, descriptionTl.
  static Future<Map<String, String>> translateEquipmentFields({
    required String name,
    required String description,
  }) async {
    final results = await Future.wait([
      translate(name,        from: 'tl', to: 'en'), // nameEn
      translate(name,        from: 'en', to: 'tl'), // nameTl
      translate(description, from: 'tl', to: 'en'), // descriptionEn
      translate(description, from: 'en', to: 'tl'), // descriptionTl
    ]);
    return {
      'nameEn'       : results[0],
      'nameTl'       : results[1],
      'descriptionEn': results[2],
      'descriptionTl': results[3],
    };
  }
}
