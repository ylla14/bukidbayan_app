import 'dart:convert';

import 'package:bukidbayan_app/services/crop_calendar_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('CropCalendarService', () {
    test(
      'parses rich API payload including planting/harvesting windows',
      () async {
        final service = CropCalendarService(
          apiUrl: 'https://example.com/crops',
          httpClient: MockClient((request) async {
            expect(request.url.queryParameters['country'], 'PHL');
            expect(request.url.queryParameters['region'], 'philippines');
            expect(request.url.queryParameters['month'], '1');

            return http.Response(
              jsonEncode([
                {
                  'canonicalKey': 'rice_dry',
                  'name': 'Rice (Dry Season)',
                  'regions': ['philippines'],
                  'seasons': ['dry season'],
                  'plantingMonths': [11, 12, 1],
                  'harvestingMonths': [3, 4],
                  'plantingPhase': 'November-January',
                  'harvestingPhase': 'March-April',
                  'notes': 'Stable irrigation recommended.',
                  'imageUrl': 'https://example.com/rice.jpg',
                },
                {
                  'name': 'Upo / Bottle gourd',
                  'regions': ['philippines'],
                  'seasons': ['year round'],
                  'plantingMonths': [10, 11, 12, 1],
                  'harvestingMonths': [1, 2, 3, 4],
                },
              ]),
              200,
            );
          }),
        );

        final crops = await service.getRegionalCrops(
          region: 'philippines',
          now: DateTime(2026, 1, 10),
        );

        expect(crops, hasLength(2));
        final crop = crops.first;
        expect(crop.canonicalKey, 'rice_dry');
        expect(crop.name, 'Rice (Dry Season)');
        expect(crop.seasons, ['Dry Season']);
        expect(crop.plantingMonths, [1, 11, 12]);
        expect(crop.harvestingMonths, [3, 4]);
        expect(crop.plantingPhase, 'November-January');
        expect(crop.harvestingPhase, 'March-April');
        expect(crop.notes, 'Stable irrigation recommended.');
        expect(crop.imageUrl, 'https://example.com/rice.jpg');
        expect(crops.last.name, 'Upo (Bottle Gourd)');
      },
    );

    test('uses curated fallback crop list when API is unavailable', () async {
      final service = CropCalendarService(
        apiUrl: 'https://example.com/crops',
        httpClient: MockClient((request) async {
          return http.Response('error', 500);
        }),
      );

      final crops = await service.getRegionalCrops(
        region: 'philippines',
        now: DateTime(2026, 7, 1),
      );

      final names = crops.map((c) => c.name).toSet();
      expect(names.contains('Rice (Wet Season)'), isTrue);
      expect(names.contains('Rice (Dry Season)'), isTrue);
      expect(names.contains('White Corn'), isTrue);
      expect(names.contains('Pechay'), isTrue);
      expect(names.contains('Banana'), isTrue);
      expect(crops.length, greaterThanOrEqualTo(10));
    });

    test('detectSeason follows PH wet/dry baseline', () {
      final service = CropCalendarService(apiUrl: '');
      expect(service.detectSeason(7), 'Wet Season');
      expect(service.detectSeason(12), 'Dry Season');
    });
  });
}
