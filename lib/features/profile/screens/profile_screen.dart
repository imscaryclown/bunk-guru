import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/colors.dart';
import '../../../core/database/local_storage_service.dart';
import '../../../services/providers.dart';
import '../../../services/supabase_service.dart';
import '../../notifications/services/notification_service.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/custom_text_field.dart';
import '../../../widgets/page_header.dart';
import '../../../widgets/batch_import_success_dialog.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../subjects/services/subject_parser.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isUploadingAvatar = false;

  // ===== PHOTO PICKING & UPLOADING =====
  Future<void> _pickAndUploadAvatar() async {
    if (!SupabaseService.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please log in online to upload a profile avatar picture.',
          ),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 85,
      );

      if (image == null) return;

      final File file = File(image.path);
      final int fileSize = await file.length();
      if (fileSize > 2 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image size must be under 2MB.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      setState(() {
        _isUploadingAvatar = true;
      });

      final String avatarUrl = await SupabaseService.uploadAvatar(file);

      // Refresh states
      ref.read(profileProvider.notifier).refresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated successfully! 📷'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingAvatar = false;
        });
      }
    }
  }

  // ===== OPEN EDIT PROFILE MODAL =====
  void _showEditProfileSheet(BuildContext context) {
    final profile = ref.read(profileProvider);
    final user = ref.read(authProvider);

    final nameController = TextEditingController(
      text: profile?.displayName ?? user?.email?.split('@')[0] ?? 'Student',
    );
    final uniController = TextEditingController(
      text: profile?.university ?? 'Galgotias University',
    );
    final deptController = TextEditingController(
      text: profile?.department ?? 'Computer Science',
    );
    final yearController = TextEditingController(
      text: profile?.year ?? '1st Year',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bool isDark = Theme.of(context).brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1D2022) : Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24.0),
                  ),
                ),
                padding: const EdgeInsets.all(24.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white30 : Colors.black12,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Edit Profile',
                        style: Theme.of(context).textTheme.displayMedium,
                      ),
                      const SizedBox(height: 20),
                      CustomTextField(
                        controller: nameController,
                        hintText: 'Display Name',
                        prefixIcon: const Icon(Icons.person),
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        controller: uniController,
                        hintText: 'University',
                        prefixIcon: const Icon(Icons.school),
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        controller: deptController,
                        hintText: 'Department',
                        prefixIcon: const Icon(Icons.corporate_fare),
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        controller: yearController,
                        hintText: 'Year (e.g. 1st Year)',
                        prefixIcon: const Icon(Icons.calendar_today),
                      ),
                      const SizedBox(height: 20),
                      CustomButton(
                        child: const Text('Save Profile'),
                        onTap: () async {
                          HapticFeedback.mediumImpact();
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Updating profile...'),
                              duration: Duration(milliseconds: 500),
                            ),
                          );

                          try {
                            await ref
                                .read(profileProvider.notifier)
                                .update(
                                  displayName: nameController.text.trim(),
                                  university: uniController.text.trim(),
                                  department: deptController.text.trim(),
                                  year: yearController.text.trim(),
                                );
                            ref.read(profileProvider.notifier).refresh();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Profile updated! ✨'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Failed to update: ${e.toString()}',
                                  ),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ===== OPEN NOTIFICATIONS SHEET =====
  void _showNotificationPrefsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return const NotificationPrefsSheet();
      },
    );
  }

  // ===== OPEN SHARE SHEET =====
  void _showShareScheduleSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ShareScheduleSheet(
          onSyncDataFetched: (subjects, schedule) {
            Future.delayed(const Duration(milliseconds: 150), () {
              _showSyncSheet(subjects, schedule);
            });
          },
        );
      },
    );
  }

  void _toast(String msg, bool isSuccess) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textAlign: TextAlign.center),
        backgroundColor: isSuccess
            ? const Color(0xFF16A34A)
            : AppColors.primaryContainer,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildCounterBtn(
    String symbol,
    VoidCallback onTap, {
    bool isAdd = false,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color bg = isAdd
        ? (isDark
              ? AppColors.primaryDark.withValues(alpha: 0.1)
              : AppColors.primaryFixed)
        : (isDark
              ? Colors.white.withValues(alpha: 0.04)
              : AppColors.bgSurfaceContainerLight);

    final Color fg = isAdd
        ? AppColors.primaryLight
        : (isDark ? Colors.white70 : Colors.black87);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Center(
          child: Text(
            symbol,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }

  void _showSyncSheet(List<dynamic> subjectsJson, List<dynamic> scheduleJson) {
    // Clone subjects list to hold mutable state
    final List<Map<String, dynamic>> syncList = List.from(
      subjectsJson.map((s) => Map<String, dynamic>.from(s as Map)),
    );

    // Track state: Map for theory and practical attended counts
    final Map<String, int> theoryCounts = {};
    final Map<String, int> practicalCounts = {};

    for (final s in syncList) {
      final String id = s['id'] as String;
      // Start with total classes as attended (same as Capacitor app)
      theoryCounts[id] = s['total_classes'] as int? ?? 0;
      practicalCounts[id] = s['practical_total'] as int? ?? 0;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        bool isScanning = false;
        String? scanMessage;
        bool isSubmitting = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1D2022) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white30 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Sync Attendance',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'How many of these classes have you attended so far?',
                    style: TextStyle(
                      color: AppColors.outlineLight,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Auto-fill via Scan Button
                  InkWell(
                    onTap: isScanning
                        ? null
                        : () async {
                            final picker = ImagePicker();
                            final pickedFiles = await picker.pickMultiImage();
                            if (pickedFiles.isEmpty) return;

                            setModalState(() {
                              isScanning = true;
                              scanMessage = null;
                            });

                            try {
                              List<Uint8List> imagesBytes = [];
                              for (var file in pickedFiles) {
                                imagesBytes.add(await file.readAsBytes());
                              }

                              final expectedSubjects = syncList
                                  .map((s) => s['name'] as String)
                                  .toList();
                              final parsed =
                                  await SubjectParser.parseMappedImages(
                                    imagesBytes,
                                    expectedSubjects,
                                  );

                              if (parsed.isNotEmpty) {
                                setModalState(() {
                                  for (var p in parsed) {
                                    final match = syncList.firstWhere(
                                      (s) =>
                                          (s['name'] as String).toLowerCase() ==
                                          p.subjectName.toLowerCase(),
                                      orElse: () => {},
                                    );
                                    if (match.isNotEmpty) {
                                      final id = match['id'] as String;
                                      theoryCounts[id] = p.attendedClasses;
                                      practicalCounts[id] = p.practicalAttended;
                                    }
                                  }
                                  isScanning = false;
                                  scanMessage =
                                      '✅ Attendance auto-filled successfully!';
                                });
                              } else {
                                setModalState(() {
                                  isScanning = false;
                                  scanMessage = '❌ No attendance data found.';
                                });
                              }
                            } catch (e) {
                              setModalState(() {
                                isScanning = false;
                                scanMessage = '❌ Error scanning images.';
                              });
                            }
                          },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.primaryDark.withValues(alpha: 0.1)
                            : AppColors.primaryFixed.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primaryLight.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isScanning)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primaryLight,
                              ),
                            )
                          else
                            const Icon(
                              Icons.document_scanner,
                              color: AppColors.primaryLight,
                              size: 20,
                            ),
                          const SizedBox(width: 8),
                          Text(
                            isScanning
                                ? 'Extracting data ✨'
                                : 'Auto-fill via Scan',
                            style: const TextStyle(
                              color: AppColors.primaryLight,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (scanMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Center(
                        child: Text(
                          scanMessage!,
                          style: TextStyle(
                            color: scanMessage!.contains('✅')
                                ? Colors.green
                                : Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Scrollable List of Subjects
                  Expanded(
                    child: ListView.builder(
                      itemCount: syncList.length,
                      itemBuilder: (context, index) {
                        final s = syncList[index];
                        final String id = s['id'] as String;
                        final String name = s['name'] as String? ?? 'Subject';
                        final bool hasPractical =
                            s['has_practical'] as bool? ?? false;
                        final bool isPracticalOnly =
                            s['is_practical_only'] as bool? ?? false;
                        final int theoryTotal = s['total_classes'] as int? ?? 0;
                        final int practicalTotal =
                            s['practical_total'] as int? ?? 0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF242729)
                                : AppColors.bgSurfaceLight,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : AppColors.outlineVariantLight.withValues(
                                      alpha: 0.3,
                                    ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Theory row
                              if (!isPracticalOnly) ...[
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Theory Classes',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                        Text(
                                          '$theoryTotal Held',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: AppColors.outlineLight,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        _buildCounterBtn('-', () {
                                          setModalState(() {
                                            theoryCounts[id] = max(
                                              0,
                                              (theoryCounts[id] ?? 0) - 1,
                                            );
                                          });
                                        }),
                                        SizedBox(
                                          width: 38,
                                          child: Center(
                                            child: Text(
                                              '${theoryCounts[id] ?? 0}',
                                              style: TextStyle(
                                                color: isDark
                                                    ? Colors.white
                                                    : Colors.black,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                        _buildCounterBtn('+', () {
                                          setModalState(() {
                                            theoryCounts[id] = min(
                                              theoryTotal,
                                              (theoryCounts[id] ?? 0) + 1,
                                            );
                                          });
                                        }, isAdd: true),
                                      ],
                                    ),
                                  ],
                                ),
                              ],

                              // Practical / Lab Row
                              if (hasPractical) ...[
                                if (!isPracticalOnly)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: Divider(
                                      color: isDark
                                          ? Colors.white10
                                          : Colors.black12,
                                      height: 1,
                                    ),
                                  ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Practical / Lab',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w400,
                                            color: Color(0xFF006A7C),
                                          ),
                                        ),
                                        Text(
                                          '$practicalTotal Held',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: AppColors.outlineLight,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        _buildCounterBtn('-', () {
                                          setModalState(() {
                                            practicalCounts[id] = max(
                                              0,
                                              (practicalCounts[id] ?? 0) - 1,
                                            );
                                          });
                                        }),
                                        SizedBox(
                                          width: 38,
                                          child: Center(
                                            child: Text(
                                              '${practicalCounts[id] ?? 0}',
                                              style: TextStyle(
                                                color: isDark
                                                    ? Colors.white
                                                    : Colors.black,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                        _buildCounterBtn('+', () {
                                          setModalState(() {
                                            practicalCounts[id] = min(
                                              practicalTotal,
                                              (practicalCounts[id] ?? 0) + 1,
                                            );
                                          });
                                        }, isAdd: true),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Commit Sync Button
                  CustomButton(
                    color: const Color(0xFF4F46E5),
                    onTap: isSubmitting
                        ? null
                        : () async {
                            setModalState(() {
                              isSubmitting = true;
                            });

                            try {
                              // Map counts back
                              final List<dynamic> updatedSubjects = syncList.map((s) {
                                final String id = s['id'] as String;
                                return {
                                  ...s,
                                  'attended_classes': theoryCounts[id] ?? 0,
                                  'practical_attended': practicalCounts[id] ?? 0,
                                };
                              }).toList();

                              await SupabaseService.commitSharedData(
                                updatedSubjects,
                                scheduleJson,
                              );

                              ref.read(subjectProvider.notifier).refresh();
                              ref.read(scheduleProvider.notifier).refresh();

                              if (context.mounted) {
                                Navigator.of(context).pop(); // Close sync sheet
                                ref.read(tabIndexProvider.notifier).state =
                                    0; // Go to Dashboard
                                BatchImportSuccessDialog.show(
                                  context: context,
                                  title: 'Batch Joined Successfully!',
                                  subtitle:
                                      'Your course tracker and timetable are now synced with this batch.',
                                  subjectCount: updatedSubjects.length,
                                  slotCount: scheduleJson.length,
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                setModalState(() {
                                  isSubmitting = false;
                                });
                              }
                              _toast('Failed to join batch: $e', false);
                            }
                          },
                    child: isSubmitting
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text(
                                'LOADING DATA...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          )
                        : const Text(
                            'LOAD DATA AND FINISH',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final user = ref.watch(authProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final String displayName =
        profile?.displayName ?? user?.email?.split('@')[0] ?? 'Student';
    final String email =
        profile?.email ?? user?.email ?? 'student@university.edu';
    final String uni = profile?.university ?? 'Galgotias University';
    final String dept = profile?.department ?? 'Computer Science';
    final String year = profile?.year ?? '1st Year';
    final String? avatarUrl = profile?.avatarUrl;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: 'Profile',
                padding: const EdgeInsets.only(bottom: 16.0),
                trailing: IconButton(
                  icon: const Icon(Icons.notifications_none_rounded, size: 24),
                  tooltip: 'Notification Settings',
                  onPressed: () => _showNotificationPrefsSheet(context),
                ),
              ),
              // PROFILE HEADER CARD (BENTO BOX)
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF242729) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.3)
                          : Colors.indigo.withValues(alpha: 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.indigo.withValues(alpha: 0.05),
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    // Avatar image circle
                    GestureDetector(
                      onTap: _pickAndUploadAvatar,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark
                                    ? Colors.white10
                                    : Colors.indigo.withValues(alpha: 0.1),
                                width: 2,
                              ),
                              color: AppColors.primaryLight.withValues(
                                alpha: 0.1,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _isUploadingAvatar
                                ? const Padding(
                                    padding: EdgeInsets.all(20.0),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : (avatarUrl != null &&
                                          avatarUrl.startsWith('http')
                                      ? CachedNetworkImage(
                                          imageUrl: avatarUrl,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) =>
                                              const Padding(
                                                padding: EdgeInsets.all(20.0),
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              ),
                                          errorWidget: (context, url, error) =>
                                              Center(
                                                child: Text(
                                                  displayName.isNotEmpty
                                                      ? displayName[0]
                                                            .toUpperCase()
                                                      : 'S',
                                                  style: const TextStyle(
                                                    fontSize: 28,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        AppColors.primaryLight,
                                                  ),
                                                ),
                                              ),
                                        )
                                      : Center(
                                          child: Text(
                                            displayName.isNotEmpty
                                                ? displayName[0].toUpperCase()
                                                : 'S',
                                            style: const TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.primaryLight,
                                            ),
                                          ),
                                        )),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppColors.primaryLight,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Profile Details text
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: Theme.of(
                              context,
                            ).textTheme.displayMedium?.copyWith(fontSize: 20),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.mail_outline,
                                size: 14,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  email,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.copyWith(fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            uni,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? const Color(0xFFC3C0FF)
                                  : AppColors.primaryLight.withValues(
                                      alpha: 0.8,
                                    ),
                              letterSpacing: 0.8,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.indigo.withValues(alpha: 0.2)
                                  : AppColors.primaryFixed.withValues(
                                      alpha: 0.2,
                                    ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$dept · $year',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.primaryDark
                                    : AppColors.primaryLight,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // SETTINGS LIST / BENTO TILES
              const Text(
                'PROFILE SETTINGS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.0,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),

              // Edit Profile Button
              _buildSettingsTile(
                context: context,
                icon: Icons.edit,
                title: 'Edit Profile Details',
                subtitle: 'Change name, university, dept, or year',
                iconColor: Colors.blue,
                onTap: () => _showEditProfileSheet(context),
              ),

              const SizedBox(height: 16),
              const Text(
                'PREFERENCES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.0,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),

              // Notification Preferences
              _buildSettingsTile(
                context: context,
                icon: Icons.notifications_active,
                title: 'Notification Preferences',
                subtitle: LocalStorageService.isNotificationEnabled
                    ? '${NotificationService.personas[LocalStorageService.notificationPersona]?.icon} ${NotificationService.personas[LocalStorageService.notificationPersona]?.name}'
                    : 'Off',
                iconColor: Colors.deepOrange,
                onTap: () => _showNotificationPrefsSheet(context),
              ),
              const SizedBox(height: 8),

              // Dark Mode Switch Tile
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF242729) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.indigo.withValues(alpha: 0.04),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.dark_mode, color: Colors.purple),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dark Theme',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Easy on the eyes at night',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: ref.watch(themeModeProvider) == ThemeMode.dark,
                      activeThumbColor: AppColors.primaryLight,
                      onChanged: (val) {
                        HapticFeedback.lightImpact();
                        ref.read(themeModeProvider.notifier).toggleTheme();
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const Text(
                'BATCH WORKSPACE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.0,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),

              // Share timetable & importing
              _buildSettingsTile(
                context: context,
                icon: Icons.share,
                title: 'Share & Import Timetable',
                subtitle: 'Sync schedule with roommates & classmates',
                iconColor: Colors.green,
                onTap: () => _showShareScheduleSheet(context),
              ),

              const SizedBox(height: 8),
              // Export Attendance Report
              _buildSettingsTile(
                context: context,
                icon: Icons.download,
                title: 'Export Attendance Report (PDF)',
                subtitle: 'Save a detailed report of your records',
                iconColor: Colors.amber,
                onTap: () {
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('PDF export coming soon! 📑'),
                      backgroundColor: Colors.indigo,
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),
              const Text(
                'ABOUT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.0,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),

              // About Bunk Guru
              _buildSettingsTile(
                context: context,
                icon: Icons.info,
                title: 'About Bunk Guru',
                subtitle: 'Meet the creators of Bunk Guru',
                iconColor: Colors.teal,
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push('/about');
                },
              ),

              const SizedBox(height: 24),

              // Log out button
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                ),
                child: InkWell(
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Confirm Logout'),
                        content: const Text(
                          'Are you sure you want to log out? All your local databases and sessions will be reset.',
                        ),
                        actions: [
                          TextButton(
                            child: const Text('Cancel'),
                            onPressed: () => Navigator.pop(context, false),
                          ),
                          TextButton(
                            child: const Text(
                              'Logout',
                              style: TextStyle(color: Colors.red),
                            ),
                            onPressed: () => Navigator.pop(context, true),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Signing out...')),
                        );
                      }
                      await ref.read(authProvider.notifier).signOut();
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout, color: Colors.red),
                        SizedBox(width: 8),
                        Text(
                          'Logout',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF242729) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.indigo.withValues(alpha: 0.04),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== NOTIFICATION PREFS SHEET =====
class NotificationPrefsSheet extends ConsumerStatefulWidget {
  const NotificationPrefsSheet({super.key});

  @override
  ConsumerState<NotificationPrefsSheet> createState() =>
      _NotificationPrefsSheetState();
}

class _NotificationPrefsSheetState
    extends ConsumerState<NotificationPrefsSheet> {
  late bool _notifEnabled;
  late bool _morningEnabled;
  late String _personaId;

  @override
  void initState() {
    super.initState();
    _notifEnabled = LocalStorageService.isNotificationEnabled;
    _morningEnabled = LocalStorageService.isMorningBriefingEnabled;
    _personaId = LocalStorageService.notificationPersona;
  }

  void _updatePersona(String pId) {
    HapticFeedback.selectionClick();
    setState(() {
      _personaId = pId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1D2022) : Colors.white,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24.0),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 20.0),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white30 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notification Preferences',
                        style: Theme.of(context).textTheme.displayMedium,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Choose your Bunk Buddy — they will remind you in their unique style before class.',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 20),

                      // MASTER SWITCH
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.indigo.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.notifications_active,
                                  color: AppColors.primaryLight,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Enable Notifications',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Switch(
                              value: _notifEnabled,
                              activeThumbColor: AppColors.primaryLight,
                              onChanged: (val) async {
                                HapticFeedback.lightImpact();
                                if (val) {
                                  final granted =
                                      await NotificationService.requestPermission();
                                  if (!granted) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Please enable notification permissions in system settings.',
                                          ),
                                          backgroundColor: Colors.redAccent,
                                        ),
                                      );
                                    }
                                    return;
                                  }
                                }
                                setState(() {
                                  _notifEnabled = val;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // MORNING SUMMARY SWITCH
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.indigo.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.wb_sunny, color: Colors.orange),
                                SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Morning Briefing',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      'Daily 8:00 AM summary of slots',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Switch(
                              value: _morningEnabled,
                              activeThumbColor: AppColors.primaryLight,
                              onChanged: (val) {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  _morningEnabled = val;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        'CHOOSE YOUR BUNK BUDDY',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.0,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // PERSONAS LIST
                      ...NotificationService.personas.entries.map((entry) {
                        final p = entry.value;
                        final bool isSelected = p.id == _personaId;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark
                                        ? AppColors.primaryDark.withValues(
                                            alpha: 0.1,
                                          )
                                        : AppColors.primaryFixed.withValues(
                                            alpha: 0.3,
                                          ))
                                  : (isDark
                                        ? const Color(0xFF242729)
                                        : Colors.white),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primaryLight
                                    : (isDark
                                          ? Colors.white.withValues(alpha: 0.04)
                                          : Colors.indigo.withValues(
                                              alpha: 0.04,
                                            )),
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: InkWell(
                              onTap: () => _updatePersona(p.id),
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  children: [
                                    Text(
                                      p.icon,
                                      style: const TextStyle(fontSize: 32),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p.name,
                                            style: TextStyle(
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            p.desc,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(
                                        Icons.check_circle,
                                        color: AppColors.primaryLight,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: 12),

                      // PREVIEW BUBBLE
                      const Text(
                        'LIVE PREVIEW',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.8,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF242729)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.indigo.withValues(alpha: 0.05),
                          ),
                        ),
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              NotificationService.personas[_personaId]?.icon ??
                                  '🤙',
                              style: const TextStyle(fontSize: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '📚 DATA STRUCTURES · 15 MIN',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primaryLight,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    NotificationService.previewMessage(
                                      _personaId,
                                      'classReminder',
                                    ),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ACTION BUTTON (DONE) PINNED AT BOTTOM
              SafeArea(
                top: false,
                child: CustomButton(
                  child: const Text('Done'),
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    try {
                      await LocalStorageService.setNotificationEnabled(
                        _notifEnabled,
                      );
                      await LocalStorageService.setMorningBriefingEnabled(
                        _morningEnabled,
                      );
                      await LocalStorageService.setNotificationPersona(
                        _personaId,
                      );

                      if (_notifEnabled) {
                        await NotificationService.scheduleAll();
                      } else {
                        await NotificationService.cancelAll();
                      }
                    } catch (e) {
                      print('Error saving notification preferences: $e');
                    }

                    // Refresh parent UI state
                    ref.read(profileProvider.notifier).refresh();

                    if (mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ===== SHARE SCHEDULE & IMPORTER SHEET =====
class ShareScheduleSheet extends ConsumerStatefulWidget {
  final Function(List<dynamic> subjects, List<dynamic> schedule)?
  onSyncDataFetched;
  const ShareScheduleSheet({super.key, this.onSyncDataFetched});

  @override
  ConsumerState<ShareScheduleSheet> createState() => _ShareScheduleSheetState();
}

class _ShareScheduleSheetState extends ConsumerState<ShareScheduleSheet> {
  final TextEditingController _importController = TextEditingController();
  bool _isGenerating = false;
  bool _isImporting = false;
  String _generatedCode = '';

  Future<void> _generateCode() async {
    if (!SupabaseService.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in online to generate sharing codes.'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    HapticFeedback.selectionClick();
    setState(() {
      _isGenerating = true;
      _generatedCode = '';
    });

    try {
      final code = await SupabaseService.generateShareCode();
      setState(() {
        _generatedCode = code;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  Future<void> _importSchedule() async {
    final code = _importController.text.trim();
    if (code.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid share code.'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isImporting = true;
    });

    try {
      final res = await SupabaseService.fetchShareData(code);
      final List<dynamic> subjects = res['subjects'];
      final List<dynamic> schedule = res['schedule'];

      if (mounted) {
        Navigator.pop(context);
        if (widget.onSyncDataFetched != null) {
          widget.onSyncDataFetched!(subjects, schedule);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      setState(() {
        _isImporting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1D2022) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
        ),
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white30 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Share & Import Timetable',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 4),
              const Text(
                'Generate a code to share your weekly schedule classes with friends, or enter their code to import theirs.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 20),

              // GENERATE CONTAINER
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.indigo.withValues(alpha: 0.02),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.indigo.withValues(alpha: 0.05),
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SHARE YOUR SCHEDULE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_isGenerating)
                      const Center(child: CircularProgressIndicator())
                    else if (_generatedCode.isNotEmpty)
                      Center(
                        child: Column(
                          children: [
                            const Text(
                              'YOUR SHARING CODE:',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryLight,
                              ),
                            ),
                            const SizedBox(height: 4),
                            SelectableText(
                              _generatedCode,
                              style: GoogleFonts.outfit(
                                fontSize: 32,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 2,
                                color: AppColors.primaryLight,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: _generatedCode),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Code copied to clipboard!'),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.copy, size: 16),
                              label: const Text('Copy Code'),
                            ),
                          ],
                        ),
                      )
                    else
                      CustomButton(
                        onTap: _generateCode,
                        child: const Text('Generate Share Code'),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // IMPORT CONTAINER
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.indigo.withValues(alpha: 0.02),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.indigo.withValues(alpha: 0.05),
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'IMPORT SCHEDULE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 10),
                    CustomTextField(
                      controller: _importController,
                      hintText: 'Enter 6-char share code',
                      prefixIcon: const Icon(Icons.qr_code),
                    ),
                    const SizedBox(height: 12),
                    _isImporting
                        ? const Center(child: CircularProgressIndicator())
                        : CustomButton(
                            onTap: _importSchedule,
                            child: const Text('Import Schedule'),
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
