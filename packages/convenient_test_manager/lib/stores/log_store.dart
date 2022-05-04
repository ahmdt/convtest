import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:convenient_test_common/convenient_test_common.dart';
import 'package:mobx/mobx.dart';

part 'log_store.g.dart';

class LogStore = _LogStore with _$LogStore;

abstract class _LogStore with Store {
  final logEntryInTest = RelationOneToMany();

  final logEntryMap = ObservableMap<int, LogEntry>();

  /// `snapshotInLog[logEntryId][name] == snapshot bytes`
  final snapshotInLog = ObservableMap<int, ObservableMap<String, Uint8List>>();

  @observable
  int? activeLogEntryId;

  @observable
  String? activeSnapshotName;

  @computed
  String? get effectiveActiveSnapshotName {
    if (activeSnapshotName != null) return activeSnapshotName;
    return snapshotInLog[activeLogEntryId]?.keys.firstOrNull;
  }

  bool isTestFlaky(int testInfoId) =>
      // If see multiple TEST_START, then this test is flaky
      (logEntryInTest[testInfoId] ?? <int>[])
          .where((logEntryId) => logEntryMap[logEntryId]?.type == LogSubEntryType.TEST_START)
          .length >
      1;

  void clear() {
    logEntryInTest.clear();
    logEntryMap.clear();
    snapshotInLog.clear();
    activeLogEntryId = null;
    activeSnapshotName = null;
  }
}
