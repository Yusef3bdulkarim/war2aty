import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/result/result.dart';

// A trivial failure type for exercising Result<T, F> in isolation.
final class _Failure {
  const _Failure(this.code);
  final String code;

  @override
  bool operator ==(Object other) => other is _Failure && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

void main() {
  const ok = Ok<int, _Failure>(5);
  const err = Err<int, _Failure>(_Failure('boom'));

  group('isOk / isErr', () {
    test('Ok reports isOk', () {
      expect(ok.isOk, isTrue);
      expect(ok.isErr, isFalse);
    });

    test('Err reports isErr', () {
      expect(err.isErr, isTrue);
      expect(err.isOk, isFalse);
    });
  });

  group('valueOrNull / failureOrNull', () {
    test('Ok exposes value, null failure', () {
      expect(ok.valueOrNull, 5);
      expect(ok.failureOrNull, isNull);
    });

    test('Err exposes failure, null value', () {
      expect(err.valueOrNull, isNull);
      expect(err.failureOrNull, const _Failure('boom'));
    });
  });

  group('when', () {
    test('calls ok branch for Ok', () {
      expect(ok.when(ok: (v) => 'ok:$v', err: (f) => 'err'), 'ok:5');
    });

    test('calls err branch for Err', () {
      expect(
        err.when(ok: (v) => 'ok', err: (f) => 'err:${f.code}'),
        'err:boom',
      );
    });
  });

  group('fold (success-first)', () {
    test('calls onOk for Ok', () {
      expect(ok.fold((v) => v * 2, (f) => -1), 10);
    });

    test('calls onErr for Err', () {
      expect(err.fold((v) => v * 2, (f) => -1), -1);
    });
  });

  group('map', () {
    test('transforms Ok value', () {
      expect(ok.map((v) => 'n=$v'), const Ok<String, _Failure>('n=5'));
    });

    test('leaves Err untouched', () {
      expect(
        err.map((v) => 'n=$v'),
        const Err<String, _Failure>(_Failure('boom')),
      );
    });
  });

  group('mapErr', () {
    test('transforms Err failure', () {
      expect(
        err.mapErr((f) => f.code.toUpperCase()),
        const Err<int, String>('BOOM'),
      );
    });

    test('leaves Ok untouched', () {
      expect(ok.mapErr((f) => f.code), const Ok<int, String>(5));
    });
  });

  group('flatMap', () {
    test('chains on Ok', () {
      final result = ok.flatMap((v) => Ok<String, _Failure>('v=$v'));
      expect(result, const Ok<String, _Failure>('v=5'));
    });

    test('short-circuits on Err', () {
      final result = err.flatMap((v) => Ok<String, _Failure>('v=$v'));
      expect(result, const Err<String, _Failure>(_Failure('boom')));
    });
  });

  group('getOrElse', () {
    test('returns value for Ok', () {
      expect(ok.getOrElse((f) => 0), 5);
    });

    test('returns fallback for Err', () {
      expect(err.getOrElse((f) => f.code.length), 4);
    });
  });

  group('equality', () {
    test('Ok equals Ok with same value', () {
      expect(const Ok<int, _Failure>(5), const Ok<int, _Failure>(5));
      expect(
        const Ok<int, _Failure>(5).hashCode,
        const Ok<int, _Failure>(5).hashCode,
      );
    });

    test('Err equals Err with same failure', () {
      expect(
        const Err<int, _Failure>(_Failure('boom')),
        const Err<int, _Failure>(_Failure('boom')),
      );
    });

    test('Ok and Err are never equal', () {
      expect(ok, isNot(equals(err)));
    });
  });
}
