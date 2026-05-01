import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/storage/storage_service.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/base_screen.dart';
import 'course_details_screen.dart';

class DoctorDashboardScreen extends StatelessWidget {
  const DoctorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = serviceLocator<StorageService>();

    return BaseScreen(
      title: 'Lectures Dashboard',
      actions: [
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'Log out',
          onPressed: () => _confirmLogout(context),
        ),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCourseDialog(context),
        backgroundColor: const Color(0xFF558B80),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Courses',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: storage.getCoursesListenable(),
              builder: (context, Box<Map> box, _) {
                final courses = box.values.toList();
                if (courses.isEmpty) {
                  return const _EmptyState();
                }

                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisSpacing: AppSpacing.md,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: courses.length,
                  itemBuilder: (context, index) {
                    final course = courses[index];
                    return _CourseCard(
                      name: course['name'],
                      code: course['code'],
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CourseDetailsScreen(
                              courseId: course['id'],
                              courseName: course['name'],
                            ),
                          ),
                        );
                      },
                      onLongPress: () => _confirmDeleteCourse(context, course),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddCourseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _AddCourseDialog(),
    );
  }

  void _confirmDeleteCourse(BuildContext context, Map course) {
    showDialog(
      context: context,
      builder: (context) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Colors.red,
            surface: Color(0xFF1E1E1E),
          ),
          dialogTheme: DialogThemeData(
            shape: RoundedRectangleBorder(
              borderRadius: AppSpacing.borderRadiusLg,
            ),
          ),
        ),
        child: AlertDialog(
          title: const Text('Delete Course'),
          content: Text(
            'Are you sure you want to delete ${course['name']} and all its attendance records?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () async {
                await serviceLocator<StorageService>().deleteCourse(course['id']);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    const primaryColor = Color(0xFF558B80);
    const dialogBackground = Color(0xFF1E1E1E);
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: primaryColor,
            background: dialogBackground,
            surface: dialogBackground,
          ),
          dialogTheme: DialogThemeData(
            backgroundColor: dialogBackground,
            shape: RoundedRectangleBorder(
              borderRadius: AppSpacing.borderRadiusLg,
            ),
          ),
        ),
        child: AlertDialog(
          title: const Text('Log out'),
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                'Cancel',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                'Log out',
                style: const TextStyle(color: primaryColor),
              ),
            ),
          ],
        ),
      ),
    );

    if (shouldLogout != true || !context.mounted) {
      return;
    }

    await serviceLocator<StorageService>().clearAllData();
    if (!context.mounted) {
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRouter.roleSelection,
      (_) => false,
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({
    required this.name,
    required this.code,
    required this.onTap,
    this.onLongPress,
  });

  final String name;
  final String code;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: AppSpacing.borderRadiusLg,
      child: Container(
        padding: AppSpacing.cardPadding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppSpacing.borderRadiusLg,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.book, color: const Color(0xFF558B80), size: 32),
            const Spacer(),
            Text(
              name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              code,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddCourseDialog extends StatefulWidget {
  const _AddCourseDialog();

  @override
  State<_AddCourseDialog> createState() => _AddCourseDialogState();
}

class _AddCourseDialogState extends State<_AddCourseDialog> {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Course'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Course Name'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _codeController,
            decoration: const InputDecoration(labelText: 'Course Code'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        AppButton(
          label: 'Add',
          onPressed: _addCourse,
        ),
      ],
    );
  }

  void _addCourse() async {
    FocusScope.of(context).unfocus();
    final name = _nameController.text.trim();
    final code = _codeController.text.trim();
    if (name.isEmpty || code.isEmpty) return;

    final id = const Uuid().v4();
    await serviceLocator<StorageService>().addCourse(id, name, code);
    if (mounted) Navigator.pop(context);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.library_books_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No courses added yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text('Tap the + button to add your first course'),
        ],
      ),
    );
  }
}
