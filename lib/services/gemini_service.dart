import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';

class GeminiService {
  /// The active Gemini model for OCR and parsing (defaults to gemini-flash-lite-latest, configurable via .env)
  static String get _modelName =>
      dotenv.env['GEMINI_MODEL'] ?? 'gemini-flash-lite-latest';

  /// Detects the actual MIME type of the image bytes (supports PNG, JPEG, WEBP)
  static String _detectMimeType(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
      return 'image/jpeg';
    }
    if (bytes.length >= 4 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }

  /// Robustly extracts and decodes a JSON list from a model's response string,
  /// safely handling code fences, preambles, and reasoning tokens.
  static List<Map<String, dynamic>> _extractJsonList(String raw) {
    var text = raw.trim();

    // Look for the array boundaries [ ... ]
    final startIndex = text.indexOf('[');
    final endIndex = text.lastIndexOf(']');
    if (startIndex != -1 && endIndex != -1 && endIndex >= startIndex) {
      text = text.substring(startIndex, endIndex + 1);
    } else {
      if (text.startsWith('```json')) {
        text = text.substring(7);
      } else if (text.startsWith('```')) {
        text = text.substring(3);
      }
      if (text.endsWith('```')) {
        text = text.substring(0, text.length - 3);
      }
      text = text.trim();
    }

    try {
      final List<dynamic> jsonList = jsonDecode(text);
      return jsonList.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error decoding JSON from Gemini: $e. Raw text was: $raw');
      return [];
    }
  }

