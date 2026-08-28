class PropertyAddress {
  const PropertyAddress({
    required this.districtName,
    required this.cityName,
    required this.formatted,
    this.streetName,
    this.neighborhoodName,
  });

  final String? streetName;
  final String? neighborhoodName;
  final String districtName;
  final String cityName;
  final String formatted;

  factory PropertyAddress.fromJson(Map<String, dynamic> json) =>
      PropertyAddress(
        streetName: json['streetName'] as String?,
        neighborhoodName: json['neighborhoodName'] as String?,
        districtName: json['districtName'] as String? ?? 'Çankaya',
        cityName: json['cityName'] as String? ?? 'Ankara',
        formatted:
            json['formatted'] as String? ??
            _joinAddress([
              json['streetName'] as String?,
              json['neighborhoodName'] as String?,
              json['districtName'] as String?,
              json['cityName'] as String?,
            ]),
      );
}

class PropertySummary {
  const PropertySummary({
    required this.id,
    required this.externalRef,
    required this.monthlyRent,
    required this.areaM2,
    required this.roomCount,
    required this.latitude,
    required this.longitude,
    required this.totalScore,
    required this.band,
    required this.address,
    required this.isFavorite,
    this.topStrength,
    this.topWeakness,
  });

  final String id;
  final String externalRef;
  final double monthlyRent;
  final int areaM2;
  final String roomCount;
  final double latitude;
  final double longitude;
  final double totalScore;
  final String band;
  final PropertyAddress address;
  final String? topStrength;
  final String? topWeakness;
  final bool isFavorite;

  int? get numericId => int.tryParse(id);

  factory PropertySummary.fromJson(Map<String, dynamic> json) =>
      PropertySummary(
        id: json['id'].toString(),
        externalRef: json['externalRef'] as String? ?? '',
        monthlyRent: (json['monthlyRent'] as num).toDouble(),
        areaM2: (json['areaM2'] as num).toInt(),
        roomCount: json['roomCount'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        totalScore: (json['totalScore'] as num).toDouble(),
        band: json['band'] as String? ?? 'poor',
        address: PropertyAddress.fromJson(
          json['address'] as Map<String, dynamic>? ?? const {},
        ),
        topStrength: json['topStrength'] as String?,
        topWeakness: json['topWeakness'] as String?,
        isFavorite: json['isFavorite'] as bool? ?? false,
      );

  PropertySummary copyWith({bool? isFavorite}) => PropertySummary(
    id: id,
    externalRef: externalRef,
    monthlyRent: monthlyRent,
    areaM2: areaM2,
    roomCount: roomCount,
    latitude: latitude,
    longitude: longitude,
    totalScore: totalScore,
    band: band,
    address: address,
    topStrength: topStrength,
    topWeakness: topWeakness,
    isFavorite: isFavorite ?? this.isFavorite,
  );
}

class PropertyFeatures {
  const PropertyFeatures({
    required this.hasElevator,
    required this.hasParking,
    required this.isFurnished,
    required this.petsAllowed,
    this.floorNo,
    this.totalFloors,
    this.buildingAge,
    this.rentPerM2,
    this.deposit,
  });

  final int? floorNo;
  final int? totalFloors;
  final int? buildingAge;
  final bool hasElevator;
  final bool hasParking;
  final bool isFurnished;
  final bool petsAllowed;
  final double? rentPerM2;
  final double? deposit;

  factory PropertyFeatures.fromJson(Map<String, dynamic> json) =>
      PropertyFeatures(
        floorNo: (json['floorNo'] as num?)?.toInt(),
        totalFloors: (json['totalFloors'] as num?)?.toInt(),
        buildingAge: (json['buildingAge'] as num?)?.toInt(),
        hasElevator: json['hasElevator'] as bool? ?? false,
        hasParking: json['hasParking'] as bool? ?? false,
        isFurnished: json['isFurnished'] as bool? ?? false,
        petsAllowed: json['petsAllowed'] as bool? ?? false,
        rentPerM2: (json['rentPerM2'] as num?)?.toDouble(),
        deposit: (json['deposit'] as num?)?.toDouble(),
      );
}

class PropertyScoreRow {
  const PropertyScoreRow({
    required this.categoryCode,
    required this.label,
    required this.durationMin,
    required this.targetMin,
    required this.cutoffMin,
    required this.subScore,
    required this.weight,
    required this.contribution,
    required this.status,
    required this.densityBonus,
    required this.searchRadiusM,
    this.poiCountInRadius,
    this.poiId,
  });

  final String categoryCode;
  final String label;
  final double durationMin;
  final double targetMin;
  final double cutoffMin;
  final double subScore;
  final double weight;
  final double contribution;
  final String status;
  final int? poiCountInRadius;
  final double densityBonus;
  final String? poiId;
  final int searchRadiusM;

  factory PropertyScoreRow.fromJson(Map<String, dynamic> json) =>
      PropertyScoreRow(
        categoryCode: json['categoryCode'] as String? ?? '',
        label: json['label'] as String? ?? '',
        durationMin: (json['durationMin'] as num? ?? 0).toDouble(),
        targetMin: (json['targetMin'] as num? ?? 0).toDouble(),
        cutoffMin: (json['cutoffMin'] as num? ?? 0).toDouble(),
        subScore: (json['subScore'] as num? ?? 0).toDouble(),
        weight: (json['weight'] as num? ?? 0).toDouble(),
        contribution: (json['contribution'] as num? ?? 0).toDouble(),
        status: json['status'] as String? ?? 'weak',
        poiCountInRadius: (json['poiCountInRadius'] as num?)?.toInt(),
        densityBonus: (json['densityBonus'] as num? ?? 0).toDouble(),
        poiId: json['poiId']?.toString(),
        searchRadiusM: (json['searchRadiusM'] as num? ?? 0).toInt(),
      );
}

class PropertyBudgetFit {
  const PropertyBudgetFit({
    required this.monthlyRent,
    required this.status,
    required this.message,
    this.minMonthlyBudget,
    this.maxMonthlyBudget,
    this.ratioToMax,
  });

