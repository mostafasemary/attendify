import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'storage_keys.dart';

class StorageService {
  Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox<Map>(StorageKeys.studentRegistry);
    await Hive.openBox<Map>(StorageKeys.attendanceSessions);
    await Hive.openBox<Map>(StorageKeys.coursesBox);
  }

  Future<Box<Map>> _openMapBox(String name) async {
    return Hive.openBox<Map>(name);
  }

  Future<Box<String>> _openStringBox(String name) async {
    return Hive.openBox<String>(name);
  }

  Future<Box<List>> _openListBox(String name) async {
    return Hive.openBox<List>(name);
  }

  Future<void> saveUserRole(String role) async {
    final box = await _openStringBox(StorageKeys.userRole);
    await box.put(StorageKeys.userRole, role);
  }

  Future<void> clearUserRole() async {
    final box = await _openStringBox(StorageKeys.userRole);
    await box.delete(StorageKeys.userRole);
  }

  Future<String?> readUserRole() async {
    final box = await _openStringBox(StorageKeys.userRole);
    return box.get(StorageKeys.userRole);
  }

  Future<void> saveStudentProfileLink(String link) async {
    final box = await _openStringBox(StorageKeys.studentProfileBox);
    await box.put(StorageKeys.studentProfileLink, link);
  }

  Future<String?> readStudentProfileLink() async {
    final box = await _openStringBox(StorageKeys.studentProfileBox);
    return box.get(StorageKeys.studentProfileLink);
  }

  Future<void> addSessionAttendee({
    required String sessionId,
    required String studentId,
  }) async {
    final box = await _openListBox(StorageKeys.sessionsBox);
    final attendees = (box.get(sessionId) ?? <String>[]).cast<String>();
    if (attendees.contains(studentId)) {
      return;
    }
    attendees.add(studentId);
    await box.put(sessionId, attendees);
  }

  Future<List<String>> readSessionAttendees(String sessionId) async {
    final box = await _openListBox(StorageKeys.sessionsBox);
    return (box.get(sessionId) ?? <String>[]).cast<String>();
  }

  Future<void> saveStudentLink(String link) async {
    final box = await _openListBox(StorageKeys.studentLinksBox);
    final links = (box.get(StorageKeys.studentLinksBox) ?? <String>[]).cast<String>();
    if (links.contains(link)) {
      return;
    }
    links.add(link);
    await box.put(StorageKeys.studentLinksBox, links);
  }

  Future<List<String>> readStudentLinks() async {
    final box = await _openListBox(StorageKeys.studentLinksBox);
    return (box.get(StorageKeys.studentLinksBox) ?? <String>[]).cast<String>();
  }

  // Registry methods
  Future<void> updateStudentInRegistry(int studentId, {String? name}) async {
    final box = Hive.box<Map>(StorageKeys.studentRegistry);
    final existing = box.get(studentId);
    final data = {
      'name': name ?? (existing != null ? existing['name'] : null),
      'last_synced': DateTime.now().toIso8601String(),
    };
    await box.put(studentId, data);
  }

  Map? getStudentFromRegistry(int studentId) {
    return Hive.box<Map>(StorageKeys.studentRegistry).get(studentId);
  }

  // Session methods
  Future<void> addStudentToSession(String sessionId, int studentId, {String? courseId}) async {
    final box = Hive.box<Map>(StorageKeys.attendanceSessions);
    final data = Map<String, dynamic>.from(box.get(sessionId) ?? {});
    
    final List<int> list = List<int>.from(data['studentIds'] ?? []);
    if (!list.contains(studentId)) {
      list.add(studentId);
      data['studentIds'] = list;
      if (courseId != null) data['courseId'] = courseId;
      await box.put(sessionId, data);

      // Also ensure student is in registry
      final registry = Hive.box<Map>(StorageKeys.studentRegistry);
      if (!registry.containsKey(studentId)) {
        await updateStudentInRegistry(studentId);
      }
    }
  }

  Future<void> createSession(String sessionId, String courseId) async {
    final box = Hive.box<Map>(StorageKeys.attendanceSessions);
    await box.put(sessionId, {
      'courseId': courseId,
      'studentIds': <int>[],
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  List<int> getSessionStudents(String sessionId) {
    final box = Hive.box<Map>(StorageKeys.attendanceSessions);
    final data = box.get(sessionId);
    return List<int>.from(data?['studentIds'] ?? []);
  }

  String? getSessionCourseId(String sessionId) {
    final box = Hive.box<Map>(StorageKeys.attendanceSessions);
    final data = box.get(sessionId);
    return data?['courseId'];
  }

  Map<int, Map> getAllRegistryStudents() {
    final box = Hive.box<Map>(StorageKeys.studentRegistry);
    return box.toMap().cast<int, Map>();
  }

  Map<String, Map> getAllSessions() {
    final box = Hive.box<Map>(StorageKeys.attendanceSessions);
    return box.toMap().cast<String, Map>();
  }

  ValueListenable<Box<Map>> getRegistryListenable() {
    return Hive.box<Map>(StorageKeys.studentRegistry).listenable();
  }

  ValueListenable<Box<Map>> getSessionsListenable() {
    return Hive.box<Map>(StorageKeys.attendanceSessions).listenable();
  }

  // Course methods
  Future<void> addCourse(String id, String name, String code) async {
    final box = Hive.box<Map>(StorageKeys.coursesBox);
    await box.put(id, {
      'id': id,
      'name': name,
      'code': code,
    });
  }

  List<Map> getAllCourses() {
    final box = Hive.box<Map>(StorageKeys.coursesBox);
    return box.values.cast<Map>().toList();
  }

  ValueListenable<Box<Map>> getCoursesListenable() {
    return Hive.box<Map>(StorageKeys.coursesBox).listenable();
  }

  Future<void> deleteCourse(String courseId) async {
    final coursesBox = Hive.box<Map>(StorageKeys.coursesBox);
    final sessionsBox = Hive.box<Map>(StorageKeys.attendanceSessions);

    // 1. Delete the course
    await coursesBox.delete(courseId);

    // 2. Find and delete all sessions associated with this course
    final sessionsToDelete = sessionsBox.keys.where((key) {
      final session = sessionsBox.get(key);
      return session != null && session['courseId'] == courseId;
    }).toList();

    for (final key in sessionsToDelete) {
      await sessionsBox.delete(key);
    }
  }

  Future<void> clearAllData() async {
    final roleBox = await _openStringBox(StorageKeys.userRole);
    await roleBox.delete(StorageKeys.userRole);

    final profileBox = await _openStringBox(StorageKeys.studentProfileBox);
    await profileBox.clear();

    final sessionsBox = await _openListBox(StorageKeys.sessionsBox);
    await sessionsBox.clear();

    final studentLinksBox = await _openListBox(StorageKeys.studentLinksBox);
    await studentLinksBox.clear();

    final registryBox = await _openMapBox(StorageKeys.studentRegistry);
    await registryBox.clear();

    final attendanceBox = await _openMapBox(StorageKeys.attendanceSessions);
    await attendanceBox.clear();

    final coursesBox = await _openMapBox(StorageKeys.coursesBox);
    await coursesBox.clear();
  }
}
