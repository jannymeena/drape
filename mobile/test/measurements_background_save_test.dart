import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modules/onboarding/models/measurements_draft.dart';
import 'package:mobile/modules/onboarding/onboarding_controller.dart';
import 'package:mobile/modules/onboarding/onboarding_service.dart';
import 'package:mobile/shared/models/api_error.dart';
import 'package:mobile/shared/services/analytics/analytics_service.dart';

/// Records partial saves; [failWith] makes the next ones throw.
class _Service extends OnboardingService {
  _Service() : super(Dio());

  final saved = <(Map<MeasurementField, double>, String)>[];
  ApiException? failWith;

  @override
  Future<void> saveSomeMeasurements(
    Map<MeasurementField, double> cm, {
    required String unitSystem,
  }) async {
    if (failWith case final e?) throw e;
    saved.add((Map.of(cm), unitSystem));
  }

  @override
  Future<String> completeBlueprint() async => 'complete';
}

const _offline = ApiException(code: 'network', message: 'offline');
const _rejected = ApiException(
  code: 'validation',
  message: 'bad',
  statusCode: 422,
);

const _four = {
  MeasurementField.chest: 92.0,
  MeasurementField.waist: 72.0,
  MeasurementField.hips: 98.0,
  MeasurementField.shoulders: 40.0,
};

void main() {
  late _Service service;
  late OnboardingController controller;

  setUp(() {
    service = _Service();
    controller = OnboardingController(service, DebugAnalyticsService());
  });
  tearDown(() => controller.dispose());

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('saves just the given measurements, in the background', () async {
    controller.saveMeasurements(_four, imperial: true);

    // The draft has them at once, before the save lands.
    expect(controller.state.measurements.values[MeasurementField.waist], 72);
    expect(service.saved, isEmpty);

    await settle();
    expect(service.saved.single.$1, _four);
    expect(service.saved.single.$2, 'imperial');
  });

  test('a save that fails offline is sent with the next one', () async {
    service.failWith = _offline;
    controller.saveMeasurements(const {
      MeasurementField.chest: 92,
    }, imperial: false);
    await settle();
    expect(service.saved, isEmpty);

    service.failWith = null;
    controller.saveMeasurements(const {
      MeasurementField.waist: 72,
    }, imperial: false);
    await settle();
    expect(service.saved.single.$1, const {
      MeasurementField.chest: 92.0,
      MeasurementField.waist: 72.0,
    });
  });

  test('completing the blueprint retries unsent measurements without '
      'waiting for them', () async {
    service.failWith = _offline;
    controller.saveMeasurements(_four, imperial: false);
    await settle();

    service.failWith = null;
    expect(await controller.completeBlueprint(), 'complete');
    await settle();
    expect(service.saved.single.$1, _four);
  });

  test('a failed measurement save doesn’t hold up the blueprint', () async {
    service.failWith = _offline;
    controller.saveMeasurements(_four, imperial: false);
    expect(await controller.completeBlueprint(), 'complete');
  });

  test('a save the server rejects isn’t retried', () async {
    service.failWith = _rejected;
    controller.saveMeasurements(_four, imperial: false);
    await settle();

    service.failWith = null;
    controller.saveMeasurements(const {
      MeasurementField.height: 165,
    }, imperial: false);
    await settle();
    expect(service.saved.single.$1, const {MeasurementField.height: 165.0});
  });
  test('each measurement step saves its answer as it is entered', () async {
    controller.saveMeasurement(MeasurementField.height, 165, imperial: false);
    await settle();
    controller.saveMeasurement(MeasurementField.chest, 92, imperial: false);
    await settle();

    expect(service.saved.map((s) => s.$1), [
      const {MeasurementField.height: 165.0},
      const {MeasurementField.chest: 92.0},
    ]);
    expect(controller.state.measurements.values[MeasurementField.chest], 92);
  });

  test('a landed save tells the app to refresh saved progress', () async {
    var refreshes = 0;
    final c = OnboardingController(
      service,
      DebugAnalyticsService(),
      onMeasurementsSaved: () => refreshes++,
    );
    addTearDown(c.dispose);

    service.failWith = _offline;
    c.saveMeasurement(MeasurementField.height, 165, imperial: false);
    await settle();
    expect(refreshes, 0);

    service.failWith = null;
    c.saveMeasurement(MeasurementField.chest, 92, imperial: false);
    await settle();
    expect(refreshes, 1);
  });

  test('an empty optional step only clears the draft', () async {
    controller.saveMeasurement(MeasurementField.weight, 60, imperial: false);
    await settle();
    controller.saveMeasurement(MeasurementField.weight, null, imperial: false);
    await settle();

    expect(service.saved.single.$1, const {MeasurementField.weight: 60.0});
    expect(controller.state.measurements.get(MeasurementField.weight), isNull);
  });
}
