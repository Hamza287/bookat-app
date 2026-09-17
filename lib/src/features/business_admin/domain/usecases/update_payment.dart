import '../../../../core/utils/result.dart';
import '../repositories/business_admin_repository.dart';

/// Settling a payment is two separate endpoints on the server — the method and
/// the status are updated independently — so both live behind this one use case
/// to keep callers from having to know that.
class UpdatePayment {
  const UpdatePayment(this._repository);

  final BusinessAdminRepository _repository;

  Future<Result<void>> status({
    required String paymentId,
    required String accessToken,
    required String status,
  }) {
    return _repository.updatePaymentStatus(
      paymentId: paymentId,
      accessToken: accessToken,
      status: status,
    );
  }

  Future<Result<void>> method({
    required String paymentId,
    required String accessToken,
    required String method,
  }) {
    return _repository.updatePaymentMethod(
      paymentId: paymentId,
      accessToken: accessToken,
      method: method,
    );
  }
}
