class ExpenseEntry {
  final String id;
  final String itemName;
  final String category;
  final double quantity;
  final String unit;
  final double price;
  final DateTime date;
  final String source;

  const ExpenseEntry({
    required this.id,
    required this.itemName,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.price,
    required this.date,
    required this.source,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'itemName': itemName,
      'category': category,
      'quantity': quantity,
      'unit': unit,
      'price': price,
      'date': date.toIso8601String(),
      'source': source,
    };
  }

  factory ExpenseEntry.fromJson(Map<String, dynamic> json) {
    return ExpenseEntry(
      id: json['id'] as String,
      itemName: json['itemName'] as String,
      category: json['category'] as String,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit'] as String,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      date: DateTime.parse(json['date'] as String),
      source: json['source'] as String,
    );
  }
}
