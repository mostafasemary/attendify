import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/storage/storage_service.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/base_screen.dart';
import '../application/attendance_broadcaster.dart';

enum BroadcasterState { idle, broadcasting, success }

class StudentBroadcasterScreen extends StatefulWidget {
  const StudentBroadcasterScreen({super.key});

  @override
  State<StudentBroadcasterScreen> createState() => _StudentBroadcasterScreenState();
}

class _StudentBroadcasterScreenState extends State<StudentBroadcasterScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _sessionController = TextEditingController();
  late final AttendanceBroadcaster _broadcaster;
  BroadcasterState _state = BroadcasterState.idle;
  bool _isLoading = false;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _broadcaster = AttendanceBroadcaster(FlutterBlePeripheral());
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    _broadcaster.stop();
    _sessionController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: 'Student Profile',
      resizeToAvoidBottomInset: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'Log out',
          onPressed: _confirmLogout,
        ),
      ],
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  child: Icon(
                    Icons.person,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  'Student Profile',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Container(
              padding: AppSpacing.cardPadding,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: AppSpacing.borderRadiusLg,
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Attendance Submission',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _sessionController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Session Code',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: _isLoading ? 'Broadcasting...' : 'Submit Attendance',
                    onPressed: _isLoading ? null : _startBroadcast,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (_state == BroadcasterState.broadcasting)
              Center(
                child: GestureDetector(
                  onTap: _stopBroadcast,
                  child: _PulseIndicator(controller: _pulseController),
                ),
              ),
            if (_state == BroadcasterState.success) _SuccessState(onReset: _reset),
          ],
        ),
      ),
    );
  }

  Future<void> _startBroadcast() async {
    FocusScope.of(context).unfocus();
    final sessionCode = _sessionController.text.trim();
    if (sessionCode.isEmpty) {
      return;
    }

    final ready = await _broadcaster.isReady();
    if (!ready) {
      await _broadcaster.stop();
      if (!mounted) {
        return;
      }
      _pulseController.stop();
      setState(() {
        _isLoading = false;
        _state = BroadcasterState.idle;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bluetooth must be enabled to record attendance.'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _state = BroadcasterState.broadcasting;
    });

    await _broadcaster.start();
    _pulseController.repeat(reverse: true);

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _stopBroadcast() async {
    await _broadcaster.stop();
    HapticFeedback.mediumImpact();
    if (!mounted) {
      return;
    }
    _pulseController.stop();
    setState(() {
      _state = BroadcasterState.success;
    });
  }

  void _reset() {
    setState(() {
      _state = BroadcasterState.idle;
    });
  }

  Future<void> _confirmLogout() async {
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

    if (shouldLogout != true || !mounted) {
      return;
    }

    await _broadcaster.stop();
    await serviceLocator<StorageService>().clearAllData();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRouter.roleSelection,
      (_) => false,
    );
  }
}

class _PulseIndicator extends StatelessWidget {
  const _PulseIndicator({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    final animation = Tween<double>(begin: 0.7, end: 1.1).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeInOut),
    );

    return ScaleTransition(
      scale: animation,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        ),
        child: Icon(
          Icons.wifi_tethering,
          size: 48,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _SuccessState extends StatelessWidget {
  const _SuccessState({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          Icons.check_circle,
          size: 64,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Attendance Recorded Successfully',
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(label: 'New Session', onPressed: onReset),
      ],
    );
  }
}
