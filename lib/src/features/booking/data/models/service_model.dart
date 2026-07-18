import '../../domain/entities/service.dart';

class ServiceModel extends Service {
  const ServiceModel({
    required super.id,
    required super.companyName,
    required super.title,
    required super.category,
    required super.location,
    required super.priceLabel,
    required super.rating,
    required super.nextAvailableSlot,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: json['id'] as String,
      companyName: json['companyName'] as String,
      title: json['title'] as String,
      category: json['category'] as String,
      location: json['location'] as String,
      priceLabel: json['priceLabel'] as String,
      rating: (json['rating'] as num).toDouble(),
      nextAvailableSlot: DateTime.parse(json['nextAvailableSlot'] as String),
    );
  }
}
