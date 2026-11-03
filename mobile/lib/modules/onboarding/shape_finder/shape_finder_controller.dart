import 'dart:ui' as ui;

import 'package:flutter/painting.dart' show Offset, Size;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/body_shapes.dart';
import '../models/measurements_draft.dart';

/// The "Not sure?" sub-flow of Style Blueprint step 2: the user either enters
/// four measurements or takes/uploads a full-body photo, and we suggest a body
/// shape from it.
///
/// How a shape is actually identified is still open, so it sits behind
/// [BodyShapeEstimator]; [PlaceholderBodyShapeEstimator] stands in for now.

/// The measurements the measurements path asks for.
const shapeMeasurements = [
  MeasurementField.chest,
  MeasurementField.waist,
  MeasurementField.hips,
  MeasurementField.shoulders,
];

/// Which path produced the suggestion.
enum ShapeSource { measurements, photo }

/// A suggested shape (a backend `BodyShape` literal) and the runners-up.
class ShapeEstimate {
  const ShapeEstimate({required this.best, required this.alternatives});

  final String best;
  final List<String> alternatives;

  /// [shape] (one of [alternatives]) promoted to best; the old best joins
  /// the runners-up in its place.
  ShapeEstimate promote(String shape) => ShapeEstimate(
    best: shape,
    alternatives: [for (final a in alternatives) a == shape ? best : a],
  );
}

/// The three body landmarks the user lines up on their photo.
enum Landmark { shoulders, waist, hips }

/// Where the user placed each [Landmark] line, as a fraction of the photo's
/// height (0 = top). Always in top-to-bottom order, [minGap] apart.
class FramingGuides {
  const FramingGuides({
    this.shoulders = 0.22,
    this.waist = 0.40,
    this.hips = 0.52,
  });

  final double shoulders;
  final double waist;
  final double hips;

  static const minGap = 0.04;
  static const _top = 0.03;
  static const _bottom = 0.97;

  double operator [](Landmark l) => switch (l) {
    Landmark.shoulders => shoulders,
    Landmark.waist => waist,
    Landmark.hips => hips,
  };

  /// [landmark] moved to [y], held between its neighbours.
  FramingGuides move(Landmark landmark, double y) {
    double clamp(double lo, double hi) => y.clamp(lo, hi).toDouble();
    return switch (landmark) {
      Landmark.shoulders => FramingGuides(
        shoulders: clamp(_top, waist - minGap),
        waist: waist,
        hips: hips,
      ),
      Landmark.waist => FramingGuides(
        shoulders: shoulders,
        waist: clamp(shoulders + minGap, hips - minGap),
        hips: hips,
      ),
      Landmark.hips => FramingGuides(
        shoulders: shoulders,
        waist: waist,
        hips: clamp(waist + minGap, _bottom),
      ),
    };
  }
}

/// The disc the user places over their face to blur it. [center] is a
/// fraction of the photo's width and height; [radius] a fraction of its
/// width.
class FaceBlur {
  const FaceBlur({this.center = const Offset(0.5, 0.1), this.radius = 0.13});

  final Offset center;
  final double radius;

  static const minRadius = 0.05;
  static const maxRadius = 0.4;

  FaceBlur moveBy(Offset delta) => FaceBlur(
    center: Offset(
      (center.dx + delta.dx).clamp(0.0, 1.0),
      (center.dy + delta.dy).clamp(0.0, 1.0),
    ),
    radius: radius,
  );

  FaceBlur resize(double r) =>
      FaceBlur(center: center, radius: r.clamp(minRadius, maxRadius));
}

/// What the photo path hands to [BodyShapeEstimator.fromPhoto].
class ShapePhoto {
  const ShapePhoto({required this.file, required this.guides, this.faceBlur});

  final XFile file;
  final FramingGuides guides;

  /// Where to blur before analysis; null when the user turned blurring off.
  final FaceBlur? faceBlur;
}

/// The photo doesn't show a whole body, so no shape can be read from it.
class PhotoUnreadableException implements Exception {
  const PhotoUnreadableException();
}

abstract class BodyShapeEstimator {
  Future<ShapeEstimate> fromMeasurements(
    BodyShapeSet set,
    Map<MeasurementField, double> cm,
  );

