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

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('weather pill shows its label', (tester) async {
    await tester.pumpWidget(
      _host(
        const TodayContextChip(
          icon: Icons.umbrella_outlined,
          label: '8°C, feels 5° · Rain',
        ),
      ),
    );
    expect(find.text('8°C, feels 5° · Rain'), findsOneWidget);
  });

  testWidgets('source credit shows the logo and data-sources link', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(const WeatherAttributionLine(attribution: _attribution)),
    );
    await tester.pump();

    expect(find.text('Data sources'), findsOneWidget);
    final logo = tester.widget<Image>(find.byType(Image));
    expect((logo.image as NetworkImage).url, 'https://example.test/light.png');
    expect(
      find.bySemanticsLabel(RegExp('Weather data from Apple Weather')),
      findsWidgets,
    );
    semantics.dispose();
  });

  testWidgets('falls back to the service name when the logo fails to load', (
    tester,
  ) async {
    // Test HttpClient answers 400, so the network logo errors out.
    await tester.pumpWidget(
      _host(const WeatherAttributionLine(attribution: _attribution)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Apple Weather'), findsOneWidget);
  });
}
