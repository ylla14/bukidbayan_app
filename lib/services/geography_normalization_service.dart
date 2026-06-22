class GeographyNormalizationService {
  const GeographyNormalizationService();

  static const List<String> _regionMarkers = [
    'region',
    'ncr',
    'car',
    'barmm',
    'mimaropa',
    'soccsksargen',
    'calabarzon',
    'metro manila',
    'western visayas',
    'central visayas',
    'eastern visayas',
    'northern mindanao',
    'davao region',
    'caraga',
    'bicol region',
    'ilocos region',
    'cagayan valley',
    'zamboanga peninsula',
    'central luzon',
    'western mindanao',
    'southern tagalog',
  ];

  Map<String, dynamic> normalizeAddressFields({
    required String? address,
    String prefix = '',
    bool includeNulls = false,
  }) {
    if (address == null) {
      return includeNulls ? _emptyMap(prefix: prefix) : <String, dynamic>{};
    }

    final trimmed = address.trim();
    if (trimmed.isEmpty) {
      return includeNulls ? _emptyMap(prefix: prefix) : <String, dynamic>{};
    }

    final parts = trimmed
        .split(',')
        .map(_cleanSegment)
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return includeNulls ? _emptyMap(prefix: prefix) : <String, dynamic>{};
    }

    final parsed = _parseParts(parts);
    final mapped = prefix.isEmpty
        ? parsed.toMap()
        : parsed.toPrefixedMap(prefix);

    if (includeNulls) {
      return mapped;
    }

    mapped.removeWhere((key, value) => value == null);
    return mapped;
  }

  Map<String, dynamic> buildUserGeographyFields({
    String? address,
    String? farmAddress,
    bool includeNulls = false,
  }) {
    return {
      ...normalizeAddressFields(address: address, includeNulls: includeNulls),
      ...normalizeAddressFields(
        address: farmAddress,
        prefix: 'farm',
        includeNulls: includeNulls,
      ),
    };
  }

  ParsedGeography _parseParts(List<String> parts) {
    final regionIndex = _findRegionIndex(parts);
    final barangayIndex = _findBarangayIndex(parts);

    if (barangayIndex != null) {
      return ParsedGeography(
        barangay: parts[barangayIndex],
        municipality: _partAt(parts, barangayIndex + 1),
        province: _partAt(parts, barangayIndex + 2),
        region: regionIndex != null
            ? parts[regionIndex]
            : _partAt(parts, barangayIndex + 3),
      );
    }

    if (regionIndex != null && regionIndex >= 3) {
      return ParsedGeography(
        barangay: parts[regionIndex - 3],
        municipality: parts[regionIndex - 2],
        province: parts[regionIndex - 1],
        region: parts[regionIndex],
      );
    }

    if (parts.length >= 3) {
      return ParsedGeography(
        barangay: parts[parts.length - 3],
        municipality: parts[parts.length - 2],
        province: parts[parts.length - 1],
        region: null,
      );
    }

    if (parts.length == 2) {
      return ParsedGeography(
        barangay: parts.first,
        municipality: parts.last,
        province: null,
        region: null,
      );
    }

    return ParsedGeography(
      barangay: parts.first,
      municipality: null,
      province: null,
      region: null,
    );
  }

  int? _findBarangayIndex(List<String> parts) {
    for (var i = 0; i < parts.length; i++) {
      final lower = parts[i].toLowerCase();
      if (RegExp(r'\b(brgy|barangay|bgy)\b').hasMatch(lower)) {
        return i;
      }
    }
    return null;
  }

  int? _findRegionIndex(List<String> parts) {
    for (var i = parts.length - 1; i >= 0; i--) {
      final lower = parts[i].toLowerCase();
      if (_regionMarkers.any(lower.contains)) {
        return i;
      }
    }
    return null;
  }

  String _cleanSegment(String raw) {
    return raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String? _partAt(List<String> parts, int index) {
    if (index < 0 || index >= parts.length) {
      return null;
    }
    return parts[index];
  }

  Map<String, dynamic> _emptyMap({required String prefix}) {
    final parsed = const ParsedGeography();
    return prefix.isEmpty ? parsed.toMap() : parsed.toPrefixedMap(prefix);
  }
}

class ParsedGeography {
  final String? barangay;
  final String? municipality;
  final String? province;
  final String? region;

  const ParsedGeography({
    this.barangay,
    this.municipality,
    this.province,
    this.region,
  });

  Map<String, dynamic> toMap() {
    return {
      'barangay': barangay,
      'municipality': municipality,
      'province': province,
      'region': region,
    };
  }

  Map<String, dynamic> toPrefixedMap(String prefix) {
    return {
      '${prefix}Barangay': barangay,
      '${prefix}Municipality': municipality,
      '${prefix}Province': province,
      '${prefix}Region': region,
    };
  }
}
