import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/papers/paper_explanation.dart';
import 'package:war2aty/core/papers/paper_status.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/features/explain/data/validators/explain_response_validator.dart';

const _validator = ExplainResponseValidator();

Map<String, dynamic> _schoolLetter() => {
  'explain_schema_version': '1.0',
  'session_id': 'session-1',
  'status': 'success',
  'paper': {'title': 'جواب من مدرسة النور'},
  'explain': [
    'دي ورقة من مدرسة النور لولي أمر الطالب أحمد محمود في الصف الرابع. المدرسة بتعزمك على اجتماع أولياء الأمور عشان يكلموك عن مستوى أحمد في نص السنة.',
    'الاجتماع هيبقى مع مدرّس الفصل، وهيوريك درجات أحمد في الامتحانات اللي فاتت.',
  ],
  'todo': {
    'required': true,
    'text':
        'روح الاجتماع بنفسك، وخد معاك بطاقتك الشخصية وكراسة الواجب بتاعة أحمد.',
  },
  'date': {
    'date': '2026-11-20',
    'time': '10:00',
    'text': 'اجتماع أولياء الأمور',
  },
  'caution': {'text': 'لو مش هتقدر تروح، لازم تبلّغ المدرسة قبل الميعاد.'},
  'contact': {'name': 'مدرسة النور', 'phone': '0453312244'},
  'place': null,
};

Map<String, dynamic> _electricityBill() => {
  'explain_schema_version': '1.0',
  'session_id': 'session-2',
  'status': 'success',
  'paper': {'title': 'فاتورة الكهربا'},
  'explain': [
    'دي فاتورة كهربا من شركة شمال القاهرة، عن شهر أكتوبر. القراءة الجديدة ٤٢٠ وحدة، والمبلغ اللي عليك ٢٨٥ جنيه.',
  ],
  'todo': {
    'required': true,
    'text':
        'ادفع ٢٨٥ جنيه قبل ٢٥ نوفمبر. تقدر تدفع من ماكينة الدفع أو من محفظة الموبايل.',
  },
  'date': {'date': '2026-11-25', 'time': null, 'text': 'آخر ميعاد للدفع'},
  'caution': {
    'text': 'لو اتأخرت عن الميعاد، بيتضاف رسم تأخير على الفاتورة اللي بعدها.',
  },
  'contact': {'name': 'شركة شمال القاهرة', 'phone': '121'},
  'place': null,
};

Map<String, dynamic> _bankLetter() => {
  'explain_schema_version': '1.0',
  'session_id': 'session-3',
  'status': 'success',
  'paper': {'title': 'جواب من البنك'},
  'explain': [
    'دي ورقة من البنك الأهلي بتقولك إن حسابك اتغير رقمه بعد ما البنك طوّر نظامه. الرقم الجديد مكتوب في الورقة.',
  ],
  'todo': {
    'required': false,
    'text':
        'مش مطلوب منك حاجة. احفظ الورقة دي عندك، وخد الرقم الجديد معاك أول مرة تروح البنك.',
  },
  'date': null,
  'caution': null,
  'contact': {'name': 'البنك الأهلي', 'phone': '19623'},
  'place': null,
};

Map<String, dynamic> _notAPaper() => {
  'explain_schema_version': '1.0',
  'session_id': 'session-4',
  'status': 'unsupported',
  'paper': {'title': 'صورة مش ورقة'},
  'explain': [
    'الصورة دي مفيهاش ورقة فيها كلام أقدر أشرحه. صوّر الورقة نفسها وهي كلها جوه الصورة.',
  ],
  'todo': {'required': false, 'text': 'صوّر الورقة تاني في نور أوضح.'},
  'date': null,
  'caution': null,
  'contact': null,
  'place': null,
};

PaperExplanation _expectOk(Result<PaperExplanation, AppFailure> result) {
  expect(result.isOk, isTrue, reason: 'expected Ok, got $result');
  return result.valueOrNull!;
}

void _expectInvalid(Result<PaperExplanation, AppFailure> result) {
  expect(result.failureOrNull, isA<InvalidAnalysisResponseFailure>());
}

