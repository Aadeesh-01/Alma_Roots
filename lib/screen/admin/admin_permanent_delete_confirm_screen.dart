import 'package:flutter/material.dart';
import 'package:cs261_project/model/participant_model.dart';
import 'package:cs261_project/service/admin_service.dart';

class AdminPermanentDeleteConfirmScreen extends StatefulWidget {
  final String instituteId;
  final ParticipantModel user;

  const AdminPermanentDeleteConfirmScreen({
    super.key,
    required this.instituteId,
    required this.user,
  });

  @override
  State<AdminPermanentDeleteConfirmScreen> createState() => _AdminPermanentDeleteConfirmScreenState();
}

class _AdminPermanentDeleteConfirmScreenState extends State<AdminPermanentDeleteConfirmScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _deleteController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _scheduleDeletion() async {
    setState(() => _errorMessage = null);

    if (_emailController.text.trim() != widget.user.email) {
      setState(() => _errorMessage = "Email does not match.");
      return;
    }

    if (_deleteController.text != "DELETE") {
      setState(() => _errorMessage = "You must type DELETE exactly to confirm.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      await AdminService.schedulePermanentDeletion(
        instituteId: widget.instituteId,
        targetUid: widget.user.uid,
        targetEmail: widget.user.email,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green, // Success
          content: Text('Permanent deletion scheduled. It will execute in 24 hours.'),
        ),
      );
      Navigator.pop(context, true); // Return true indicating success
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = "Error: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text('Schedule Permanent Deletion', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.error.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 48, color: colorScheme.error),
                  const SizedBox(height: 12),
                  Text(
                    "WARNING",
                    style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.error),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "This account will be permanently removed after 24 hours.\n\n"
                    "The following data will be removed:\n"
                    "• Authentication account\n"
                    "• Participant profile\n"
                    "• Search visibility\n"
                    "• Networking profile\n\n"
                    "Chat history will be preserved using tombstoning.",
                    style: textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              "Confirm User Details",
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "User Email: ${widget.user.email}",
              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Type exact email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Confirm Action",
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Type DELETE to continue.",
              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _deleteController,
              decoration: const InputDecoration(
                labelText: 'Type DELETE',
                border: OutlineInputBorder(),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.error, fontWeight: FontWeight.bold),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _scheduleDeletion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.error,
                  foregroundColor: colorScheme.onError,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: colorScheme.onError, strokeWidth: 2))
                    : const Text("Schedule Permanent Deletion", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _deleteController.dispose();
    super.dispose();
  }
}
