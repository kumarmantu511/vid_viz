double parseAspectRatioString(String value, {double fallback = 16.0 / 9.0}) {
  final s = value.trim();
  if (s.isEmpty) return fallback;
  if (s.contains(':')) {
    final parts = s.split(':');
    final w = double.tryParse(parts[0]) ?? 16.0;
    final h = double.tryParse(parts.length > 1 ? parts[1] : '') ?? 9.0;
    if (h == 0) return fallback;
    final r = w / h;
    return r.isFinite && r > 0 ? r : fallback;
  }
  return fallback;
}
