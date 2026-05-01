import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/storage/storage_service.dart';
import '../../../shared/widgets/base_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  static const String _doctorPin = '54';

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: 'Select Role',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose your role',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _RoleCard(
                  label: 'I am a Doctor',
                  icon: Icons.school,
                  onTap: () => _handleDoctorAccess(context),
                ),
                const SizedBox(height: AppSpacing.lg),
                _RoleCard(
                  label: 'I am a Student',
                  icon: Icons.person,
                  onTap: () => _selectRole(
                    context,
                    role: 'student',
                    routeName: AppRouter.studentSetup,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectRole(
    BuildContext context, {
    required String role,
    required String routeName,
  }) async {
    await serviceLocator<StorageService>().saveUserRole(role);
    if (!context.mounted) {
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil(
      routeName,
      (_) => false,
    );
  }

  Future<void> _handleDoctorAccess(BuildContext context) async {
    final controller = TextEditingController();
    const primaryColor = Color(0xFF558B80);
    const dialogBackground = Color(0xFF1E1E1E);

    final approved = await showDialog<bool>(
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
          title: const Text('Doctor Access'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Enter the Doctor PIN'),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Doctor PIN',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                'Cancel',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () {
                final enteredPin = controller.text.trim();
                if (enteredPin != _doctorPin) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Incorrect PIN'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: Text(
                'Continue',
                style: const TextStyle(color: primaryColor),
              ),
            ),
          ],
        ),
      ),
    );

    controller.dispose();
    if (approved != true || !context.mounted) {
      return;
    }

    await _selectRole(
      context,
      role: 'doctor',
      routeName: AppRouter.doctorDashboard,
    );
  }
}

class _RoleCard extends StatefulWidget {
  const _RoleCard({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: double.infinity,
          padding: AppSpacing.cardPadding,
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: AppSpacing.borderRadiusLg,
            border: Border.all(color: scheme.primary.withOpacity(0.15)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 48, color: scheme.primary),
              const SizedBox(height: AppSpacing.md),
              Text(
                widget.label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _setPressed(bool pressed) {
    if (_pressed == pressed) {
      return;
    }
    setState(() {
      _pressed = pressed;
    });
  }
}
