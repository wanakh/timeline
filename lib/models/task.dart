import 'package:hive_ce/hive.dart';

part 'task.g.dart';

@HiveType(typeId: 0)
class Task extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String? description;

  @HiveField(3)
  final DateTime startDate;

  @HiveField(4)
  final DateTime endDate;

  @HiveField(5)
  final DateTime? startAt;

  @HiveField(6)
  final DateTime? endAt;

  @HiveField(7)
  bool isCompleted;

  /// リマインダーを発火する絶対日時。
  ///
  /// null の場合はリマインダーなし。
  @HiveField(8)
  final DateTime? reminderAt;

  Task({
    required this.id,
    required this.title,
    this.description,
    required this.startDate,
    required this.endDate,
    this.startAt,
    this.endAt,
    this.isCompleted = false,
    this.reminderAt,
  });
}
