import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/shared/widgets/garment_placeholder.dart';

/// Renders the placeholder contact sheet to a PNG when
/// GARMENT_SHEET_OUT is set — a visual review harness for the flat
/// sketches; asserts only that every category/colour combination paints.
void main() {
  testWidgets('every category x colour paints (optional PNG contact sheet)',
      (tester) async {
    const categories = [
      'tops',
      'outerwear',
      'bottoms',
      'dresses',
      'shoes',
      'bags',
      'accessories',
    ];
    final colors = <Color?>[
      null,
      garmentColorFromName('white'),
      garmentColorFromName('navy'),
      garmentColorFromName('black'),
      garmentColorFromName('red'),
      garmentColorFromName('tan'),
    ];

    final key = GlobalKey();
    await tester.binding.setSurfaceSize(Size(colors.length * 90.0, categories.length * 110.0));
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: key,
          child: Column(
            children: [
              for (final c in categories)
                Expanded(
                  child: Row(
                    children: [
                      for (final col in colors)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(3),
                            child: GarmentPlaceholder(category: c, color: col),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    const outPath = String.fromEnvironment('GARMENT_SHEET_OUT');
    if (outPath.isNotEmpty) {
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 2));
      final bytes = await tester
          .runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
      File(outPath).writeAsBytesSync(bytes!.buffer.asUint8List());
    }
    await tester.binding.setSurfaceSize(null);
  });
}
