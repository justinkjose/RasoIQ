import 'package:hive/hive.dart';

import '../../domain/grocery_item.dart';
import '../../domain/grocery_unit.dart';
import '../../domain/shopping_list.dart';

class ShoppingListAdapter extends TypeAdapter<ShoppingList> {
  @override
  final int typeId = 10;

  @override
  ShoppingList read(BinaryReader reader) {
    final fieldCount = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < fieldCount; i++) {
      fields[reader.readByte()] = reader.read();
    }
    final createdAt = fields[5] as DateTime? ?? DateTime.now();
    return ShoppingList(
      id: fields[0] as String,
      userId: fields[1] as String? ?? '',
      members: (fields[2] as List?)?.cast<String>() ?? const [],
      name: fields[3] as String,
      icon: fields[4] as String,
      createdDate: createdAt,
      updatedAt: fields[6] as DateTime? ?? createdAt,
      isArchived: fields[7] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, ShoppingList obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.members)
      ..writeByte(3)
      ..write(obj.name)
      ..writeByte(4)
      ..write(obj.icon)
      ..writeByte(5)
      ..write(obj.createdDate)
      ..writeByte(6)
      ..write(obj.updatedAt)
      ..writeByte(7)
      ..write(obj.isArchived);
  }
}

class GroceryItemAdapter extends TypeAdapter<GroceryItem> {
  @override
  final int typeId = 11;

  @override
  GroceryItem read(BinaryReader reader) {
    final fieldCount = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < fieldCount; i++) {
      fields[reader.readByte()] = reader.read();
    }
    final createdAt = fields[13] as DateTime? ?? DateTime.now();
    final unitIndex = fields[8] as int? ?? 0;
    final safeUnitIndex = unitIndex < 0
        ? 0
        : unitIndex >= GroceryUnit.values.length
            ? GroceryUnit.values.length - 1
            : unitIndex;
    return GroceryItem(
      id: fields[0] as String,
      listId: fields[1] as String,
      userId: fields[2] as String? ?? '',
      name: fields[3] as String,
      normalizedName: fields[4] as String,
      quantity: fields[5] as double? ?? 0.0,
      packCount: fields[6] as int? ?? 1,
      packSize: fields[7] as double? ?? 0.0,
      unit: GroceryUnit.values[safeUnitIndex],
      categoryId: fields[9] as String? ?? 'uncategorized',
      isDone: fields[10] as bool? ?? false,
      isImportant: fields[11] as bool? ?? false,
      isUnavailable: fields[12] as bool? ?? false,
      expiryDate: fields[14] as DateTime?,
      createdAt: createdAt,
      updatedAt: fields[15] as DateTime? ?? createdAt,
    );
  }

  @override
  void write(BinaryWriter writer, GroceryItem obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.listId)
      ..writeByte(2)
      ..write(obj.userId)
      ..writeByte(3)
      ..write(obj.name)
      ..writeByte(4)
      ..write(obj.normalizedName)
      ..writeByte(5)
      ..write(obj.quantity)
      ..writeByte(6)
      ..write(obj.packCount)
      ..writeByte(7)
      ..write(obj.packSize)
      ..writeByte(8)
      ..write(obj.unit.index)
      ..writeByte(9)
      ..write(obj.categoryId)
      ..writeByte(10)
      ..write(obj.isDone)
      ..writeByte(11)
      ..write(obj.isImportant)
      ..writeByte(12)
      ..write(obj.isUnavailable)
      ..writeByte(13)
      ..write(obj.createdAt)
      ..writeByte(14)
      ..write(obj.expiryDate)
      ..writeByte(15)
      ..write(obj.updatedAt);
  }
}
