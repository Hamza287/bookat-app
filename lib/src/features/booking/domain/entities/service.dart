class Service {
  const Service({
    required this.id,
    required this.companyName,
    required this.title,
    required this.category,
    required this.location,
    required this.priceLabel,
    required this.rating,
    required this.nextAvailableSlot,
  });

  final String id;
  final String companyName;
  final String title;
  final String category;
  final String location;
  final String priceLabel;
  final double rating;
  final DateTime nextAvailableSlot;
}
