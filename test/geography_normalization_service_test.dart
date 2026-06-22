import 'package:bukidbayan_app/services/geography_normalization_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GeographyNormalizationService', () {
    const service = GeographyNormalizationService();

    test(
      'extracts barangay, municipality, province, and region when labeled',
      () {
        final fields = service.normalizeAddressFields(
          address:
              'Purok 4, Barangay San Jose, Tanauan City, Batangas, CALABARZON',
        );

        expect(fields['barangay'], 'Barangay San Jose');
        expect(fields['municipality'], 'Tanauan City');
        expect(fields['province'], 'Batangas');
        expect(fields['region'], 'CALABARZON');
      },
    );

    test('builds prefixed farm geography fields', () {
      final fields = service.normalizeAddressFields(
        address: 'Sitio Uno, Barangay Sampaga, Los Banos, Laguna',
        prefix: 'farm',
      );

      expect(fields['farmBarangay'], 'Barangay Sampaga');
      expect(fields['farmMunicipality'], 'Los Banos');
      expect(fields['farmProvince'], 'Laguna');
      expect(fields.containsKey('farmRegion'), isFalse);
    });

    test('can emit null fields when clearing an address', () {
      final fields = service.normalizeAddressFields(
        address: '',
        prefix: 'farm',
        includeNulls: true,
      );

      expect(fields['farmBarangay'], isNull);
      expect(fields['farmMunicipality'], isNull);
      expect(fields['farmProvince'], isNull);
      expect(fields['farmRegion'], isNull);
    });
  });
}
