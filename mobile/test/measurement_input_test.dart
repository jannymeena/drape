import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modules/onboarding/widgets/measurement_input.dart';

/// Verifies [MeasurementInput] reports values converted to metric: it's the one
/// place the imperial→metric math lives before the bulk measurements POST.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    required double imperialFactor,
    required MeasurementUnit initialUnit,
    required void Function(double?, MeasurementUnit) onReading,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MeasurementInput(
            imperialFactor: imperialFactor,
            initialUnit: initialUnit,
            onReading: onReading,
          ),
        ),
      ),
    );
  }

  testWidgets('imperial length input is converted ×2.54 to cm', (tester) async {
    double? metric;
    MeasurementUnit? unit;
    await pump(tester,
        imperialFactor: 2.54,
        initialUnit: MeasurementUnit.imperial,
        onReading: (m, u) {
          metric = m;
          unit = u;
        });

    await tester.enterText(find.byType(TextField), '10');
    expect(metric, closeTo(25.4, 1e-9));
    expect(unit, MeasurementUnit.imperial);
  });

  testWidgets('toggling to metric reports the raw value unchanged',
      (tester) async {
    double? metric;
    await pump(tester,
        imperialFactor: 2.54,
        initialUnit: MeasurementUnit.imperial,
        onReading: (m, _) => metric = m);

    await tester.enterText(find.byType(TextField), '10');
    expect(metric, closeTo(25.4, 1e-9));

    await tester.tap(find.text('METRIC'));
    await tester.pump();
    expect(metric, closeTo(10.0, 1e-9));
  });

  testWidgets('weight uses the lbs→kg factor', (tester) async {
    double? metric;
    await pump(tester,
        imperialFactor: 0.45359237,
        initialUnit: MeasurementUnit.imperial,
        onReading: (m, _) => metric = m);

    await tester.enterText(find.byType(TextField), '100');
    expect(metric, closeTo(45.359237, 1e-6));
  });

  testWidgets('blank or non-positive input reports null', (tester) async {
    double? metric = 1;
    await pump(tester,
        imperialFactor: 2.54,
        initialUnit: MeasurementUnit.metric,
        onReading: (m, _) => metric = m);

    await tester.enterText(find.byType(TextField), '0');
    expect(metric, isNull);
    await tester.enterText(find.byType(TextField), 'abc');
    expect(metric, isNull);
  });
}
