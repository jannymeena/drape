import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modules/wardrobe/widgets/wardrobe_picture.dart';

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
final _spinner = find.byType(CircularProgressIndicator);

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
