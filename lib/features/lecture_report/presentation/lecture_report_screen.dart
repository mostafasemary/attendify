import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/storage/storage_service.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/base_screen.dart';
import '../application/lecture_report_service.dart';

class LectureReportScreen extends StatefulWidget {
  const LectureReportScreen({super.key, required this.courseId});

  final String courseId;

  @override
  State<LectureReportScreen> createState() => _LectureReportScreenState();
}

class _LectureReportScreenState extends State<LectureReportScreen> {
  final LectureReportService _service = LectureReportService();
  final StorageService _storage = serviceLocator<StorageService>();
  bool _isSyncing = false;
  double _syncProgress = 0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        BaseScreen(
          title: 'Advanced Reports',
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderActions(),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Student Records',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(child: _buildStudentList()),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Generate Excel Report',
                onPressed: _showReportDialog,
              ),
            ],
          ),
        ),
        if (_isSyncing) _buildSyncOverlay(),
      ],
    );
  }

  Widget _buildHeaderActions() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: AppSpacing.cardPadding,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: AppSpacing.borderRadiusMd,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Database Status',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                ValueListenableBuilder(
                  valueListenable: _storage.getRegistryListenable(),
                  builder: (context, Box<Map> box, _) {
                    final total = box.length;
                    final named = box.values.where((v) => v['name'] != null).length;
                    return Text(
                      '$named / $total Names Synced',
                      style: Theme.of(context).textTheme.titleMedium,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        IconButton.filledTonal(
          onPressed: _isSyncing ? null : _handleSync,
          icon: const Icon(Icons.sync),
          tooltip: 'Sync Student Names',
        ),
      ],
    );
  }

  Widget _buildStudentList() {
    return ValueListenableBuilder(
      valueListenable: _storage.getSessionsListenable(),
      builder: (context, Box<Map> sessionBox, _) {
        // Collect students for this course
        final sessions = sessionBox.toMap().entries.where((e) => e.value['courseId'] == widget.courseId).toList();
        final Set<int> studentIds = {};
        for (final s in sessions) {
          studentIds.addAll(List<int>.from(s.value['studentIds'] ?? []));
        }

        if (studentIds.isEmpty) {
          return const _EmptyState();
        }

        return ValueListenableBuilder(
          valueListenable: _storage.getRegistryListenable(),
          builder: (context, Box<Map> registryBox, _) {
            final ids = studentIds.toList();
            return ListView.separated(
              itemCount: ids.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final id = ids[index];
                final data = registryBox.get(id);
                final name = data?['name'];

                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  child: Container(
                    key: ValueKey(name ?? id.toString()),
                    padding: AppSpacing.cardPadding,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: AppSpacing.borderRadiusMd,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          child: Text(
                            (name != null && name.isNotEmpty) ? name[0].toUpperCase() : '?',
                            style: TextStyle(color: Theme.of(context).colorScheme.primary),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name ?? 'Unknown Student',
                                style: TextStyle(
                                  fontWeight: name != null ? FontWeight.bold : FontWeight.normal,
                                  color: name != null ? null : Colors.grey,
                                ),
                              ),
                              Text('ID: $id', style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSyncOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: AppSpacing.borderRadiusLg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Syncing Student Data...',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              LinearProgressIndicator(value: _syncProgress),
              const SizedBox(height: AppSpacing.sm),
              Text('${(_syncProgress * 100).toInt()}%'),
            ],
          ),
        ),
      ),
    );
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => _ReportSettingsDialog(
        onConfirm: (marks) {
          _service.generateAndShareReport(
            courseId: widget.courseId,
            marksPerLecture: marks,
          );
        },
      ),
    );
  }

  Future<void> _handleSync() async {
    setState(() {
      _isSyncing = true;
      _syncProgress = 0;
    });

    await _service.syncAllSessionsData(
      courseId: widget.courseId,
      onProgress: (p) {
        if (mounted) setState(() => _syncProgress = p);
      },
    );

    if (mounted) setState(() => _isSyncing = false);
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
          Icon(Icons.inbox, size: 64, color: color),
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

class _ReportSettingsDialog extends StatefulWidget {
  const _ReportSettingsDialog({required this.onConfirm});

  final Function(double?) onConfirm;

  @override
  State<_ReportSettingsDialog> createState() => _ReportSettingsDialogState();
}

class _ReportSettingsDialogState extends State<_ReportSettingsDialog> {
  bool _includeMarks = false;
  final TextEditingController _marksController = TextEditingController();

  @override
  void dispose() {
    _marksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFFF6F5F0), // Cream background
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Report Settings',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFF558B80), // Teal accent
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text('Would you like to include marks for attendance?'),
            const SizedBox(height: AppSpacing.md),
            SwitchListTile(
              title: const Text('Enable Marks'),
              value: _includeMarks,
              activeColor: const Color(0xFF558B80),
              onChanged: (v) => setState(() => _includeMarks = v),
            ),
            if (_includeMarks) ...[
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _marksController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Marks per Lecture',
                  prefixIcon: Icon(Icons.grade),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Export & Share',
              onPressed: () {
                final marks = _includeMarks ? double.tryParse(_marksController.text) : null;
                Navigator.pop(context);
                widget.onConfirm(marks);
              },
            ),
          ],
        ),
      ),
    );
  }
}
