import 'package:flutter/foundation.dart';
import '../../../services/gemini_service.dart';
import 'package:csv/csv.dart';

class ParsedSubject {
  final String subjectName;
  final String professor;
  final int totalClasses;
  final int attendedClasses;
  final bool hasPractical;
  final int practicalTotal;
  final int practicalAttended;
  final double confidence;

  ParsedSubject({
    required this.subjectName,
    this.professor = '',
    this.totalClasses = 0,
    this.attendedClasses = 0,
    this.hasPractical = false,
    this.practicalTotal = 0,
    this.practicalAttended = 0,
    this.confidence = 1.0,
  });

  factory ParsedSubject.fromJson(Map<String, dynamic> json) {
    return ParsedSubject(
      subjectName: json['subjectName']?.toString() ?? 'Unknown Subject',
      professor: json['professor']?.toString() ?? '',
      totalClasses: int.tryParse(json['totalClasses']?.toString() ?? '0') ?? 0,
      attendedClasses: int.tryParse(json['attendedClasses']?.toString() ?? '0') ?? 0,
      hasPractical: json['hasPractical'] == true || json['hasPractical'] == 'true',
      practicalTotal: int.tryParse(json['practicalTotal']?.toString() ?? '0') ?? 0,
      practicalAttended: int.tryParse(json['practicalAttended']?.toString() ?? '0') ?? 0,
      confidence: double.tryParse(json['confidence']?.toString() ?? '1.0') ?? 1.0,
    );
  }
}

class SubjectParser {
  /// Parse image containing subjects using Gemini Vision
  static Future<List<ParsedSubject>> parseImages(List<Uint8List> imagesBytes) async {
    final geminiResult = await GeminiService.parseSubjects('', imagesBytes: imagesBytes);
    
    if (geminiResult != null && geminiResult.isNotEmpty) {
      try {
        return geminiResult.map((json) => ParsedSubject.fromJson(json)).toList();
      } catch (e) {
        debugPrint('Error mapping Gemini result to ParsedSubject: $e');
      }
    }
    return [];
  }

  /// Parse raw OCR/pasted text into structured subjects using Gemini with a fallback
  static Future<List<ParsedSubject>> parseText(String rawText) async {
    // 1. Try Gemini first
    final geminiResult = await GeminiService.parseSubjects(rawText);
    
    if (geminiResult != null && geminiResult.isNotEmpty) {
      try {
        return geminiResult.map((json) => ParsedSubject.fromJson(json)).toList();
      } catch (e) {
        debugPrint('Error mapping Gemini result to ParsedSubject: $e');
        // Fallthrough to regex if mapping fails
      }
    }

    // 2. Fallback to basic heuristics/regex if Gemini fails or API key is missing
    debugPrint('Using regex fallback for subject parsing');
    return _parseWithRegex(rawText);
  }

  /// Parse CSV rows into structured subjects
  static Future<List<ParsedSubject>> parseCsv(String csvContent) async {
    try {
      final List<List<dynamic>> rowsAsListOfValues = const CsvToListConverter().convert(csvContent);
      if (rowsAsListOfValues.isEmpty) return [];

      final List<ParsedSubject> subjects = [];
      
      // Assume first row is header, try to find column indices
      final header = rowsAsListOfValues.first.map((e) => e.toString().toLowerCase()).toList();
      int subjectIdx = header.indexWhere((h) => h.contains('subject') || h.contains('course') || h.contains('name'));
      int totalIdx = header.indexWhere((h) => h.contains('total') && !h.contains('lab') && !h.contains('practical'));
      int attendedIdx = header.indexWhere((h) => h.contains('attend') && !h.contains('lab') && !h.contains('practical'));
      
      // Fallback indices if header not found
      if (subjectIdx == -1) subjectIdx = 0;
      if (totalIdx == -1) totalIdx = 1;
      if (attendedIdx == -1) attendedIdx = 2;
      
      for (int i = 1; i < rowsAsListOfValues.length; i++) {
        final row = rowsAsListOfValues[i];
        if (row.length <= subjectIdx) continue;
        
        final String subjectStr = row[subjectIdx].toString();
        if (subjectStr.trim().isEmpty) continue;

        final int total = totalIdx < row.length ? (int.tryParse(row[totalIdx].toString()) ?? 0) : 0;
        final int attended = attendedIdx < row.length ? (int.tryParse(row[attendedIdx].toString()) ?? 0) : 0;
        
        subjects.add(ParsedSubject(
          subjectName: subjectStr,
          totalClasses: total,
          attendedClasses: attended,
          confidence: 0.9,
        ));
      }
      return subjects;
    } catch (e) {
      debugPrint('Error parsing CSV: $e');
      return [];
    }
  }

  static List<ParsedSubject> _parseWithRegex(String text) {
    final List<ParsedSubject> subjects = [];
    final lines = text.split('\n');

    // Very basic fallback: matches strings like "Data Structures 40 35"
    final RegExp basicRegex = RegExp(r'^([a-zA-Z\s]+)\s+(\d+)\s+(\d+)$');

    for (final line in lines) {
      final cleanLine = line.trim();
      if (cleanLine.isEmpty) continue;

      final match = basicRegex.firstMatch(cleanLine);
      if (match != null && match.groupCount >= 3) {
        final name = match.group(1)!.trim();
        final num1 = int.parse(match.group(2)!);
        final num2 = int.parse(match.group(3)!);
        
        // Assume the larger number is total, smaller is attended
        final total = num1 > num2 ? num1 : num2;
        final attended = num1 > num2 ? num2 : num1;

        subjects.add(ParsedSubject(
          subjectName: name,
          totalClasses: total,
          attendedClasses: attended,
          confidence: 0.5,
        ));
      }
    }
    
    return subjects;
  }
  static Future<List<ParsedSubject>> parseMappedImages(List<Uint8List> imagesBytes, List<String> expectedSubjects) async {
    final geminiResult = await GeminiService.parseAttendanceForSubjects(imagesBytes, expectedSubjects);
    
    if (geminiResult != null && geminiResult.isNotEmpty) {
      try {
        return geminiResult.map((json) => ParsedSubject.fromJson(json)).toList();
      } catch (e) {
        debugPrint('Error mapping Gemini result to ParsedSubject: $e');
      }
    }
    return [];
  }
}
