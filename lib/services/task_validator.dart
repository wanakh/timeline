import '../models/task.dart';

/// Taskの保存前に守るべき制約を、画面と保存処理で共有する。
class TaskValidator {
  const TaskValidator._();

  static const int maxTitleLength = 30;
  static const int maxDescriptionLength = 100;

  static String? validate({
    required String title,
    String? description,
    required DateTime startDate,
    required DateTime endDate,
    DateTime? startAt,
    DateTime? endAt,
  }) {
    if (title.trim().isEmpty) {
      return 'タイトルを入力してください。';
    }
    if (title.trim().length > maxTitleLength) {
      return 'タイトルは$maxTitleLength文字以内で入力してください。';
    }
    if (description != null &&
        description.trim().length > maxDescriptionLength) {
      return '説明は$maxDescriptionLength文字以内で入力してください。';
    }
    if (endDate.isBefore(startDate)) {
      return '終了日は開始日より前にできません。';
    }
    if (startAt != null &&
        endAt != null &&
        _isSameDate(startDate, endDate) &&
        endAt.isBefore(startAt)) {
      return '終了時刻は開始時刻より前にできません。';
    }
    return null;
  }

  static String? validateTask(Task task) => validate(
    title: task.title,
    description: task.description,
    startDate: task.startDate,
    endDate: task.endDate,
    startAt: task.startAt,
    endAt: task.endAt,
  );

  static void validateOrThrow(Task task) {
    final message = validateTask(task);
    if (message != null) {
      throw ArgumentError.value(task, 'task', message);
    }
  }

  static bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
