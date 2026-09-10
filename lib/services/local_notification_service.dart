import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/task.dart';

class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance =
      LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'task_reminders';
  static const String _channelName = 'タスクのリマインダー';
  static const String _channelDescription = 'タスクのリマインダー通知';

  bool _initialized = false;

  void Function(String taskId)? _notificationTapCallback;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) {
      return;
    }

    tz.initializeTimeZones();

    final timezoneInfo = await FlutterTimezone.getLocalTimezone();

    tz.setLocalLocation(
      tz.getLocation(timezoneInfo.identifier),
    );

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const settings = InitializationSettings(
      android: androidSettings,
    );

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
    );

    final android =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await android?.createNotificationChannel(channel);

    _initialized = true;
  }

  void setNotificationTapCallback(
    void Function(String taskId) callback,
  ) {
    _notificationTapCallback = callback;
  }

  void _onNotificationResponse(NotificationResponse response) {
    final taskId = response.payload;

    if (taskId == null || taskId.isEmpty) {
      return;
    }

    _notificationTapCallback?.call(taskId);
  }

  Future<bool> requestPermissions() async {
    if (kIsWeb) {
      return false;
    }

    final android =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (android == null) {
      return false;
    }

    final notificationGranted =
        await android.requestNotificationsPermission() ?? false;

    if (!notificationGranted) {
      return false;
    }

    final canScheduleExact =
        await android.canScheduleExactNotifications() ?? false;

    if (!canScheduleExact) {
      await android.requestExactAlarmsPermission();

      final grantedAfterRequest =
          await android.canScheduleExactNotifications() ?? false;

      if (!grantedAfterRequest) {
        return false;
      }
    }

    return true;
  }

  Future<bool> scheduleTaskReminder(Task task) async {
    if (kIsWeb) {
      return false;
    }

    await initialize();

    await cancelTaskReminder(task);

    final reminderAt = task.reminderAt;

    if (task.isCompleted || reminderAt == null) {
      return false;
    }

    if (!reminderAt.isAfter(DateTime.now())) {
      return false;
    }

    final permissionGranted = await requestPermissions();

    if (!permissionGranted) {
      return false;
    }

    final notificationId = _notificationId(task.id);

    final notificationTime = tz.TZDateTime.from(
      reminderAt,
      tz.local,
    );

    await _plugin.zonedSchedule(
      id: notificationId,
      title: 'タスクのリマインダー',
      body: task.title,
      scheduledDate: notificationTime,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: task.id,
    );

    return true;
  }

  Future<void> cancelTaskReminder(Task task) async {
    if (kIsWeb) {
      return;
    }

    await initialize();

    await _plugin.cancel(
      id: _notificationId(task.id),
    );
  }

  int _notificationId(String taskId) {
    var hash = 0x811c9dc5;

    for (final byte in taskId.codeUnits) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xffffffff;
    }

    final id = hash & 0x7fffffff;

    return id == 0 ? 1 : id;
  }
}
