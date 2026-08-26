import '../../properties/domain/property_models.dart';

class FavoriteEntry {
  const FavoriteEntry({
    required this.propertyId,
    required this.createdAt,
    this.property,
  });

  final String propertyId;
  final DateTime createdAt;
  final PropertySummary? property;

  factory FavoriteEntry.fromJson(Map<String, dynamic> json) => FavoriteEntry(
    propertyId: json['propertyId'].toString(),
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    property:
        json['property'] is Map<String, dynamic>
            ? PropertySummary.fromJson(json['property'] as Map<String, dynamic>)
            : null,
  );
}
