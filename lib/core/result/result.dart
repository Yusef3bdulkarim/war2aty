/// A lightweight success/failure container used across every layer.
///
/// A [Result] is either an [Ok] carrying a success value of type [T], or an
/// [Err] carrying a failure of type [F]. Repositories and use cases return
/// `Result<T, AppFailure>` instead of throwing, so callers are forced by the
/// compiler to handle both outcomes.
///
/// Zero dependencies — pure Dart. Prefer [when] / [fold] or a Dart 3 `switch`
/// over the sealed subtypes for exhaustive handling.
sealed class Result<T, F extends Object> {
  const Result();

  /// Whether this is an [Ok].
  bool get isOk => this is Ok<T, F>;

  /// Whether this is an [Err].
  bool get isErr => this is Err<T, F>;

  /// The success value, or `null` when this is an [Err].
  T? get valueOrNull => switch (this) {
    Ok(:final value) => value,
    Err() => null,
  };

  /// The failure, or `null` when this is an [Ok].
  F? get failureOrNull => switch (this) {
    Ok() => null,
    Err(:final failure) => failure,
  };

  /// Collapses this result into a single value using named branches.
  R when<R>({
    required R Function(T value) ok,
    required R Function(F failure) err,
  }) {
    return switch (this) {
      Ok(:final value) => ok(value),
      Err(:final failure) => err(failure),
    };
  }

  /// Collapses this result into a single value. Success branch first.
  R fold<R>(R Function(T value) onOk, R Function(F failure) onErr) {
    return switch (this) {
      Ok(:final value) => onOk(value),
      Err(:final failure) => onErr(failure),
    };
  }

  /// Transforms the success value, leaving a failure untouched.
  Result<R, F> map<R>(R Function(T value) transform) {
    return switch (this) {
      Ok(:final value) => Ok(transform(value)),
      Err(:final failure) => Err(failure),
    };
  }

  /// Transforms the failure, leaving a success untouched.
  Result<T, G> mapErr<G extends Object>(G Function(F failure) transform) {
    return switch (this) {
      Ok(:final value) => Ok(value),
      Err(:final failure) => Err(transform(failure)),
    };
  }

  /// Chains another fallible operation on the success value.
  Result<R, F> flatMap<R>(Result<R, F> Function(T value) transform) {
    return switch (this) {
      Ok(:final value) => transform(value),
      Err(:final failure) => Err(failure),
    };
  }

  /// The success value, or [fallback] computed from the failure.
  T getOrElse(T Function(F failure) fallback) {
    return switch (this) {
      Ok(:final value) => value,
      Err(:final failure) => fallback(failure),
    };
  }
}

/// The success case of a [Result].
final class Ok<T, F extends Object> extends Result<T, F> {
  const Ok(this.value);

  final T value;

  @override
  bool operator ==(Object other) => other is Ok<T, F> && other.value == value;

  @override
  int get hashCode => Object.hash(Ok, value);

  @override
  String toString() => 'Ok($value)';
}

/// The failure case of a [Result].
final class Err<T, F extends Object> extends Result<T, F> {
  const Err(this.failure);

  final F failure;

  @override
  bool operator ==(Object other) =>
      other is Err<T, F> && other.failure == failure;

  @override
  int get hashCode => Object.hash(Err, failure);

  @override
  String toString() => 'Err($failure)';
}
