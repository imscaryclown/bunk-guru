import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/database/local_storage_service.dart';
import '../models/profile.dart';
import '../models/subject.dart';
import '../models/schedule_slot.dart';
import '../models/attendance_response.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://iaiklxwrxfnwjjlhkxcr.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlhaWtseHdyeGZud2pqbGhreGNyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc4MTMwNjMsImV4cCI6MjA5MzM4OTA2M30.ermjH8movGuekmEB0xc6ZD8DRm9v_G3TOUxD-HifSfg';

  static final SupabaseClient client = Supabase.instance.client;
  static final ValueNotifier<bool> syncNotifier = ValueNotifier<bool>(false);

  static Future<void> init() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  // ===== AUTH OPERATIONS =====
  
  static User? get currentUser => client.auth.currentUser;

  static bool get isAuthenticated => currentUser != null;

  static Future<AuthResponse> signInWithEmail(String email, String password) async {
    final response = await client.auth.signInWithPassword(email: email, password: password);
    final user = response.user;
    if (user != null && user.emailConfirmedAt == null) {
      await client.auth.signOut();
      throw Exception('Please verify your email before logging in. Check your inbox for a confirmation link.');
    }
    // Set local cache details
    if (user != null) {
      await LocalStorageService.saveProfile(Profile(
        id: user.id,
        email: user.email ?? '',
        displayName: user.userMetadata?['full_name'] ?? user.email?.split('@')[0] ?? 'Student',
      ));
    }
    return response;
  }

  static Future<AuthResponse> signUp(String email, String password, String name) async {
    final response = await client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': name},
      emailRedirectTo: 'com.mdalfaaz.bunkmitra://login',
    );
    final user = response.user;
    if (user != null && response.session == null) {
      // Verification required
      throw Exception('We\'ve sent a verification link to your email. Please check your inbox and verify before logging in.');
    }
    return response;
  }

  static Future<void> resetPassword(String email) async {
    await client.auth.resetPasswordForEmail(
      email,
      redirectTo: 'com.mdalfaaz.bunkmitra://login',
    );
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
    await LocalStorageService.clearAll();
  }

  // ===== CLOUD SYNCING (Supabase <-> Local Storage) =====

  static Future<void> syncFromCloud([bool force = false]) async {
    if (currentUser == null) return;
    
    // Throttle checks (5 minutes) unless forced
    final int now = DateTime.now().millisecondsSinceEpoch;
    final int last = LocalStorageService.lastSync;
    if (!force && (now - last < 5 * 60 * 1000)) return;

    syncNotifier.value = true;
    try {
      final String uid = currentUser!.id;

      // 1. Fetch profile
      final profData = await client.from('profiles').select().eq('id', uid).maybeSingle();
      if (profData != null) {
        await LocalStorageService.saveProfile(Profile.fromJson(profData));
      } else {
        // Create profile if not present
        final newProfile = Profile(
          id: uid,
          email: currentUser!.email ?? '',
          displayName: currentUser!.userMetadata?['full_name'] ?? currentUser!.email?.split('@')[0] ?? 'Student',
        );
        await client.from('profiles').upsert(newProfile.toJson());
        await LocalStorageService.saveProfile(newProfile);
      }

      // 2. Fetch subjects
      final List<dynamic> subjectsData = await client.from('subjects').select().eq('user_id', uid).order('created_at');
      final List<Subject> subjects = subjectsData.map((s) => Subject.fromJson(s)).toList();
      await LocalStorageService.saveSubjects(subjects);

      // 3. Fetch timetable slots
      final List<dynamic> slotsData = await client.from('schedule_slots').select().eq('user_id', uid).order('time');
      final List<ScheduleSlot> slots = slotsData.map((s) => ScheduleSlot.fromJson(s)).toList();
      await LocalStorageService.saveScheduleSlots(slots);

      // 4. Fetch attendance responses
      final List<dynamic> respData = await client.from('attendance_responses').select().eq('user_id', uid);
      final Map<String, Map<String, AttendanceResponse>> localResponses = {};
      
      for (final r in respData) {
        final resp = AttendanceResponse.fromJson(r);
        if (!localResponses.containsKey(resp.date)) {
          localResponses[resp.date] = {};
        }
        localResponses[resp.date]![resp.slotId] = resp;
      }
      await LocalStorageService.saveResponses(localResponses);

      await LocalStorageService.setLastSync(now);
    } catch (e) {
      print('Cloud sync error: $e');
      rethrow;
    } finally {
      syncNotifier.value = false;
    }
  }

  // ===== WRITE OPERATIONS (OPTIMISTIC WRITES) =====

  // Subjects
  static Future<Subject> addSubject({
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
    final String uid = currentUser?.id ?? 'demo';
    final String localId = 'local_${Random().nextInt(100000)}';
    
    final newSubject = Subject(
      id: localId,
      userId: uid,
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

    // Save locally first
    final List<Subject> localSubs = LocalStorageService.getSubjects();
    localSubs.add(newSubject);
    await LocalStorageService.saveSubjects(localSubs);

    if (isAuthenticated) {
      // Sync with Supabase
      final data = await client.from('subjects').insert({
        'user_id': uid,
        'name': name,
        'professor': professor,
        'total_classes': totalClasses,
        'attended_classes': attendedClasses,
        'has_practical': hasPractical,
        'is_practical_only': isPracticalOnly,
        'practical_total': practicalTotal,
        'practical_attended': practicalAttended,
        'icon': icon,
        'color': color,
      }).select().single();

      final syncedSubject = Subject.fromJson(data);
      // Replace temp local subject with actual database subject
      final currentList = LocalStorageService.getSubjects();
      final idx = currentList.indexWhere((s) => s.id == localId);
      if (idx != -1) {
        currentList[idx] = syncedSubject;
        await LocalStorageService.saveSubjects(currentList);
      }
      await syncFromCloud(true);
      return syncedSubject;
    }
    return newSubject;
  }

  static Future<Subject?> updateSubject(String id, Map<String, dynamic> updates) async {
    final List<Subject> currentList = LocalStorageService.getSubjects();
    final idx = currentList.indexWhere((s) => s.id == id);
    if (idx != -1) {
      final updated = currentList[idx].copyWith(
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
      currentList[idx] = updated;
      await LocalStorageService.saveSubjects(currentList);
    }

    if (isAuthenticated && !id.startsWith('local_')) {
      await client.from('subjects').update(updates).eq('id', id);
      await syncFromCloud(true);
    }
    return LocalStorageService.getSubjects().firstWhere((s) => s.id == id);
  }

  static Future<void> deleteSubject(String id) async {
    // Optimistic delete local
    final currentList = LocalStorageService.getSubjects();
    await LocalStorageService.saveSubjects(currentList.where((s) => s.id != id).toList());

    final slots = LocalStorageService.getScheduleSlots();
    await LocalStorageService.saveScheduleSlots(slots.where((s) => s.subjectId != id).toList());

    if (isAuthenticated && !id.startsWith('local_')) {
      await client.from('schedule_slots').delete().eq('subject_id', id);
      await client.from('subjects').delete().eq('id', id);
      await syncFromCloud(true);
    }
  }

  // Timetable slots
  static Future<ScheduleSlot> addScheduleSlot({
    required String subjectId,
    required int dayOfWeek,
    String time = '09:00',
    String endTime = '10:00',
    String slotType = 'theory',
    String room = '',
  }) async {
    final String uid = currentUser?.id ?? 'demo';
    final String localId = 'local_${Random().nextInt(100000)}';
    
    final newSlot = ScheduleSlot(
      id: localId,
      userId: uid,
      subjectId: subjectId,
      dayOfWeek: dayOfWeek,
      time: time,
      endTime: endTime,
      slotType: slotType,
      room: room,
      createdAt: DateTime.now().toIso8601String(),
      isPending: true,
    );

    // Save locally
    final List<ScheduleSlot> localSlots = LocalStorageService.getScheduleSlots();
    localSlots.add(newSlot);
    await LocalStorageService.saveScheduleSlots(localSlots);

    if (isAuthenticated && !subjectId.startsWith('local_')) {
      final data = await client.from('schedule_slots').insert({
        'user_id': uid,
        'subject_id': subjectId,
        'day_of_week': dayOfWeek,
        'time': time,
        'end_time': endTime,
        'slot_type': slotType,
        'room': room,
      }).select().single();
      
      final syncedSlot = ScheduleSlot.fromJson(data);
      final currentList = LocalStorageService.getScheduleSlots();
      final idx = currentList.indexWhere((s) => s.id == localId);
      if (idx != -1) {
        currentList[idx] = syncedSlot;
        await LocalStorageService.saveScheduleSlots(currentList);
      }
      await syncFromCloud(true);
      return syncedSlot;
    }
    return newSlot;
  }

  static Future<ScheduleSlot?> updateScheduleSlot(String id, Map<String, dynamic> updates) async {
    final List<ScheduleSlot> currentList = LocalStorageService.getScheduleSlots();
    final idx = currentList.indexWhere((s) => s.id == id);
    if (idx != -1) {
      final updated = currentList[idx].copyWith(
        subjectId: updates['subject_id'],
        dayOfWeek: updates['day_of_week'],
        time: updates['time'],
        endTime: updates['end_time'],
        slotType: updates['slot_type'],
        room: updates['room'],
      );
      currentList[idx] = updated;
      await LocalStorageService.saveScheduleSlots(currentList);
    }

    if (isAuthenticated && !id.startsWith('local_')) {
      await client.from('schedule_slots').update(updates).eq('id', id);
      await syncFromCloud(true);
    }
    return LocalStorageService.getScheduleSlots().firstWhere((s) => s.id == id);
  }

  static Future<void> deleteScheduleSlot(String id) async {
    final currentList = LocalStorageService.getScheduleSlots();
    await LocalStorageService.saveScheduleSlots(currentList.where((s) => s.id != id).toList());

    if (isAuthenticated && !id.startsWith('local_')) {
      await client.from('schedule_slots').delete().eq('id', id);
      await syncFromCloud(true);
    }
  }

  // Attendance recording check-ins
  static Future<void> respondToSlot({
    required String slotId,
    required bool lectureHappened,
    required bool attended,
  }) async {
    final String uid = currentUser?.id ?? 'demo';
    final String todayKey = _todayKey();

    final Map<String, Map<String, AttendanceResponse>> allResponses = LocalStorageService.getResponses();
    if (!allResponses.containsKey(todayKey)) allResponses[todayKey] = {};
    
    final newResp = AttendanceResponse(
      id: 'local_${Random().nextInt(100000)}',
      userId: uid,
      slotId: slotId,
      date: todayKey,
      lectureHappened: lectureHappened,
      attended: attended,
      createdAt: DateTime.now().toIso8601String(),
    );
    
    allResponses[todayKey]![slotId] = newResp;
    await LocalStorageService.saveResponses(allResponses);

    // Save to Supabase
    if (isAuthenticated && !slotId.startsWith('local_')) {
      await client.from('attendance_responses').upsert({
        'user_id': uid,
        'slot_id': slotId,
        'date': todayKey,
        'lecture_happened': lectureHappened,
        'attended': attended,
      });
    }

    // Update subject counters
    if (lectureHappened) {
      final slot = LocalStorageService.getScheduleSlots().firstWhere((s) => s.id == slotId);
      final subjects = LocalStorageService.getSubjects();
      final sIdx = subjects.indexWhere((s) => s.id == slot.subjectId);
      
      if (sIdx != -1) {
        final sub = subjects[sIdx];
        final bool isPractical = slot.slotType == 'practical' || sub.isPracticalOnly;
        
        Subject updatedSub;
        if (isPractical) {
          updatedSub = sub.copyWith(
            hasPractical: true,
            practicalTotal: sub.practicalTotal + 1,
            practicalAttended: sub.practicalAttended + (attended ? 1 : 0),
          );
        } else {
          updatedSub = sub.copyWith(
            totalClasses: sub.totalClasses + 1,
            attendedClasses: sub.attendedClasses + (attended ? 1 : 0),
          );
        }
        
        subjects[sIdx] = updatedSub;
        await LocalStorageService.saveSubjects(subjects);

        // Update in Supabase
        if (isAuthenticated && !sub.id.startsWith('local_')) {
          final updates = isPractical ? {
            'practical_total': updatedSub.practicalTotal,
            'practical_attended': updatedSub.practicalAttended,
            'has_practical': true,
          } : {
            'total_classes': updatedSub.totalClasses,
            'attended_classes': updatedSub.attendedClasses,
          };
          await client.from('subjects').update(updates).eq('id', sub.id);
        }
      }
    }
  }

  // Update check-in response retroactively
  static Future<void> updateResponse({
    required String date,
    required String slotId,
    required AttendanceResponse? oldResponse,
    required AttendanceResponse newResponse,
  }) async {
    final List<Subject> subjects = LocalStorageService.getSubjects();
    final List<ScheduleSlot> slots = LocalStorageService.getScheduleSlots();
    
    final slotIdx = slots.indexWhere((s) => s.id == slotId);
    if (slotIdx == -1) return;
    
    final slot = slots[slotIdx];
    final subIdx = subjects.indexWhere((s) => s.id == slot.subjectId);
    if (subIdx == -1) return;
    
    var sub = subjects[subIdx];
    final bool isPractical = slot.slotType == 'practical' || sub.isPracticalOnly;

    // 1. Revert old response impact
    if (oldResponse != null && oldResponse.lectureHappened) {
      if (isPractical) {
        sub = sub.copyWith(
          practicalTotal: max(0, sub.practicalTotal - 1),
          practicalAttended: max(0, sub.practicalAttended - (oldResponse.attended ? 1 : 0)),
        );
      } else {
        sub = sub.copyWith(
          totalClasses: max(0, sub.totalClasses - 1),
          attendedClasses: max(0, sub.attendedClasses - (oldResponse.attended ? 1 : 0)),
        );
      }
    }

    // 2. Apply new response impact
    if (newResponse.lectureHappened) {
      if (isPractical) {
        sub = sub.copyWith(
          hasPractical: true,
          practicalTotal: sub.practicalTotal + 1,
          practicalAttended: sub.practicalAttended + (newResponse.attended ? 1 : 0),
        );
      } else {
        sub = sub.copyWith(
          totalClasses: sub.totalClasses + 1,
          attendedClasses: sub.attendedClasses + (newResponse.attended ? 1 : 0),
        );
      }
    }

    // 3. Save locally
    subjects[subIdx] = sub;
    await LocalStorageService.saveSubjects(subjects);

    final allResponses = LocalStorageService.getResponses();
    if (!allResponses.containsKey(date)) allResponses[date] = {};
    allResponses[date]![slotId] = newResponse;
    await LocalStorageService.saveResponses(allResponses);

    // 4. Sync online
    if (isAuthenticated && !slotId.startsWith('local_')) {
      final String uid = currentUser!.id;
      await client.from('attendance_responses').upsert({
        'user_id': uid,
        'slot_id': slotId,
        'date': date,
        'lecture_happened': newResponse.lectureHappened,
        'attended': newResponse.attended,
      });

      final updates = isPractical ? {
        'practical_total': sub.practicalTotal,
        'practical_attended': sub.practicalAttended,
        'has_practical': true,
      } : {
        'total_classes': sub.totalClasses,
        'attended_classes': sub.attendedClasses,
      };
      await client.from('subjects').update(updates).eq('id', sub.id);
    }
  }

  // Profile update
  static Future<Profile> updateProfile({
    String? displayName,
    String? department,
    String? university,
    String? year,
    String? avatarUrl,
  }) async {
    Profile prof = LocalStorageService.getProfile() ?? Profile(id: currentUser?.id ?? 'demo');
    prof = prof.copyWith(
      displayName: displayName,
      department: department,
      university: university,
      year: year,
      avatarUrl: avatarUrl,
    );
    await LocalStorageService.saveProfile(prof);

    if (isAuthenticated) {
      final updates = <String, dynamic>{};
      if (displayName != null) updates['display_name'] = displayName;
      if (department != null) updates['department'] = department;
      if (university != null) updates['university'] = university;
      if (year != null) updates['year'] = year;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
      
      await client.from('profiles').update(updates).eq('id', currentUser!.id);
      await syncFromCloud(true);
    }
    return prof;
  }

  // Avatar Upload Service
  static Future<String> uploadAvatar(File file) async {
    if (!isAuthenticated) throw Exception('User not logged in');
    final String uid = currentUser!.id;
    final String fileExtension = file.path.split('.').last;
    final String filePath = '$uid/avatar.$fileExtension';

    try {
      // Upload to storage bucket (avatars)
      await client.storage.from('avatars').upload(
        filePath,
        file,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
      );

      // Get public URL
      final String publicUrl = client.storage.from('avatars').getPublicUrl(filePath);
      final String cacheBustUrl = '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';

      // Save URL to profile
      await updateProfile(avatarUrl: cacheBustUrl);
      return cacheBustUrl;
    } catch (e) {
      throw Exception('Avatar upload failed: $e');
    }
  }

  // ===== SCHEDULE SHARE FEATURES =====

  static Future<String> generateShareCode() async {
    if (!isAuthenticated) throw Exception('Must be connected to internet to share');
    final String uid = currentUser!.id;
    
    final subjects = LocalStorageService.getSubjects();
    final schedule = LocalStorageService.getScheduleSlots();

    if (subjects.isEmpty) throw Exception('No subjects to share. Add some subjects first.');

    // Custom random 6-character sharing code
    final constChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    final code = List.generate(6, (i) => constChars[random.nextInt(constChars.length)]).join();

    // Clean subjects for share (reset attended to 0)
    final cleanSubjects = subjects.map((s) => s.copyWith(
      attendedClasses: 0,
      practicalAttended: 0,
    ).toJson()).toList();

    final cleanSchedule = schedule.map((s) => s.toJson()).toList();

    final data = {
      'subjects': cleanSubjects,
      'schedule': cleanSchedule,
    };

    await client.from('shared_batches').insert({
      'share_code': code,
      'creator_id': uid,
      'data': data,
    });
    return code;
  }

  static Future<Map<String, dynamic>> fetchShareData(String code) async {
    if (!isAuthenticated) throw Exception('Must be connected to internet to fetch');
    final data = await client.from('shared_batches').select().eq('share_code', code.toUpperCase().trim()).single();
    return data['data'] as Map<String, dynamic>;
  }

  static Future<void> commitSharedData(List<dynamic> subjectsJson, List<dynamic> scheduleJson) async {
    if (isAuthenticated) {
      await syncFromCloud(true);
    }

    final Map<String, String> idMap = {};
    final existingSubjects = LocalStorageService.getSubjects();
    final List<Subject> localSubjectsToSave = List.from(existingSubjects);
    final List<ScheduleSlot> localSlots = LocalStorageService.getScheduleSlots();

    // Deduplicate incoming subjects by name to prevent importing duplicate entries
    final List<dynamic> uniqueSubjectsJson = [];
    final Set<String> seenNames = {};
    for (final s in subjectsJson) {
      final sharedSub = Subject.fromJson(s);
      final String nameKey = sharedSub.name.trim().toLowerCase();
      if (!seenNames.contains(nameKey)) {
        seenNames.add(nameKey);
        uniqueSubjectsJson.add(s);
      }
    }

    // 1. Collect updates & deletions
    final List<Map<String, dynamic>> supabaseSubjectUpdates = [];
    final List<String> subjectsToDeleteSlotsFromOnline = [];
    final List<Subject> newSubjectsToCreateLocally = [];

    for (final s in uniqueSubjectsJson) {
      final sharedSub = Subject.fromJson(s);
      final existingIdx = localSubjectsToSave.indexWhere(
        (ex) => ex.name.trim().toLowerCase() == sharedSub.name.trim().toLowerCase(),
      );

      if (existingIdx != -1) {
        final existing = localSubjectsToSave[existingIdx];
        
        // Update subject locally
        final updatedSub = existing.copyWith(
          professor: sharedSub.professor,
          totalClasses: sharedSub.totalClasses,
          attendedClasses: sharedSub.attendedClasses,
          hasPractical: sharedSub.hasPractical,
          isPracticalOnly: sharedSub.isPracticalOnly,
          practicalTotal: sharedSub.practicalTotal,
          practicalAttended: sharedSub.practicalAttended,
          icon: sharedSub.icon,
          color: sharedSub.color,
        );
        localSubjectsToSave[existingIdx] = updatedSub;
        idMap[sharedSub.id] = existing.id;

        // Record database updates & schedule cleanups
        if (isAuthenticated && !existing.id.startsWith('local_')) {
          supabaseSubjectUpdates.add({
            'id': existing.id,
            'updates': {
              'name': existing.name,
              'professor': sharedSub.professor,
              'total_classes': sharedSub.totalClasses,
              'attended_classes': sharedSub.attendedClasses,
              'has_practical': sharedSub.hasPractical,
              'is_practical_only': sharedSub.isPracticalOnly,
              'practical_total': sharedSub.practicalTotal,
              'practical_attended': sharedSub.practicalAttended,
              'icon': sharedSub.icon,
              'color': sharedSub.color,
            }
          });
          subjectsToDeleteSlotsFromOnline.add(existing.id);
        }

        // Clean out old schedule slots for this subject locally
        localSlots.removeWhere((slot) => slot.subjectId == existing.id);
      } else {
        // Prepare new subject
        newSubjectsToCreateLocally.add(sharedSub);
      }
    }

    // 2. Perform DB insert for new subjects if online, otherwise generate local IDs
    final String uid = currentUser?.id ?? 'demo';
    if (isAuthenticated && newSubjectsToCreateLocally.isNotEmpty) {
      final List<Map<String, dynamic>> newSubsData = newSubjectsToCreateLocally.map((sub) => {
        'user_id': uid,
        'name': sub.name,
        'professor': sub.professor,
        'total_classes': sub.totalClasses,
        'attended_classes': sub.attendedClasses,
        'has_practical': sub.hasPractical,
        'is_practical_only': sub.isPracticalOnly,
        'practical_total': sub.practicalTotal,
        'practical_attended': sub.practicalAttended,
        'icon': sub.icon,
        'color': sub.color,
      }).toList();

      final List<dynamic> insertedRows = await client.from('subjects').insert(newSubsData).select();
      
      for (final sub in newSubjectsToCreateLocally) {
        Map<String, dynamic>? insertedRow;
        for (final row in insertedRows) {
          if (row['name'].toString().toLowerCase() == sub.name.toLowerCase()) {
            insertedRow = row as Map<String, dynamic>;
            break;
          }
        }
        if (insertedRow != null) {
          final syncedSub = Subject.fromJson(insertedRow);
          localSubjectsToSave.add(syncedSub);
          idMap[sub.id] = syncedSub.id;
        } else {
          // Fallback if not found in inserted rows (unlikely)
          final String localId = 'local_${Random().nextInt(100000)}';
          final tempSub = sub.copyWith(id: localId, userId: uid, isPending: true);
          localSubjectsToSave.add(tempSub);
          idMap[sub.id] = localId;
        }
      }
    } else {
      // Offline or empty
      for (final sub in newSubjectsToCreateLocally) {
        final String localId = 'local_${Random().nextInt(100000)}';
        final tempSub = sub.copyWith(
          id: localId,
          userId: uid,
          createdAt: DateTime.now().toIso8601String(),
          isPending: true,
        );
        localSubjectsToSave.add(tempSub);
        idMap[sub.id] = localId;
      }
    }

    // 3. Process new schedule slots
    final List<Map<String, dynamic>> supabaseSlotsToInsert = [];
    final List<ScheduleSlot> localSlotsToInsert = [];

    for (final slotJson in scheduleJson) {
      final sharedSlot = ScheduleSlot.fromJson(slotJson);
      final String? mappedId = idMap[sharedSlot.subjectId];
      if (mappedId != null) {
        final String localId = 'local_${Random().nextInt(100000)}';
        final newSlot = ScheduleSlot(
          id: localId,
          userId: uid,
          subjectId: mappedId,
          dayOfWeek: sharedSlot.dayOfWeek,
          time: sharedSlot.time,
          endTime: sharedSlot.endTime,
          slotType: sharedSlot.slotType,
          room: sharedSlot.room,
          createdAt: DateTime.now().toIso8601String(),
          isPending: true,
        );
        localSlotsToInsert.add(newSlot);

        if (isAuthenticated && !mappedId.startsWith('local_')) {
          supabaseSlotsToInsert.add({
            'user_id': uid,
            'subject_id': mappedId,
            'day_of_week': sharedSlot.dayOfWeek,
            'time': sharedSlot.time,
            'end_time': sharedSlot.endTime,
            'slot_type': sharedSlot.slotType,
            'room': sharedSlot.room,
          });
        }
      }
    }

    // Combine old non-cleared local slots and new local slots
    localSlots.addAll(localSlotsToInsert);

    // 4. Update local storage first (optimistic response)
    await LocalStorageService.saveSubjects(localSubjectsToSave);
    await LocalStorageService.saveScheduleSlots(localSlots);

    // 5. Execute online updates in parallel batches if online
    if (isAuthenticated) {
      final List<Future<dynamic>> onlineOperations = [];

      // A. Existing subjects updates in Supabase
      for (final update in supabaseSubjectUpdates) {
        onlineOperations.add(
          client.from('subjects').update(update['updates']).eq('id', update['id'])
        );
      }

      // B. Delete old schedule slots in Supabase
      for (final subjectId in subjectsToDeleteSlotsFromOnline) {
        onlineOperations.add(
          client.from('schedule_slots').delete().eq('subject_id', subjectId)
        );
      }

      await Future.wait(onlineOperations);

      // C. Insert new schedule slots in Supabase in bulk
      if (supabaseSlotsToInsert.isNotEmpty) {
        await client.from('schedule_slots').insert(supabaseSlotsToInsert);
      }

      // D. Final single Sync-From-Cloud to retrieve correct database UUIDs for slots/subjects
      await syncFromCloud(true);
    }
  }

  static Future<void> commitScheduleOnly(List<dynamic> subjectsJson, List<dynamic> scheduleJson) async {
    if (isAuthenticated) {
      await syncFromCloud(true);
    }

    final Map<String, String> idMap = {};
    final existingSubjects = LocalStorageService.getSubjects();
    final List<Subject> localSubjectsToSave = List.from(existingSubjects);
    final List<ScheduleSlot> localSlots = LocalStorageService.getScheduleSlots();

    // Deduplicate incoming subjects by name to prevent importing duplicate entries
    final List<dynamic> uniqueSubjectsJson = [];
    final Set<String> seenNames = {};
    for (final s in subjectsJson) {
      final sharedSub = Subject.fromJson(s);
      final String nameKey = sharedSub.name.trim().toLowerCase();
      if (!seenNames.contains(nameKey)) {
        seenNames.add(nameKey);
        uniqueSubjectsJson.add(s);
      }
    }

    // 1. Collect updates & deletions
    final List<String> subjectsToDeleteSlotsFromOnline = [];
    final List<Subject> newSubjectsToCreateLocally = [];

    for (final s in uniqueSubjectsJson) {
      final sharedSub = Subject.fromJson(s);
      final existingIdx = localSubjectsToSave.indexWhere(
        (ex) => ex.name.trim().toLowerCase() == sharedSub.name.trim().toLowerCase(),
      );

      if (existingIdx != -1) {
        final existing = localSubjectsToSave[existingIdx];
        idMap[sharedSub.id] = existing.id;

        // Clean out old schedule slots for this subject locally
        localSlots.removeWhere((slot) => slot.subjectId == existing.id);

        if (isAuthenticated && !existing.id.startsWith('local_')) {
          subjectsToDeleteSlotsFromOnline.add(existing.id);
        }
      } else {
        // Prepare new subject with 0 stats (only schedule is being imported)
        newSubjectsToCreateLocally.add(sharedSub);
      }
    }

    // 2. Perform DB insert for new subjects if online, otherwise generate local IDs
    final String uid = currentUser?.id ?? 'demo';
    if (isAuthenticated && newSubjectsToCreateLocally.isNotEmpty) {
      final List<Map<String, dynamic>> newSubsData = newSubjectsToCreateLocally.map((sub) => {
        'user_id': uid,
        'name': sub.name,
        'professor': sub.professor,
        'total_classes': 0,
        'attended_classes': 0,
        'has_practical': sub.hasPractical,
        'is_practical_only': sub.isPracticalOnly,
        'practical_total': 0,
        'practical_attended': 0,
        'icon': sub.icon,
        'color': sub.color,
      }).toList();

      final List<dynamic> insertedRows = await client.from('subjects').insert(newSubsData).select();
      
      for (final sub in newSubjectsToCreateLocally) {
        Map<String, dynamic>? insertedRow;
        for (final row in insertedRows) {
          if (row['name'].toString().toLowerCase() == sub.name.toLowerCase()) {
            insertedRow = row as Map<String, dynamic>;
            break;
          }
        }
        if (insertedRow != null) {
          final syncedSub = Subject.fromJson(insertedRow);
          localSubjectsToSave.add(syncedSub);
          idMap[sub.id] = syncedSub.id;
        } else {
          // Fallback if not found
          final String localId = 'local_${Random().nextInt(100000)}';
          final tempSub = sub.copyWith(
            id: localId,
            userId: uid,
            totalClasses: 0,
            attendedClasses: 0,
            practicalTotal: 0,
            practicalAttended: 0,
            isPending: true,
          );
          localSubjectsToSave.add(tempSub);
          idMap[sub.id] = localId;
        }
      }
    } else {
      // Offline or empty
      for (final sub in newSubjectsToCreateLocally) {
        final String localId = 'local_${Random().nextInt(100000)}';
        final tempSub = sub.copyWith(
          id: localId,
          userId: uid,
          totalClasses: 0,
          attendedClasses: 0,
          practicalTotal: 0,
          practicalAttended: 0,
          createdAt: DateTime.now().toIso8601String(),
          isPending: true,
        );
        localSubjectsToSave.add(tempSub);
        idMap[sub.id] = localId;
      }
    }

    // 3. Process new schedule slots
    final List<Map<String, dynamic>> supabaseSlotsToInsert = [];
    final List<ScheduleSlot> localSlotsToInsert = [];

    for (final slotJson in scheduleJson) {
      final sharedSlot = ScheduleSlot.fromJson(slotJson);
      final String? mappedId = idMap[sharedSlot.subjectId];
      if (mappedId != null) {
        final String localId = 'local_${Random().nextInt(100000)}';
        final newSlot = ScheduleSlot(
          id: localId,
          userId: uid,
          subjectId: mappedId,
          dayOfWeek: sharedSlot.dayOfWeek,
          time: sharedSlot.time,
          endTime: sharedSlot.endTime,
          slotType: sharedSlot.slotType,
          room: sharedSlot.room,
          createdAt: DateTime.now().toIso8601String(),
          isPending: true,
        );
        localSlotsToInsert.add(newSlot);

        if (isAuthenticated && !mappedId.startsWith('local_')) {
          supabaseSlotsToInsert.add({
            'user_id': uid,
            'subject_id': mappedId,
            'day_of_week': sharedSlot.dayOfWeek,
            'time': sharedSlot.time,
            'end_time': sharedSlot.endTime,
            'slot_type': sharedSlot.slotType,
            'room': sharedSlot.room,
          });
        }
      }
    }

    // Combine old non-cleared local slots and new local slots
    localSlots.addAll(localSlotsToInsert);

    // 4. Update local storage first (optimistic response)
    await LocalStorageService.saveSubjects(localSubjectsToSave);
    await LocalStorageService.saveScheduleSlots(localSlots);

    // 5. Execute online updates in parallel batches if online
    if (isAuthenticated) {
      final List<Future<dynamic>> onlineOperations = [];

      // A. Delete old schedule slots in Supabase
      for (final subjectId in subjectsToDeleteSlotsFromOnline) {
        onlineOperations.add(
          client.from('schedule_slots').delete().eq('subject_id', subjectId)
        );
      }

      await Future.wait(onlineOperations);

      // B. Insert new schedule slots in Supabase in bulk
      if (supabaseSlotsToInsert.isNotEmpty) {
        await client.from('schedule_slots').insert(supabaseSlotsToInsert);
      }

      // C. Final single Sync-From-Cloud to retrieve correct database UUIDs
      await syncFromCloud(true);
    }
  }

  // ===== INTERNAL HELPERS =====

  static String _todayKey() {
    final now = DateTime.now();
    final String y = now.year.toString();
    final String m = now.month.toString().padLeft(2, '0');
    final String d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
