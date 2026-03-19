class ConsumptionEvent {
  final String itemName;
  final double quantityConsumed;
  final DateTime timestamp;

  const ConsumptionEvent({
    required this.itemName,
    required this.quantityConsumed,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'itemName': itemName,
      'quantityConsumed': quantityConsumed,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ConsumptionEvent.fromJson(Map<String, dynamic> json) {
    return ConsumptionEvent(
      itemName: json['itemName'] as String,
      quantityConsumed: (json['quantityConsumed'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}
