import 'package:hive_ce_flutter/hive_flutter.dart';

import '../models/task.dart';

class HiveService {
  static const String taskBoxName = 'tasks';

  static Future<void> init() async {
    await Hive.initFlutter();

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(TaskAdapter());
    }

    await Hive.openBox<Task>(taskBoxName);
  }

  static Box<Task> get taskBox {
    return Hive.box<Task>(taskBoxName);
  }
}
