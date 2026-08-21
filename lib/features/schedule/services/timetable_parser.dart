import 'package:csv/csv.dart';
import '../../../services/gemini_service.dart';
import 'package:flutter/foundation.dart';

class ParsedSlot {
  final String subjectName;
  final String professor;
  final int dayOfWeek; // 0=Mon..6=Sun
  final String startTime;
  final String endTime;
  final String room;
  final String slotType; // theory or practical
  final double confidence;

  ParsedSlot({
    required this.subjectName,
    this.professor = '',
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.room = 'unknown',
    this.slotType = 'theory',
    this.confidence = 1.0,
  });

  factory ParsedSlot.fromJson(Map<String, dynamic> json) {
    return ParsedSlot(
      subjectName: json['subjectName']?.toString() ?? 'Unknown Subject',
      professor: json['professor']?.toString() ?? '',
      dayOfWeek: int.tryParse(json['dayOfWeek']?.toString() ?? '0') ?? 0,
      startTime: json['startTime']?.toString() ?? '09:00',
      endTime: json['endTime']?.toString() ?? '10:00',
      room: json['room']?.toString() ?? 'unknown',
      slotType: json['slotType']?.toString().toLowerCase() == 'practical' ? 'practical' : 'theory',
      confidence: double.tryParse(json['confidence']?.toString() ?? '1.0') ?? 1.0,
    );
  }
}

class TimetableParser {
  /// Parse image containing schedule using Gemini Vision
  static Future<List<ParsedSlot>> parseImages(List<Uint8List> imagesBytes) async {
    final geminiResult = await GeminiService.parseTimetable('', imagesBytes: imagesBytes);
    
    if (geminiResult != null && geminiResult.isNotEmpty) {
      try {
        return geminiResult.map((json) => ParsedSlot.fromJson(json)).toList();
      } catch (e) {
        debugPrint('Error mapping Gemini result to ParsedSlot: $e');
      }
    }
    return [];
  }

  /// Parse raw OCR/pasted text into structured slots using Gemini with a regex fallback
  static Future<List<ParsedSlot>> parseText(String rawText) async {
    // 1. Try Gemini first
    final geminiResult = await GeminiService.parseTimetable(rawText);
    
    if (geminiResult != null && geminiResult.isNotEmpty) {
      try {
        return geminiResult.map((json) => ParsedSlot.fromJson(json)).toList();
      } catch (e) {
        debugPrint('Error mapping Gemini result to ParsedSlot: $e');
        // Fallthrough to regex if mapping fails
      }
    }

    // 2. Fallback to basic heuristics/regex if Gemini fails or API key is missing
    debugPrint('Using regex fallback for timetable parsing');
    return _parseWithRegex(rawText);
  }

  /// Parse CSV rows into structured slots
  static Future<List<ParsedSlot>> parseCsv(String csvContent) async {
    try {
      final List<List<dynamic>> rowsAsListOfValues = const CsvToListConverter().convert(csvContent);
      if (rowsAsListOfValues.isEmpty) return [];

      final List<ParsedSlot> slots = [];
      
      // Assume first row is header, try to find column indices
      final header = rowsAsListOfValues.first.map((e) => e.toString().toLowerCase()).toList();
      int dayIdx = header.indexWhere((h) => h.contains('day'));
      int timeIdx = header.indexWhere((h) => h.contains('time'));
      int subjectIdx = header.indexWhere((h) => h.contains('subject') || h.contains('course'));
      int roomIdx = header.indexWhere((h) => h.contains('room') || h.contains('venue'));
      
      // Fallback indices if header not found
      if (dayIdx == -1) dayIdx = 0;
      if (timeIdx == -1) timeIdx = 1;
      if (subjectIdx == -1) subjectIdx = 2;
      
      for (int i = 1; i < rowsAsListOfValues.length; i++) {
        final row = rowsAsListOfValues[i];
        if (row.length <= subjectIdx) continue;
        
        final String dayStr = dayIdx < row.length ? row[dayIdx].toString() : '';
        final String timeStr = timeIdx < row.length ? row[timeIdx].toString() : '';
        final String subjectStr = row[subjectIdx].toString();
        final String roomStr = (roomIdx != -1 && roomIdx < row.length) ? row[roomIdx].toString() : 'unknown';
        
        if (subjectStr.trim().isEmpty) continue;

        int dayOfWeek = _detectDay(dayStr) ?? 0;
        var (startTime, endTime) = _detectTimeRange(timeStr);
        
        slots.add(ParsedSlot(
          subjectName: subjectStr,
          dayOfWeek: dayOfWeek,
          startTime: startTime ?? '09:00',
          endTime: endTime ?? '10:00',
          room: roomStr,
          confidence: 0.9, // High confidence for CSV
        ));
      }
      return slots;
    } catch (e) {
      debugPrint('Error parsing CSV: $e');
      return [];
    }
  }

