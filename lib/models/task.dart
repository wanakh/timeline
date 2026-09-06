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

  /// 予定の開始日
  @HiveField(3)
  final DateTime startDate;

  /// 予定の終了日
  @HiveField(4)
  final DateTime endDate;

  /// 開始時刻。日付だけの予定なら null。
  @HiveField(5)
  final DateTime? startAt;

  /// 終了時刻。日付だけの予定なら null。
  @HiveField(6)
  final DateTime? endAt;

  @HiveField(7)
  bool isCompleted;

  Task({
    required this.id,
    required this.title,
    this.description,
    required this.startDate,
    required this.endDate,
    this.startAt,
    this.endAt,
    this.isCompleted = false,
  });
}
