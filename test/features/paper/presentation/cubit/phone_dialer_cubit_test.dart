import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/platform/external_link_service.dart';
import 'package:war2aty/core/platform/usecases/open_phone_dialer.dart';
import 'package:war2aty/features/paper/presentation/cubit/phone_dialer_cubit.dart';
import 'package:war2aty/features/paper/presentation/cubit/phone_dialer_state.dart';

final class _FakeExternalLinkService implements ExternalLinkService {
  _FakeExternalLinkService({this.result = true, this.throws = false});

  bool result;
  bool throws;
  final opened = <Uri>[];

  @override
  Future<bool> open(Uri destination) async {
    opened.add(destination);
    if (throws) throw Exception('no activity found');
    return result;
  }
}

void main() {
  group('PhoneDialerCubit', () {
    PhoneDialerCubit cubitOver(_FakeExternalLinkService service) =>
        PhoneDialerCubit(OpenPhoneDialer(service));

    test('says nothing when the number dials', () async {
      final service = _FakeExternalLinkService();
      final cubit = cubitOver(service);
      final states = <PhoneDialerState>[];
      cubit.stream.listen(states.add);

      await cubit.dial('0453312244');

      expect(service.opened, [Uri(scheme: 'tel', path: '0453312244')]);
      expect(cubit.state, isA<PhoneDialerIdle>());
      expect(states.whereType<PhoneDialerCallFailed>(), isEmpty);
      await cubit.close();
    });

    test('reports a number the device could not dial', () async {
      final cubit = cubitOver(_FakeExternalLinkService(result: false));

      await cubit.dial('0453312244');

      expect(cubit.state, isA<PhoneDialerCallFailed>());
      await cubit.close();
    });

    test('reports a thrown platform error the same way', () async {
      final cubit = cubitOver(_FakeExternalLinkService(throws: true));

      await cubit.dial('0453312244');

      expect(cubit.state, isA<PhoneDialerCallFailed>());
      await cubit.close();
    });

    test(
      'a second failed tap reports again instead of looking ignored',
      () async {
        final cubit = cubitOver(_FakeExternalLinkService(result: false));

        final emitted = expectLater(
          cubit.stream,
          emitsInOrder(const [
            PhoneDialerIdle(),
            PhoneDialerCallFailed(),
            PhoneDialerIdle(),
            PhoneDialerCallFailed(),
          ]),
        );

        await cubit.dial('0453312244');
        await cubit.dial('0453312244');
        await cubit.close();
        await emitted;
      },
    );
  });
}
