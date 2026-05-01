import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/storage/storage_service.dart';
import '../../../core/utils/id_extractor.dart';
import '../../../shared/widgets/base_screen.dart';

class LiveScannerScreen extends StatefulWidget {
  const LiveScannerScreen({
    super.key,
    required this.sessionCode,
    this.courseId,
  });

  final String sessionCode;
  final String? courseId;

  @override
  State<LiveScannerScreen> createState() => _LiveScannerScreenState();
}

class _LiveScannerScreenState extends State<LiveScannerScreen> {
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  final StorageService _storage = serviceLocator<StorageService>();

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: 'Live Session Active',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _PulsingDot(color: Colors.red),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Session ${widget.sessionCode}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ValueListenableBuilder(
            valueListenable: _storage.getSessionsListenable(),
            builder: (context, Box<Map> box, _) {
              final students = _storage.getSessionStudents(widget.sessionCode);
              return Text(
                '${students.length} Students Recorded',
                style: Theme.of(context).textTheme.titleMedium,
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: _storage.getSessionsListenable(),
              builder: (context, Box<Map> sessionBox, _) {
                final students = _storage.getSessionStudents(widget.sessionCode);
                
                return ValueListenableBuilder(
                  valueListenable: _storage.getRegistryListenable(),
                  builder: (context, Box<Map> registryBox, _) {
                    return ListView.separated(
                      itemCount: students.length,
                      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final id = students[index];
                        final registryEntry = _storage.getStudentFromRegistry(id);
                        final name = registryEntry?['name'];

                        return AnimatedSwitcher(
                          duration: const Duration(milliseconds: 500),
                          child: Container(
                            key: ValueKey(name ?? id.toString()),
                            padding: AppSpacing.cardPadding,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: AppSpacing.borderRadiusMd,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name ?? 'New Student Detected',
                                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                              fontWeight: name != null ? FontWeight.bold : FontWeight.normal,
                                            ),
                                      ),
                                      Text(
                                        'ID: $id',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
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
            ),
          ),
        ],
      ),
    );
  }

  void _startScan() {
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) async {
      for (final result in results) {
        if (!_isValidPacket(result)) continue;

        final url = _extractUrl(result);
        if (url == null) continue;

        final idStr = IdExtractor.extractId(url);
        if (idStr == null) continue;

        final id = int.tryParse(idStr);
        if (id == null) continue;

        final currentStudents = _storage.getSessionStudents(widget.sessionCode);
        if (currentStudents.contains(id)) continue;

        await _storage.addStudentToSession(
          widget.sessionCode, 
          id, 
          courseId: widget.courseId,
        );
        HapticFeedback.lightImpact();
      }
    });

    FlutterBluePlus.startScan(
      timeout: const Duration(minutes: 30),
      androidUsesFineLocation: true,
    );
  }

  String? _extractUrl(ScanResult result) {
    if (result.advertisementData.localName.startsWith('http')) {
      return result.advertisementData.localName;
    }
    
    for (final data in result.advertisementData.serviceData.values) {
      final decoded = String.fromCharCodes(data);
      if (decoded.contains('id=')) return decoded;
    }

    final name = result.advertisementData.localName;
    if (RegExp(r'^\d+$').hasMatch(name)) {
      return 'Http://193.227.17.23/st/s.aspx?id=$name';
    }

    return null;
  }

  bool _isValidPacket(ScanResult result) {
    return result.rssi > -90;
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});

  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 1).animate(_controller),
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
