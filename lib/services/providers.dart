import 'dart:async';
import 'dart:math';
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

  void setLocalState(List<Subject> subjects) {
    state = subjects;
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
    final String tempId = 'local_${Random().nextInt(100000)}';
    final tempSubject = Subject(
      id: tempId,
      userId: SupabaseService.currentUser?.id ?? 'demo',
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
      createdAt: DateTime.now().toIso8601String(),
      isPending: true,
    );

    // 1. Instant optimistic UI update (0ms)
    state = [...state, tempSubject];

    // 2. Background sync
    try {
      final synced = await SupabaseService.addSubject(
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
      state = state.map((s) => s.id == tempId ? synced : s).toList();
    } catch (_) {
      refresh();
      rethrow;
    }
  }

  Future<void> update(String id, Map<String, dynamic> updates) async {
    // 1. Instant optimistic UI update (0ms)
    final idx = state.indexWhere((s) => s.id == id);
    if (idx != -1) {
      final updated = state[idx].copyWith(
        name: updates['name'],
        professor: updates['professor'],
        totalClasses: updates['total_classes'],
        attendedClasses: updates['attended_classes'],
        hasPractical: updates['has_practical'],
        isPracticalOnly: updates['is_practical_only'],
        practicalTotal: updates['practical_total'],
        practicalAttended: updates['practical_attended'],
        icon: updates['icon'],
        color: updates['color'],
      );
      final newList = List<Subject>.from(state);
      newList[idx] = updated;
      state = newList;
    }

    // 2. Background sync
    unawaited(SupabaseService.updateSubject(id, updates).catchError((_) {
      refresh();
      return null;
    }));
  }

  Future<void> delete(String id) async {
    // 1. Instant optimistic UI removal (0ms)
    state = state.where((s) => s.id != id).toList();
    ref.read(scheduleProvider.notifier).removeBySubjectId(id);

    // 2. Background sync
    unawaited(SupabaseService.deleteSubject(id).catchError((_) {
      refresh();
      ref.read(scheduleProvider.notifier).refresh();
    }));
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

  void removeBySubjectId(String subjectId) {
    state = state.where((s) => s.subjectId != subjectId).toList();
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
    final String tempId = 'local_${Random().nextInt(100000)}';
    final tempSlot = ScheduleSlot(
      id: tempId,
      userId: SupabaseService.currentUser?.id ?? 'demo',
      subjectId: subjectId,
      dayOfWeek: dayOfWeek,
      time: time,
      endTime: endTime,
      slotType: slotType,
      room: room,
      createdAt: DateTime.now().toIso8601String(),
      isPending: true,
    );

    // 1. Instant optimistic UI update (0ms)
    state = [...state, tempSlot];
    if (LocalStorageService.isNotificationEnabled) {
      NotificationService.scheduleAll();
    }

    // 2. Background sync
    try {
      final synced = await SupabaseService.addScheduleSlot(
        subjectId: subjectId,
        dayOfWeek: dayOfWeek,
        time: time,
        endTime: endTime,
        slotType: slotType,
        room: room,
      );
      state = state.map((s) => s.id == tempId ? synced : s).toList();
    } catch (_) {
      refresh();
      rethrow;
    }
  }

  Future<void> update(String id, Map<String, dynamic> updates) async {
    // 1. Instant optimistic UI update (0ms)
    final idx = state.indexWhere((s) => s.id == id);
    if (idx != -1) {
      final updated = state[idx].copyWith(
        subjectId: updates['subject_id'],
        dayOfWeek: updates['day_of_week'],
        time: updates['time'],
        endTime: updates['end_time'],
        slotType: updates['slot_type'],
        room: updates['room'],
      );
      final newList = List<ScheduleSlot>.from(state);
      newList[idx] = updated;
      state = newList;
      if (LocalStorageService.isNotificationEnabled) {
        NotificationService.scheduleAll();
      }
    }

    // 2. Background sync
    unawaited(SupabaseService.updateScheduleSlot(id, updates).catchError((_) {
      refresh();
      return null;
    }));
  }

  Future<void> delete(String id) async {
    // 1. Instant optimistic UI removal (0ms)
    state = state.where((s) => s.id != id).toList();
    if (LocalStorageService.isNotificationEnabled) {
      NotificationService.scheduleAll();
    }

    // 2. Background sync
    unawaited(SupabaseService.deleteScheduleSlot(id).catchError((_) {
      refresh();
    }));
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
    // 1. Optimistic response update in memory (0ms)
    final todayKey = SupabaseService.todayKey();
    final updatedResponses = Map<String, Map<String, AttendanceResponse>>.from(state);
    if (!updatedResponses.containsKey(todayKey)) {
      updatedResponses[todayKey] = {};
    } else {
      updatedResponses[todayKey] = Map<String, AttendanceResponse>.from(updatedResponses[todayKey]!);
    }

    final newResp = AttendanceResponse(
      id: 'local_${Random().nextInt(100000)}',
      userId: SupabaseService.currentUser?.id ?? 'demo',
      slotId: slotId,
      date: todayKey,
      lectureHappened: lectureHappened,
      attended: attended,
      createdAt: DateTime.now().toIso8601String(),
    );
    updatedResponses[todayKey]![slotId] = newResp;
    state = updatedResponses;

    // 2. Optimistic subject counter update in memory (0ms)
    if (lectureHappened) {
      final allSlots = ref.read(scheduleProvider);
      final slotIdx = allSlots.indexWhere((s) => s.id == slotId);
      if (slotIdx != -1) {
        final slot = allSlots[slotIdx];
        final subjects = ref.read(subjectProvider);
        final sIdx = subjects.indexWhere((s) => s.id == slot.subjectId);
        if (sIdx != -1) {
          final sub = subjects[sIdx];
          final bool isPractical = slot.slotType == 'practical' || sub.isPracticalOnly;
          final updatedSub = isPractical
              ? sub.copyWith(
                  hasPractical: true,
                  practicalTotal: sub.practicalTotal + 1,
                  practicalAttended: sub.practicalAttended + (attended ? 1 : 0),
                )
              : sub.copyWith(
                  totalClasses: sub.totalClasses + 1,
                  attendedClasses: sub.attendedClasses + (attended ? 1 : 0),
                );
          final updatedSubs = List<Subject>.from(subjects);
          updatedSubs[sIdx] = updatedSub;
          ref.read(subjectProvider.notifier).setLocalState(updatedSubs);
        }
      }
    }

    // 3. Background sync to local storage & Supabase
    unawaited(SupabaseService.respondToSlot(
      slotId: slotId,
      lectureHappened: lectureHappened,
      attended: attended,
    ).catchError((_) {
      refresh();
      ref.read(subjectProvider.notifier).refresh();
    }));

    // 4. Reschedule notifications — attendance changed, so danger/safe
    //    levels and persona messages need to be recalculated.
    if (LocalStorageService.isNotificationEnabled) {
      NotificationService.scheduleAll();
    }
  }

  Future<void> respondMultiple({
    required List<String> slotIds,
    required bool lectureHappened,
    required bool attended,
  }) async {
    if (slotIds.isEmpty) return;

    // 1. Optimistic response update in memory (0ms)
    final todayKey = SupabaseService.todayKey();
    final updatedResponses = Map<String, Map<String, AttendanceResponse>>.from(state);
    if (!updatedResponses.containsKey(todayKey)) {
      updatedResponses[todayKey] = {};
    } else {
      updatedResponses[todayKey] = Map<String, AttendanceResponse>.from(updatedResponses[todayKey]!);
    }

    for (final slotId in slotIds) {
      updatedResponses[todayKey]![slotId] = AttendanceResponse(
        id: 'local_${Random().nextInt(100000)}',
        userId: SupabaseService.currentUser?.id ?? 'demo',
        slotId: slotId,
        date: todayKey,
        lectureHappened: lectureHappened,
        attended: attended,
        createdAt: DateTime.now().toIso8601String(),
      );
    }
    state = updatedResponses;

    // 2. Optimistic subject counters update for all affected slots (0ms)
    if (lectureHappened) {
      final allSlots = ref.read(scheduleProvider);
      final subjects = List<Subject>.from(ref.read(subjectProvider));

      for (final slotId in slotIds) {
        final slotIdx = allSlots.indexWhere((s) => s.id == slotId);
        if (slotIdx == -1) continue;
        final slot = allSlots[slotIdx];

        final sIdx = subjects.indexWhere((s) => s.id == slot.subjectId);
        if (sIdx == -1) continue;

        final sub = subjects[sIdx];
        final bool isPractical = slot.slotType == 'practical' || sub.isPracticalOnly;
        subjects[sIdx] = isPractical
            ? sub.copyWith(
                hasPractical: true,
                practicalTotal: sub.practicalTotal + 1,
                practicalAttended: sub.practicalAttended + (attended ? 1 : 0),
              )
            : sub.copyWith(
                totalClasses: sub.totalClasses + 1,
                attendedClasses: sub.attendedClasses + (attended ? 1 : 0),
              );
      }
      ref.read(subjectProvider.notifier).setLocalState(subjects);
    }

    // 3. Batched background sync
    unawaited(SupabaseService.respondMultipleSlots(
      slotIds: slotIds,
      lectureHappened: lectureHappened,
      attended: attended,
    ).catchError((_) {
      refresh();
      ref.read(subjectProvider.notifier).refresh();
    }));

    // 4. Reschedule notifications — attendance changed, so danger/safe
    //    levels and persona messages need to be recalculated.
    if (LocalStorageService.isNotificationEnabled) {
      NotificationService.scheduleAll();
    }
  }

  Future<void> update({
    required String date,
    required String slotId,
    required AttendanceResponse? oldResponse,
    required AttendanceResponse newResponse,
  }) async {
    // 1. Optimistic response update in memory (0ms)
    final updatedResponses = Map<String, Map<String, AttendanceResponse>>.from(state);
    if (!updatedResponses.containsKey(date)) {
      updatedResponses[date] = {};
    } else {
      updatedResponses[date] = Map<String, AttendanceResponse>.from(updatedResponses[date]!);
    }
    updatedResponses[date]![slotId] = newResponse;
    state = updatedResponses;

    // 2. Background sync
    unawaited(SupabaseService.updateResponse(
      date: date,
      slotId: slotId,
      oldResponse: oldResponse,
      newResponse: newResponse,
    ).then((_) {
      ref.read(subjectProvider.notifier).refresh();
    }).catchError((_) {
      refresh();
      ref.read(subjectProvider.notifier).refresh();
    }));
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
