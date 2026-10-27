import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cs261_project/theme/app_spacing.dart';
import 'package:cs261_project/service/feedback_service.dart';

class ReportBugScreen extends StatefulWidget {
  final String instituteId;
  const ReportBugScreen({super.key, required this.instituteId});

  @override
  State<ReportBugScreen> createState() => _ReportBugScreenState();
}

class _ReportBugScreenState extends State<ReportBugScreen> {
  final _formKey = GlobalKey<FormState>();
  
  String _category = 'Bug';
  final List<String> _categories = [
    'Bug', 'UI Issue', 'Feature Request', 'Performance Issue', 'Security Concern', 'Other'
  ];

  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _stepsController = TextEditingController();
  final _expectedController = TextEditingController();
  final _actualController = TextEditingController();
  final _screenshotController = TextEditingController();
  final _deviceInfoController = TextEditingController();

  bool _isLoading = false;
  bool _isSuccess = false;
  String? _errorMsg;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _stepsController.dispose();
    _expectedController.dispose();
    _actualController.dispose();
    _screenshotController.dispose();
    _deviceInfoController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not authenticated");

      // Attempt to get user role
      String role = 'unknown';
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          role = doc.data()?['role'] ?? 'unknown';
        }
      } catch (_) {}

      await FeedbackService.submitFeedback(
        uid: user.uid,
        instituteId: widget.instituteId,
        userRole: role,
        category: _category,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        stepsToReproduce: _stepsController.text.trim(),
        expectedResult: _expectedController.text.trim(),
        actualResult: _actualController.text.trim(),
        screenshotUrl: _screenshotController.text.trim(),
        deviceInfo: _deviceInfoController.text.trim(),
      );

      setState(() {
        _isLoading = false;
        _isSuccess = true;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMsg = "Failed to submit report: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Report Bug / Feedback'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 1,
        shadowColor: theme.dividerColor,
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: colorScheme.primary),
            AppSpacing.gapMd,
            Text("Submitting report...", style: textTheme.bodyLarge),
          ],
        ),
      );
    }

    if (_isSuccess) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: Colors.green, size: 64),
              ),
              AppSpacing.gapLg,
              Text("Thank You!", style: textTheme.headlineMedium),
              AppSpacing.gapMd,
              Text(
                "Thank you for helping improve the platform. Your report has been submitted successfully.",
                style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              AppSpacing.gapXXl,
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.sm)),
                ),
                child: const Text("Return to Settings"),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_errorMsg != null) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colorScheme.error.withValues(alpha: 0.1),
                  border: Border.all(color: colorScheme.error),
                  borderRadius: BorderRadius.circular(AppSpacing.sm),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: colorScheme.error),
                    AppSpacing.gapMd,
                    Expanded(child: Text(_errorMsg!, style: textTheme.bodyMedium?.copyWith(color: colorScheme.error))),
                  ],
                ),
              ),
              AppSpacing.gapLg,
            ],
            
            Text("Category", style: textTheme.titleMedium),
            AppSpacing.gapXs,
            DropdownButtonFormField<String>(
              value: _category,
              isExpanded: true,
              decoration: _buildInputDecoration(theme, "Select category"),
              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _category = val);
              },
            ),
            
            AppSpacing.gapLg,
            _buildTextField(theme, "Title", _titleController, "Brief summary of the issue", required: true),
            
            AppSpacing.gapLg,
            _buildTextField(theme, "Description", _descController, "Detailed description of what happened", required: true, maxLines: 4),
            
            AppSpacing.gapLg,
            _buildTextField(theme, "Steps to Reproduce", _stepsController, "1. Go to...\n2. Click on...\n3. See error", required: true, maxLines: 3),
            
            AppSpacing.gapLg,
            _buildTextField(theme, "Expected Result", _expectedController, "What should have happened", required: true, maxLines: 2),
            
            AppSpacing.gapLg,
            _buildTextField(theme, "Actual Result", _actualController, "What actually happened", required: true, maxLines: 2),
            
            AppSpacing.gapXXl,
            Text("Optional Information", style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            AppSpacing.gapMd,
            
            _buildTextField(theme, "Screenshot URL", _screenshotController, "Link to image (imgur, drive, etc.)", required: false),
            
            AppSpacing.gapLg,
            _buildTextField(theme, "Device Information", _deviceInfoController, "e.g., iPhone 13 Pro, Chrome on Windows", required: false),
            
            AppSpacing.gapXXl,
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.sm)),
                ),
                child: const Text("Submit Report", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            AppSpacing.gapXXl,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(ThemeData theme, String label, TextEditingController controller, String hint, {bool required = false, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: theme.textTheme.titleMedium),
            if (!required) Text(" (Optional)", style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            if (required) Text(" *", style: TextStyle(color: theme.colorScheme.error)),
          ],
        ),
        AppSpacing.gapXs,
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: _buildInputDecoration(theme, hint),
          validator: required ? (value) {
            if (value == null || value.trim().isEmpty) {
              return "This field is required";
            }
            return null;
          } : null,
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration(ThemeData theme, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
      filled: true,
      fillColor: theme.colorScheme.surface,
      contentPadding: const EdgeInsets.all(AppSpacing.md),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        borderSide: BorderSide(color: theme.dividerColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        borderSide: BorderSide(color: theme.dividerColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        borderSide: BorderSide(color: theme.colorScheme.primary),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        borderSide: BorderSide(color: theme.colorScheme.error),
      ),
    );
  }
}
