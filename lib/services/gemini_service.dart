import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class GeminiService {
  static Future<List<Map<String, dynamic>>?> parseTimetable(
    String text, {
    List<Uint8List>? imagesBytes,
  }) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];

    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('Gemini API Key is missing');
      return null;
    }

    try {
      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);

      final sourceContext = imagesBytes != null && imagesBytes.isNotEmpty
          ? 'the provided images'
          : 'the following text';
      final textSection = text.trim().isNotEmpty
          ? '\nText to parse:\n"""\n$text\n"""\n'
          : '';

      final prompt =
          '''
You are a timetable parser. Extract class schedules from $sourceContext.
Respond ONLY with a valid JSON array of objects. No markdown formatting, no backticks, no explanations.
If you can't parse anything, return an empty array [].
IMPORTANT: For "subjectName", extract ONLY the core subject name (e.g. "Discrete Mathematics"). Ignore and remove prefixes (like "Btech_CSE I 2025-2026 Sem II -") and suffixes (like section numbers or course codes).
Extract "(PP)" or similar tags into "slotType" (e.g. 'practical' if PP, otherwise 'theory').
Extract room numbers (e.g. "GU_AI-121") into the "room" field.
$textSection
Required JSON format:
[
  {
    "subjectName": "String (core subject only, no prefixes/suffixes)",
    "professor": "String (optional, empty if not found)",
    "dayOfWeek": "Integer (0 for Monday, 1 for Tuesday, ..., 6 for Sunday)",
    "startTime": "String in HH:MM format (24-hour)",
    "endTime": "String in HH:MM format (24-hour)",
    "room": "String (e.g. GU_AI-121, empty if not found)",
    "slotType": "String (either 'theory' or 'practical')",
    "confidence": "Double (0.0 to 1.0)"
  }
]
''';

      final parts = <Part>[TextPart(prompt)];
      if (imagesBytes != null) {
        for (var bytes in imagesBytes) {
          parts.add(DataPart('image/jpeg', bytes));
        }
      }
      final content = [Content.multi(parts)];
      final response = await model.generateContent(content);

      String responseText = response.text ?? '[]';

      // Clean up potential markdown formatting from the response
      responseText = responseText.trim();
      if (responseText.startsWith('```json')) {
        responseText = responseText.substring(7);
      } else if (responseText.startsWith('```')) {
        responseText = responseText.substring(3);
      }
      if (responseText.endsWith('```')) {
        responseText = responseText.substring(0, responseText.length - 3);
      }
      responseText = responseText.trim();

      final List<dynamic> jsonList = jsonDecode(responseText);
      return jsonList.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error parsing timetable with Gemini: $e');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>?> parseSubjects(
    String text, {
    List<Uint8List>? imagesBytes,
  }) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];

    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('Gemini API Key is missing');
      return null;
    }

    try {
      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);

      final sourceContext = imagesBytes != null && imagesBytes.isNotEmpty
          ? 'the provided images'
          : 'the following text';
      final textSection = text.trim().isNotEmpty
          ? '\nText to parse:\n"""\n$text\n"""\n'
          : '';

      final prompt =
          '''
You are an attendance parser. Extract subjects and their attendance counts from $sourceContext.
Respond ONLY with a valid JSON array of objects. No markdown formatting, no backticks, no explanations.
If you can't parse anything, return an empty array [].
$textSection
Required JSON format:
[
  {
    "subjectName": "String (e.g., Data Structures, OS)",
    "professor": "String (optional, empty if not found)",
    "totalClasses": "Integer (total theory classes held)",
    "attendedClasses": "Integer (theory classes attended)",
    "hasPractical": "Boolean (true if practical counts are found)",
    "practicalTotal": "Integer (total practical classes held, 0 if none)",
    "practicalAttended": "Integer (practical classes attended, 0 if none)",
    "confidence": "Double (0.0 to 1.0, how sure are you of this extraction)"
  }
]
''';

      final parts = <Part>[TextPart(prompt)];
      if (imagesBytes != null) {
        for (var bytes in imagesBytes) {
          parts.add(DataPart('image/jpeg', bytes));
        }
      }
      final content = [Content.multi(parts)];
      final response = await model.generateContent(content);

      String responseText = response.text ?? '[]';

      // Clean up potential markdown formatting from the response
      responseText = responseText.trim();
      if (responseText.startsWith('```json')) {
        responseText = responseText.substring(7);
      } else if (responseText.startsWith('```')) {
        responseText = responseText.substring(3);
      }
      if (responseText.endsWith('```')) {
        responseText = responseText.substring(0, responseText.length - 3);
      }
      responseText = responseText.trim();

      final List<dynamic> jsonList = jsonDecode(responseText);
      return jsonList.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error parsing subjects with Gemini: \$e');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>?> parseAttendanceForSubjects(
    List<Uint8List> imagesBytes,
    List<String> expectedSubjects,
  ) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];

    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('Gemini API Key is missing');
      return null;
    }

    try {
      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);

      final expectedNamesList = expectedSubjects.map((s) => '"$s"').join(', ');

      final prompt =
          '''
You are an expert attendance parser. Your task is to extract attendance counts from the provided images with 100% accuracy, but ONLY for the following exact subjects:
[$expectedNamesList]

Map the attendance you see to these exact subject names. Ignore any subjects that are not in this list.
CRITICAL RULES FOR 100% ACCURACY:
1. The attendance image might use acronyms or shortcuts for subject names (e.g., "Engineering Design and Prototyping" might be written as "EDP", or "Basic Electrical and Electronics Engineering" as "BEEE"). You must intelligently match these acronyms or partial names from the image to the exact full subject names provided in the list above.
2. Double-check every single character, number, and percentage in the image. Do not confuse theory attendance with practical/lab attendance.
3. If there are typos in the image or slight variations (e.g., "Maths II" vs "Mathematics 2"), map them correctly.
4. Verify your extraction against the provided subject list before outputting.

Respond ONLY with a valid JSON array of objects. No markdown formatting, no backticks, no explanations.
If you can't parse anything, return an empty array [].

Required JSON format:
[
  {
    "subjectName": "String (MUST exactly match one of the provided subject names)",
    "totalClasses": "Integer (total theory classes held)",
    "attendedClasses": "Integer (theory classes attended)",
    "practicalTotal": "Integer (total practical classes held, 0 if none)",
    "practicalAttended": "Integer (practical classes attended, 0 if none)"
  }
]
''';

      final parts = <Part>[TextPart(prompt)];
      for (var bytes in imagesBytes) {
        parts.add(DataPart('image/jpeg', bytes));
      }
      final content = [Content.multi(parts)];
      final response = await model.generateContent(content);

      String responseText = response.text ?? '[]';

      responseText = responseText.trim();
      if (responseText.startsWith('```json')) {
        responseText = responseText.substring(7);
      } else if (responseText.startsWith('```')) {
        responseText = responseText.substring(3);
      }
      if (responseText.endsWith('```')) {
        responseText = responseText.substring(0, responseText.length - 3);
      }
      responseText = responseText.trim();

      final List<dynamic> jsonList = jsonDecode(responseText);
      return jsonList.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error parsing mapped subjects with Gemini: \$e');
      return null;
    }
  }
}
