import 'package:one_by_two/core/errors/app_exception.dart';

/// A Result type for repository return values — either [Success] or [Failure].
///
/// This provides a type-safe way to handle operations that can succeed or fail
/// without throwing exceptions across layer boundaries. All repository methods
/// in the app return `Result<T>` instead of throwing.
///
/// Example usage:
/// ```dart
/// final result = await repository.getExpense(id);
/// result.when(
///   success: (expense) => showExpense(expense),
///   failure: (exception) => showError(exception.message),
/// );
/// ```
sealed class Result<T> {
  /// Creates a [Result].
  const Result();

  /// Creates a [Success] result wrapping [data].
  factory Result.success(T data) = Success<T>;

  /// Creates a [Failure] result wrapping an [AppException].
  factory Result.failure(AppException exception) = Failure<T>;

  /// Returns the data if this is a [Success], otherwise `null`.
  T? get dataOrNull;

  /// Returns `true` if this is a [Success].
  bool get isSuccess;

  /// Returns `true` if this is a [Failure].
  bool get isFailure;

  /// Pattern-matches on the result, calling [success] or [failure] accordingly.
  ///
  /// Both callbacks must be provided for exhaustive handling.
  ///
  /// Returns the value produced by the matching callback.
  R when<R>({
    required R Function(T data) success,
    required R Function(AppException exception) failure,
  });

  /// Transforms the data inside a [Success] using [transform].
  ///
  /// If this is a [Failure], the exception is propagated unchanged.
  ///
  /// Example:
  /// ```dart
  /// final nameResult = expenseResult.map((expense) => expense.description);
  /// ```
  Result<R> map<R>(R Function(T data) transform);

  /// Chains a dependent operation that itself returns a [Result].
  ///
  /// If this is a [Success], applies [transform] to the data and returns
  /// its result. If this is a [Failure], propagates the exception.
  ///
  /// Example:
  /// ```dart
  /// final result = await getGroup(groupId)
  ///     .flatMap((group) => validateMembership(group, userId));
  /// ```
  Result<R> flatMap<R>(Result<R> Function(T data) transform);
}

/// A successful [Result] containing [data] of type [T].
class Success<T> extends Result<T> {
  /// Creates a [Success] wrapping [data].
  const Success(this.data);

  /// The data produced by the successful operation.
  final T data;

  @override
  T? get dataOrNull => data;

  @override
  bool get isSuccess => true;

  @override
  bool get isFailure => false;

  @override
  R when<R>({
    required R Function(T data) success,
    required R Function(AppException exception) failure,
  }) => success(data);

  @override
  Result<R> map<R>(R Function(T data) transform) => Success<R>(transform(data));

  @override
  Result<R> flatMap<R>(Result<R> Function(T data) transform) => transform(data);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Success<T> && other.data == data;

  @override
  int get hashCode => data.hashCode;

  @override
  String toString() => 'Success($data)';
}

/// A failed [Result] containing an [AppException].
class Failure<T> extends Result<T> {
  /// Creates a [Failure] wrapping [exception].
  const Failure(this.exception);

  /// The exception describing what went wrong.
  final AppException exception;

  @override
  T? get dataOrNull => null;

  @override
  bool get isSuccess => false;

  @override
  bool get isFailure => true;

  @override
  R when<R>({
    required R Function(T data) success,
    required R Function(AppException exception) failure,
  }) => failure(exception);

  @override
  Result<R> map<R>(R Function(T data) transform) => Failure<R>(exception);

  @override
  Result<R> flatMap<R>(Result<R> Function(T data) transform) =>
      Failure<R>(exception);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure<T> && other.exception == exception;

  @override
  int get hashCode => exception.hashCode;

  @override
  String toString() => 'Failure($exception)';
}
