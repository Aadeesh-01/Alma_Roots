import 'package:flutter/material.dart';
import 'package:cs261_project/model/participant_model.dart';
import 'package:cs261_project/service/admin_service.dart';
import 'package:cs261_project/widget/app_avatar.dart';
import 'package:cs261_project/widget/app_section.dart';
import 'package:cs261_project/widget/app_snackbar.dart';

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

    if (_emailController.text.trim().toLowerCase() != widget.user.email.trim().toLowerCase()) {
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
      AppSnackBar.showSuccess(context, 'Scheduled. The account will be deleted in 24 hours.');
      Navigator.pop(context, true); // Return true indicating success
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool get _confirmed =>
      _emailController.text.trim().toLowerCase() == widget.user.email.trim().toLowerCase() &&
      _deleteController.text == 'DELETE';

  Widget _bullet(ThemeData theme, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.error),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final user = widget.user;
    final name = user.name.isNotEmpty ? user.name : user.email.split('@').first;

    return Scaffold(
      appBar: AppBar(title: const Text('Delete permanently')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          AppSurfaceCard(
            child: Row(
              children: [
                AppAvatar(name: name, imageUrl: user.profileImage, radius: 26),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: textTheme.titleMedium),
                      Text(user.email, style: textTheme.bodySmall),
                      const SizedBox(height: 6),
                      RoleBadge(role: user.role, dense: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colorScheme.error.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: colorScheme.error),
                    const SizedBox(width: 8),
                    Text('This cannot be undone', style: textTheme.titleSmall?.copyWith(color: colorScheme.error)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'After a 24-hour grace period, the account is deleted automatically:',
                  style: textTheme.bodyMedium,
                ),
                _bullet(theme, Icons.key_off_outlined, 'Their login is removed'),
                _bullet(theme, Icons.person_remove_outlined, 'Their profile is replaced with "Deleted User"'),
                _bullet(theme, Icons.search_off_rounded, 'They disappear from search and networking'),
                const SizedBox(height: 10),
                Text(
                  'Messages they sent stay in other people\'s chats. You can cancel any time during the grace period from the Deletion queue.',
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Type their email to confirm', style: textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: user.email,
              prefixIcon: const Icon(Icons.mail_outline_rounded, size: 20),
            ),
          ),
          const SizedBox(height: 16),
          Text('Type DELETE', style: textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _deleteController,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'DELETE',
              prefixIcon: Icon(Icons.keyboard_outlined, size: 20),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(_errorMessage!, style: textTheme.bodyMedium?.copyWith(color: colorScheme.error)),
          ],
          const SizedBox(height: 28),
          SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: _isLoading || !_confirmed ? null : _scheduleDeletion,
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              child: _isLoading
                  ? SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(color: colorScheme.onError, strokeWidth: 2.5))
                  : const Text('Schedule permanent deletion'),
            ),
          ),
        ],
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
