import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cs261_project/utils/email_validator.dart';
import 'package:cs261_project/theme/app_spacing.dart';
import 'package:cs261_project/widget/app_loading_view.dart';
import 'package:cs261_project/widget/app_snackbar.dart';

class AdminAddParticipantScreen extends StatefulWidget {
  /// The admin's own institute. New users can only be created there.
  final String instituteId;
  const AdminAddParticipantScreen({super.key, required this.instituteId});

  @override
  State<AdminAddParticipantScreen> createState() =>
      _AdminAddParticipantScreenState();
}

class _AdminAddParticipantScreenState extends State<AdminAddParticipantScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  String _email = '';
  String _password = '';
  String? _selectedInstituteId;
  String? _selectedRole;
  List<Map<String, dynamic>> _institutes = [];
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _selectedInstituteId = widget.instituteId;
    _loadInstitutes();
  }

  Future<void> _loadInstitutes() async {
    final doc = await _firestore.collection('institutes').doc(widget.instituteId).get();
    if (!mounted) return;
    setState(() {
      _institutes = [
        {'id': widget.instituteId, 'name': doc.data()?['name'] ?? widget.instituteId},
      ];
    });
  }

  Future<void> _addParticipant() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    _formKey.currentState!.save();

    setState(() => _isLoading = true);

    try {
      if (_selectedInstituteId == null) {
        throw Exception("Please select an institute.");
      }

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception("You must be logged in as an admin.");
      }

      if (!EmailValidator.isValid(_email)) {
        throw Exception("Please enter a valid email address.");
      }

      final createParticipant = FirebaseFunctions.instanceFor(region: 'asia-south1')
          .httpsCallable('createParticipantAccount');

      final result = await createParticipant.call({
        'email': _email.trim().toLowerCase(),
        'password': _password.trim(),
        'role': _selectedRole ?? 'student',
        'instituteId': _selectedInstituteId,
        'name': '', 
      });

      if (!mounted) return;
      AppSnackBar.showSuccess(context, result.data['message'] ?? 'Participant added successfully!');

      Navigator.pop(context);
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      String message = "Unable to create account. Please try again.";
      if (e.code == 'invalid-email' || e.code == 'invalid-argument') {
        message = "Please enter a valid email address.";
      } else if (e.code == 'EMAIL_EXISTS' || e.code == 'email-already-exists' || e.code == 'already-exists') {
        message = "This email is already registered.";
      } else if (e.code == 'weak-password') {
        message = "Password must meet minimum requirements.";
      } else if (e.code != 'internal' && e.code != 'unknown' && e.message != null && e.message!.isNotEmpty) {
        message = e.message!;
      }
      AppSnackBar.showError(context, message);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(context, e.toString().replaceAll('Exception: ', ''));
    }



    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text("Add Participant"),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 1,
        shadowColor: theme.dividerColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(AppSpacing.sm),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "Account Details",
                    style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  AppSpacing.gapLg,
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Institute',
                      prefixIcon: Icon(Icons.account_balance_outlined, size: 20),
                      helperText: 'Users are added to your own institute',
                    ),
                    child: Text(
                      _institutes.isEmpty ? 'Loading…' : _institutes.first['name'].toString(),
                      style: textTheme.bodyLarge,
                    ),
                  ),
                  AppSpacing.gapMd,
                  DropdownButtonFormField<String>(
                    initialValue: _selectedRole,
                    items: const [
                      DropdownMenuItem(value: 'student', child: Text('Student')),
                      DropdownMenuItem(value: 'alumni', child: Text('Alumni')),
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    ],
                    onChanged: (v) => setState(() => _selectedRole = v),
                    decoration: const InputDecoration(
                      labelText: 'Select Role',
                    ),
                    validator: (v) => v == null ? 'Please select a role' : null,
                  ),
                  AppSpacing.gapMd,
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    onSaved: (v) => _email = v!,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Please enter your email';
                      if (!EmailValidator.isValid(v)) return 'Please enter a valid email address';
                      return null;
                    },
                  ),
                  AppSpacing.gapMd,
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    obscureText: _obscurePassword,
                    onSaved: (v) => _password = v!,
                    validator: (v) => v!.length < 6
                        ? 'Password must be at least 6 characters'
                        : null,
                  ),
                  AppSpacing.gapXl,
                  _isLoading
                      ? const AppLoadingView()
                      : ElevatedButton(
                          onPressed: _addParticipant,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                          ),
                          child: const Text('Add Participant', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
