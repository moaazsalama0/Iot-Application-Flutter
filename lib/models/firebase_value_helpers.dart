// Helpers for reading Realtime Database values safely.
// Firebase returns loosely typed data (Map<Object?, Object?>, int or double, ...),
// so every model converts it through these functions instead of casting directly.

/// Converts a Firebase node into a Map with String keys.
/// Returns an empty map when the node is missing or is not a map.
Map<String, dynamic> readMap(Object? rawValue) {
  final result = <String, dynamic>{};
  if (rawValue is Map) {
    rawValue.forEach((key, value) {
      result[key.toString()] = value;
    });
  }
  return result;
}

/// Reads a string, or returns [fallback] when missing or the wrong type.
String readString(Object? rawValue, {String fallback = ''}) {
  if (rawValue is String) {
    return rawValue;
  }
  return fallback;
}

/// Reads a whole number (Firebase may return an int or a double).
int? readInt(Object? rawValue) {
  if (rawValue is num) {
    return rawValue.toInt();
  }
  return null;
}

/// Reads a boolean, or returns [fallback] when missing or the wrong type.
bool readBool(Object? rawValue, {bool fallback = false}) {
  if (rawValue is bool) {
    return rawValue;
  }
  return fallback;
}
