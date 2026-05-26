sealed class Result<T, E> {
  const Result();

  bool get isSuccess => this is Success<T, E>;
  bool get isFailure => this is Failure<T, E>;

  T? get valueOrNull => switch (this) {
        Success<T, E>(value: final v) => v,
        Failure<T, E>() => null,
      };

  E? get errorOrNull => switch (this) {
        Success<T, E>() => null,
        Failure<T, E>(error: final e) => e,
      };

  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(E error) onFailure,
  }) {
    return switch (this) {
      Success<T, E>(value: final v) => onSuccess(v),
      Failure<T, E>(error: final e) => onFailure(e),
    };
  }
}

final class Success<T, E> extends Result<T, E> {
  final T value;
  const Success(this.value);
}

final class Failure<T, E> extends Result<T, E> {
  final E error;
  const Failure(this.error);
}
