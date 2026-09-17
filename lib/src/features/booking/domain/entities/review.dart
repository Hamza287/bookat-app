import 'package:equatable/equatable.dart';

class Review extends Equatable {
  const Review({
    required this.id,
    required this.rating,
    required this.comment,
    required this.customerName,
    required this.createdAt,
  });

  final String id;
  final int rating;
  final String comment;
  final String customerName;
  final DateTime? createdAt;

  @override
  List<Object?> get props => [id, rating, comment, customerName, createdAt];
}
