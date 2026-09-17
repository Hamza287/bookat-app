import '../errors/failure.dart';

sealed class Result<T> {
  const Result();
}

final class Success<T> extends Result<T> {
  const Success(this.data);

  final T data;
}

final class Fail<T> extends Result<T> {
  const Fail(this.failure);

  final Failure failure;
}
