import 'dart:io';

import 'package:cs261_project/service/profile_service.dart';
import 'package:cs261_project/screen/student/user_home_screen.dart';
import 'package:cs261_project/theme/app_spacing.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cs261_project/widget/app_loading_view.dart';
import 'package:cs261_project/widget/app_snackbar.dart';

class ProfileEditScreen extends StatefulWidget {
  final String instituteId;
  final String userDocumentId;
  const ProfileEditScreen(
      {super.key, required this.userDocumentId, required this.instituteId});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final ProfileService _profileService;

  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController rollCtrl = TextEditingController();
  final TextEditingController interestCtrl = TextEditingController();
  final TextEditingController bioCtrl = TextEditingController();
  final TextEditingController yearCtrl = TextEditingController();
  final TextEditingController companyCtrl = TextEditingController();

  bool _isLoading = true;
  bool _isUploading = false;
  bool _isSaving = false;
  String? _profilePicUrl;
  String _role = 'student';

  @override
  void initState() {
    super.initState();
    _profileService = ProfileService(instituteId: widget.instituteId);
    _loadProfile();
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    rollCtrl.dispose();
    interestCtrl.dispose();
    bioCtrl.dispose();
    yearCtrl.dispose();
    companyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await _profileService.getProfile(widget.userDocumentId);
    if (profile != null && mounted) {
      setState(() {
        _role = profile.role;
        nameCtrl.text = profile.name;
        rollCtrl.text = profile.rollNo ?? '';
        interestCtrl.text = profile.interest ?? '';
        bioCtrl.text = profile.bio ?? '';
        yearCtrl.text = profile.year ?? '';
        companyCtrl.text = profile.company ?? '';
        _profilePicUrl = profile.profileImage;
      });
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      setState(() => _isUploading = true);

      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source, imageQuality: 80);
      if (pickedFile == null) return;

      File file = File(pickedFile.path);
      final user = FirebaseAuth.instance.currentUser!;

      final storageRef = FirebaseStorage.instance
          .ref('profile_pictures/${user.uid}/avatar.jpg');
      await storageRef.putFile(file);
      final downloadUrl = await storageRef.getDownloadURL();

      setState(() {
        _profilePicUrl = downloadUrl;
      });
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, "Image upload failed");
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);

      try {
        final updateData = {
          'name': nameCtrl.text.trim(),
          if (_role == 'student' || _role == 'admin') 'rollNo': rollCtrl.text.trim(),
          if (_role != 'admin') 'year': yearCtrl.text.trim(),
          'interest': interestCtrl.text.trim(),
          'bio': bioCtrl.text.trim(),
          if (_role == 'alumni') 'company': companyCtrl.text.trim(),
          'profileImage': _profilePicUrl,
          'isProfileComplete': true,
        };

        await _profileService.saveProfile(widget.userDocumentId, updateData);

        if (!mounted) return;

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => UserHomeScreen(instituteId: widget.instituteId),
          ),
          (route) => false,
        );
      } catch (e) {
        if (mounted) {
          AppSnackBar.showError(context, "Could not save profile");
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  void _showImageSourceActionSheet() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.md)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: colorScheme.onSurface),
              title: Text('Choose from Gallery', style: textTheme.bodyLarge),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt_outlined, color: colorScheme.onSurface),
              title: Text('Take a Photo', style: textTheme.bodyLarge),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileAvatar(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Center(
      child: Stack(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.surface,
              border: Border.all(color: theme.dividerColor, width: 2),
            ),
            child: _isUploading
                ? const Center(child: CircularProgressIndicator())
                : ClipOval(
                    child: _profilePicUrl != null
                        ? CachedNetworkImage(
                            imageUrl: _profilePicUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                            errorWidget: (context, url, error) => Icon(Icons.person, color: colorScheme.onSurfaceVariant, size: 60),
                          )
                        : Icon(Icons.person, color: colorScheme.onSurfaceVariant, size: 60),
                  ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _isUploading ? null : _showImageSourceActionSheet,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: colorScheme.surface, width: 2),
                ),
                child: Icon(Icons.camera_alt, color: colorScheme.onPrimary, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(ThemeData theme, {
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isNumeric = false,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
        ),
        validator: (value) => (value == null || value.isEmpty) ? 'Required' : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: AppLoadingView(message: 'Loading profile...'),
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text("Edit Profile"),
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        actions: [
          if (!_isSaving)
            TextButton(
              onPressed: _saveProfile,
              child: const Text("Save", style: TextStyle(fontWeight: FontWeight.bold)),
            )
          else
            const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildProfileAvatar(theme),
              AppSpacing.gapXl,

              Text("Personal Details", style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              AppSpacing.gapMd,
              _buildTextField(
                theme,
                controller: nameCtrl,
                label: 'Full Name',
                icon: Icons.person_outline,
              ),

              if (_role == 'student' || _role == 'admin')
                _buildTextField(
                  theme,
                  controller: rollCtrl,
                  label: 'Roll Number',
                  icon: Icons.badge_outlined,
                  isNumeric: true,
                ),

              if (_role != 'admin')
                _buildTextField(
                  theme,
                  controller: yearCtrl,
                  label: 'Graduation Year',
                  icon: Icons.school_outlined,
                  isNumeric: true,
                ),

              if (_role == 'alumni')
                _buildTextField(
                  theme,
                  controller: companyCtrl,
                  label: 'Organization / Company',
                  icon: Icons.business_outlined,
                ),

              AppSpacing.gapLg,
              Text("Professional Profile", style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              AppSpacing.gapMd,

              _buildTextField(
                theme,
                controller: interestCtrl,
                label: _role == 'alumni' ? 'Areas of Expertise (Comma separated)' : 'Interests & Skills (Comma separated)',
                icon: Icons.star_outline,
              ),

              _buildTextField(
                theme,
                controller: bioCtrl,
                label: 'Biography',
                icon: Icons.edit_note_outlined,
                maxLines: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
