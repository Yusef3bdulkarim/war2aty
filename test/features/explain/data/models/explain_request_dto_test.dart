import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/features/explain/data/models/explain_request_dto.dart';

void main() {
  group('ExplainRequestDto', () {
    test('serializes the §33 envelope, flat, with no input_type', () {
      const dto = ExplainRequestDto(
        explainSchemaVersion: '1.0',
        sessionId: '3f2504e0-4f89-41d3-9a0c-0305e82c3301',
        installationId: '9c858901-8a57-4791-81fe-4c455b099bc9',
        appVersion: '1.1.0',
        image: ExplainImageDto(data: 'YWJj', mimeType: 'image/jpeg'),
      );

      expect(dto.toJson(), {
        'explain_schema_version': '1.0',
        'session_id': '3f2504e0-4f89-41d3-9a0c-0305e82c3301',
        'installation_id': '9c858901-8a57-4791-81fe-4c455b099bc9',
        'app_version': '1.1.0',
        'image': {'data': 'YWJj', 'mime_type': 'image/jpeg'},
      });
      expect(dto.toJson().keys, isNot(contains('input_type')));
    });
  });
}
