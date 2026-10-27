import 'dart:io';

import 'package:cs261_project/service/profile_service.dart';
import 'package:cs261_project/screen/student/user_home_screen.dart';
import 'package:cs261_project/theme/app_spacing.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cs261_project/widget/app_avatar.dart';
import 'package:cs261_project/widget/app_section.dart';
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
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: _isUploading ? null : _showImageSourceActionSheet,
                child: _isUploading
                    ? Container(
                        width: 112,
                        height: 112,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: colorScheme.surfaceContainer),
                        child: const Center(child: CircularProgressIndicator()),
                      )
                    : ValueListenableBuilder<TextEditingValue>(
                        valueListenable: nameCtrl,
                        builder: (_, value, __) => AppAvatar(
                          name: value.text.isEmpty ? '?' : value.text,
                          imageUrl: _profilePicUrl,
                          radius: 53,
                          ring: true,
                        ),
                      ),
              ),
              Positioned(
                bottom: 2,
                right: 2,
                child: Material(
                  color: colorScheme.primary,
                  shape: CircleBorder(side: BorderSide(color: theme.scaffoldBackgroundColor, width: 3)),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _isUploading ? null : _showImageSourceActionSheet,
                    child: Padding(
                      padding: const EdgeInsets.all(9),
                      child: Icon(Icons.photo_camera_outlined, color: colorScheme.onPrimary, size: 18),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _isUploading ? null : _showImageSourceActionSheet,
            child: Text(_profilePicUrl?.isNotEmpty == true ? 'Change photo' : 'Add a photo'),
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
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
        textCapitalization: isNumeric ? TextCapitalization.none : TextCapitalization.sentences,
        minLines: maxLines > 1 ? 3 : 1,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          alignLabelWithHint: maxLines > 1,
          prefixIcon: maxLines > 1 ? null : Icon(icon, size: 20),
        ),
        validator: (value) => (value == null || value.isEmpty) ? 'Required' : null,
      ),
    );
  }

  Widget _buildSection(ThemeData theme, String title, String subtitle, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(subtitle, style: theme.textTheme.bodySmall),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
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

    return Scaffold(
      appBar: AppBar(title: const Text("Edit profile")),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _buildProfileAvatar(theme),
            const SizedBox(height: 12),

            _buildSection(theme, "About you", "How others will see you across Alma Roots.", [
              _buildTextField(
                theme,
                controller: nameCtrl,
                label: 'Full name',
                icon: Icons.person_outline_rounded,
              ),
              if (_role == 'student' || _role == 'admin')
                _buildTextField(
                  theme,
                  controller: rollCtrl,
                  label: 'Roll number',
                  icon: Icons.tag_rounded,
                  isNumeric: true,
                ),
              if (_role != 'admin')
                _buildTextField(
                  theme,
                  controller: yearCtrl,
                  label: 'Graduation year',
                  icon: Icons.school_outlined,
                  isNumeric: true,
                ),
              if (_role == 'alumni')
                _buildTextField(
                  theme,
                  controller: companyCtrl,
                  label: 'Organization / company',
                  icon: Icons.apartment_rounded,
                ),
            ]),

            _buildSection(theme, "Professional profile", "Helps alumni and mentors find you in search.", [
              _buildTextField(
                theme,
                controller: interestCtrl,
                label: _role == 'alumni' ? 'Areas of expertise' : 'Interests & skills',
                hint: 'e.g. Flutter, Product design, Finance',
                icon: Icons.auto_awesome_outlined,
              ),
              _buildTextField(
                theme,
                controller: bioCtrl,
                label: 'Bio',
                hint: 'A few lines about what you do and what you are looking for',
                icon: Icons.notes_rounded,
                maxLines: 6,
              ),
            ]),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: _isSaving ? null : _saveProfile,
              child: _isSaving
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: colorScheme.onPrimary),
                    )
                  : const Text('Save profile'),
            ),
          ),
        ),
      ),
    );
  }
}