  static List<ParsedSlot> _parseWithRegex(String text) {
    final List<ParsedSlot> slots = [];
    final lines = text.split('\n');
    
    int currentDay = -1;

    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      
      // Try to detect day
      final detectedDay = _detectDay(line);
      if (detectedDay != null) {
        currentDay = detectedDay;
        // If line is just a day name, continue
        if (line.trim().length < 10) continue;
      }
      
      // If we don't have a day, skip
      if (currentDay == -1) continue;

      // Try to extract time
      var (startTime, endTime) = _detectTimeRange(line);
      if (startTime != null) {
        // Remove time and day from line to get subject
        String subjectPart = line;
        
        // Basic cleanup
        subjectPart = subjectPart.replaceAll(RegExp(r'\d{1,2}:\d{2}\s*(AM|PM)?\s*-\s*\d{1,2}:\d{2}\s*(AM|PM)?', caseSensitive: false), '');
        subjectPart = subjectPart.replaceAll(RegExp(r'\d{1,2}\s*-\s*\d{1,2}', caseSensitive: false), ''); // e.g. 9-10
        
        final dayStr = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'][currentDay];
        subjectPart = subjectPart.replaceAll(RegExp(dayStr, caseSensitive: false), '');
        
        subjectPart = subjectPart.trim();
        if (subjectPart.isEmpty) continue;

        slots.add(ParsedSlot(
          subjectName: subjectPart,
          dayOfWeek: currentDay,
          startTime: startTime,
          endTime: endTime ?? _addHour(startTime),
          confidence: 0.6, // Lower confidence for regex fallback
        ));
      }
    }
    
    return slots;
  }

  static int? _detectDay(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('monday') || lower.contains('mon')) return 0;
    if (lower.contains('tuesday') || lower.contains('tue')) return 1;
    if (lower.contains('wednesday') || lower.contains('wed')) return 2;
    if (lower.contains('thursday') || lower.contains('thu')) return 3;
    if (lower.contains('friday') || lower.contains('fri')) return 4;
    if (lower.contains('saturday') || lower.contains('sat')) return 5;
    if (lower.contains('sunday') || lower.contains('sun')) return 6;
    return null;
  }

  static (String?, String?) _detectTimeRange(String text) {
    // Matches 09:00 - 10:00 or 9:00 AM - 10:00 AM
    final RegExp timeRegex = RegExp(r'(\d{1,2}:\d{2})\s*(?:AM|PM|am|pm)?\s*[-|to]\s*(\d{1,2}:\d{2})\s*(?:AM|PM|am|pm)?');
    final match = timeRegex.firstMatch(text);
    
    if (match != null && match.groupCount >= 2) {
      // Basic formatting, assumes 24hr or mostly correct parsed strings
      String start = match.group(1)!;
      String end = match.group(2)!;
      if (start.length == 4) start = '0$start'; // pad 9:00 to 09:00
      if (end.length == 4) end = '0$end';
      return (start, end);
    }
    
    // Matches simple '9-10'
    final RegExp simpleRegex = RegExp(r'(\d{1,2})\s*-\s*(\d{1,2})');
    final simpleMatch = simpleRegex.firstMatch(text);
    if (simpleMatch != null && simpleMatch.groupCount >= 2) {
      int s = int.parse(simpleMatch.group(1)!);
      int e = int.parse(simpleMatch.group(2)!);
      return ('${s.toString().padLeft(2, '0')}:00', '${e.toString().padLeft(2, '0')}:00');
    }
    
    return (null, null);
  }
  
  static String _addHour(String time) {
    try {
      final parts = time.split(':');
      int h = int.parse(parts[0]) + 1;
      return '${h.toString().padLeft(2, '0')}:${parts[1]}';
    } catch (_) {
      return time;
    }
  }
}