  /// Executes generateContent with automatic retry on 503 errors and cascading
  /// fallback to secondary healthy models (flash-lite -> 3.5-flash-lite -> 3.5-flash -> 3.8-flash).
  static Future<String?> _generateContentWithFallback(
    List<Content> content, {
    Duration attemptTimeout = const Duration(seconds: 30),
  }) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('Gemini API Key is missing');
      return null;
    }

    final modelsToTry = [
      _modelName,
      if (_modelName != 'gemini-3.5-flash-lite') 'gemini-3.5-flash-lite',
      if (_modelName != 'gemini-3.5-flash') 'gemini-3.5-flash',
      if (_modelName != 'gemini-3.8-flash') 'gemini-3.8-flash',
    ];

    Object? lastError;

    for (final modelName in modelsToTry) {
      for (int attempt = 1; attempt <= 2; attempt++) {
        try {
          debugPrint('Trying Gemini model: $modelName (attempt $attempt)...');
          final model = GenerativeModel(model: modelName, apiKey: apiKey);
          final response = await model
              .generateContent(content)
              .timeout(attemptTimeout);
          final text = response.text;
          if (text != null && text.trim().isNotEmpty) {
            debugPrint('Gemini success with $modelName on attempt $attempt');
            return text;
          }
        } catch (e) {
          lastError = e;
          debugPrint('Attempt $attempt on model $modelName failed: $e');
          final errorStr = e.toString();
          if (errorStr.contains('503') || errorStr.contains('demand')) {
            await Future.delayed(const Duration(milliseconds: 1500));
          } else if (errorStr.contains('TimeoutException')) {
            break; // Switch to next model immediately
          }
        }
      }
    }

    debugPrint('All Gemini fallback models exhausted. Last error: $lastError');
    return null;
  }

  static Future<List<Map<String, dynamic>>?> parseTimetable(
    String text, {
    List<Uint8List>? imagesBytes,
  }) async {
    try {
      final sourceContext = imagesBytes != null && imagesBytes.isNotEmpty
          ? 'the provided images'
          : 'the following text';
      final textSection = text.trim().isNotEmpty
          ? '\nText to parse:\n"""\n$text\n"""\n'
          : '';

      final prompt =
          '''
You are an expert timetable schedule parser. Extract class schedules from $sourceContext.
Respond ONLY with a valid JSON array of objects. No markdown formatting, no backticks, no explanations.
If you can't parse anything, return an empty array [].

INSTRUCTIONS:
1. For "subjectName", extract ONLY the clean core subject name (e.g. "Data Base management System", "Java Programming"). Ignore and strip degree/semester prefixes (e.g. "Btech_AIDS II 2025-2026 Sem III -") and trailing course codes/sections.
2. For "dayOfWeek", map the day: 0 for Monday, 1 for Tuesday, 2 for Wednesday, 3 for Thursday, 4 for Friday, 5 for Saturday, 6 for Sunday. Check any day header (e.g., "Oct 9, Friday" -> 4, "Oct 6, Tuesday" -> 1).
3. For "slotType", identify whether the class is theory or practical:
   - "(PR)" or "Practical" or "Lab" indicates 'practical'.
   - "(PP)" or "Theory" or "Lecture" indicates 'theory'.
   - Default to 'theory' if unspecified.
4. Extract room numbers (e.g. "GU_AI-114", "GU_AI-225") into the "room" field.
5. Extract professor/faculty name (e.g. "Puri Dr. Vartika", "Singh Dr.Pooja") into "professor".
6. Format "startTime" and "endTime" strictly in HH:MM format (24-hour).
$textSection
Required JSON format:
[
  {
    "subjectName": "String (core subject only, no prefixes/suffixes)",
    "professor": "String (optional, empty if not found)",
    "dayOfWeek": 0,
    "startTime": "08:30",
    "endTime": "09:20",
    "room": "GU_AI-114",
    "slotType": "theory",
    "confidence": 0.95
  }
]
''';

      final parts = <Part>[TextPart(prompt)];
      if (imagesBytes != null) {
        for (var bytes in imagesBytes) {
          parts.add(DataPart(_detectMimeType(bytes), bytes));
        }
      }
      final content = [Content.multi(parts)];
      final responseText = await _generateContentWithFallback(content);
      if (responseText == null) return null;
      return _extractJsonList(responseText);
    } catch (e) {
      debugPrint('Error parsing timetable with Gemini: $e');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>?> parseSubjects(
    String text, {
    List<Uint8List>? imagesBytes,
  }) async {
    try {
      final sourceContext = imagesBytes != null && imagesBytes.isNotEmpty
          ? 'the provided images'
          : 'the following text';
      final textSection = text.trim().isNotEmpty
          ? '\nText to parse:\n"""\n$text\n"""\n'
          : '';

      final prompt =
          '''
You are an expert college subject and attendance parser. Extract subjects and their attendance counts from $sourceContext.
Respond ONLY with a valid JSON array of objects. No markdown formatting, no backticks, no explanations.
If you can't parse anything, return an empty array [].

INSTRUCTIONS:
1. Extract ONLY the clean core subject name into "subjectName" (e.g. "Data Base management System", "Java Programming"). Strip out course codes, prefixes, or section tags.
2. In attendance tables:
   - Rows marked with "(PP)", "Theory", or "Lecture" represent theory lectures.
   - Rows marked with "(PR)", "Practical", or "Lab" represent practical/lab sessions.
   - "Attended/Delivered: X/Y" or "X/Y" means X classes attended out of Y total classes held.
3. If a subject appears with both theory "(PP)" and practical "(PR)" rows, MERGE THEM into a single object:
   - "totalClasses": theory classes held
   - "attendedClasses": theory classes attended
   - "hasPractical": true
   - "practicalTotal": practical classes held
   - "practicalAttended": practical classes attended
4. If a subject only has practical classes, set "hasPractical": true, "practicalTotal" and "practicalAttended" accordingly, and set "totalClasses": 0, "attendedClasses": 0.
$textSection
Required JSON format:
[
  {
    "subjectName": "String",
    "professor": "String (optional, empty if not found)",
    "totalClasses": 16,
    "attendedClasses": 11,
    "hasPractical": true,
    "practicalTotal": 6,
    "practicalAttended": 6,
    "confidence": 0.95
  }
]
''';

      final parts = <Part>[TextPart(prompt)];
      if (imagesBytes != null) {
        for (var bytes in imagesBytes) {
          parts.add(DataPart(_detectMimeType(bytes), bytes));
        }
      }
      final content = [Content.multi(parts)];
      final responseText = await _generateContentWithFallback(content);
      if (responseText == null) return null;
      return _extractJsonList(responseText);
    } catch (e) {
      debugPrint('Error parsing subjects with Gemini: $e');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>?> parseAttendanceForSubjects(
    List<Uint8List> imagesBytes,
    List<String> expectedSubjects,
  ) async {
    try {
      final expectedNamesList = expectedSubjects.map((s) => '"$s"').join(', ');

      final prompt =
          '''
You are an expert college attendance parser. Extract subjects and their attendance counts from the provided images.
Target subjects in the user's tracker:
[$expectedNamesList]

INSTRUCTIONS:
1. Examine all attendance tables and rows in the provided image(s).
2. For each subject you see, match it to the closest subject from the target list above (including acronyms like "EDP", "CN", "DBMS", course codes, or abbreviations). If it matches a target subject, use that target subject's exact name. If there are other subjects in the image not in the target list, also include them using their clean name from the image.
3. Distinguish theory and practical:
   - Rows with "(PP)", "Theory", or "Lecture" represent theory classes -> map to "attendedClasses" and "totalClasses".
   - Rows with "(PR)", "Practical", or "Lab" represent practical classes -> map to "practicalAttended" and "practicalTotal".
4. "Attended/Delivered: X/Y" means X classes attended and Y total classes delivered/conducted.
5. Merge theory and practical counts for the same subject into a single JSON object.
6. Do NOT confuse attendance percentage (e.g. 85%) with class counts. Only extract whole number counts of classes.

Respond ONLY with a valid JSON array of objects. No markdown formatting, no backticks, no explanations.
If no attendance tables or rows are found, return [].

Required JSON format:
[
  {
    "subjectName": "String",
    "totalClasses": 10,
    "attendedClasses": 8,
    "practicalTotal": 0,
    "practicalAttended": 0
  }
]
''';

      final parts = <Part>[TextPart(prompt)];
      for (var bytes in imagesBytes) {
        parts.add(DataPart(_detectMimeType(bytes), bytes));
      }
      final content = [Content.multi(parts)];
      debugPrint('Sending attendance OCR request with ${imagesBytes.length} images...');
      final responseText = await _generateContentWithFallback(content);
      if (responseText == null) return null;
      debugPrint('Gemini attendance OCR response: $responseText');
      return _extractJsonList(responseText);
    } catch (e) {
      debugPrint('Error parsing mapped subjects with Gemini: $e');
      return null;
    }
  }
}

