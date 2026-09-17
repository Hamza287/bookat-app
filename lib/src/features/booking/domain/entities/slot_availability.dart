import 'package:equatable/equatable.dart';

class SlotAvailability extends Equatable {
  const SlotAvailability({
    required this.time,
    required this.available,
  });

  final String time;
  final bool available;

  @override
  List<Object?> get props => [time, available];
}
