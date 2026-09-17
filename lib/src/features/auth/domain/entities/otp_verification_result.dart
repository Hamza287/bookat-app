import 'package:equatable/equatable.dart';

class OtpVerificationResult extends Equatable {
  const OtpVerificationResult({
    required this.success,
    required this.message,
  });

  final bool success;
  final String message;

  @override
  List<Object?> get props => [success, message];
}
