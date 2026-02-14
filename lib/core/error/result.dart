import 'package:meta/meta.dart';

import 'app_exception.dart';

/// Result type for handling success and failure cases in repository layer
/// 
/// This sealed class ensures exhaustive pattern matching when handling
/// repository responses. Use [Success] for successful operations and
/// [Failure] for errors.
/// 
/// Example:
/// ```dart
/// final result = await repository.getUser(id);
/// switch (result) {
///   case Success(:final data):
///     // Handle success
///     print(data);
///   case Failure(:final exception):
///     // Handle error
///     print(exception.message);
/// }
/// ```
@immutable
sealed class Result<T> {
  const Result();
}

/// Represents a successful operation with data
@immutable
final class Success<T> extends Result<T> {
  const Success(this.data);
  
  final T data;
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Success<T> &&
          runtimeType == other.runtimeType &&
          data == other.data;
  
  @override
  int get hashCode => data.hashCode;
  
  @override
  String toString() => 'Success(data: $data)';
}

/// Represents a failed operation with an exception
@immutable
final class Failure<T> extends Result<T> {
  const Failure(this.exception);
  
  final AppException exception;
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure<T> &&
          runtimeType == other.runtimeType &&
          exception == other.exception;
  
  @override
  int get hashCode => exception.hashCode;
  
  @override
  String toString() => 'Failure(exception: $exception)';
}
