import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart' show Offset, Size;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/body_shapes.dart';
import '../models/measurements_draft.dart';
import 'body_reading.dart';
import 'measurement_shape.dart';
import 'pose_detector.dart';
import 'shape_photo_render.dart';

export 'body_reading.dart' show PhotoProblem, PhotoUnreadableException;

/// The "Not sure?" sub-flow of Style Blueprint step 2: the user either enters
/// four measurements or takes/uploads a full-body photo, and we suggest a body
/// shape from it. Both are worked out on the device; nothing is uploaded.
///
/// Measurements go straight into the formula ([shapeFromMeasurements]). A
/// photo is read by MediaPipe ([PoseDetector]) as soon as it's picked; the
/// reading ([BodyReading]) places the framing lines and the face blur, and
/// after the user's adjustments gives the body's widths at the lines, which
/// go into the same formula ([photoSignals]).

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

  /// Lines at about these heights, put in order and apart, inside the photo.
  factory FramingGuides.fitted({
    required double shoulders,
    required double waist,
    required double hips,
  }) {
    final s = shoulders.clamp(_top, _bottom - 2 * minGap).toDouble();
    final w = waist.clamp(s + minGap, _bottom - minGap).toDouble();
    final h = hips.clamp(w + minGap, _bottom).toDouble();
    return FramingGuides(shoulders: s, waist: w, hips: h);
  }

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
  const ShapePhoto({
    required this.file,
    required this.guides,
    this.faceBlur,
    this.body,
  });

  /// The framed photo: the face blur and the guide lines are already drawn
  /// into it (see [ShapePhotoRenderer]).
  final XFile file;

  /// Where the user put the lines: the body is measured there.
  final FramingGuides guides;

  /// Where the face was blurred; null when the user turned blurring off.
  final FaceBlur? faceBlur;

  /// What MediaPipe found in the original photo.
  final BodyReading? body;
}

abstract class BodyShapeEstimator {
  Future<ShapeEstimate> fromMeasurements(
    BodyShapeSet set,
    Map<MeasurementField, double> cm,
  );

  /// Throws [PhotoUnreadableException] when the body can't be made out.
  Future<ShapeEstimate> fromPhoto(BodyShapeSet set, ShapePhoto photo);
}

/// Both paths, on the device: measurements through [shapeFromMeasurements];
/// a photo by measuring the body MediaPipe found at the user's lines.
class LocalBodyShapeEstimator implements BodyShapeEstimator {
  const LocalBodyShapeEstimator({
    this.analysisTime = const Duration(milliseconds: 1500),
  });

  /// The least time the analyzing screen shows, so it doesn't just flash:
  /// the reading itself is done by the time it opens.
  final Duration analysisTime;

  @override
  Future<ShapeEstimate> fromMeasurements(
    BodyShapeSet set,
    Map<MeasurementField, double> cm,
  ) async => shapeFromMeasurements(set, cm);

