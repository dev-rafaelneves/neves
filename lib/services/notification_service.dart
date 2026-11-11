import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  static bool get isTestEnvironment {
    try {
      return !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  Future<void> init() async {
    if (isTestEnvironment) {
      _isInitialized = true;
      return;
    }
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();

      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings darwinSettings =
          DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      );

      await _notificationsPlugin.initialize(settings: initSettings);
      _isInitialized = true;
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  Future<bool> requestPermissions() async {
    if (isTestEnvironment) return true;
    try {
      final androidPlatform = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlatform != null) {
        final granted =
            await androidPlatform.requestNotificationsPermission();
        return granted ?? false;
      }
      return true;
    } catch (e) {
      debugPrint('Erro ao solicitar permissões de notificação: $e');
      return false;
    }
  }

  /// Dispara notificação instantânea quando o orçamento de uma categoria atinge 80% ou 100%
  Future<void> notifyBudgetThreshold({
    required String categoryName,
    required double percentage,
    required double spent,
    required double limit,
  }) async {
    if (isTestEnvironment || !_isInitialized) return;
    try {
      final isExceeded = percentage >= 1.0;
      final pctInt = (percentage * 100).round();

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'neves_budget_alerts',
        'Alertas de Orçamento',
        channelDescription:
            'Avisos ao atingir 80% ou 100% do limite mensal de uma categoria',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const NotificationDetails platformDetails =
          NotificationDetails(android: androidDetails);

      await _notificationsPlugin.show(
        id: categoryName.hashCode.abs() % 100000,
        title: isExceeded
            ? '🚨 Limite excedido em $categoryName ($pctInt%)'
            : '⚠️ Atenção ao orçamento de $categoryName ($pctInt%)',
        body:
            'Você utilizou R\$ ${spent.toStringAsFixed(2)} de R\$ ${limit.toStringAsFixed(2)} planejados para este mês.',
        notificationDetails: platformDetails,
      );
    } catch (e) {
      debugPrint('Erro ao enviar alerta de orçamento: $e');
    }
  }

  /// Agenda lembrete diário de revisão de contas pendentes e faturas próximas
  Future<void> scheduleDailyBillsReminder({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    if (isTestEnvironment) return;
    try {
      const int notificationId = 201;
      await _notificationsPlugin.cancel(id: notificationId);
      if (!enabled) return;

      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'neves_daily_bills',
        'Vencimentos e Faturas',
        channelDescription:
            'Lembrete diário de faturas de cartão e contas fixas pendentes',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const NotificationDetails platformDetails =
          NotificationDetails(android: androidDetails);

      await _notificationsPlugin.zonedSchedule(
        id: notificationId,
        title: 'Lembrete Financeiro Diário 💳',
        body:
            'Confira suas contas pendentes do dia e acompanhe o limite das suas faturas.',
        scheduledDate: scheduledDate,
        notificationDetails: platformDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('Erro ao agendar lembrete financeiro: $e');
    }
  }
}
