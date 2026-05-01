/// A lightweight sealed Result type for explicit error handling.
///
/// Prefer this over throwing exceptions for expected error conditions.
/// [T] is the success value type, [E] is the error type.
sealed class Result<T, E> {
  /// Creates a [Result].
  const Result();
}

/// A successful result containing a [value].
final class Success<T, E> extends Result<T, E> {
  /// Creates a [Success] with the given [value].
  const Success(this.value);

  /// The success value.
  final T value;
}

/// A failed result containing an [error].
final class Failure<T, E> extends Result<T, E> {
  /// Creates a [Failure] with the given [error].
  const Failure(this.error);

  /// The error value.
  final E error;
}
