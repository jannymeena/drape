import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modules/onboarding/models/body_shapes.dart';
import 'package:mobile/modules/onboarding/shape_finder/body_reading.dart';
import 'package:mobile/modules/onboarding/shape_finder/measurement_shape.dart';
import 'package:mobile/modules/onboarding/shape_finder/shape_finder_controller.dart';

import 'package:mobile/modules/onboarding/shape_finder/pose_detector.dart';

import 'support/synthetic_body.dart';

Matcher _problem(PhotoProblem p) =>
    isA<PhotoUnreadableException>().having((e) => e.problem, 'problem', p);

void main() {
  group('checks', () {
    test('a single person, head to feet, facing the camera, is read', () {
      expect(() => BodyReading.from([syntheticBody()]), returnsNormally);
    });

    test('nobody', () {
      expect(
        () => BodyReading.from([]),
        throwsA(_problem(PhotoProblem.noPerson)),
      );
    });

    test('two people', () {
      expect(
        () => BodyReading.from([syntheticBody(), syntheticBody()]),
        throwsA(_problem(PhotoProblem.severalPeople)),
      );
    });

    test('feet out of the shot', () {
      expect(
        () => BodyReading.from([syntheticBody(feet: false)]),
        throwsA(_problem(PhotoProblem.notFullBody)),
      );
    });

    test('the face may be out of the shot', () {
      final pose = syntheticBody();
      final faceless = DetectedPose([
        for (final (i, p) in pose.landmarks.indexed)
          PosePoint.face.contains(i) ? PoseLandmark(p.x, -0.05) : p,
      ], pose.mask);
      final reading = BodyReading.from([faceless]);
      // The circle still starts above the shoulders.
      expect(reading.suggestedFaceBlur.center.dy, lessThan(80 / 400));
    });

    test('turned sideways', () {
      expect(
        () => BodyReading.from([syntheticBody(shoulderSpan: 20)]),
        throwsA(_problem(PhotoProblem.sideOn)),
      );
    });
  });

  group('suggestions', () {
    final body = BodyReading.from([syntheticBody()]);

    test('the lines land on the shoulders, the narrowest waist and the '
        'broadest hips', () {
      final g = body.suggestedGuides;
      // Shoulder joints at y 80 of 400, just under them.
      expect(g.shoulders, closeTo(0.21, 0.01));
      // Narrowest at y 150.
      expect(g.waist, closeTo(150 / 400, 0.01));
      // Broadest from y 190.
      expect(g.hips, closeTo(190 / 400, 0.01));
    });

    test('the blur circle covers the head', () {
      final b = body.suggestedFaceBlur;
      // Head: centre (100, 40), radius 15, in a 200 × 400 image.
      expect(b.center.dx, closeTo(0.5, 0.01));
      expect(b.center.dy, closeTo(40 / 400, 0.015));
      expect(b.radius * 200, greaterThanOrEqualTo(15));
    });
  });

  group('measuring', () {
    test('widths at the lines, with the arms left out', () {
      final body = BodyReading.from([syntheticBody()]);
      final w = body.widthsAt(body.suggestedGuides);
      // Torso half-widths 40 / 25 / 35 px of 200, so about 81, 51, 71 wide;
      // the arms (8 px away) aren't counted.
      expect(w.shoulders * 200, closeTo(79, 3));
      expect(w.waist * 200, closeTo(51, 2));
      expect(w.hips * 200, closeTo(71, 2));
    });

    test('arms touching the body are cut off', () {
      final body = BodyReading.from([syntheticBody(armGap: 0)]);
      final w = body.widthsAt(
        const FramingGuides(shoulders: 0.21, waist: 150 / 400, hips: 0.5),
      );
      // The same torso widths as with the arms clear.
      expect(w.waist * 200, closeTo(51, 2));
      expect(w.hips * 200, closeTo(71, 2));
    });

    test('arms across the body can’t be cut off', () {
      final body = BodyReading.from([syntheticBody(handsInFront: true)]);
      expect(
        () => body.widthsAt(
          const FramingGuides(shoulders: 0.21, waist: 0.45, hips: 0.5),
        ),
        throwsA(_problem(PhotoProblem.armsTouching)),
      );
    });

    test('a line below the body misses it', () {
      final body = BodyReading.from([syntheticBody()]);
      expect(
        () => body.widthsAt(
          const FramingGuides(shoulders: 0.21, waist: 0.375, hips: 0.97),
        ),
        throwsA(_problem(PhotoProblem.notFullBody)),
      );
    });

    test('widths become a shape from the user’s set', () {
      final body = BodyReading.from([syntheticBody()]);
      final widths = body.widthsAt(body.suggestedGuides);
      for (final set in BodyShapeSet.values) {
        final e = shapeFromSignals(set, photoSignals(set, widths));
        final offered = {for (final o in bodyShapesFor(set)) o.value};
        expect(offered, contains(e.best));
      }
    });
  });

  test('fitted guides are put in order, apart, inside the photo', () {
    final g = FramingGuides.fitted(shoulders: 0.5, waist: 0.4, hips: 1.2);
    expect(g.waist - g.shoulders, greaterThanOrEqualTo(FramingGuides.minGap));
    expect(g.hips - g.waist, greaterThanOrEqualTo(FramingGuides.minGap - 1e-9));
    expect(g.hips, lessThan(1));
  });
}
