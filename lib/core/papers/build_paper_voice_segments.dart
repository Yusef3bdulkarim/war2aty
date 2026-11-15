import '../../features/voice/domain/entities/voice_segment.dart';
import 'paper_explanation.dart';

final class BuildPaperVoiceSegments {
  const BuildPaperVoiceSegments();

  List<VoiceSegment> call(PaperExplanation explanation) {
    final segments = <VoiceSegment>[
      VoiceSegment(id: 'explain', text: _explainText(explanation)),
      VoiceSegment(id: 'todo', text: explanation.todo.text),
    ];

    final date = explanation.date;
    if (date != null) {
      segments.add(VoiceSegment(id: 'date', text: date.text));
    }

    final caution = explanation.caution;
    if (caution != null) {
      segments.add(VoiceSegment(id: 'caution', text: caution.text));
    }

    final contact = explanation.contact;
    if (contact != null) {
      segments.add(VoiceSegment(id: 'contact', text: contact.name));
    }

    final place = explanation.place;
    if (place != null) {
      segments.add(VoiceSegment(id: 'place', text: place.text));
    }

    return List.unmodifiable(segments);
  }

  String _explainText(PaperExplanation explanation) =>
      '${explanation.title}. ${explanation.paragraphs.join(' ')}';
}