  /// Throws [PhotoUnreadableException] when the body can't be made out.
  Future<ShapeEstimate> fromPhoto(BodyShapeSet set, ShapePhoto photo);
}

/// Stand-in until shape detection is designed: suggests the shape each set's
/// mockup shows, whatever the input. A landscape photo is reported as
/// unreadable — a full body rarely fits one — which is also how to reach the
/// error screen while this is in place.
class PlaceholderBodyShapeEstimator implements BodyShapeEstimator {
  const PlaceholderBodyShapeEstimator({
    this.analysisTime = const Duration(seconds: 3),
  });

  /// How long the photo "analysis" takes, so the analyzing screen is seen.
  final Duration analysisTime;

  static const _suggestions = {
    BodyShapeSet.mens: ShapeEstimate(
      best: 'inverted_triangle',
      alternatives: ['trapezoid', 'rectangle'],
    ),
    BodyShapeSet.womens: ShapeEstimate(
      best: 'hourglass',
      alternatives: ['triangle', 'rectangle'],
    ),
    BodyShapeSet.neutral: ShapeEstimate(
      best: 'rectangle',
      alternatives: ['triangle', 'trapezoid'],
    ),
  };

  @override
  Future<ShapeEstimate> fromMeasurements(
    BodyShapeSet set,
    Map<MeasurementField, double> cm,
  ) async => _suggestions[set]!;

  @override
  Future<ShapeEstimate> fromPhoto(BodyShapeSet set, ShapePhoto photo) async {
    final size = await photoSize(photo.file);
    final landscape = size.width > size.height;
    await Future<void>.delayed(analysisTime);
    if (landscape) throw const PhotoUnreadableException();
    return _suggestions[set]!;
  }
}

/// The pixel size of [photo].
Future<Size> photoSize(XFile photo) async {
  final codec = await ui.instantiateImageCodec(await photo.readAsBytes());
  final image = (await codec.getNextFrame()).image;
  final size = Size(image.width.toDouble(), image.height.toDouble());
  image.dispose();
  codec.dispose();
  return size;
}

final bodyShapeEstimatorProvider = Provider<BodyShapeEstimator>(
  (ref) => const PlaceholderBodyShapeEstimator(),
);

class ShapeFinderState {
  const ShapeFinderState({
    this.set = BodyShapeSet.neutral,
    this.fitTops = 'regular',
    this.fitBottoms = 'relaxed',
    this.imperial = false,
    this.cm = const {},
    this.photo,
    this.photoSize,
    this.guides = const FramingGuides(),
    this.faceBlur = const FaceBlur(),
    this.blurFace = true,
    this.source,
    this.estimate,
  });

  /// Which shape set (and so which names and drawings) the user sees.
  final BodyShapeSet set;

  /// Step 2's fit answers, carried through so finishing the sub-flow can save
  /// the whole step.
  final String fitTops;
  final String fitBottoms;

  /// Inches rather than centimetres on the measurements screen.
  final bool imperial;

  /// Entered measurements, always in centimetres.
  final Map<MeasurementField, double> cm;

  final XFile? photo;

  /// [photo]'s pixel size, once read; the review screen frames it at this
  /// aspect ratio so nothing is cropped.
  final Size? photoSize;

  final FramingGuides guides;
  final FaceBlur faceBlur;
  final bool blurFace;

  final ShapeSource? source;
  final ShapeEstimate? estimate;

  ShapeFinderState copyWith({
    bool? imperial,
    Map<MeasurementField, double>? cm,
    XFile? photo,
    Size? photoSize,
    FramingGuides? guides,
    FaceBlur? faceBlur,
    bool? blurFace,
    ShapeSource? source,
    ShapeEstimate? estimate,
  }) => ShapeFinderState(
    set: set,
    fitTops: fitTops,
    fitBottoms: fitBottoms,
    imperial: imperial ?? this.imperial,
    cm: cm ?? this.cm,
    photo: photo ?? this.photo,
    photoSize: photoSize ?? this.photoSize,
    guides: guides ?? this.guides,
    faceBlur: faceBlur ?? this.faceBlur,
    blurFace: blurFace ?? this.blurFace,
    source: source ?? this.source,
    estimate: estimate ?? this.estimate,
  );
}

