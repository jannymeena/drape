import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modules/today/models/today_dashboard.dart';
import 'package:mobile/modules/today/widgets/weather_chip.dart';

const _attribution = WeatherAttribution(
  serviceName: 'Apple Weather',
  logoLightUrl: 'https://example.test/light.png',
  logoDarkUrl: 'https://example.test/dark.png',
  legalUrl: 'https://example.test/legal',
);

Widget _chip({WeatherAttribution? attribution}) => MaterialApp(
      home: Scaffold(
        body: WeatherChip(
          temperature: '21°C',
          condition: 'cloudy',
          hint: 'Mild — light layers work well.',
          attribution: attribution,
        ),
      ),
    );

void main() {
  testWidgets('shows the source credit when the provider requires one',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_chip(attribution: _attribution));
    await tester.pump();

    expect(find.text('Data sources'), findsOneWidget);
    final logo = tester.widget<Image>(find.byType(Image));
    expect((logo.image as NetworkImage).url, 'https://example.test/light.png');
    expect(
      // The chip merges its children's semantics, so match within the label.
      find.bySemanticsLabel(RegExp('Weather data from Apple Weather')),
      findsWidgets,
    );
    semantics.dispose();
  });

  testWidgets('falls back to the service name when the logo fails to load',
      (tester) async {
    // Test HttpClient answers 400, so the network logo errors out.
    await tester.pumpWidget(_chip(attribution: _attribution));
    await tester.pumpAndSettle();
    expect(find.text('Apple Weather'), findsOneWidget);
  });

  testWidgets('no credit row without attribution', (tester) async {
    await tester.pumpWidget(_chip());
    expect(find.text('Data sources'), findsNothing);
    expect(find.byType(Image), findsNothing);
  });
}
