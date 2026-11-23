import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/platform/usecases/open_phone_dialer.dart';
import '../../../../core/result/result.dart';
import 'phone_dialer_state.dart';

final class PhoneDialerCubit extends Cubit<PhoneDialerState> {
  PhoneDialerCubit(this._openPhoneDialer) : super(const PhoneDialerIdle());

  final OpenPhoneDialer _openPhoneDialer;

  Future<void> dial(String phone) async {
    emit(const PhoneDialerIdle());

    final result = await _openPhoneDialer(phone);
    final opened = switch (result) {
      Ok(value: final launched) => launched,
      Err() => false,
    };

    if (!opened) emit(const PhoneDialerCallFailed());
  }
}
