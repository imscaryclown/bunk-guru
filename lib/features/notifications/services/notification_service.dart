import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import '../../../core/database/local_storage_service.dart';
import '../../../core/utils/attendance_math.dart';
import '../../../models/subject.dart';
import '../../../models/schedule_slot.dart';
import '../../../models/attendance_response.dart';

class Persona {
  final String id;
  final String name;
  final String icon;
  final String desc;
  final List<String> classReminder;
  final List<String> danger;
  final List<String> safe;
  final List<String> streak;
  final List<String> morning;

  const Persona({
    required this.id,
    required this.name,
    required this.icon,
    required this.desc,
    required this.classReminder,
    required this.danger,
    required this.safe,
    required this.streak,
    required this.morning,
  });
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static bool _exactAlarmGranted = false;

  // ===== PERSONAS DATABASE =====
  static final Map<String, Persona> personas = {
    'sharma': const Persona(
      id: 'sharma',
      name: 'Sharma Ji Ka Beta',
      icon: '👨‍👦',
      desc: 'Guilt-tripping desi parent energy',
      classReminder: [
        '"{subject}" in {time} min. Sharma ji ka beta already seated. Front row. 😤',
        'Beta, {subject} class aa rahi hai. {pct}% attendance pe kaise face dikhaaoge?',
        '{subject} starts soon. Sharma ji ka beta has 95% attendance. Just saying. 🫣',
        'Tumhare papa ne fees bhari hai, {subject} in {time} min. Jaao padhne.',
        '{subject} ka class hai. Padosi ka beta toh IIT mein hai... tum toh attend kar lo 😑',
        'Bus {bunksLeft} bunk baaki hain {subject} mein. Papa ko bataaun? 📞',
      ],
      danger: [
        '🚨 {subject} mein {pct}% attendance?! Sharma ji ka beta rota hoga tumhare liye.',
        'Beta {needed} classes attend karo nahi toh papa ko phone karunga. {subject}: {pct}%.',
        '{subject}: {pct}%. Sharma ji ke bete ne kabhi 75% neeche nahi dekha. KABHI.',
        'Debar hone ke baad LinkedIn pe kya likhoge? "{subject} Expert"? Attend karo! 💀',
      ],
      safe: [
        '{bunksLeft} bunks safe hain {subject} mein. But Sharma ji ka beta never bunks. 😇',
        '{subject}: {pct}%. Theek hai, Sharma ji ka beta se 10% peeche ho bas.',
        'Aaj {subject} skip kar sakte ho. But will Sharma ji approve? Think about it. 🤔',
      ],
      streak: [
        '🔥 {streak} din se bunk nahi maara! Sharma ji impressed honge... thoda.',
        '{streak}-day streak! Beta, finally kuch accha kar rahe ho.',
        'Lagaataar {streak} din class attend ki. Sharma ji ke bete ka record {streak}+1 hai 😤',
      ],
      morning: [
        '☀️ Aaj {totalToday} classes hain. Sharma ji ka beta subah 6 baje uthta hai. Tum?',
        'Good morning! Aaj ka plan: {totalToday} classes. Papa ki mehnat barbaad mat karo.',
        'Subah ho gayi. {totalToday} classes aaj. Sharma ji ka beta already ready hai 🧑‍🎓',
      ],
    ),
    'toxic_ex': const Persona(
      id: 'toxic_ex',
      name: 'Toxic Ex',
      icon: '💔',
      desc: 'Clingy, dramatic & guilt-trippy',
      classReminder: [
        '{subject} in {time} min. You\'ll go to class but won\'t reply to my texts? 💔',
        'Remember when you said you\'d never miss {subject}? Lies. Like everything else. 😢',
        '{subject} starts soon. At least commit to SOMETHING in your life. 🥀',
        'You have time for {subject} in {time} min but no time for me? Cool cool cool 😒',
        'I KNOW you\'re thinking of skipping {subject}. I can feel it. Don\'t. 👁️',
        '{subject} misses you more than I do. {pct}% btw. We both deserve better. 💔',
      ],
      danger: [
        '{subject}: {pct}%. You\'re losing {subject} just like you lost me. 💔',
        'You abandoned me AND your {subject} attendance? {needed} more classes or debar.',
        '{pct}% in {subject}. Even I wasn\'t this neglected. Actually wait... 😭',
        'You promised you\'d change. {subject} attendance says otherwise. {pct}%. 🥀',
      ],
      safe: [
        '{bunksLeft} bunks left in {subject}. At least you\'re committed to SOMETHING 🙄',
        '{subject}: {pct}%. If only you gave our relationship this much attention. 😤',
        'Skip {subject} today? Sure, add it to the list of things you\'ve given up on. 💅',
      ],
      streak: [
        '{streak} days without bunking? Wow you CAN commit. Just not to me apparently. 💔',
        '🔥 {streak}-day streak. I\'m... proud? No wait, I\'m still hurt. But proud. 😢🔥',
        '{streak} days! You never showed up for me this consistently. 💀',
      ],
      morning: [
        '☀️ Good morning. {totalToday} classes today. I hope you attend. I still care. 💔',
        'New day, {totalToday} classes. At least show up for your future since you didn\'t for us. 😢',
        'Morning! {totalToday} classes await. Try not to ghost them like you ghosted me 👻',
      ],
    ),
    'ipl': const Persona(
      id: 'ipl',
      name: 'IPL Commentator',
      icon: '🏏',
      desc: 'Hype & dramatic cricket energy',
      classReminder: [
        '🏏 AND HE WALKS IN! {subject} in {time} min! Will he ATTEND or will he BUNK?!',
        'MASSIVE match coming up! {subject} vs Laziness! {time} min to first ball! ⚡',
        '{subject} in {time} min! The crowd is waiting! Your seat is at {pct}%! 🏟️',
        'STRATEGIC TIMEOUT is over! {subject} ka powerplay shuru hone wala hai in {time} min! 🏏',
        'Last over situation! {subject} in {time} min! Will the student survive?! 🔥',
        'What a DELIVERY! {subject} coming at you in {time} min! Be READY! 💥',
      ],
      danger: [
        '🚨 RED ALERT! {subject} at {pct}%! The team is COLLAPSING! Need {needed} more! 🏏💀',
        'WICKET DOWN! {subject}: {pct}%. This innings is in SERIOUS trouble! 😱',
        '{subject}: {pct}%. THE SCOREBOARD DOESN\'T LIE! Need {needed} classes to save the match! 🏏',
        'It\'s looking like a FOLLOW-ON situation! {subject}: {pct}%. FIGHT BACK! 💪',
      ],
      safe: [
        '{subject}: {pct}%! WHAT A KNOCK! {bunksLeft} runs in the bank! Champion! 🏆',
        'SOLID DEFENSE! {bunksLeft} bunks safe! The batsman is SET! 🏏',
        '{subject} at {pct}%. DOMINATING performance! Can afford a few dot balls! 😎',
      ],
      streak: [
        '🔥 {streak} MATCHES UNBEATEN! What a FORM this student is in!',
        '{streak}-day streak! SIXER AFTER SIXER! This student is ON FIRE! 🏏🔥',
        'UNBELIEVABLE! {streak} consecutive wins! The crowd goes WILD! 🎉',
      ],
      morning: [
        '🏏 MATCH DAY! {totalToday} games on the schedule! Let\'s GO! 🏟️',
        'TOSS WON! Today\'s playing XI has {totalToday} classes. Time to PERFORM!',
        'Good morning champion! {totalToday} innings today. Pad up! 🏏🔥',
      ],
    ),
    'chapri': const Persona(
      id: 'chapri',
      name: 'Hostel Bestie',
      icon: '🤙',
      desc: 'Your hostel bestie/NCR energy',
      classReminder: [
        'Bhai {subject} in {time} min. Block A mein milte hain, jaldi nikal! 🏃‍♂️',
        'Abe chal {subject} chal, prof system hang kar dega agar nahi aaya toh! 💀',
        'Bro {subject} shuru hone wala hai. Canteen mein kab tak baitha rahega? 🍟',
        '{subject} in {time} min bhai. Is baar proxy nahi lagegi, scene ho jayega! 😭',
        'Abe phone rakh aur {subject} ke liye nikal. Attendance ka kalesh mat kar ab 😤',
        'Bhai last bench reserved hai {subject} mein. Pari Chowk se nikal gaya kya? 😂',
      ],
      danger: [
        '💀 Bhai {subject}: {pct}%. Tera scene toh full tight hai. Class attend kar!',
        'Abe {subject} mein {pct}%?! Dean office se call aayega, attendance badha le! 😱',
        '{subject}: {pct}%. Bhai seriously, system phat jayega agar ab bunk kiya toh 💀',
        'Bro tera {subject} attendance dekh ke security guard bhi ro diya. {pct}% 😭',
      ],
      safe: [
        '{subject}: {pct}%. Bhai mast hai! Aaj toh cafeteria mein party karte hain 😎',
        'Bhai {bunksLeft} free bunks hain {subject} mein. Chal bakchodi karte hain kahin! 🍿',
        '{subject} mein tension nahi bhai. {bunksLeft} bunks baaki hain. Full mauj! 🤙',
      ],
      streak: [
        '🔥 Bhai {streak} din se class ja raha hai?! Kaunsi jadui shakti mil gayi? 😂',
        '{streak}-day streak bro! Tu toh GU ka naya topper banega kya? 🤓',
        'Abe {streak} din bina bunk?! Poore hostel mein tere charche hain bhai 😱',
      ],
      morning: [
        'Uth ja bhai ☀️ {totalToday} class hain aaj. Mess ka paratha kha aur nikal 🤙',
        'Good morning bro! {totalToday} lectures aaj. Neend mein proxy mat mangne lag jana 😂',
        'Bhai {totalToday} classes aaj. Sham ko Pari Chowk chalenge, abhi class chal 🍳',
      ],
    ),
    'motivational': const Persona(
      id: 'motivational',
      name: 'Motivational Guru',
      icon: '🦁',
      desc: 'LinkedIn hustle-bro vibes',
      classReminder: [
        '🦁 Lions don\'t skip {subject}. Class in {time} min. BE THE LION.',
        'While you hesitate, someone else is attending {subject}. {time} min. Rise. 🔥',
        '{subject} in {time} min. Your future self will thank you. Show up. 💪',
        'Discipline is doing what needs to be done. {subject} in {time} min. EXECUTE.',
        'Success isn\'t given, it\'s earned. One class at a time. {subject} in {time} min. 🏆',
        'The difference between you and a topper? They showed up. {subject} in {time} min. 📚',
      ],
      danger: [
        '⚠️ {subject}: {pct}%. Winners don\'t quit. You need {needed} more. DIG DEEP. 💪',
        'Your {subject} attendance is {pct}%. Champions face adversity HEAD ON. Go. 🦁',
        '{pct}% in {subject}. This is your COMEBACK arc. {needed} classes. Let\'s GO.',
        'Rock bottom is the foundation for greatness. {subject}: {pct}%. BUILD. 🔥',
      ],
      safe: [
        '{subject}: {pct}%. Solid. {bunksLeft} bunks available. But winners don\'t rest. 💪',
        'You\'re above 75% in {subject}. Good. Now aim for 90%. EXCELLENCE. 🦁',
        '{bunksLeft} safe bunks in {subject}. But ask yourself: What would a champion do? 🏆',
      ],
      streak: [
        '🔥 {streak}-DAY STREAK. This is what DISCIPLINE looks like. Keep going.',
        '{streak} days of showing up. You\'re becoming the person you were meant to be. 🦁',
        'Consistency is the mother of mastery. {streak} days. UNSTOPPABLE. 💪🔥',
      ],
      morning: [
        '🌅 New day. New opportunity. {totalToday} classes. DOMINATE.',
        'While others sleep, you RISE. {totalToday} classes today. Make each one count. 🦁',
        'Good morning, future topper. {totalToday} classes await. CONQUER THEM ALL. 💪',
      ],
    ),
    'prof': const Persona(
      id: 'prof',
      name: 'Passive-Aggressive Prof',
      icon: '🧑‍🏫',
      desc: 'Cold, calculated sarcasm',
      classReminder: [
        'I notice your seat in {subject} has been... vacant. Class in {time} min. 🧑‍🏫',
        '{subject} in {time} min. I\'ve prepared today\'s lecture just for the 12 students who show up.',
        'Interesting. My records show your {subject} attendance is {pct}%. Class in {time} min.',
        '{subject} in {time} min. I\'ll be marking attendance at the START. Just so you know.',
        'Oh, you\'re awake? {subject} in {time} min. What a pleasant surprise. 🙂',
        'Your {subject} presence has been... noted. Or rather, your absence. {time} min.',
      ],
      danger: [
        '{subject}: {pct}%. I\'ve forwarded the debar list to the Dean. No more proxy games. 📋',
        'Fascinating. {pct}% in {subject}. I admire your confidence in the end-sem exams. 🙂',
        '{needed} more classes needed in {subject}. Or you can find me in Block B office for "reasons." 🧑‍🏫',
        '{subject}: {pct}%. Your attendance is lower than the campus WiFi signal strength.',
      ],
      safe: [
        '{subject}: {pct}%. Acceptable. {bunksLeft} more absences permitted. I\'m watching. 👁️',
        '{bunksLeft} bunks remaining in {subject}. I do maintain very accurate records. 📊',
        'Your {subject} attendance of {pct}% is... adequate. I suppose. 🙂',
      ],
      streak: [
        '{streak} consecutive classes attended. I\'m cautiously optimistic. Very cautiously. 🧑‍🏫',
        'A {streak}-day streak. I\'ve alerted the department. This is unprecedented behavior. 😏',
        '{streak} days without absence. Have you considered that the exam is NEXT WEEK? 📚',
      ],
      morning: [
        'Good morning. {totalToday} classes today. I trust you\'ll grace us with your presence? 🧑‍🏫',
        '{totalToday} lectures today. I\'ve already taken note of which seats are typically empty.',
        'Ah, a new day. {totalToday} opportunities to prove you\'re enrolled in this university. 🙂',
      ],
    ),
  };

