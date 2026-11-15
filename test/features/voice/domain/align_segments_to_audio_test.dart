import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/features/voice/domain/entities/pcm_format.dart';
import 'package:war2aty/features/voice/domain/entities/spoken_card_span.dart';
import 'package:war2aty/features/voice/domain/entities/transcript_audio_anchor.dart';
import 'package:war2aty/features/voice/domain/entities/voice_segment.dart';
import 'package:war2aty/features/voice/domain/usecases/align_segments_to_audio.dart';
import 'package:war2aty/features/voice/domain/usecases/normalise_arabic_for_diff.dart';

/// F37-T07 · where each card sits on the audio's timeline.
///
/// Table-driven and pure: no clock, no delay, no stream. The spine's rule is
/// that alignment never fails a read, so most of these cases are about what
/// comes out when the transcription is *not* cooperating — a card re-spelled,
/// a card missing, no anchors at all — and about `exact` telling the truth
/// about which spans were measured.
void main() {
  const normalise = NormaliseArabicForDiff();
  const align = AlignSegmentsToAudio(normalise);
  const format = PcmFormat.geminiLive;

  // Three cards whose words are distinct, so a match is unambiguous.
  const greeting = VoiceSegment(id: 'greeting', text: 'الورقة دي فاتورة كهربا');
  const amount = VoiceSegment(id: 'amount', text: 'المبلغ المطلوب 250 جنيه');
  const due = VoiceSegment(id: 'due', text: 'آخر ميعاد للدفع 20 نوفمبر');

  const page = [greeting, amount, due];

  /// The whole page as one spoken string, in reading order.
  String spokenPage([List<VoiceSegment> segments = page]) =>
      segments.map((segment) => segment.text).join(' ');

  /// A read of [bytes] bytes whose transcription arrived evenly, one anchor per
  /// word, which is the shape a real session produces: the service packs audio
  /// and its transcription into the same frame most of the time.
  List<TranscriptAudioAnchor> evenAnchors(String transcript, int bytes) {
    final words = normalise.wordsOf(transcript);
    return List<TranscriptAudioAnchor>.generate(words.length, (i) {
      // Cumulative on both counts: the first i+1 words, and the share of the
      // audio they occupy. +1 on the word count because the aligner drops each
      // anchor's newest (possibly partial) word.
      return TranscriptAudioAnchor(
        transcriptSoFar: words.take(i + 1).join(' '),
        audioBytesSoFar: (i + 1) * bytes ~/ words.length,
      );
    });
  }

  /// 24 seconds at 48,000 bytes a second — a realistic page read.
  const totalBytes = 24 * 48000;
  final totalDuration = format.durationOfBytes(totalBytes);

  SpokenCardSpan spanOf(List<SpokenCardSpan> spans, String id) =>
      spans.firstWhere((span) => span.segmentId == id);

  group('a read the transcription matches word for word', () {
    late List<SpokenCardSpan> spans;

    setUp(() {
      final transcript = spokenPage();
      spans = align(
        segments: page,
        transcript: transcript,
        anchors: evenAnchors(transcript, totalBytes),
        totalAudioBytes: totalBytes,
        format: format,
      );
    });

    test('gives every card a span, in the page order', () {
      expect(spans.map((span) => span.segmentId), [
        'greeting',
        'amount',
        'due',
      ]);
    });

    test('marks every card exact, because every card was heard', () {
      expect(spans.every((span) => span.exact), isTrue);
    });

    test('starts the first card with the audio', () {
      expect(spans.first.start, Duration.zero);
    });

    test('ends the last card with the audio', () {
      expect(spans.last.end, totalDuration);
    });

    test('places each card near its share of the words', () {
      // 4, 4 and 5 words: the second card begins around 4/13 of 24 s and the
      // third around 8/13. Within a word's width, since an anchor is only
      // accurate to the word it was taken at.
      final word = totalDuration.inMilliseconds / 13;
      expect(
        spanOf(spans, 'amount').start.inMilliseconds,
        closeTo(totalDuration.inMilliseconds * 4 / 13, word),
      );
      expect(
        spanOf(spans, 'due').start.inMilliseconds,
        closeTo(totalDuration.inMilliseconds * 8 / 13, word),
      );
    });
  });

  group('the spans partition the read', () {
    test('each one ends exactly where the next begins', () {
      final transcript = spokenPage();
      final spans = align(
        segments: page,
        transcript: transcript,
        anchors: evenAnchors(transcript, totalBytes),
        totalAudioBytes: totalBytes,
        format: format,
      );

      for (var i = 0; i < spans.length - 1; i++) {
        expect(spans[i].end, spans[i + 1].start);
      }
    });

    test('so any moment of the read belongs to exactly one card', () {
      // F40 highlights and scrolls from this; a moment owned by no card would
      // leave the screen pointing at the wrong paragraph mid-sentence, and a
      // moment owned by two would fight over the highlight.
      final transcript = spokenPage();
      final spans = align(
        segments: page,
        transcript: transcript,
        anchors: evenAnchors(transcript, totalBytes),
        totalAudioBytes: totalBytes,
        format: format,
      );

      for (var second = 0; second < 24; second++) {
        final at = Duration(seconds: second);
        expect(
          spans.where((span) => span.contains(at)).length,
          1,
          reason: 'at ${at.inSeconds}s',
        );
      }
    });
  });

  group('a card the transcription does not contain', () {
    // The failure the design expects: every word of the due card was spoken
    // differently — a paraphrase, not just a re-spelled digit — so the card
    // cannot be located in the transcription at all.
    late List<SpokenCardSpan> spans;

    setUp(() {
      const transcript =
          'الورقة دي فاتورة كهربا المبلغ المطلوب 250 جنيه '
          'لازم تدفع قبل نهاية الشهر ده';
      spans = align(
        segments: page,
        transcript: transcript,
        anchors: evenAnchors(transcript, totalBytes),
        totalAudioBytes: totalBytes,
        format: format,
      );
    });

    test('still yields a span for every card', () {
      expect(spans.length, 3);
      expect(spans.map((span) => span.segmentId), [
        'greeting',
        'amount',
        'due',
      ]);
    });

    test('says so, instead of dressing a guess as a measurement', () {
      expect(spanOf(spans, 'greeting').exact, isTrue);
      expect(spanOf(spans, 'amount').exact, isTrue);
      expect(spanOf(spans, 'due').exact, isFalse);
    });

    test('and the read is not failed over it', () {
      expect(spans.last.end, totalDuration);
    });
  });

  group('a card between two matched ones', () {
    test('is bounded by its neighbours, not by the whole page', () {
      // The middle card matches nothing, but the two around it do, so its
      // placement comes from them. Its raw share of the page's characters
      // would be a worse guess than the window its neighbours leave.
      const transcript =
          'الورقة دي فاتورة كهربا مية وخمسين جنيه بس اخر ميعاد للدفع 20 نوفمبر';
      final spans = align(
        segments: page,
        transcript: transcript,
        anchors: evenAnchors(transcript, totalBytes),
        totalAudioBytes: totalBytes,
        format: format,
      );

      final middle = spanOf(spans, 'amount');
      expect(middle.exact, isFalse);
      expect(middle.start, greaterThanOrEqualTo(spans.first.start));
      expect(middle.end, lessThanOrEqualTo(spanOf(spans, 'due').start));
      expect(spanOf(spans, 'due').exact, isTrue);
    });
  });

  group('spelled-out digits', () {
    test('do not break the card that carries them', () {
      // The folding makes «٢٥٠» and «250» the same word, so the amount card
      // still anchors on the rest of its words even when the number is read
      // out in full.
      const transcript =
          'الورقة دي فاتورة كهربا المبلغ المطلوب ٢٥٠ جنيه '
          'اخر ميعاد للدفع 20 نوفمبر';
      final spans = align(
        segments: page,
        transcript: transcript,
        anchors: evenAnchors(transcript, totalBytes),
        totalAudioBytes: totalBytes,
        format: format,
      );

      expect(spans.every((span) => span.exact), isTrue);
    });
  });

  group('all the transcription arriving after all the audio', () {
    test('falls back to each card share of the page characters', () {
      // Nothing ever tied a word to a byte, so the transcription — however
      // complete — cannot say when anything was said.
      final transcript = spokenPage();
      final spans = align(
        segments: page,
        transcript: transcript,
        anchors: const [],
        totalAudioBytes: totalBytes,
        format: format,
      );

      final totalChars = page.fold<int>(
        0,
        (sum, segment) => sum + segment.text.length,
      );
      var before = 0;
      for (var i = 0; i < page.length; i++) {
        expect(
          spans[i].start.inMicroseconds,
          totalDuration.inMicroseconds * before ~/ totalChars,
          reason: page[i].id,
        );
        before += page[i].text.length;
      }
      expect(spans.every((span) => span.exact), isFalse);
    });

    test('and an anchor with no audio behind it contributes nothing', () {
      final transcript = spokenPage();
      // A transcript delta that arrived before a single byte was played. The
      // aligner correctly drops it — but the transcript and totalAudioBytes
      // are still enough to form a tail-end pair, which the word match then
      // uses. The result must be identical to a run with a valid anchor that
      // covers the same range as that tail-end pair.
      final withBadAnchor = align(
        segments: page,
        transcript: transcript,
        anchors: [
          TranscriptAudioAnchor(
            transcriptSoFar: transcript,
            audioBytesSoFar: 0,
          ),
        ],
        totalAudioBytes: totalBytes,
        format: format,
      );

      // A good anchor at 1 byte (trivially valid) plus the tail-end pair
      // produces the same (0,0)→(words,totalBytes) curve.
      final withGoodAnchor = align(
        segments: page,
        transcript: transcript,
        anchors: evenAnchors(transcript, totalBytes),
        totalAudioBytes: totalBytes,
        format: format,
      );

      // Both runs match all cards against the full transcript; the zero-byte
      // anchor was dead weight.
      expect(
        withBadAnchor.map((s) => s.exact),
        withGoodAnchor.map((s) => s.exact),
      );
    });
  });

  group('a delta that landed mid-word', () {
    test('never pushes a card past where it was heard', () {
      // The last word of any anchor may be half-arrived, so the aligner drops
      // it. The effect must be to place a card a fraction early, never late:
      // highlighting the line about to be read is survivable, highlighting one
      // already finished is not.
      final words = normalise.wordsOf(spokenPage());
      final anchors = <TranscriptAudioAnchor>[];
      for (var i = 0; i < words.length; i++) {
        final bytes = (i + 1) * totalBytes ~/ words.length;
        anchors.add(
          TranscriptAudioAnchor(
            // The newest word is truncated to its first letter.
            transcriptSoFar:
                '${words.take(i).join(' ')} ${words[i].substring(0, 1)}'.trim(),
            audioBytesSoFar: bytes,
          ),
        );
      }

      final spans = align(
        segments: page,
        transcript: spokenPage(),
        anchors: anchors,
        totalAudioBytes: totalBytes,
        format: format,
      );

      final wordMicros = totalDuration.inMicroseconds ~/ words.length;
      for (var i = 0; i < page.length; i++) {
        expect(spans[i].exact, isTrue, reason: page[i].id);
      }
      expect(
        spanOf(spans, 'amount').start.inMicroseconds,
        lessThanOrEqualTo(totalDuration.inMicroseconds * 4 ~/ 13 + wordMicros),
      );
    });
  });

  group('degenerate pages', () {
    test('no segments yields no spans', () {
      expect(
        align(
          segments: const [],
          transcript: 'أي كلام',
          anchors: const [],
          totalAudioBytes: totalBytes,
          format: format,
        ),
        isEmpty,
      );
    });

    test('one segment owns the whole read', () {
      final spans = align(
        segments: const [greeting],
        transcript: greeting.text,
        anchors: evenAnchors(greeting.text, totalBytes),
        totalAudioBytes: totalBytes,
        format: format,
      );

      expect(spans.single.start, Duration.zero);
      expect(spans.single.end, totalDuration);
      expect(spans.single.exact, isTrue);
    });

    test('empty segments are spaced evenly rather than stacked at zero', () {
      // Dividing by a page of zero characters is the division this guards.
      final spans = align(
        segments: const [
          VoiceSegment(id: 'a', text: ''),
          VoiceSegment(id: 'b', text: ''),
        ],
        transcript: '',
        anchors: const [],
        totalAudioBytes: totalBytes,
        format: format,
      );

      expect(spans.first.start, Duration.zero);
      expect(spans.last.start, totalDuration ~/ 2);
      expect(spans.last.end, totalDuration);
      expect(spans.every((span) => span.exact), isFalse);
    });

    test('a read with no audio yields empty spans rather than throwing', () {
      final spans = align(
        segments: page,
        transcript: spokenPage(),
        anchors: const [],
        totalAudioBytes: 0,
        format: format,
      );

      expect(spans.length, 3);
      expect(
        spans.every(
          (span) => span.start == Duration.zero && span.end == Duration.zero,
        ),
        isTrue,
      );
      expect(spans.every((span) => span.exact), isFalse);
    });

    test('an empty transcription matches nothing', () {
      final spans = align(
        segments: page,
        transcript: '',
        anchors: const [
          TranscriptAudioAnchor(transcriptSoFar: '', audioBytesSoFar: 48000),
        ],
        totalAudioBytes: totalBytes,
        format: format,
      );

      expect(spans.every((span) => span.exact), isFalse);
    });
  });

  group('a single word matching by coincidence', () {
    test('is not enough to anchor a card', () {
      // «في» appears in the amount card and nowhere else in what was heard.
      // Trusting it would place that card wherever the word happened to land.
      const wordy = VoiceSegment(
        id: 'amount',
        text: 'المبلغ المستحق في الفاتورة 250 جنيه',
      );
      const transcript = 'الورقة دي فاتورة كهربا في الاخر اخر ميعاد 20 نوفمبر';

      final spans = align(
        segments: const [greeting, wordy, due],
        transcript: transcript,
        anchors: evenAnchors(transcript, totalBytes),
        totalAudioBytes: totalBytes,
        format: format,
      );

      expect(spanOf(spans, 'amount').exact, isFalse);
    });

    test('but a one-word card has only ever one word to offer', () {
      const shout = VoiceSegment(id: 'shout', text: 'مستعجل');
      const transcript = 'الورقة دي فاتورة كهربا مستعجل اخر ميعاد 20 نوفمبر';

      final spans = align(
        segments: const [greeting, shout, due],
        transcript: transcript,
        anchors: evenAnchors(transcript, totalBytes),
        totalAudioBytes: totalBytes,
        format: format,
      );

      expect(spanOf(spans, 'shout').exact, isTrue);
    });
  });

  group('anchors that do not describe this read', () {
    test('out-of-order and over-long ones are dropped, not trusted', () {
      final transcript = spokenPage();
      final good = evenAnchors(transcript, totalBytes);
      final spans = align(
        segments: page,
        transcript: transcript,
        anchors: [
          ...good,
          // Goes backwards in bytes.
          TranscriptAudioAnchor(
            transcriptSoFar: transcript,
            audioBytesSoFar: 48000,
          ),
          // Claims more audio than was ever played.
          TranscriptAudioAnchor(
            transcriptSoFar: transcript,
            audioBytesSoFar: totalBytes * 3,
          ),
        ],
        totalAudioBytes: totalBytes,
        format: format,
      );

      // Identical to the clean run: the bad anchors changed nothing.
      final clean = align(
        segments: page,
        transcript: transcript,
        anchors: good,
        totalAudioBytes: totalBytes,
        format: format,
      );
      expect(spans, clean);
    });

    test('spans stay inside the read however the anchors arrive', () {
      final transcript = spokenPage();
      final spans = align(
        segments: page,
        transcript: transcript,
        anchors: [
          TranscriptAudioAnchor(
            transcriptSoFar: transcript,
            audioBytesSoFar: totalBytes,
          ),
        ],
        totalAudioBytes: totalBytes,
        format: format,
      );

      for (final span in spans) {
        expect(span.start, greaterThanOrEqualTo(Duration.zero));
        expect(span.end, lessThanOrEqualTo(totalDuration));
        expect(span.start, lessThanOrEqualTo(span.end));
      }
    });
  });

  group('an anchor in a log', () {
    test('describes the transcription by size, never by its words', () {
      const anchor = TranscriptAudioAnchor(
        transcriptSoFar: 'فاتورة الكهربا 250 جنيه',
        audioBytesSoFar: 48000,
      );

      expect(anchor.toString(), isNot(contains('250')));
      expect(anchor.toString(), isNot(contains('الكهربا')));
      expect(anchor.toString(), contains('48000 bytes'));
    });
  });
}
