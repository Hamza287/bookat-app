sealed class Failure {
  const Failure({required this.message});

  final String message;
}

final class NetworkFailure extends Failure {
  const NetworkFailure({required super.message});
}

final class ServerFailure extends Failure {
  const ServerFailure({required super.message});
}

final class UnexpectedFailure extends Failure {
  const UnexpectedFailure({required super.message});
}