  // ===== CORE INITIALIZATION =====
  static Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    // Safely configure local timezone
    try {
      final dynamic tzInfo = await FlutterTimezone.getLocalTimezone();
      final String timeZoneName = tzInfo is String ? tzInfo : (tzInfo.identifier?.toString() ?? 'Asia/Kolkata');
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
      } catch (_) {
        tz.setLocalLocation(tz.UTC);
      }
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _plugin.initialize(initializationSettings);

    // Create Notification Channels for Android
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'bunk_guru_reminders',
            'Class Reminders',
            description: 'Meme-worthy reminders before your classes',
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
          ),
        );

        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'bunk_guru_morning',
            'Morning Briefing',
            description: 'Daily attendance summary with personality',
            importance: Importance.defaultImportance,
            playSound: true,
            enableVibration: false,
          ),
        );
      }
    }

    _initialized = true;

    // Reschedule if enabled — but first ensure we have OS-level permission.
    // Without this, zonedSchedule silently does nothing on Android 13+.
    if (LocalStorageService.isNotificationEnabled) {
      try {
        await requestPermission();
        await scheduleAll();
      } catch (e) {
        // Suppress and log error to avoid locking up application startup
        debugPrint('NotificationService: Failed to reschedule on startup: $e');
      }
    }
  }

  // ===== PERMISSION GATES =====
  static Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        // Request POST_NOTIFICATIONS permission (Android 13+)
        final bool? granted = await androidPlugin.requestNotificationsPermission();
        if (granted != true) return false;

        // Request exact alarm permission (Android 12+)
        // Without this, zonedSchedule with exactAllowWhileIdle silently fails
        try {
          final bool? exactAlarmGranted = await androidPlugin.requestExactAlarmsPermission();
          _exactAlarmGranted = exactAlarmGranted == true;
          if (!_exactAlarmGranted) {
            debugPrint('NotificationService: Exact alarm permission not granted, will use inexact scheduling');
          }
        } catch (e) {
          _exactAlarmGranted = false;
          debugPrint('NotificationService: requestExactAlarmsPermission error: $e');
        }

        return true;
      }
    } else if (Platform.isIOS) {
      final bool? granted = await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      return granted ?? false;
    }
    return true;
  }

  // ===== TEST NOTIFICATION =====
  static Future<void> showTestNotification({String? personaId}) async {
    await init();
    await requestPermission();

    final String activePersonaId = personaId ?? LocalStorageService.notificationPersona;
    final Persona persona = personas[activePersonaId] ?? personas['chapri']!;

    final String? body = _generateMessage(
      persona,
      'classReminder',
      subject: 'Data Structures',
      pct: '76.5',
      bunksLeft: 3,
      needed: 2,
      time: 15,
      streak: 4,
      totalToday: 4,
    );

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'bunk_guru_reminders',
      'Class Reminders',
      channelDescription: 'Meme-worthy reminders before your classes',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _plugin.show(
      9999,
      '${persona.icon} 📚 Data Structures in 15m',
      body ?? 'Sharma ji ka beta already seated. Class in 15 min!',
      platformChannelSpecifics,
    );
  }

  // ===== CANCEL ALL SCHEDULINGS =====
  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  // ===== TIME PARSER HELPER =====
  static (int, int)? _parseTimeString(String timeStr) {
    try {
      final clean = timeStr.trim().toLowerCase();
      final bool isPM = clean.contains('pm');
      final bool isAM = clean.contains('am');

      // Strip any non-digit/colon characters
      final digitsColonOnly = clean.replaceAll(RegExp(r'[^0-9:]'), '');
      final parts = digitsColonOnly.split(':');
      if (parts.isEmpty || parts[0].isEmpty) return null;

      int hour = int.parse(parts[0]);
      int minute = parts.length > 1 && parts[1].isNotEmpty ? int.parse(parts[1]) : 0;

      if (isPM && hour < 12) {
        hour += 12;
      } else if (isAM && hour == 12) {
        hour = 0;
      }

      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
      return (hour, minute);
    } catch (_) {
      return null;
    }
  }

  // ===== SCHEDULER ENGINE =====
  static Future<void> scheduleAll() async {
    try {
      // CRITICAL: Ensure plugin is initialized before scheduling.
      // If init() failed at app startup (swallowed by try-catch in main.dart),
      // _plugin won't be initialized and all zonedSchedule calls will silently fail.
      if (!_initialized) {
        debugPrint('NotificationService: Plugin not initialized, calling init()...');
        await init();
      }

      if (!LocalStorageService.isNotificationEnabled) {
        debugPrint('NotificationService: Notifications disabled, skipping scheduleAll');
        return;
      }

      final List<Subject> subjects = LocalStorageService.getSubjects();
      final List<ScheduleSlot> schedule = LocalStorageService.getScheduleSlots();

      if (subjects.isEmpty || schedule.isEmpty) {
        debugPrint('NotificationService: No data to schedule — subjects: ${subjects.length}, slots: ${schedule.length}');
        return;
      }

      // Only cancel AFTER we've confirmed there's data to reschedule with.
      // Previously, cancelAll() was called first, so if subjects/schedule were
      // empty, all existing notifications would be wiped with nothing to replace them.
      await cancelAll();

      final int streak = _calculateStreak();
      final String activePersonaId = LocalStorageService.notificationPersona;
      final Persona persona = personas[activePersonaId] ?? personas['chapri']!;

      final DateTime now = DateTime.now();
      int idCounter = 1000;
      int scheduledCount = 0;
      int skippedPast = 0;
      int skippedParseFail = 0;
      int skippedNoSubject = 0;

      // Schedule class reminders for next 7 days
      for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
        final DateTime targetDate = now.add(Duration(days: dayOffset));
        final int targetDayOfWeek = (targetDate.weekday - 1) % 7; // 0 = Monday, 6 = Sunday

        // Filter slots that occur on targetDayOfWeek
        final List<ScheduleSlot> daySlots =
            schedule.where((s) => s.dayOfWeek == targetDayOfWeek).toList();

        for (final slot in daySlots) {
          try {
            final subjectIdx = subjects.indexWhere((s) => s.id == slot.subjectId);
            if (subjectIdx == -1) {
              skippedNoSubject++;
              continue;
            }
            final subject = subjects[subjectIdx];

            // Parse slot time with robust helper
            final parsedTime = _parseTimeString(slot.time);
            if (parsedTime == null) {
              skippedParseFail++;
              debugPrint('NotificationService: Failed to parse time "${slot.time}" for ${subject.name}');
              continue;
            }
            final int hour = parsedTime.$1;
            final int minute = parsedTime.$2;

            final DateTime slotDateTime = DateTime(
              targetDate.year,
              targetDate.month,
              targetDate.day,
              hour,
              minute,
            );

            // Schedule reminder 15 minutes before the class
            final DateTime reminderDateTime =
                slotDateTime.subtract(const Duration(minutes: 15));

            // Skip reminders in the past
            if (reminderDateTime.isBefore(now)) {
              skippedPast++;
              continue;
            }

            // Calculate math values
            final int totalA = subject.isPracticalOnly
                ? subject.practicalAttended
                : (subject.attendedClasses + (subject.hasPractical ? subject.practicalAttended : 0));
            final int totalT = subject.isPracticalOnly
                ? subject.practicalTotal
                : (subject.totalClasses + (subject.hasPractical ? subject.practicalTotal : 0));

            final double pct = AttendanceMath.currentPercent(totalA, totalT);
            final AttendanceStatus status = AttendanceMath.getStatus(totalA, totalT);
            final int bunksLeft = AttendanceMath.safeBunks(totalA, totalT);
            final int needed = AttendanceMath.requiredClasses(totalA, totalT);

            // Choose message template type
            String msgType = 'classReminder';
            if (status == AttendanceStatus.danger) {
              msgType = 'danger';
            } else if (bunksLeft <= 2 && status == AttendanceStatus.warning) {
              msgType = 'danger';
            } else if (status == AttendanceStatus.safe) {
              // 30% chance to remind of safe bunks instead of generic reminder
              if (Random().nextDouble() < 0.3) {
                msgType = 'safe';
              }
            }

            final String? body = _generateMessage(
              persona,
              msgType,
              subject: subject.name,
              pct: pct.toStringAsFixed(1),
              bunksLeft: bunksLeft,
              needed: needed,
              time: 15,
              streak: streak,
              totalToday: daySlots.length,
            );

            if (body != null) {
              final tz.TZDateTime scheduledTZDate =
                  tz.TZDateTime.from(reminderDateTime, tz.local);

              final int currentId = idCounter++;
              final bool scheduled = await _scheduleNotification(
                id: currentId,
                title: '📚 ${subject.name}',
                body: body,
                scheduledDate: scheduledTZDate,
                channelId: 'bunk_guru_reminders',
                channelName: 'Class Reminders',
                channelDesc: 'Meme-worthy reminders before your classes',
                highPriority: true,
              );
              if (scheduled) scheduledCount++;
            }
          } catch (slotError) {
            debugPrint('NotificationService: Error scheduling for slot ${slot.id}: $slotError');
          }
        }
      }

      // Schedule morning summary at 8:00 AM daily for the next 7 days
      if (LocalStorageService.isMorningBriefingEnabled) {
        for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
          try {
            final DateTime targetDate = now.add(Duration(days: dayOffset));
            final DateTime morningTime = DateTime(
              targetDate.year,
              targetDate.month,
              targetDate.day,
              8, // 8:00 AM
              0,
            );

            if (morningTime.isBefore(now)) continue;

            final int targetDayOfWeek = (targetDate.weekday - 1) % 7;
            final List<ScheduleSlot> daySlots =
                schedule.where((s) => s.dayOfWeek == targetDayOfWeek).toList();

            // Skip if no classes scheduled today
            if (daySlots.isEmpty) continue;

            final String? body = _generateMessage(
              persona,
              'morning',
              totalToday: daySlots.length,
              streak: streak,
            );

            if (body != null) {
              final tz.TZDateTime scheduledTZDate =
                  tz.TZDateTime.from(morningTime, tz.local);

              final int currentMorningId = idCounter++;
              final bool scheduled = await _scheduleNotification(
                id: currentMorningId,
                title: '🌅 Bunk Guru — Daily Briefing',
                body: body,
                scheduledDate: scheduledTZDate,
                channelId: 'bunk_guru_morning',
                channelName: 'Morning Briefing',
                channelDesc: 'Daily attendance summary with personality',
                highPriority: false,
              );
              if (scheduled) scheduledCount++;
            }
          } catch (morningError) {
            debugPrint('NotificationService: Error scheduling morning briefing for dayOffset $dayOffset: $morningError');
          }
        }
      }

      debugPrint('NotificationService: scheduleAll complete — '
          'scheduled: $scheduledCount, '
          'skippedPast: $skippedPast, '
          'skippedParseFail: $skippedParseFail, '
          'skippedNoSubject: $skippedNoSubject');
    } catch (globalError) {
      debugPrint('NotificationService: CRITICAL global error in scheduleAll: $globalError');
    }
  }

  /// Helper to schedule a single notification with exact → inexact fallback.
  static Future<bool> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required String channelId,
    required String channelName,
    required String channelDesc,
    required bool highPriority,
  }) async {
    final notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDesc,
        importance: highPriority ? Importance.high : Importance.defaultImportance,
        priority: highPriority ? Priority.high : Priority.defaultPriority,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
      ),
    );

    // Use exact scheduling only when we know the permission was granted.
    // On Android 12+, using exactAllowWhileIdle without the permission
    // causes zonedSchedule to silently do nothing on many OEMs.
    final AndroidScheduleMode scheduleMode = _exactAlarmGranted
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        notificationDetails,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: scheduleMode,
      );
      return true;
    } catch (e) {
      debugPrint('NotificationService: zonedSchedule failed (id=$id, mode=$scheduleMode): $e');
      // If exact failed, try inexact as a last resort
      if (scheduleMode == AndroidScheduleMode.exactAllowWhileIdle) {
        try {
          await _plugin.zonedSchedule(
            id,
            title,
            body,
            scheduledDate,
            notificationDetails,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          );
          _exactAlarmGranted = false; // Remember for future calls in this session
          return true;
        } catch (fallbackError) {
          debugPrint('NotificationService: BOTH exact and inexact scheduling failed (id=$id): $fallbackError');
          return false;
        }
      }
      return false;
    }
  }

  /// Call this when app resumes from background to keep notifications fresh.
  static Future<void> rescheduleIfNeeded() async {
    if (!LocalStorageService.isNotificationEnabled) return;
    try {
      await scheduleAll();
    } catch (e) {
      debugPrint('NotificationService: rescheduleIfNeeded failed: $e');
    }
  }

  // ===== GENERATE PREVIEW MESSAGE FOR UI =====
  static String previewMessage(String personaId, String type) {
    final Persona persona = personas[personaId] ?? personas['chapri']!;
    return _generateMessage(
          persona,
          type,
          subject: 'Data Structures',
          pct: '76.5',
          bunksLeft: 3,
          needed: 2,
          time: 15,
          streak: 4,
          totalToday: 4,
        ) ??
        '';
  }

  // ===== HELPER METHODS =====
  static String? _generateMessage(
    Persona persona,
    String type, {
    String subject = '',
    String pct = '0',
    int bunksLeft = 0,
    int needed = 0,
    int time = 15,
    int streak = 0,
    int totalToday = 0,
  }) {
    List<String> templates;
    switch (type) {
      case 'classReminder':
        templates = persona.classReminder;
        break;
      case 'danger':
        templates = persona.danger;
        break;
      case 'safe':
        templates = persona.safe;
        break;
      case 'streak':
        templates = persona.streak;
        break;
      case 'morning':
        templates = persona.morning;
        break;
      default:
        templates = persona.classReminder;
    }

    if (templates.isEmpty) return null;
    final String template = templates[Random().nextInt(templates.length)];

    return template
        .replaceAll('{subject}', subject)
        .replaceAll('{pct}', pct)
        .replaceAll('{bunksLeft}', bunksLeft.toString())
        .replaceAll('{needed}', needed.toString())
        .replaceAll('{time}', time.toString())
        .replaceAll('{streak}', streak.toString())
        .replaceAll('{totalToday}', totalToday.toString());
  }

  static int _calculateStreak() {
    final Map<String, Map<String, AttendanceResponse>> allResponses =
        LocalStorageService.getResponses();
    final List<String> sortedDates = allResponses.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // Sort in reverse chronological order
    
    int streak = 0;

    for (final date in sortedDates) {
      final Map<String, AttendanceResponse> dayResponses = allResponses[date] ?? {};
      if (dayResponses.isEmpty) continue;

      // Check if all lectures that happened on that day were attended
      final bool allAttended = dayResponses.values.every(
        (r) => !r.lectureHappened || r.attended,
      );

      if (allAttended) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }
}