void main() {
  group('§33.10 worked examples', () {
    test('school letter parses byte-for-byte', () {
      final body = _schoolLetter();
      final paper = body['paper'] as Map<String, dynamic>;
      final todo = body['todo'] as Map<String, dynamic>;
      final date = body['date'] as Map<String, dynamic>;
      final caution = body['caution'] as Map<String, dynamic>;
      final contact = body['contact'] as Map<String, dynamic>;
      final explanation = _expectOk(_validator.validate(body));

      expect(explanation.title, paper['title']);
      expect(explanation.status, PaperStatus.success);
      expect(explanation.paragraphs, body['explain']);
      expect(explanation.todo.required, todo['required']);
      expect(explanation.todo.text, todo['text']);
      expect(explanation.date?.day, DateTime(2026, 11, 20));
      expect(explanation.date?.time?.hour, 10);
      expect(explanation.date?.time?.minute, 0);
      expect(explanation.date?.text, date['text']);
      expect(explanation.caution?.text, caution['text']);
      expect(explanation.contact?.name, contact['name']);
      expect(explanation.contact?.phone, contact['phone']);
      expect(explanation.place, isNull);
    });

    test(
      'electricity bill keeps money inside todo, not a field of its own',
      () {
        final explanation = _expectOk(_validator.validate(_electricityBill()));

        expect(explanation.todo.text, contains('٢٨٥ جنيه'));
        expect(explanation.date?.time, isNull);
        expect(explanation.place, isNull);
      },
    );

    test('bank letter has todo.required false and no date', () {
      final explanation = _expectOk(_validator.validate(_bankLetter()));

      expect(explanation.todo.required, isFalse);
      expect(explanation.date, isNull);
      expect(explanation.caution, isNull);
      expect(explanation.contact?.phone, '19623');
    });

    test('a paper with every optional card null round-trips', () {
      final explanation = _expectOk(_validator.validate(_bankLetter()));

      expect(explanation.date, isNull);
      expect(explanation.caution, isNull);
      expect(explanation.place, isNull);
    });

    test('status: unsupported is a valid, saveable response', () {
      final explanation = _expectOk(_validator.validate(_notAPaper()));

      expect(explanation.status, PaperStatus.unsupported);
      expect(explanation.todo.required, isFalse);
    });

    test('accepts a real decoded JSON string', () {
      final decoded = jsonDecode(jsonEncode(_schoolLetter()));

      expect(_validator.validate(decoded).isOk, isTrue);
    });
  });

  group('structural invalidity (D15)', () {
    test('a missing todo is InvalidAnalysisResponseFailure', () {
      final body = _schoolLetter()..remove('todo');

      _expectInvalid(_validator.validate(body));
    });

    test('a missing explain is InvalidAnalysisResponseFailure', () {
      final body = _schoolLetter()..remove('explain');

      _expectInvalid(_validator.validate(body));
    });

    test('a missing paper is InvalidAnalysisResponseFailure', () {
      final body = _schoolLetter()..remove('paper');

      _expectInvalid(_validator.validate(body));
    });

    test('a wrong-typed date is InvalidAnalysisResponseFailure', () {
      final wrongShape = _schoolLetter()..['date'] = 'اجتماع أولياء الأمور';
      _expectInvalid(_validator.validate(wrongShape));

      final malformedDate = _schoolLetter();
      (malformedDate['date'] as Map<String, dynamic>)['date'] = '20/11/2026';
      _expectInvalid(_validator.validate(malformedDate));

      final malformedTime = _schoolLetter();
      (malformedTime['date'] as Map<String, dynamic>)['time'] = '25:00';
      _expectInvalid(_validator.validate(malformedTime));
    });

    test('an unknown status is InvalidAnalysisResponseFailure', () {
      final body = _schoolLetter()..['status'] = 'maybe';

      _expectInvalid(_validator.validate(body));
    });

    test('does not crash on a body that is not a JSON object', () {
      _expectInvalid(_validator.validate(null));
      _expectInvalid(_validator.validate('<html>502 Bad Gateway</html>'));
      _expectInvalid(_validator.validate(<Object>[]));
      _expectInvalid(_validator.validate(42));
    });

    test('does not crash on an empty object', () {
      _expectInvalid(_validator.validate(<String, dynamic>{}));
    });
  });

  group('schema version', () {
    test('accepts the supported version', () {
      expect(kSupportedExplainSchemaVersions, contains('1.0'));
      expect(_validator.validate(_schoolLetter()).isOk, isTrue);
    });

    test('rejects an unknown version without parsing the body', () {
      for (final version in ['2.0', '0.9', '1', '']) {
        final body = _schoolLetter()..['explain_schema_version'] = version;

        _expectInvalid(_validator.validate(body));
      }
    });

    test('rejects a missing or non-string version', () {
      _expectInvalid(
        _validator.validate(_schoolLetter()..remove('explain_schema_version')),
      );
      _expectInvalid(
        _validator.validate(_schoolLetter()..['explain_schema_version'] = 1.0),
      );
      _expectInvalid(
        _validator.validate(_schoolLetter()..['explain_schema_version'] = null),
      );
    });
  });

  group('over-cap values are drawn, not rejected (D15)', () {
    test('a title over 24 characters is accepted on purpose', () {
      const overCapTitle = 'جواب طويل جدًا من مدرسة النور لولي أمر الطالب';
      expect(overCapTitle.length, greaterThan(24));

      final body = _schoolLetter()..['paper'] = {'title': overCapTitle};

      final explanation = _expectOk(_validator.validate(body));
      expect(explanation.title, overCapTitle);
    });
  });
}
