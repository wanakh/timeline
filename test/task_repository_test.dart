import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:timeline/models/task.dart';
import 'package:timeline/services/task_repository.dart';

void main() {
  late Directory temporaryDirectory;
  late TaskRepository repository;

  setUpAll(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'timeline_repository_test_',
    );
    Hive.init(temporaryDirectory.path);
    Hive.registerAdapter(TaskAdapter());
    await Hive.openBox<Task>(TaskRepository.boxName);
    repository = TaskRepository();
  });

  setUp(() async {
    await Hive.box<Task>(TaskRepository.boxName).clear();
  });

  tearDownAll(() async {
    await Hive.close();
    await temporaryDirectory.delete(recursive: true);
  });

  test('不正なタスクはHiveへ保存されない', () async {
    final invalidTask = Task(
      id: 'invalid',
      title: '',
      startDate: DateTime(2026, 9, 9),
      endDate: DateTime(2026, 9, 9),
    );

    await expectLater(repository.add(invalidTask), throwsArgumentError);
    expect(await repository.getAll(), isEmpty);
  });

  test('有効なタスクはHiveへ保存される', () async {
    final task = Task(
      id: 'valid',
      title: 'タスク',
      description: '説明',
      startDate: DateTime(2026, 9, 9),
      endDate: DateTime(2026, 9, 9),
    );

    await repository.add(task);

    final savedTask = await repository.getById(task.id);
    expect(savedTask?.title, 'タスク');
    expect(savedTask?.description, '説明');
  });
}
