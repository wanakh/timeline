import 'package:flutter_test/flutter_test.dart';
import 'package:timeline/services/task_validator.dart';

void main() {
  final today = DateTime(2026, 9, 9);

  group('TaskValidator', () {
    test('有効な日付のみのタスクを受け入れる', () {
      final result = TaskValidator.validate(
        title: '買い物',
        description: '牛乳を買う',
        startDate: today,
        endDate: today,
      );

      expect(result, isNull);
    });

    test('空のタイトル、長すぎるタイトル・説明を拒否する', () {
      expect(
        TaskValidator.validate(title: '  ', startDate: today, endDate: today),
        'タイトルを入力してください。',
      );
      expect(
        TaskValidator.validate(
          title: 'あ' * 31,
          startDate: today,
          endDate: today,
        ),
        'タイトルは30文字以内で入力してください。',
      );
      expect(
        TaskValidator.validate(
          title: 'タスク',
          description: 'あ' * 101,
          startDate: today,
          endDate: today,
        ),
        '説明は100文字以内で入力してください。',
      );
    });

    test('日付と同日の時刻の矛盾を拒否する', () {
      expect(
        TaskValidator.validate(
          title: 'タスク',
          startDate: today,
          endDate: today.subtract(const Duration(days: 1)),
        ),
        '終了日は開始日より前にできません。',
      );
      expect(
        TaskValidator.validate(
          title: 'タスク',
          startDate: today,
          endDate: today,
          startAt: DateTime(2026, 9, 9, 18),
          endAt: DateTime(2026, 9, 9, 9),
        ),
        '終了時刻は開始時刻より前にできません。',
      );
    });
  });
}