  final double monthlyRent;
  final double? minMonthlyBudget;
  final double? maxMonthlyBudget;
  final double? ratioToMax;
  final String status;
  final String message;

  factory PropertyBudgetFit.fromJson(Map<String, dynamic> json) =>
      PropertyBudgetFit(
        monthlyRent: (json['monthlyRent'] as num? ?? 0).toDouble(),
        minMonthlyBudget: (json['minMonthlyBudget'] as num?)?.toDouble(),
        maxMonthlyBudget: (json['maxMonthlyBudget'] as num?)?.toDouble(),
        ratioToMax: (json['ratioToMax'] as num?)?.toDouble(),
        status: json['status'] as String? ?? 'unknown',
        message: json['message'] as String? ?? '',
      );
}

class PropertyWeakLink {
  const PropertyWeakLink({
    required this.categoryCode,
    required this.label,
    required this.points,
    required this.weightedAverage,
    required this.message,
  });

  final String categoryCode;
  final String label;
  final double points;
  final double weightedAverage;
  final String message;

  factory PropertyWeakLink.fromJson(Map<String, dynamic> json) =>
      PropertyWeakLink(
        categoryCode: json['categoryCode'] as String? ?? '',
        label: json['label'] as String? ?? '',
        points: (json['points'] as num? ?? 0).toDouble(),
        weightedAverage: (json['weightedAverage'] as num? ?? 0).toDouble(),
        message: json['message'] as String? ?? '',
      );
}

class PropertyScoreDetail {
  const PropertyScoreDetail({
    required this.total,
    required this.band,
    required this.rows,
    required this.strengths,
    required this.weaknesses,
    required this.budget,
    this.weakLink,
  });

  final double total;
  final String band;
  final List<PropertyScoreRow> rows;
  final List<PropertyScoreRow> strengths;
  final List<PropertyScoreRow> weaknesses;
  final PropertyBudgetFit budget;
  final PropertyWeakLink? weakLink;

  factory PropertyScoreDetail.fromJson(Map<String, dynamic> json) =>
      PropertyScoreDetail(
        total: (json['total'] as num? ?? 0).toDouble(),
        band: json['band'] as String? ?? 'poor',
        rows: _scoreRows(json['rows']),
        strengths: _scoreRows(json['strengths']),
        weaknesses: _scoreRows(json['weaknesses']),
        budget: PropertyBudgetFit.fromJson(
          json['budget'] as Map<String, dynamic>? ?? const {},
        ),
        weakLink:
            json['weakLink'] is Map<String, dynamic>
                ? PropertyWeakLink.fromJson(
                  json['weakLink'] as Map<String, dynamic>,
                )
                : null,
      );
}

class PropertyDetail {
  const PropertyDetail({
    required this.id,
    required this.externalRef,
    required this.monthlyRent,
    required this.areaM2,
    required this.roomCount,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.features,
    required this.score,
    required this.isFavorite,
    required this.isSynthetic,
  });

  final String id;
  final String externalRef;
  final double monthlyRent;
  final int areaM2;
  final String roomCount;
  final double latitude;
  final double longitude;
  final PropertyAddress address;
  final PropertyFeatures features;
  final PropertyScoreDetail score;
  final bool isFavorite;
  final bool isSynthetic;

  int? get numericId => int.tryParse(id);

  factory PropertyDetail.fromJson(Map<String, dynamic> json) => PropertyDetail(
    id: json['id'].toString(),
    externalRef: json['externalRef'] as String? ?? '',
    monthlyRent: (json['monthlyRent'] as num).toDouble(),
    areaM2: (json['areaM2'] as num).toInt(),
    roomCount: json['roomCount'] as String,
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    address: PropertyAddress.fromJson(
      json['address'] as Map<String, dynamic>? ?? const {},
    ),
    features: PropertyFeatures.fromJson(
      json['features'] as Map<String, dynamic>? ?? const {},
    ),
    score: PropertyScoreDetail.fromJson(
      json['score'] as Map<String, dynamic>? ?? const {},
    ),
    isFavorite: json['isFavorite'] as bool? ?? false,
    isSynthetic: json['isSynthetic'] as bool? ?? false,
  );

  PropertyDetail copyWith({bool? isFavorite}) => PropertyDetail(
    id: id,
    externalRef: externalRef,
    monthlyRent: monthlyRent,
    areaM2: areaM2,
    roomCount: roomCount,
    latitude: latitude,
    longitude: longitude,
    address: address,
    features: features,
    score: score,
    isFavorite: isFavorite ?? this.isFavorite,
    isSynthetic: isSynthetic,
  );
}

List<PropertyScoreRow> _scoreRows(Object? value) =>
    (value as List<dynamic>? ?? const [])
        .map((item) => PropertyScoreRow.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);

String _joinAddress(List<String?> parts) => parts
    .whereType<String>()
    .map((part) => part.trim())
    .where((part) => part.isNotEmpty)
    .join(', ');
