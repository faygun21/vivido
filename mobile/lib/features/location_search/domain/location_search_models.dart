class LocationBounds {
  const LocationBounds({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  final double south;
  final double west;
  final double north;
  final double east;

  factory LocationBounds.fromJson(Map<String, dynamic> json) => LocationBounds(
    south: (json['south'] as num).toDouble(),
    west: (json['west'] as num).toDouble(),
    north: (json['north'] as num).toDouble(),
    east: (json['east'] as num).toDouble(),
  );
}

class LocationSearchResult {
  const LocationSearchResult({
    required this.id,
    required this.label,
    required this.kind,
    required this.latitude,
    required this.longitude,
    required this.source,
    this.bounds,
    this.neighborhood,
  });

  final String id;
  final String label;
  final String kind;
  final double latitude;
  final double longitude;
  final LocationBounds? bounds;
  final String? neighborhood;
  final String source;

  factory LocationSearchResult.fromJson(Map<String, dynamic> json) {
    final rawBounds = json['bounds'];
    return LocationSearchResult(
      id: json['id'] as String,
      label: json['label'] as String,
      kind: json['kind'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      bounds: rawBounds is Map<String, dynamic>
          ? LocationBounds.fromJson(rawBounds)
          : null,
      neighborhood: json['neighborhood'] as String?,
      source: json['source'] as String,
    );
  }
}

class LocationSearchResponse {
  const LocationSearchResponse({
    required this.items,
    required this.attribution,
  });

  final List<LocationSearchResult> items;
  final String attribution;

  factory LocationSearchResponse.fromJson(Map<String, dynamic> json) =>
      LocationSearchResponse(
        items: (json['items'] as List<dynamic>? ?? const [])
            .map(
              (item) =>
                  LocationSearchResult.fromJson(item as Map<String, dynamic>),
            )
            .toList(growable: false),
        attribution: json['attribution'] as String? ?? '',
      );
}
