import 'dart:io';
import 'package:excel/excel.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/storage/storage_service.dart';

class LectureReportService {
  final StorageService _storage = serviceLocator<StorageService>();

  /// Syncs all unique student IDs that have a null name in the registry for a specific course.
  Future<void> syncAllSessionsData({required String courseId, Function(double)? onProgress}) async {
    final registry = _storage.getAllRegistryStudents();
    final sessions = _storage.getAllSessions();
    final Set<int> idsToSync = {};

    // Filter sessions by courseId
    for (final sessionData in sessions.values) {
      if (sessionData['courseId'] == courseId) {
        final List<int> studentIds = List<int>.from(sessionData['studentIds'] ?? []);
        for (final id in studentIds) {
          final registryData = registry[id];
          if (registryData == null || registryData['name'] == null) {
            idsToSync.add(id);
          }
        }
      }
    }

    if (idsToSync.isEmpty) {
      onProgress?.call(1.0);
      return;
    }

    int completed = 0;
    final total = idsToSync.length;

    await Future.wait(idsToSync.map((id) async {
      try {
        final response = await http.get(Uri.parse('Http://193.227.17.23/st/s.aspx?id=$id'));
        if (response.statusCode == 200) {
          final document = html.parse(response.body);
          final nameElement = document.querySelector('#lblName') ?? 
                            document.querySelector('.name') ??
                            document.querySelector('title');
          
          String? name = nameElement?.text.trim();
          if (name != null && name.contains(' - ')) {
            name = name.split(' - ').first;
          }

          if (name != null && name.isNotEmpty) {
            await _storage.updateStudentInRegistry(id, name: name);
          }
        }
      } catch (e) {
        // Log error
      } finally {
        completed++;
        onProgress?.call(completed / total);
      }
    }));
  }

  /// Generates an Excel report for a specific course and shares it.
  Future<void> generateAndShareReport({required String courseId, double? marksPerLecture}) async {
    final sessions = _storage.getAllSessions();
    final registry = _storage.getAllRegistryStudents();

    final Map<int, int> attendanceCounts = {};
    for (final sessionData in sessions.values) {
      if (sessionData['courseId'] == courseId) {
        final List<int> studentIds = List<int>.from(sessionData['studentIds'] ?? []);
        for (final id in studentIds) {
          attendanceCounts[id] = (attendanceCounts[id] ?? 0) + 1;
        }
      }
    }

    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];

    final headerStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#558B80'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
    );

    final headerRow = [
      TextCellValue('Name'),
      TextCellValue('Attendance Count'),
      if (marksPerLecture != null) TextCellValue('Total Marks'),
    ];
    sheet.appendRow(headerRow);

    for (var i = 0; i < headerRow.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.cellStyle = headerStyle;
    }

    for (final entry in attendanceCounts.entries) {
      final id = entry.key;
      final count = entry.value;
      final studentData = registry[id];
      final name = studentData?['name'] ?? 'ID: $id';
      
      final row = [
        TextCellValue(name),
        IntCellValue(count),
        if (marksPerLecture != null) DoubleCellValue(count * marksPerLecture),
      ];
      sheet.appendRow(row);
    }

    final fileBytes = excel.save();
    final directory = await getTemporaryDirectory();
    final filePath = '${directory.path}/Attendance_Report_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    final file = File(filePath);
    await file.writeAsBytes(fileBytes!);

    await Share.shareXFiles([XFile(filePath)], text: 'Attendance Report');
  }

  /// Generates an Absence Warnings report based on a Master Excel file and a threshold.
  Future<void> generateAbsenceWarningsReport({
    required String courseId,
    required String courseName,
    required String masterExcelPath,
    required int threshold,
  }) async {
    final sessions = _storage.getAllSessions();
    final courseSessions = sessions.values.where((s) => s['courseId'] == courseId).toList();
    final totalSessionsHeld = courseSessions.length;

    // Load Master Excel
    final bytes = await File(masterExcelPath).readAsBytes();
    final masterExcel = Excel.decodeBytes(bytes);
    final masterSheet = masterExcel.tables.values.first;

    final Map<int, int> attendanceCounts = {};
    for (final sessionData in courseSessions) {
      final List<int> studentIds = List<int>.from(sessionData['studentIds'] ?? []);
      for (final id in studentIds) {
        attendanceCounts[id] = (attendanceCounts[id] ?? 0) + 1;
      }
    }

    final warningsExcel = Excel.createExcel();
    final warningsSheet = warningsExcel['Sheet1'];

    // Header Style
    final headerStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#C62828'), // Red for warnings
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
    );

    final headerRow = [
      TextCellValue('Student ID'),
      TextCellValue('Student Name'),
      TextCellValue('Total Absences'),
    ];
    warningsSheet.appendRow(headerRow);

    for (var i = 0; i < headerRow.length; i++) {
      final cell = warningsSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.cellStyle = headerStyle;
    }

    // Parse students from Master Excel (Column A: ID, Column B: Name)
    for (var i = 0; i < masterSheet.maxRows; i++) {
      final row = masterSheet.rows[i];
      if (row.length < 2) continue;

      final idValue = row[0]?.value;
      final nameValue = row[1]?.value;

      if (idValue == null || nameValue == null) continue;

      int? studentId;
      if (idValue is IntCellValue) {
        studentId = idValue.value;
      } else if (idValue is TextCellValue) {
        studentId = int.tryParse(idValue.value.toString());
      } else {
        studentId = int.tryParse(idValue.toString());
      }

      if (studentId == null) continue;

      final count = attendanceCounts[studentId] ?? 0;
      final absences = totalSessionsHeld - count;

      if (absences >= threshold) {
        warningsSheet.appendRow([
          IntCellValue(studentId),
          TextCellValue(nameValue.toString()),
          IntCellValue(absences),
        ]);
      }
    }

    final fileBytes = warningsExcel.save();
    final directory = await getTemporaryDirectory();
    final filePath = '${directory.path}/Warnings_${courseName.replaceAll(' ', '_')}.xlsx';
    final file = File(filePath);
    await file.writeAsBytes(fileBytes!);

    await Share.shareXFiles([XFile(filePath)], text: 'Absence Warnings for $courseName');
  }
}
