import 'dart:async';

import 'package:convenient_test_common/convenient_test_common.dart';
import 'package:convenient_test_dev/src/functions/binding.dart';
import 'package:convenient_test_dev/src/functions/entrypoint.dart';
import 'package:convenient_test_dev/src/functions/goldens.dart';
import 'package:convenient_test_dev/src/support/get_it.dart';
import 'package:convenient_test_dev/src/support/manager_rpc_service.dart';
import 'package:convenient_test_dev/src/support/reporter_service.dart';
import 'package:convenient_test_dev/src/support/setup.dart';
import 'package:convenient_test_dev/src/support/slot.dart';
import 'package:convenient_test_dev/src/support/static_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;

@internal
Future<void> convenientTestEntrypointWhenEnvDevice(VoidCallback testBody) async {
  myGetIt.registerSingleton<ConvenientTestManagerRpcService>(ConvenientTestManagerRpcService());
  myGetIt.registerSingleton<ReporterService>(ReporterServiceSendToManager());

  final currentRunConfig = await myGetIt.get<ConvenientTestManagerRpcService>().getWorkerCurrentRunConfig();
  switch (currentRunConfig.whichSubType()) {
    case WorkerCurrentRunConfig_SubType.interactiveApp:
      return _runModeInteractiveApp();
    case WorkerCurrentRunConfig_SubType.integrationTest:
      return _runModeIntegrationTest(testBody, currentRunConfig.integrationTest);
    case WorkerCurrentRunConfig_SubType.notSet:
      throw Exception('Unknown WorkerCurrentRunConfig_SubType: $currentRunConfig');
  }
}

Future<void> _runModeInteractiveApp() async {
  await myGetIt.get<ConvenientTestSlot>().appMain(AppMainExecuteMode.interactiveApp);
}

Future<void> _runModeIntegrationTest(
  VoidCallback testBody,
  WorkerCurrentRunConfig_IntegrationTest currentRunConfig,
) async {
  runZonedGuarded(() {
    _configureGoldens(currentRunConfig);
    collectIntoDeclarerAndExecute(
      testBody,
      defaultRetry: currentRunConfig.defaultRetryCount,
      reportSuiteInfo: currentRunConfig.reportSuiteInfo,
      executionFilter: currentRunConfig.executionFilter,
      insideSetup: () {
        try {
          // use *constructor* instead of `ensureInitialized`, such that if it is already initialized it will throw
          // (TODO add tests)
          MyIntegrationTestWidgetsFlutterBinding(); // initialize it
        } catch (e) {
          // This is because:
          // (1) Must call [runZonedGuarded] *outside* [ensureInitialized], otherwise no errors will be captured.
          //     See https://docs.flutter.dev/testing/errors#errors-not-caught-by-flutter for details.
          // (2) [IntegrationTestWidgetsFlutterBinding] must be called *inside* `collectIntoDeclarer`,
          //     because it calls some logic inside it.
          // ignore: avoid_print
          print('Please do *not* initialize `WidgetsBinding.instance` outside `convenientTestMain`.');
          rethrow;
        }

        unawaited(ReporterService.I?.report(ReportItem(setUpAll: SetUpAll())));

        setup();
      },
    );
  }, (e, s) {
    Log.w('ConvenientTestMain',
        'ConvenientTest captured error (via runZonedGuarded). type(e)=${e.runtimeType} exception=$e stackTrace=$s');
  });
}

void _configureGoldens(WorkerCurrentRunConfig_IntegrationTest currentRunConfig) {
  const _kTag = 'ConfigureGoldens';

  goldenFileComparator = EnhancedLocalFileComparator(
      Uri.file(path.join(StaticConfig.kAppCodeDir, 'integration_test/dummy.dart')),
      captureFailure: true);
  autoUpdateGoldenFiles = currentRunConfig.autoUpdateGoldenFiles;

  Log.d(
      _kTag,
      'configure '
      'autoUpdateGoldenFiles=$autoUpdateGoldenFiles '
      'comparator.basedir=${(goldenFileComparator as LocalFileComparator).basedir}');
}
