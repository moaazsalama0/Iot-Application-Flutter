// HistoryReading: one history/{moduleId}/{sensorName}/{entryId} entry (bonus: charts).

import 'firebase_value_helpers.dart';

class HistoryReading {
  final double value;

  /// Server time of the reading, in milliseconds since epoch.
  final int timestampMillis;

  const HistoryReading({
    required this.value,
    required this.timestampMillis,
  });

  /// Boolean readings (e.g. motion) are stored as 1.0 / 0.0 so they can be charted.
  factory HistoryReading.fromFirebase(Object? rawValue) {
    final readingMap = readMap(rawValue);
    final rawReading = readingMap['value'];

    double numericValue = 0;
    if (rawReading is num) {
      numericValue = rawReading.toDouble();
    } else if (rawReading == true) {
      numericValue = 1;
    }

    return HistoryReading(
      value: numericValue,
      timestampMillis: readInt(readingMap['timestamp']) ?? 0,
    );
  }

  DateTime get recordedAt => DateTime.fromMillisecondsSinceEpoch(timestampMillis);
}
