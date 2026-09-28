enum TempStatus { normal, low, high, disconnected }

class AlertRecord {
  final DateTime timestamp;
  final double temperature;
  final TempStatus status;

  AlertRecord({
    required this.timestamp,
    required this.temperature,
    required this.status,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'temperature': temperature,
        'status': status.name,
      };

  factory AlertRecord.fromJson(Map<String, dynamic> json) => AlertRecord(
        timestamp: DateTime.parse(json['timestamp']),
        temperature: (json['temperature'] as num).toDouble(),
        status: TempStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => TempStatus.normal,
        ),
      );
}
