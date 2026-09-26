import 'package:flutter_test/flutter_test.dart';
import 'package:opentof_app/domain/algorithm_metadata.dart';
import 'package:opentof_app/domain/sensor_events.dart';

JumpEvent event(JumpEventType type, List<int> extras) => JumpEvent(
  jumpId: 1,
  type: type,
  stage: JumpEventStage.finalized,
  deviceTimeMs: 0,
  receivedAt: DateTime(2026),
  extras: extras,
);

void main() {
  test('missing or malformed strings mean "not provided"', () {
    final m = AlgorithmMetadata.parse(
      fieldsJson: '{not json',
      reasonsJson: null,
      confidenceKind: '  ',
    );
    expect(m.fields, isEmpty);
    expect(m.reasons, isEmpty);
    expect(m.confidenceKind, 'none');
  });

  test('malformed field objects are skipped, valid ones kept', () {
    final m = AlgorithmMetadata.parse(
      fieldsJson:
          '[{"id":"a","name":"A","t":"f32","on":"L"},'
          '{"name":"no id","t":"u8","on":"L"},'
          '{"id":"b","name":"B","t":"i16","on":"TL","unit":"g",'
          '"scale":0.01,"rel":true,"na":-1,"desc":"d"}] ',
    );
    expect(m.fields, hasLength(1));
    final b = m.fields.single;
    expect(b.id, 'b');
    expect(b.onTakeoff && b.onLanding, isTrue);
    expect(b.unit, 'g');
    expect(b.relative, isTrue);
    expect(b.description, 'd');
  });

  test('decode packs per event type in declaration order', () {
    final m = AlgorithmMetadata.parse(
      fieldsJson:
          '[{"id":"t8","name":"x","t":"u8","on":"T"},'
          '{"id":"l16","name":"x","t":"u16","on":"L"},'
          '{"id":"both","name":"x","t":"i8","on":"TL"},'
          '{"id":"u32","name":"x","t":"u32","on":"L"}]',
    );
    expect(m.decode(event(JumpEventType.takeoff, [7, 0xFE])), {
      't8': 7,
      'both': -2,
    });
    expect(
      m.decode(event(JumpEventType.landing, [0x34, 0x12, 0x80, 1, 0, 0, 1])),
      {'l16': 0x1234, 'both': -128, 'u32': 0x01000001},
    );
  });

  test('decode: wrong byte count -> no fields; na and scale applied', () {
    final m = AlgorithmMetadata.parse(
      fieldsJson:
          '[{"id":"a","name":"A","t":"u8","on":"L","na":255},'
          '{"id":"b","name":"B","t":"i16","on":"L","scale":0.5}]',
    );
    expect(m.decode(event(JumpEventType.landing, [1, 2])), isEmpty);
    expect(m.decode(event(JumpEventType.landing, [255, 0xFC, 0xFF])), {
      'b': -2,
    });
  });

  test('reason names, with a fallback for unnamed bits', () {
    final m = AlgorithmMetadata.parse(reasonsJson: '["weak push"]');
    expect(m.reasonNames(0), isEmpty);
    expect(m.reasonNames(0x81), ['weak push', 'reason 7']);
  });
}
