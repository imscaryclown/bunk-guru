import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/database/local_storage_service.dart';
import '../models/profile.dart';
import '../models/subject.dart';
import '../models/schedule_slot.dart';
import '../models/attendance_response.dart';
import '../features/notifications/services/notification_service.dart';
import 'supabase_service.dart';

// ===== AUTH PROVIDER =====

class AuthNotifier extends StateNotifier<User?> {
  final Ref ref;

  AuthNotifier(this.ref) : super(SupabaseService.currentUser) {
    // Listen for session alterations
    SupabaseService.client.auth.onAuthStateChange.listen((data) {
      state = data.session?.user ?? SupabaseService.currentUser;
      if (data.event == AuthChangeEvent.signedIn) {
        // Trigger background sync on switch account
        SupabaseService.syncFromCloud(true).then((_) {
          // Notify profile updates
          ref.read(profileProvider.notifier).refresh();
          ref.read(subjectProvider.notifier).refresh();
          ref.read(scheduleProvider.notifier).refresh();
          ref.read(responseProvider.notifier).refresh();
          if (LocalStorageService.isNotificationEnabled) {
            NotificationService.scheduleAll();
          }
        }).catchError((e) {
          print('Sync error on login: $e');
          return null;
        });
      }
    });
  }

  Future<void> signIn(String email, String password) async {
    await SupabaseService.signInWithEmail(email, password);
    state = SupabaseService.currentUser;
  }

  Future<void> signUp(String email, String password, String name) async {
    await SupabaseService.signUp(email, password, name);
  }

  Future<void> resetPassword(String email) async {
    await SupabaseService.resetPassword(email);
  }

