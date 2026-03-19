import 'dart:io';

import 'package:flutter/material.dart';

import '../domain/pantry_scan_item.dart';
import 'receipt_preview_screen.dart';

class ReceiptReviewScreen extends StatelessWidget {
  const ReceiptReviewScreen({
    super.key,
    required this.image,
    required this.items,
  });

  final File image;
  final List<PantryScanItem> items;

  @override
  Widget build(BuildContext context) {
    return ReceiptPreviewScreen(image: image, items: items);
  }
}
