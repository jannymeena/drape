import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modules/wardrobe/widgets/wardrobe_picture.dart';
import 'package:mobile/shared/widgets/garment_placeholder.dart';

const _url = 'http://img/item.png';
const _bg = 'assets/wardrobe_backgrounds/studio_grey.jpg';

Future<void> _pump(WidgetTester tester, WardrobePicture picture) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 200, height: 250, child: picture),
      ),
    ),
  );
  await tester.pump();
}

final _background = find.byWidgetPredicate(
  (w) => w is Image && w.image is AssetImage,
);
final _spinner = find.byType(WardrobePictureProcessing);
final _loading = find.byType(WardrobePictureLoading);

CachedNetworkImage _network(WidgetTester tester) =>
    tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));

void main() {
  testWidgets('a mannequin shot lies whole on the background, padded',
      (tester) async {
    await _pump(
      tester,
      const WardrobePicture(
        imageUrl: _url,
        placeholder: SizedBox(),
        mannequinShot: true,
        backgroundAsset: _bg,
        shotPadding: EdgeInsets.all(12),
      ),
    );

    expect(_background, findsOneWidget);
    expect(_network(tester).fit, BoxFit.contain);
    final padding = tester.widget<Padding>(
      find.ancestor(
        of: find.byType(CachedNetworkImage),
        matching: find.byType(Padding),
      ).first,
    );
    expect(padding.padding, const EdgeInsets.all(12));
    expect(_spinner, findsNothing);
  });

  testWidgets('a photo fills the frame: no background, no padding',
      (tester) async {
    await _pump(
      tester,
      const WardrobePicture(
        imageUrl: _url,
        placeholder: SizedBox(),
        backgroundAsset: _bg,
        shotPadding: EdgeInsets.all(12),
      ),
    );

    expect(_background, findsNothing);
    expect(_network(tester).fit, BoxFit.cover);
    expect(
      find.ancestor(
        of: find.byType(CachedNetworkImage),
        matching: find.byType(Padding),
      ),
      findsNothing,
    );
    expect(_spinner, findsNothing);
  });

  testWidgets('while the shot is being made: the photo, a loading indicator',
      (tester) async {
    await _pump(
      tester,
      const WardrobePicture(
        imageUrl: _url,
        placeholder: SizedBox(),
        processing: true,
        backgroundAsset: _bg,
      ),
    );

    expect(_background, findsNothing);
    expect(_network(tester).fit, BoxFit.cover);
    expect(_spinner, findsOneWidget);
    expect(find.bySemanticsLabel('Preparing the picture'), findsOneWidget);
  });

  testWidgets('while a photo downloads: the card surface with a spinner',
      (tester) async {
    for (final shot in [false, true]) {
      await _pump(
        tester,
        WardrobePicture(
          imageUrl: shot ? '$_url?shot' : _url,
          placeholder: const Text('placeholder'),
          mannequinShot: shot,
          backgroundAsset: _bg,
        ),
      );
      expect(_loading, findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('placeholder'), findsNothing);
    }
    // The photo card paints its own surface; on a shot, the background is it.
    final surface = tester.widget<ColoredBox>(
      find.descendant(of: _loading, matching: find.byType(ColoredBox)),
    );
    expect(surface.color, Colors.transparent);
  });

  testWidgets('a photo that fails: broken, never the drawn placeholder',
      (tester) async {
    for (final shot in [false, true]) {
      await _pump(
        tester,
        WardrobePicture(
          imageUrl: _url,
          placeholder: const Text('placeholder'),
          mannequinShot: shot,
          backgroundAsset: _bg,
        ),
      );
      final failed = _network(tester).errorWidget!(
        tester.element(find.byType(CachedNetworkImage)),
        _url,
        Exception('host lookup failed'),
      );
      expect(failed, isA<BrokenImageTile>());
    }
  });

  testWidgets('the broken tile says so where there is room', (tester) async {
    Future<void> tile(double side) => tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox.square(
                dimension: side,
                child: const BrokenImageTile(),
              ),
            ),
          ),
        );
    await tile(160);
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    expect(find.text("Photo didn't load"), findsOneWidget);
    await tile(56);
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    expect(find.text("Photo didn't load"), findsNothing);
  });

  testWidgets('no picture: the placeholder', (tester) async {
    await _pump(
      tester,
      const WardrobePicture(
        imageUrl: null,
        placeholder: Text('placeholder'),
        backgroundAsset: _bg,
      ),
    );

    expect(find.text('placeholder'), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(_background, findsNothing);
  });
}
