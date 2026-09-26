import 'dart:convert';

import 'sensor_events.dart';

/// One custom per-event field declared by the sensor's algorithm (Fields
/// characteristic, a JSON array of these objects).
class CustomField {
  const CustomField({
    required this.id,
    required this.name,
    required this.type,
    required this.onTakeoff,
    required this.onLanding,
    this.description,
    this.unit,
    this.scale = 1,
    this.relative = false,
    this.notAvailable,
  });

  /// Short stable key; also the CSV column name.
  final String id;

  /// English label.
  final String name;

  /// `u8`, `i8`, `u16`, `i16`, `u32` or `i32`.
  final String type;
  final bool onTakeoff;
  final bool onLanding;
  final String? description;
  final String? unit;

  /// Shown value = raw * scale.
  final num scale;

  /// Only meaningful relative to the same session (no absolute unit).
  final bool relative;

  /// Raw value meaning "not available for this event".
  final int? notAvailable;

  static const _sizes = {
    'u8': 1,
    'i8': 1,
    'u16': 2,
    'i16': 2,
    'u32': 4,
    'i32': 4,
  };

  int get size => _sizes[type]!;

  bool carriedBy(JumpEventType t) =>
      t == JumpEventType.takeoff ? onTakeoff : onLanding;

  /// Null if the object is malformed (missing keys, unknown type).
  static CustomField? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final name = json['name'];
    final type = json['t'];
    final on = json['on'];
    if (id is! String || id.isEmpty || name is! String) return null;
    if (type is! String || !_sizes.containsKey(type) || on is! String) {
      return null;
    }
    final scale = json['scale'];
    final na = json['na'];
    final desc = json['desc'];
    final unit = json['unit'];
    return CustomField(
      id: id,
      name: name,
      type: type,
      onTakeoff: on.contains('T'),
      onLanding: on.contains('L'),
      description: desc is String ? desc : null,
      unit: unit is String && unit.isNotEmpty ? unit : null,
      scale: scale is num ? scale : 1,
      relative: json['rel'] == true,
      notAvailable: na is int ? na : null,
    );
  }

  /// Reads this field at [offset]; null if it is the "not available" value.
  num? read(List<int> bytes, int offset) {
    var raw = 0;
    for (var i = size - 1; i >= 0; i--) {
      raw = (raw << 8) | bytes[offset + i];
    }
    if (raw == notAvailable) return null;
    if (type.startsWith('i')) {
      final bits = size * 8;
      if (raw >= 1 << (bits - 1)) raw -= 1 << bits;
    }
    return scale == 1 ? raw : raw * scale;
  }
}

/// What the sensor's algorithm says about its events: custom fields, the
/// names of its reason bits, and what its confidence means. Every part is
/// optional; [none] is a plain timestamp-only algorithm.
class AlgorithmMetadata {
  const AlgorithmMetadata({
    this.fields = const [],
    this.reasons = const [],
    this.confidenceKind = 'none',
  });

  static const none = AlgorithmMetadata();

  final List<CustomField> fields;

  /// Entry i names bit i of [JumpEvent.reasons].
  final List<String> reasons;

  /// `none`, `heuristic` or `calibrated`.
  final String confidenceKind;

  /// Builds the metadata from the three characteristic strings; anything
  /// missing or malformed falls back to "not provided".
  factory AlgorithmMetadata.parse({
    String? fieldsJson,
    String? reasonsJson,
    String? confidenceKind,
  }) {
    final fields = <CustomField>[];
    for (final f in _jsonList(fieldsJson)) {
      final field = CustomField.fromJson(f);
      if (field != null) fields.add(field);
    }
    final reasons = [
      for (final r in _jsonList(reasonsJson)) r is String ? r : '$r',
    ];
    final kind = confidenceKind?.trim();
    return AlgorithmMetadata(
      fields: fields,
      reasons: reasons,
      confidenceKind: kind == null || kind.isEmpty ? 'none' : kind,
    );
  }

  static List<Object?> _jsonList(String? s) {
    if (s == null || s.trim().isEmpty) return const [];
    try {
      final v = jsonDecode(s);
      return v is List ? v : const [];
    } on FormatException {
      return const [];
    }
  }

  /// Decodes an event's custom fields (id -> value; "not available" values
  /// are left out). Returns an empty map if the byte count doesn't match the
  /// declared fields for that event type.
  Map<String, num> decode(JumpEvent e) {
    final carried = [
      for (final f in fields)
        if (f.carriedBy(e.type)) f,
    ];
    final expected = carried.fold(0, (sum, f) => sum + f.size);
    if (carried.isEmpty || e.extras.length != expected) return const {};
    final out = <String, num>{};
    var offset = 0;
    for (final f in carried) {
      final v = f.read(e.extras, offset);
      if (v != null) out[f.id] = v;
      offset += f.size;
    }
    return out;
  }

  /// Names of the set bits of [bits]; unnamed bits show as "reason N".
  List<String> reasonNames(int bits) => [
    for (var i = 0; i < 8; i++)
      if (bits & (1 << i) != 0) i < reasons.length ? reasons[i] : 'reason $i',
  ];
}