class ShapeFinderController extends StateNotifier<ShapeFinderState> {
  ShapeFinderController(this._estimator) : super(const ShapeFinderState());

  final BodyShapeEstimator _estimator;

  /// Starts afresh from step 2, remembering its fit answers. [saved] are
  /// measurements entered earlier (in cm); they prefill the measurements path.
  void start({
    required BodyShapeSet set,
    required String fitTops,
    required String fitBottoms,
    Map<MeasurementField, double> saved = const {},
  }) {
    state = ShapeFinderState(
      set: set,
      fitTops: fitTops,
      fitBottoms: fitBottoms,
      cm: {for (final f in shapeMeasurements) f: ?saved[f]},
    );
  }

  void setImperial(bool imperial) => state = state.copyWith(imperial: imperial);

  /// [cm] null clears the field.
  void setMeasurement(MeasurementField field, double? cm) {
    final next = {...state.cm};
    if (cm == null) {
      next.remove(field);
    } else {
      next[field] = cm;
    }
    state = state.copyWith(cm: next);
  }

  /// A new photo, with the guides and blur back at their defaults. Its size
  /// is read in the background.
  void setPhoto(XFile photo) {
    state = ShapeFinderState(
      set: state.set,
      fitTops: state.fitTops,
      fitBottoms: state.fitBottoms,
      imperial: state.imperial,
      cm: state.cm,
      photo: photo,
      blurFace: state.blurFace,
    );
    photoSize(photo).then((size) {
      if (mounted && state.photo == photo) {
        state = state.copyWith(photoSize: size);
      }
    }, onError: (Object _) {}); // unreadable: the frame keeps a default shape
  }

  // The editing calls below take *changes*, applied to the current state:
  // several drag events can land between two rebuilds, and positions taken
  // from the last build would drop all but the last.

  /// Moves [landmark]'s line by [dy] (a fraction of the photo's height).
  void nudgeGuide(Landmark landmark, double dy) => state = state.copyWith(
    guides: state.guides.move(landmark, state.guides[landmark] + dy),
  );

  /// [delta] in fractions of the photo's width and height.
  void moveFaceBlur(Offset delta) =>
      state = state.copyWith(faceBlur: state.faceBlur.moveBy(delta));

  /// Grows the disc's radius by [dr] (a fraction of the photo's width).
  void growFaceBlur(double dr) => state = state.copyWith(
    faceBlur: state.faceBlur.resize(state.faceBlur.radius + dr),
  );

  /// Scales the disc's radius by [factor].
  void scaleFaceBlur(double factor) => state = state.copyWith(
    faceBlur: state.faceBlur.resize(state.faceBlur.radius * factor),
  );

  void setBlurFace(bool blur) => state = state.copyWith(blurFace: blur);

  Future<ShapeEstimate> estimateFromMeasurements() async {
    final estimate = await _estimator.fromMeasurements(state.set, state.cm);
    state = state.copyWith(
      source: ShapeSource.measurements,
      estimate: estimate,
    );
    return estimate;
  }

  /// Throws [PhotoUnreadableException].
  Future<ShapeEstimate> estimateFromPhoto() async {
    final photo = state.photo;
    if (photo == null) throw const PhotoUnreadableException();
    final estimate = await _estimator.fromPhoto(
      state.set,
      ShapePhoto(
        file: photo,
        guides: state.guides,
        faceBlur: state.blurFace ? state.faceBlur : null,
      ),
    );
    state = state.copyWith(source: ShapeSource.photo, estimate: estimate);
    return estimate;
  }

  /// The user picked one of the runners-up instead.
  void promote(String shape) {
    final estimate = state.estimate;
    if (estimate == null || !estimate.alternatives.contains(shape)) return;
    state = state.copyWith(estimate: estimate.promote(shape));
  }
}

final shapeFinderProvider =
    StateNotifierProvider<ShapeFinderController, ShapeFinderState>(
      (ref) => ShapeFinderController(ref.read(bodyShapeEstimatorProvider)),
    );
