import 'package:hive_ce/hive.dart';

import '../models/task.dart';

class TaskRepository {
  static const String boxName = 'tasks';

  Future<Box<Task>> _openBox() async {
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<Task>(boxName);
    }

    return Hive.openBox<Task>(boxName);
  }

  /// 全Taskを取得
  Future<List<Task>> getAll() async {
    final box = await _openBox();
    return box.values.toList();
  }

  /// IDでTaskを取得
  Future<Task?> getById(String id) async {
    final box = await _openBox();
    return box.get(id);
  }

  /// Taskを追加
  Future<void> add(Task task) async {
    final box = await _openBox();
    await box.put(task.id, task);
  }

  /// Taskを更新
  Future<void> update(Task task) async {
    final box = await _openBox();
    await box.put(task.id, task);
  }

  /// Taskを削除
  Future<void> delete(String id) async {
    final box = await _openBox();
    await box.delete(id);
  }

  /// Taskの完了状態を切り替え
  Future<void> toggleCompleted(String id) async {
    final box = await _openBox();
    final task = box.get(id);

    if (task == null) {
      return;
    }

    task.isCompleted = !task.isCompleted;
    await task.save();
  }
}
