import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:timeline/models/task.dart';
import 'package:timeline/screens/timeline_screen.dart';

void main() {
  late Directory temporaryDirectory;

  setUpAll(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'timeline_widget_test_',
    );
    Hive.init(temporaryDirectory.path);
    Hive.registerAdapter(TaskAdapter());
    await Hive.openBox<Task>('tasks');
  });

  setUp(() async {
    await Hive.box<Task>('tasks').clear();
  });

  tearDownAll(() async {
    await Hive.close();
    await temporaryDirectory.delete(recursive: true);
  });

  testWidgets('作成画面から日付のみのタスクを追加できる', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: TimelineScreen())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('タスクを追加'));
    await tester.pumpAndSettle();

    expect(find.text('タスクを追加'), findsOneWidget);
    expect(find.text('時間を設定'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'テストタスク');
    await tester.tap(find.widgetWithText(FilledButton, '追加'));
    await tester.pumpAndSettle();

    final savedTask = Hive.box<Task>('tasks').values.single;
    expect(savedTask.title, 'テストタスク');
    expect(savedTask.startAt, isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('タイトル未入力では作成できない', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: TimelineScreen())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('タスクを追加'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '追加'));
    await tester.pump();

    expect(find.text('タイトルを入力してください。'), findsOneWidget);
    expect(Hive.box<Task>('tasks').values, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
