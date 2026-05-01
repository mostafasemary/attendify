import 'dart:math';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/storage/storage_service.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/base_screen.dart';
import '../../../core/routing/app_router.dart';
import '../../lecture_report/application/lecture_report_service.dart';

class CourseDetailsScreen extends StatefulWidget {
  const CourseDetailsScreen({
    super.key,
    required this.courseId,
    required this.courseName,
  });

  final String courseId;
  final String courseName;

  @override
  State<CourseDetailsScreen> createState() => _CourseDetailsScreenState();
}

class _CourseDetailsScreenState extends State<CourseDetailsScreen> {
  final StorageService _storage = serviceLocator<StorageService>();
  final LectureReportService _reportService = LectureReportService();

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: widget.courseName,
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ActionsGrid(
            onCreateSession: () => _showCreateSession(context),
            onSync: _handleSync,
            onReports: () => Navigator.of(context).pushNamed(
              AppRouter.lectureReport,
              arguments: widget.courseId,
            ),
            onAbsenceWarnings: () => _showAbsenceWarningsDialog(context),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Course Sessions',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          _RecentSessionsList(courseId: widget.courseId),
        ],
      ),
    );
  }

  void _showCreateSession(BuildContext context) {
    FocusScope.of(context).unfocus();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: AppSpacing.radiusLg),
      ),
      builder: (_) => _CreateSessionSheet(courseId: widget.courseId),
    );
  }

  void _handleSync() async {
    // Show sync overlay or snackbar
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Starting bulk sync for this course...')),
    );
    await _reportService.syncAllSessionsData(courseId: widget.courseId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sync completed.')),
      );
    }
  }

  void _showAbsenceWarningsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _AbsenceWarningsDialog(
        courseId: widget.courseId,
        courseName: widget.courseName,
        reportService: _reportService,
      ),
    );
  }
}

class _ActionsGrid extends StatelessWidget {
  const _ActionsGrid({
    required this.onCreateSession,
    required this.onSync,
    required this.onReports,
    required this.onAbsenceWarnings,
  });

  final VoidCallback onCreateSession;
  final VoidCallback onSync;
  final VoidCallback onReports;
  final VoidCallback onAbsenceWarnings;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 2,
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _ActionCard(
          title: 'Create Session',
          icon: Icons.add_box_outlined,
          onTap: onCreateSession,
        ),
        _ActionCard(
          title: 'Sync Data',
          icon: Icons.cloud_sync_outlined,
          onTap: onSync,
        ),
        _ActionCard(
          title: 'Lecture Reports',
          icon: Icons.description_outlined,
          onTap: onReports,
        ),
        _ActionCard(
          title: 'Absence Warnings',
          icon: Icons.notification_important_outlined,
          onTap: onAbsenceWarnings,
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
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
          children: [
            Icon(icon, color: const Color(0xFF558B80)),
            const Spacer(),
            Text(title, style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
      ),
    );
  }
}

class _AbsenceWarningsDialog extends StatefulWidget {
  const _AbsenceWarningsDialog({
    required this.courseId,
    required this.courseName,
    required this.reportService,
  });

  final String courseId;
  final String courseName;
  final LectureReportService reportService;

  @override
  State<_AbsenceWarningsDialog> createState() => _AbsenceWarningsDialogState();
}

class _AbsenceWarningsDialogState extends State<_AbsenceWarningsDialog> {
  final _thresholdController = TextEditingController(text: '3');
  String? _selectedFilePath;
  bool _isLoading = false;

  @override
  void dispose() {
    _thresholdController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (result != null) {
      setState(() {
        _selectedFilePath = result.files.single.path;
      });
    }
  }

  Future<void> _generateReport() async {
    FocusScope.of(context).unfocus();
    if (_selectedFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Master Excel file.')),
      );
      return;
    }

    final threshold = int.tryParse(_thresholdController.text) ?? 3;

    setState(() => _isLoading = true);
    try {
      await widget.reportService.generateAbsenceWarningsReport(
        courseId: widget.courseId,
        courseName: widget.courseName,
        masterExcelPath: _selectedFilePath!,
        threshold: threshold,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Absence Warnings'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Master Excel file (Column A: ID, Column B: Name)',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: _isLoading ? null : _pickFile,
            icon: const Icon(Icons.file_upload),
            label: Text(_selectedFilePath == null
                ? 'Select Excel File'
                : 'Selected: ${_selectedFilePath!.split('\\').last.split('/').last}'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF558B80),
              side: const BorderSide(color: Color(0xFF558B80)),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _thresholdController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Absence Threshold',
              helperText: 'Number of absences to trigger warning',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: CircularProgressIndicator(),
          )
        else
          AppButton(
            label: 'Generate Report',
            onPressed: _generateReport,
          ),
      ],
    );
  }
}

class _RecentSessionsList extends StatelessWidget {
  const _RecentSessionsList({required this.courseId});

  final String courseId;

  @override
  Widget build(BuildContext context) {
    final storage = serviceLocator<StorageService>();

    return ValueListenableBuilder(
      valueListenable: storage.getSessionsListenable(),
      builder: (context, Box<Map> box, _) {
        final sessions = box.toMap().entries.where((e) => e.value['courseId'] == courseId).toList();
        
        if (sessions.isEmpty) {
          return const _EmptyState();
        }

        return Column(
          children: sessions.map((entry) {
            final sessionId = entry.key;
            final data = entry.value;
            final studentIds = List<int>.from(data['studentIds'] ?? []);
            
            return Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: AppSpacing.cardPadding,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppSpacing.borderRadiusMd,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Session $sessionId'),
                  Text('${studentIds.length} Attendees'),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _CreateSessionSheet extends StatefulWidget {
  const _CreateSessionSheet({required this.courseId});

  final String courseId;

  @override
  State<_CreateSessionSheet> createState() => _CreateSessionSheetState();
}

class _CreateSessionSheetState extends State<_CreateSessionSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.text = (Random().nextInt(90) + 10).toString();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Create New Session', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Session Code',
              suffixIcon: IconButton(
                icon: const Icon(Icons.shuffle),
                onPressed: () {
                  final code = Random().nextInt(90) + 10;
                  _controller.text = code.toString();
                },
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Start Discovery',
            onPressed: _startSession,
          ),
        ],
      ),
    );
  }

  void _startSession() async {
    FocusScope.of(context).unfocus();
    final code = _controller.text.trim();
    if (code.isEmpty) return;

    await serviceLocator<StorageService>().createSession(code, widget.courseId);
    
    if (mounted) {
      Navigator.pop(context);
      Navigator.of(context).pushNamed(
        AppRouter.liveScanner,
        arguments: {'code': code, 'courseId': widget.courseId},
      );
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final color = const Color(0xFF558B80).withOpacity(0.55);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 64, color: color),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No data available yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}
