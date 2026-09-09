import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timeline/models/task.dart';
import 'package:timeline/providers/task_provider.dart';
import 'package:timeline/screens/timeline_screen.dart';
import 'package:timeline/services/task_repository.dart';

class _FakeTaskRepository extends TaskRepository {
  final tasks = <Task>[];

  @override
  Future<List<Task>> getAll() async => List.of(tasks);

  @override
  Future<void> add(Task task) async {
    tasks.removeWhere((item) => item.id == task.id);
    tasks.add(task);
  }
}

void main() {
  Widget buildTestApp(_FakeTaskRepository repository) {
    return ProviderScope(
      overrides: [taskRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(home: TimelineScreen()),
    );
  }

  testWidgets('作成画面から日付のみのタスクを追加できる', (tester) async {
    final repository = _FakeTaskRepository();
    await tester.pumpWidget(buildTestApp(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('タスクを追加'));
    await tester.pumpAndSettle();

    expect(find.text('タスクを追加'), findsOneWidget);
    expect(find.text('時間を設定'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'テストタスク');
    await tester.tap(find.widgetWithText(FilledButton, '追加'));
    await tester.pumpAndSettle();

    final savedTask = repository.tasks.single;
    expect(savedTask.title, 'テストタスク');
    expect(savedTask.startAt, isNull);
  });

  testWidgets('タイトル未入力では作成できない', (tester) async {
    final repository = _FakeTaskRepository();
    await tester.pumpWidget(buildTestApp(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('タスクを追加'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '追加'));
    await tester.pump();

    expect(find.text('タイトルを入力してください。'), findsOneWidget);
    expect(repository.tasks, isEmpty);
  });

  testWidgets('文字数超過のタイトルは入力できても作成できない', (tester) async {
    final repository = _FakeTaskRepository();
    await tester.pumpWidget(buildTestApp(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('タスクを追加'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'あ' * 31);
    await tester.pump();

    expect(find.text('タイトルは30文字以内で入力してください。'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '追加'));
    await tester.pump();
    expect(repository.tasks, isEmpty);
  });

  testWidgets('長い説明文のタスクをoverflowせず表示できる', (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final description = '説明文' * 33;
    final repository = _FakeTaskRepository()
      ..tasks.add(
        Task(
          id: 'long-description',
          title: '長い説明のタスク',
          description: description,
          startDate: today,
          endDate: today,
        ),
      );

    await tester.pumpWidget(buildTestApp(repository));
    await tester.pumpAndSettle();

    expect(find.text('長い説明のタスク'), findsOneWidget);
    expect(find.text(description), findsOneWidget);
  });
}