  Future<void> signOut() async {
    await SupabaseService.signOut();
    state = null;
    ref.read(profileProvider.notifier).clear();
    ref.read(subjectProvider.notifier).clear();
    ref.read(scheduleProvider.notifier).clear();
    ref.read(responseProvider.notifier).clear();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, User?>((ref) {
  return AuthNotifier(ref);
});

// ===== PROFILE PROVIDER =====

class ProfileNotifier extends StateNotifier<Profile?> {
  ProfileNotifier() : super(LocalStorageService.getProfile());

  void refresh() {
    state = LocalStorageService.getProfile();
  }

  void clear() {
    state = null;
  }

  Future<void> update({
    String? displayName,
    String? department,
    String? university,
    String? year,
    String? avatarUrl,
  }) async {
    final updated = await SupabaseService.updateProfile(
      displayName: displayName,
      department: department,
      university: university,
      year: year,
      avatarUrl: avatarUrl,
    );
    state = updated;
  }
}

final profileProvider = StateNotifierProvider<ProfileNotifier, Profile?>((ref) {
  return ProfileNotifier();
});

// ===== SUBJECT PROVIDER =====

class SubjectNotifier extends StateNotifier<List<Subject>> {
  final Ref ref;

  SubjectNotifier(this.ref) : super(LocalStorageService.getSubjects());

  void refresh() {
    state = LocalStorageService.getSubjects();
  }

  void clear() {
    state = [];
  }

  Future<void> add({
    required String name,
    String professor = '',
    int totalClasses = 0,
    int attendedClasses = 0,
    bool hasPractical = false,
    bool isPracticalOnly = false,
    int practicalTotal = 0,
    int practicalAttended = 0,
    String icon = 'school',
    String color = 'primary',
  }) async {
    await SupabaseService.addSubject(
      name: name,
      professor: professor,
      totalClasses: totalClasses,
      attendedClasses: attendedClasses,
      hasPractical: hasPractical,
      isPracticalOnly: isPracticalOnly,
      practicalTotal: practicalTotal,
      practicalAttended: practicalAttended,
      icon: icon,
      color: color,
    );
    refresh();
  }

  Future<void> update(String id, Map<String, dynamic> updates) async {
    await SupabaseService.updateSubject(id, updates);
    refresh();
  }

  Future<void> delete(String id) async {
    await SupabaseService.deleteSubject(id);
    refresh();
    ref.read(scheduleProvider.notifier).refresh();
  }
}

final subjectProvider = StateNotifierProvider<SubjectNotifier, List<Subject>>((ref) {
  return SubjectNotifier(ref);
});

// ===== SCHEDULE SLOT PROVIDER =====

class ScheduleNotifier extends StateNotifier<List<ScheduleSlot>> {
  ScheduleNotifier() : super(LocalStorageService.getScheduleSlots());

  void refresh() {
    state = LocalStorageService.getScheduleSlots();
    if (LocalStorageService.isNotificationEnabled) {
      NotificationService.scheduleAll();
    }
  }

  void clear() {
    state = [];
    if (LocalStorageService.isNotificationEnabled) {
      NotificationService.scheduleAll();
    }
  }

  Future<void> add({
    required String subjectId,
    required int dayOfWeek,
    String time = '09:00',
    String endTime = '10:00',
    String slotType = 'theory',
    String room = '',
  }) async {
    await SupabaseService.addScheduleSlot(
      subjectId: subjectId,
      dayOfWeek: dayOfWeek,
      time: time,
      endTime: endTime,
      slotType: slotType,
      room: room,
    );
    refresh();
  }

  Future<void> update(String id, Map<String, dynamic> updates) async {
    await SupabaseService.updateScheduleSlot(id, updates);
    refresh();
  }

  Future<void> delete(String id) async {
    await SupabaseService.deleteScheduleSlot(id);
    refresh();
  }
}

final scheduleProvider = StateNotifierProvider<ScheduleNotifier, List<ScheduleSlot>>((ref) {
  return ScheduleNotifier();
});

// ===== ATTENDANCE RESPONSE PROVIDER =====

class ResponseNotifier extends StateNotifier<Map<String, Map<String, AttendanceResponse>>> {
  final Ref ref;

  ResponseNotifier(this.ref) : super(LocalStorageService.getResponses());

  void refresh() {
    state = LocalStorageService.getResponses();
  }

  void clear() {
    state = {};
  }

  Future<void> respond({
    required String slotId,
    required bool lectureHappened,
    required bool attended,
  }) async {
    await SupabaseService.respondToSlot(
      slotId: slotId,
      lectureHappened: lectureHappened,
      attended: attended,
    );
    refresh();
    ref.read(subjectProvider.notifier).refresh(); // Sync subject stats
  }

  Future<void> respondMultiple({
    required List<String> slotIds,
    required bool lectureHappened,
    required bool attended,
  }) async {
    for (final slotId in slotIds) {
      await SupabaseService.respondToSlot(
        slotId: slotId,
        lectureHappened: lectureHappened,
        attended: attended,
      );
    }
    refresh();
    ref.read(subjectProvider.notifier).refresh(); // Sync subject stats
  }

  Future<void> update({
    required String date,
    required String slotId,
    required AttendanceResponse? oldResponse,
    required AttendanceResponse newResponse,
  }) async {
    await SupabaseService.updateResponse(
      date: date,
      slotId: slotId,
      oldResponse: oldResponse,
      newResponse: newResponse,
    );
    refresh();
    ref.read(subjectProvider.notifier).refresh(); // Sync subject stats
  }
}

final responseProvider = StateNotifierProvider<ResponseNotifier, Map<String, Map<String, AttendanceResponse>>>((ref) {
  return ResponseNotifier(ref);
});

// ===== SYNC STATE PROVIDER =====
class SyncNotifier extends StateNotifier<bool> {
  SyncNotifier() : super(SupabaseService.syncNotifier.value) {
    SupabaseService.syncNotifier.addListener(() {
      state = SupabaseService.syncNotifier.value;
    });
  }
}

final syncProvider = StateNotifierProvider<SyncNotifier, bool>((ref) {
  return SyncNotifier();
});

// ===== THEME MODE PROVIDER =====
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(LocalStorageService.isDarkMode ? ThemeMode.dark : ThemeMode.light);

  void toggleTheme() {
    if (state == ThemeMode.dark) {
      state = ThemeMode.light;
      LocalStorageService.setDarkMode(false);
    } else {
      state = ThemeMode.dark;
      LocalStorageService.setDarkMode(true);
    }
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

// ===== TAB INDEX PROVIDER =====
final tabIndexProvider = StateProvider<int>((ref) => 0);
