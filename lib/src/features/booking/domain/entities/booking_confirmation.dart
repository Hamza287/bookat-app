import 'package:equatable/equatable.dart';

class BookingConfirmation extends Equatable {
  const BookingConfirmation({required this.data});

  final Map<String, dynamic> data;

  @override
  List<Object?> get props => [data];
}
