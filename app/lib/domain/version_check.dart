/// App and sensor firmware share MAJOR.MINOR (hotfix/patch versions may
/// differ); a different MAJOR.MINOR usually means a different BLE protocol.
library;

final _majorMinor = RegExp(r'(\d+)\.(\d+)');

/// MAJOR.MINOR of a version string such as "0.4.0", "0.4.0 (3)" or
/// "v0.4.1-dev"; null if it contains none.
(int, int)? majorMinor(String? version) {
  if (version == null) return null;
  final m = _majorMinor.firstMatch(version);
  if (m == null) return null;
  return (int.parse(m.group(1)!), int.parse(m.group(2)!));
}

/// False if both versions are known and their MAJOR.MINOR differ; true
/// otherwise (an unknown version is no reason to warn).
bool versionsCompatible(String? appVersion, String? firmwareVersion) {
  final a = majorMinor(appVersion);
  final f = majorMinor(firmwareVersion);
  return a == null || f == null || a == f;
}
