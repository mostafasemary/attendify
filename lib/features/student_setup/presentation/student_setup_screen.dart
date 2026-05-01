import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/storage/storage_service.dart';
import '../../../shared/widgets/base_screen.dart';
import '../../../core/routing/app_router.dart';

class StudentSetupScreen extends StatefulWidget {
  const StudentSetupScreen({super.key});

  @override
  State<StudentSetupScreen> createState() => _StudentSetupScreenState();
}

class _StudentSetupScreenState extends State<StudentSetupScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: 'Scan College ID',
      actions: [
        IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close',
          onPressed: _handleClose,
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _ScannerFrame(
            controller: _controller,
            onDetect: _handleDetect,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Position your ID QR code inside the frame to register your profile',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Future<void> _handleDetect(BarcodeCapture capture) async {
    if (_isProcessing) {
      return;
    }
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) {
      return;
    }
    final value = barcodes.first.rawValue;
    if (value == null || value.isEmpty) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    await _controller.stop();
    final storage = serviceLocator<StorageService>();
    await storage.saveStudentProfileLink(value);
    await storage.saveStudentLink(value);
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile registered successfully.')),
    );
    Navigator.of(context).pushReplacementNamed(AppRouter.studentBroadcaster);
  }

  Future<void> _handleClose() async {
    await _controller.stop();
    await serviceLocator<StorageService>().clearUserRole();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRouter.roleSelection,
      (_) => false,
    );
  }
}

class _ScannerFrame extends StatelessWidget {
  const _ScannerFrame({
    required this.controller,
    required this.onDetect,
  });

  final MobileScannerController controller;
  final void Function(BarcodeCapture) onDetect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: AppSpacing.borderRadiusLg,
        child: Stack(
          children: [
            MobileScanner(
              controller: controller,
              onDetect: onDetect,
            ),
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: scheme.primary.withOpacity(0.6),
                  width: 2,
                ),
                borderRadius: AppSpacing.borderRadiusLg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
