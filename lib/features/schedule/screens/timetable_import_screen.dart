import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../../core/constants/colors.dart';
import '../services/timetable_parser.dart';

class TimetableImportScreen extends StatefulWidget {
  const TimetableImportScreen({super.key});

  @override
  State<TimetableImportScreen> createState() => _TimetableImportScreenState();
}

class _TimetableImportScreenState extends State<TimetableImportScreen> {
  bool _isProcessing = false;
  String _processingMessage = '';

  void _setProcessing(bool processing, [String message = '']) {
    setState(() {
      _isProcessing = processing;
      _processingMessage = message;
    });
  }

  void _toast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.redBg : const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _processParsedSlots(List<ParsedSlot> slots) async {
    _setProcessing(false);
    if (slots.isEmpty) {
      _toast('Could not find any timetable data', isError: true);
      return;
    }
    // Navigate to review screen with parsed slots
    context.push('/review-timetable', extra: slots);
  }

  // 1. Photo Import
  Future<void> _importFromPhoto() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();
    if (pickedFiles.isEmpty) return;

    _setProcessing(true, 'AI is scanning images...');
    try {
      List<Uint8List> imagesBytes = [];
      for (var file in pickedFiles) {
        imagesBytes.add(await file.readAsBytes());
      }
      final slots = await TimetableParser.parseImages(imagesBytes);
      if (mounted) {
        await _processParsedSlots(slots);
      }
    } catch (e) {
      if (mounted) {
        _setProcessing(false);
        _toast('Failed to process images: $e', isError: true);
      }
    }
  }

  // 2. CSV Import
  Future<void> _importFromCsv() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null && result.files.single.path != null) {
        _setProcessing(true, 'Parsing CSV...');
        final file = File(result.files.single.path!);
        final content = await file.readAsString();
        final slots = await TimetableParser.parseCsv(content);
        await _processParsedSlots(slots);
      }
    } catch (e) {
      _setProcessing(false);
      _toast('Failed to parse CSV: $e', isError: true);
    }
  }

  // 3. Paste as Text
  void _showPasteBottomSheet() {
    final TextEditingController controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1D2022) : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Paste Timetable Text',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  maxLines: 8,
                  decoration: InputDecoration(
                    hintText: 'Monday\n9:00 - 10:00 Data Structures\n...',
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF242729)
                        : Colors.grey.withValues(alpha: 0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    final text = controller.text.trim();
                    if (text.isEmpty) return;
                    Navigator.pop(context);

                    _setProcessing(true, 'AI is parsing text...');
                    final slots = await TimetableParser.parseText(text);
                    await _processParsedSlots(slots);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Parse Text',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF4F46E5), Color(0xFFB4136D)],
          ).createShader(bounds),
          child: const Text(
            'Import Timetable',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Skip manual entry — import your schedule instantly',
                  style: TextStyle(color: AppColors.outlineLight, fontSize: 14),
                ),
                const SizedBox(height: 32),

                _buildOptionCard(
                  title: 'Scan from Photo',
                  subtitle: 'Take a photo of your printed timetable',
                  icon: Icons.camera_alt,
                  isPrimary: true,
                  isDark: isDark,
                  onTap: _importFromPhoto,
                ),
                const SizedBox(height: 16),
                _buildOptionCard(
                  title: 'Paste as Text',
                  subtitle: 'Copy-paste your timetable text',
                  icon: Icons.paste,
                  isDark: isDark,
                  onTap: _showPasteBottomSheet,
                ),
                const SizedBox(height: 16),
                _buildOptionCard(
                  title: 'From CSV File',
                  subtitle: 'Import from spreadsheet',
                  icon: Icons.table_chart,
                  isDark: isDark,
                  onTap: _importFromCsv,
                ),
              ],
            ),
          ),

          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1D2022) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Color(0xFF4F46E5)),
                      const SizedBox(height: 16),
                      Text(
                        _processingMessage,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOptionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    bool isPrimary = false,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF242729) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPrimary
                ? const Color(0xFF4F46E5).withValues(alpha: 0.5)
                : (isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.withValues(alpha: 0.2)),
            width: isPrimary ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isPrimary
                    ? const Color(0xFF4F46E5).withValues(alpha: 0.1)
                    : (isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.grey.withValues(alpha: 0.1)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isPrimary
                    ? const Color(0xFF4F46E5)
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.outlineLight,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.outlineLight),
          ],
        ),
      ),
    );
  }
}
