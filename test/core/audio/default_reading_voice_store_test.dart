import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/audio/default_reading_voice_store.dart';
import 'package:war2aty/core/audio/tts_voice.dart';
import 'package:war2aty/core/database/app_database.dart';

import '../../support/fakes.dart';

void main() {
  late AppDatabase db;
  late DriftDefaultReadingVoiceStore store;

  setUp(() {
    db = memoryDatabase();
    store = DriftDefaultReadingVoiceStore(db);
  });

  tearDown(() => db.close());

  test('readVoice() returns null (الصوت الافتراضي) when nothing has been '
      'written', () async {
    expect(await store.readVoice(), isNull);
  });

  test('writeVoice() then readVoice() round-trips the choice', () async {
    const voice = TtsVoice(name: 'Maged', locale: 'ar-EG');

    await store.writeVoice(voice);

    expect(await store.readVoice(), voice);
  });

  test(
    'writing null resets a previously picked voice back to automatic',
    () async {
      const voice = TtsVoice(name: 'Maged', locale: 'ar-EG');
      await store.writeVoice(voice);

      await store.writeVoice(null);

      expect(await store.readVoice(), isNull);
    },
  );
}
