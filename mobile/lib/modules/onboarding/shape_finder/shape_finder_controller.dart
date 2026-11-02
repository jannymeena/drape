import 'dart:ui' as ui;

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
  Future<ShapeEstimate> fromPhoto(BodyShapeSet set, XFile photo);
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
  Future<ShapeEstimate> fromPhoto(BodyShapeSet set, XFile photo) async {
    final codec = await ui.instantiateImageCodec(await photo.readAsBytes());
    final image = (await codec.getNextFrame()).image;
    final landscape = image.width > image.height;
    image.dispose();
    await Future<void>.delayed(analysisTime);
    if (landscape) throw const PhotoUnreadableException();
    return _suggestions[set]!;
  }
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
  final bool blurFace;

  final ShapeSource? source;
  final ShapeEstimate? estimate;

  ShapeFinderState copyWith({
    bool? imperial,
    Map<MeasurementField, double>? cm,
    XFile? photo,
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

  void setPhoto(XFile photo) => state = state.copyWith(photo: photo);

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
    final estimate = await _estimator.fromPhoto(state.set, photo);
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
