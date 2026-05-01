import 'package:flutter/material.dart';

import '../../features/home/presentation/pages/home_page.dart';
import '../../features/role_selection/presentation/role_selection_screen.dart';
import '../../features/student_setup/presentation/student_setup_screen.dart';
import '../../features/student_broadcaster/presentation/student_broadcaster_screen.dart';
import '../../features/doctor_dashboard/presentation/doctor_dashboard_screen.dart';
import '../../features/live_scanner/presentation/live_scanner_screen.dart';
import '../../features/lecture_report/presentation/lecture_report_screen.dart';

class AppRouter {
  static const String home = '/';
  static const String roleSelection = '/role';
  static const String studentSetup = '/student-setup';
  static const String studentBroadcaster = '/student-broadcaster';
  static const String doctorDashboard = '/doctor-dashboard';
  static const String liveScanner = '/live-scanner';
  static const String lectureReport = '/lecture-report';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case roleSelection:
        return MaterialPageRoute<void>(
          builder: (_) => const RoleSelectionScreen(),
          settings: settings,
        );
      case studentSetup:
        return MaterialPageRoute<void>(
          builder: (_) => const StudentSetupScreen(),
          settings: settings,
        );
      case studentBroadcaster:
        return MaterialPageRoute<void>(
          builder: (_) => const StudentBroadcasterScreen(),
          settings: settings,
        );
      case doctorDashboard:
        return MaterialPageRoute<void>(
          builder: (_) => const DoctorDashboardScreen(),
          settings: settings,
        );
      case liveScanner:
        final args = settings.arguments as Map<String, dynamic>?;
        final sessionCode = args?['code'] ?? '00';
        final courseId = args?['courseId'];
        return MaterialPageRoute<void>(
          builder: (_) => LiveScannerScreen(
            sessionCode: sessionCode,
            courseId: courseId,
          ),
          settings: settings,
        );
      case lectureReport:
        final courseId = settings.arguments as String? ?? '';
        return MaterialPageRoute<void>(
          builder: (_) => LectureReportScreen(courseId: courseId),
          settings: settings,
        );
      case home:
      default:
        return MaterialPageRoute<void>(
          builder: (_) => const HomePage(),
          settings: settings,
        );
    }
  }
}