  @override
  Future<ShapeEstimate> fromPhoto(BodyShapeSet set, ShapePhoto photo) async {
    await Future<void>.delayed(analysisTime);
    final body = photo.body;
    if (body == null) throw const PhotoUnreadableException();
    return shapeFromSignals(
      set,
      photoSignals(set, body.widthsAt(photo.guides)),
    );
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
  (ref) => const LocalBodyShapeEstimator(),
);

class ShapeFinderState {
  const ShapeFinderState({
    this.set = BodyShapeSet.neutral,
    this.fitTops = 'regular',
    this.fitBottoms = 'relaxed',
    this.imperial = false,
    this.cm = const {},
    this.photo,
    this.framed = false,
    this.photoSize,
    this.guides = const FramingGuides(),
    this.faceBlur = const FaceBlur(),
    this.blurFace = true,
    this.detecting = false,
    this.body,
    this.photoProblem,
    this.guidesTouched = false,
    this.blurTouched = false,
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

  /// The photo being checked; after "Use This Photo", the framed copy that
  /// replaces it (see [framed]).
  final XFile? photo;

  /// [photo] has the face blur and the guide lines drawn into it, and the
  /// original is gone. The blur and the lines can no longer be edited.
  final bool framed;

  /// [photo]'s pixel size, once read; the review screen frames it at this
  /// aspect ratio so nothing is cropped.
  final Size? photoSize;

  final FramingGuides guides;
  final FaceBlur faceBlur;
  final bool blurFace;

  /// MediaPipe is reading [photo].
  final bool detecting;

  /// What it found; null while [detecting] or when there's a [photoProblem].
  final BodyReading? body;

  /// Why the photo can't be used, once known; the error screen explains it.
  final PhotoProblem? photoProblem;

  /// The user has moved a line, or the blur circle: the reading's
  /// suggestions, if they arrive later, mustn't undo that.
  final bool guidesTouched;
  final bool blurTouched;

  final ShapeSource? source;
  final ShapeEstimate? estimate;

  ShapeFinderState copyWith({
    bool? imperial,
    Map<MeasurementField, double>? cm,
    XFile? photo,
    bool? framed,
    Size? photoSize,
    FramingGuides? guides,
    FaceBlur? faceBlur,
    bool? blurFace,
    bool? detecting,
    BodyReading? body,
    PhotoProblem? photoProblem,
    bool? guidesTouched,
    bool? blurTouched,
    ShapeSource? source,
    ShapeEstimate? estimate,
  }) => ShapeFinderState(
    set: set,
    fitTops: fitTops,
    fitBottoms: fitBottoms,
    imperial: imperial ?? this.imperial,
    cm: cm ?? this.cm,
    photo: photo ?? this.photo,
    framed: framed ?? this.framed,
    photoSize: photoSize ?? this.photoSize,
    guides: guides ?? this.guides,
    faceBlur: faceBlur ?? this.faceBlur,
    blurFace: blurFace ?? this.blurFace,
    detecting: detecting ?? this.detecting,
    body: body ?? this.body,
    photoProblem: photoProblem ?? this.photoProblem,
    guidesTouched: guidesTouched ?? this.guidesTouched,
    blurTouched: blurTouched ?? this.blurTouched,
    source: source ?? this.source,
    estimate: estimate ?? this.estimate,
  );
}

class ShapeFinderController extends StateNotifier<ShapeFinderState> {
  ShapeFinderController(this._estimator, this._renderer, this._detector)
    : super(const ShapeFinderState());

  final BodyShapeEstimator _estimator;
  final ShapePhotoRenderer _renderer;
  final PoseDetector _detector;

  /// The reading of the current photo, started when it was picked.
  Future<BodyReading>? _reading;

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
  /// is read, and MediaPipe reads the body, in the background; when the body
  /// is found, the lines and the blur move onto it (unless the user has
  /// already moved them).
  void setPhoto(XFile photo) {
    state = ShapeFinderState(
      set: state.set,
      fitTops: state.fitTops,
      fitBottoms: state.fitBottoms,
      imperial: state.imperial,
      cm: state.cm,
      photo: photo,
      blurFace: state.blurFace,
      detecting: true,
    );
    bool current() => mounted && state.photo == photo;
    photoSize(photo).then((size) {
      if (current()) state = state.copyWith(photoSize: size);
    }, onError: (Object _) {}); // unreadable: the frame keeps a default shape

    final reading = _reading = _read(photo);
    reading.then(
      (body) {
        if (!current()) return;
        state = state.copyWith(
          detecting: false,
          body: body,
          guides: state.guidesTouched ? null : body.suggestedGuides,
          faceBlur: state.blurTouched ? null : body.suggestedFaceBlur,
        );
      },
      onError: (Object e) {
        if (!current()) return;
        state = state.copyWith(
          detecting: false,
          photoProblem: e is PhotoUnreadableException
              ? e.problem
              : PhotoProblem.unreadable,
        );
      },
    );
  }

  Future<BodyReading> _read(XFile photo) async {
    final List<DetectedPose> poses;
    try {
      poses = await _detector.detect(photo);
    } catch (_) {
      // Undecodable, or the detector failed.
      throw const PhotoUnreadableException();
    }
    return BodyReading.from(poses);
  }

  // The editing calls below take *changes*, applied to the current state:
  // several drag events can land between two rebuilds, and positions taken
  // from the last build would drop all but the last.

  /// Moves [landmark]'s line by [dy] (a fraction of the photo's height).
  void nudgeGuide(Landmark landmark, double dy) => state = state.copyWith(
    guides: state.guides.move(landmark, state.guides[landmark] + dy),
    guidesTouched: true,
  );

  /// [delta] in fractions of the photo's width and height.
  void moveFaceBlur(Offset delta) => state = state.copyWith(
    faceBlur: state.faceBlur.moveBy(delta),
    blurTouched: true,
  );

  /// Grows the disc's radius by [dr] (a fraction of the photo's width).
  void growFaceBlur(double dr) => state = state.copyWith(
    faceBlur: state.faceBlur.resize(state.faceBlur.radius + dr),
    blurTouched: true,
  );

  /// Scales the disc's radius by [factor].
  void scaleFaceBlur(double factor) => state = state.copyWith(
    faceBlur: state.faceBlur.resize(state.faceBlur.radius * factor),
    blurTouched: true,
  );

  void setBlurFace(bool blur) => state = state.copyWith(blurFace: blur);

  /// "Use This Photo": once MediaPipe has found a readable body, draws the
  /// face blur (if on) and the guide lines into a new image, which replaces
  /// [ShapeFinderState.photo] from here on, and deletes the original.
  ///
  /// Throws [PhotoUnreadableException] when the body can't be read; the
  /// original is deleted then too, as the error screen says.
  Future<XFile> framePhoto() async {
    final original = state.photo;
    if (original == null) throw const PhotoUnreadableException();
    if (state.framed) return original;
    try {
      await (_reading ?? Future.error(const PhotoUnreadableException()));
    } on PhotoUnreadableException catch (e) {
      if (mounted) state = state.copyWith(photoProblem: e.problem);
      await _deletePicked(original);
      rethrow;
    }
    final framed = await _renderer.render(
      original,
      guides: state.guides,
      faceBlur: state.blurFace ? state.faceBlur : null,
    );
    if (mounted && state.photo == original) {
      state = state.copyWith(photo: framed, framed: true);
    }
    await _deletePicked(original);
    return framed;
  }

  /// image_picker hands over a copy in the app's cache on Android and iOS,
  /// so deleting it never touches the user's own gallery. Elsewhere the path
  /// may be the user's file, so it's left alone.
  static Future<void> _deletePicked(XFile photo) async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      await File(photo.path).delete();
    } on FileSystemException {
      // Already gone.
    }
  }

  Future<ShapeEstimate> estimateFromMeasurements() async {
    final estimate = await _estimator.fromMeasurements(state.set, state.cm);
    state = state.copyWith(
      source: ShapeSource.measurements,
      estimate: estimate,
    );
    return estimate;
  }

  /// Throws [PhotoUnreadableException] (and deletes the framed photo, which
  /// is no use then).
  Future<ShapeEstimate> estimateFromPhoto() async {
    final photo = state.framed ? state.photo! : await framePhoto();
    final ShapeEstimate estimate;
    try {
      estimate = await _estimator.fromPhoto(
        state.set,
        ShapePhoto(
          file: photo,
          guides: state.guides,
          faceBlur: state.blurFace ? state.faceBlur : null,
          body: state.body,
        ),
      );
    } on PhotoUnreadableException catch (e) {
      if (mounted) state = state.copyWith(photoProblem: e.problem);
      await _renderer.discard(photo);
      rethrow;
    }
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
      (ref) => ShapeFinderController(
        ref.read(bodyShapeEstimatorProvider),
        ref.read(shapePhotoRendererProvider),
        ref.read(poseDetectorProvider),
      ),
    );
