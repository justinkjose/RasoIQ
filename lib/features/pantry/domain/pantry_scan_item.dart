class PantryScanItem {
  PantryScanItem({
    required this.name,
    required this.quantity,
    required this.unit,
    this.price,
  });

  String name;
  double quantity;
  String unit;
  double? price;
}
