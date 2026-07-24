/// Normalizes GET /ezzy/v1/dashboard JSON (handles `data` wrappers & nested maps).
abstract final class DashboardPayload {
  static Map<String, dynamic> unwrap(dynamic raw) {
    if (raw == null || raw is! Map) return {};
    final root = Map<String, dynamic>.from(
      raw.map((k, v) => MapEntry(k.toString(), v)),
    );
    if (_isWpAuthShape(root)) return {};

    final merged = Map<String, dynamic>.from(root);
    merged.remove('data');
    final data = root['data'];
    if (data is Map) {
      final inner = Map<String, dynamic>.from(
        data.map((k, v) => MapEntry(k.toString(), v)),
      );
      if (!_isWpAuthShape(inner)) {
        inner.forEach((k, v) => merged[k] = v);
      }
    }

    return _flattenKnownNested(merged);
  }

  static bool _isWpAuthShape(Map<String, dynamic> m) {
    final code = m['code']?.toString();
    if (code == null || code.isEmpty) return false;
    final data = m['data'];
    if (data is Map && data['status'] == 401) return true;
    return code == 'invalid_username' ||
        code == 'rest_forbidden' ||
        code == 'woocommerce_rest_authentication_error';
  }

  static Map<String, dynamic> _flattenKnownNested(Map<String, dynamic> m) {
    final out = Map<String, dynamic>.from(m);
    const nestedKeys = [
      'shipments',
      'warehouse',
      'stats',
      'counts',
      'summary',
      'metrics',
    ];
    for (final nk in nestedKeys) {
      final v = out[nk];
      if (v is Map) {
        final vm = Map<String, dynamic>.from(
          v.map((k, val) => MapEntry(k.toString(), val)),
        );
        vm.forEach((k, val) {
          out.putIfAbsent('$nk.$k', () => val);
        });
      }
    }
    return out;
  }
}
