import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/profile.dart';
import '../../models/subject.dart';
import '../../models/schedule_slot.dart';
import '../../models/attendance_response.dart';

class LocalStorageService {
  static late final SharedPreferences _prefs;

  static const String keySubjects = 'bm_subjects';
  static const String keySchedule = 'bm_schedule';
  static const String keyProfile = 'bm_profile';
  static const String keyResponses = 'bm_responses';
  static const String keySeeded = 'bm_seeded';
  static const String keyDarkMode = 'bm_dark_mode';
  static const String keyLastSync = 'bm_last_sync';
  
  // Notification configurations
  static const String keyNotifEnabled = 'bm_notif_enabled';
  static const String keyNotifPersona = 'bm_notif_persona';
  static const String keyNotifMorning = 'bm_notif_morning';

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Seeding flag
  static bool get isSeeded => _prefs.getBool(keySeeded) ?? false;
  static Future<void> setSeeded(bool val) async => await _prefs.setBool(keySeeded, val);

  // Dark mode flag
  static bool get isDarkMode => _prefs.getBool(keyDarkMode) ?? false;
  static Future<void> setDarkMode(bool val) async => await _prefs.setBool(keyDarkMode, val);

  // Sync timing
  static int get lastSync => _prefs.getInt(keyLastSync) ?? 0;
  static Future<void> setLastSync(int val) async => await _prefs.setInt(keyLastSync, val);

  // Notification toggles
  static bool get isNotificationEnabled => _prefs.getBool(keyNotifEnabled) ?? false;
  static Future<void> setNotificationEnabled(bool val) async => await _prefs.setBool(keyNotifEnabled, val);

  static String get notificationPersona => _prefs.getString(keyNotifPersona) ?? 'chapri';
  static Future<void> setNotificationPersona(String persona) async => await _prefs.setString(keyNotifPersona, persona);

  static bool get isMorningBriefingEnabled => _prefs.getBool(keyNotifMorning) ?? true;
  static Future<void> setMorningBriefingEnabled(bool val) async => await _prefs.setBool(keyNotifMorning, val);

  // Profiles
  static Profile? getProfile() {
    final String? data = _prefs.getString(keyProfile);
    if (data == null) return null;
    try {
      return Profile.fromJson(jsonDecode(data));
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveProfile(Profile profile) async {
    await _prefs.setString(keyProfile, jsonEncode(profile.toJson()));
  }

  // Subjects
  static List<Subject> getSubjects() {
    final String? data = _prefs.getString(keySubjects);
    if (data == null) return [];
    try {
      final List<dynamic> list = jsonDecode(data);
      return list.map((item) => Subject.fromJson(item)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveSubjects(List<Subject> subjects) async {
    final List<Map<String, dynamic>> mapped = subjects.map((s) => s.toJson()).toList();
    await _prefs.setString(keySubjects, jsonEncode(mapped));
  }

  // Schedule Slots
  static List<ScheduleSlot> getScheduleSlots() {
    final String? data = _prefs.getString(keySchedule);
    if (data == null) return [];
    try {
      final List<dynamic> list = jsonDecode(data);
      return list.map((item) => ScheduleSlot.fromJson(item)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveScheduleSlots(List<ScheduleSlot> slots) async {
    final List<Map<String, dynamic>> mapped = slots.map((s) => s.toJson()).toList();
    await _prefs.setString(keySchedule, jsonEncode(mapped));
  }

  // Attendance Responses
  // Structure: YYYY-MM-DD -> slot_id -> AttendanceResponse
  static Map<String, Map<String, AttendanceResponse>> getResponses() {
    final String? data = _prefs.getString(keyResponses);
    if (data == null) return {};
    try {
      final Map<String, dynamic> rawMap = jsonDecode(data);
      final Map<String, Map<String, AttendanceResponse>> result = {};
      
      rawMap.forEach((dateKey, value) {
        final Map<String, dynamic> rawSubMap = value;
        final Map<String, AttendanceResponse> subMap = {};
        rawSubMap.forEach((slotId, respJson) {
          subMap[slotId] = AttendanceResponse.fromJson(respJson);
        });
        result[dateKey] = subMap;
      });
      return result;
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveResponses(Map<String, Map<String, AttendanceResponse>> responses) async {
    final Map<String, Map<String, dynamic>> mapped = {};
    responses.forEach((dateKey, subMap) {
      final Map<String, dynamic> mappedSub = {};
      subMap.forEach((slotId, resp) {
        mappedSub[slotId] = resp.toJson();
      });
      mapped[dateKey] = mappedSub;
    });
    await _prefs.setString(keyResponses, jsonEncode(mapped));
  }

  static Future<void> clearAll() async {
    await _prefs.clear();
  }
}
