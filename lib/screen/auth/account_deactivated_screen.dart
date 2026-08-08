import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cs261_project/screen/auth.dart';
import 'package:cs261_project/service/admin_service.dart';
import 'package:cs261_project/widget/app_snackbar.dart';

class AccountDeactivatedScreen extends StatefulWidget {
  final String instituteId;
  final Map<String, dynamic> participantData;

  const AccountDeactivatedScreen({
    super.key,
    required this.instituteId,
    required this.participantData,
  });

  @override
  State<AccountDeactivatedScreen> createState() => _AccountDeactivatedScreenState();
}

class _AccountDeactivatedScreenState extends State<AccountDeactivatedScreen> {
  bool _isLoading = false;

  Future<void> _requestReactivation() async {
    setState(() => _isLoading = true);

    try {
      final userUid = widget.participantData['uid'] ?? FirebaseAuth.instance.currentUser?.uid ?? '';
      final userEmail = widget.participantData['email'] ?? '';
      final userName = widget.participantData['name'] ?? 'Unknown';

      await AdminService.requestReactivation(
        instituteId: widget.instituteId,
        userUid: userUid,
        userEmail: userEmail,
        userName: userName,
      );

      if (mounted) {
        AppSnackBar.showSuccess(context, "Reactivation request submitted successfully. We will notify you once reviewed.");
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, e.toString().replaceAll("Exception: ", ""));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _returnToLogin() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('lastInstituteId');
      await FirebaseAuth.instance.signOut();
      
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, "Error signing out: $e");
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final name = widget.participantData['name'] ?? 'User';
    final email = widget.participantData['email'] ?? 'Unknown Email';

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.block, size: 80, color: colorScheme.error),
                  const SizedBox(height: 24),
                  Text(
                    "Account Deactivated",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: textTheme.titleLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Your account has been deactivated by an administrator.\n\n"
                    "If you believe this was a mistake, you may request account reactivation.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: textTheme.bodyMedium?.color,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow(Icons.person, name),
                        const Divider(height: 24),
                        _buildInfoRow(Icons.email, email),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  _isLoading
                      ? const CircularProgressIndicator()
                      : Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _requestReactivation,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colorScheme.primary,
                                  foregroundColor: colorScheme.onPrimary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  "Request Reactivation",
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: OutlinedButton(
                                onPressed: _returnToLogin,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: colorScheme.onSurface,
                                  side: BorderSide(color: colorScheme.outline),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  "Return to Login",
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Icon(icon, color: colorScheme.onSurfaceVariant, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 16, color: textTheme.bodyLarge?.color),
          ),
        ),
      ],
    );
  }
}
