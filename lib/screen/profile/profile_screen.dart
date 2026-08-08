import 'package:cs261_project/screen/profile/profile_edit_screen.dart';
import 'package:cs261_project/model/participant_model.dart';
import 'package:cs261_project/service/profile_service.dart';
import 'package:cs261_project/theme/app_spacing.dart';
import 'package:cs261_project/screen/settings/settings_screen.dart';
import 'package:cs261_project/widget/app_loading_view.dart';
import 'package:cs261_project/widget/app_error_state.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProfileScreen extends StatefulWidget {
  final String instituteId;
  final String? viewUid;
  final bool isNested;

  const ProfileScreen({super.key, required this.instituteId, this.viewUid, this.isNested = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileService _profileService;
  bool _isLoading = true;
  String? _errorMessage;
  ParticipantModel? _profile;
  String? _userDocumentId;

  @override
  void initState() {
    super.initState();
    _profileService = ProfileService(instituteId: widget.instituteId);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final user = FirebaseAuth.instance.currentUser;
    final viewUid = widget.viewUid;
    
    if (user == null && viewUid == null) {
      if (mounted) {
        setState(() {
          _errorMessage = "Authentication error. No profile specified.";
          _isLoading = false;
        });
      }
      return;
    }

    final uid = viewUid ?? user?.uid;
    if (uid == null) {
      if (mounted) {
        setState(() {
          _errorMessage = "Could not identify user.";
          _isLoading = false;
        });
      }
      return;
    }

    _userDocumentId = uid;
    await _loadProfile(uid);
  }

  Future<void> _loadProfile(String uid) async {
    try {
      final profile = await _profileService.getProfile(uid);
      if (mounted) {
        setState(() {
          _profile = profile;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Failed to load profile. Please try again.";
        });
      }
    }
  }

  void _showImageDialog(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.8),
      builder: (_) => Dialog(
        backgroundColor: const Color(0x00000000), // transparent
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.md),
          child: InteractiveViewer(
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              placeholder: (context, url) => const AppLoadingView(),
              errorWidget: (context, url, error) => Container(
                color: Theme.of(context).colorScheme.surface,
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Icon(Icons.broken_image, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 60),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(ThemeData theme) {
    final name = _profile?.name ?? "Alumni";
    final pictureUrl = _profile?.profileImage;
    final isAlumni = _profile?.role == 'alumni';
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Container(
      color: colorScheme.surface,
      child: Column(
        children: [
          // Cover Photo Area
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary,
                  colorScheme.primaryContainer,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // Avatar and Actions
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            transform: Matrix4.translationValues(0.0, -40.0, 0.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: pictureUrl != null ? () => _showImageDialog(pictureUrl) : null,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorScheme.surface,
                      border: Border.all(color: colorScheme.surface, width: 4),
                    ),
                    child: ClipOval(
                      child: pictureUrl != null
                          ? CachedNetworkImage(
                              imageUrl: pictureUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                              errorWidget: (context, url, error) => Icon(Icons.person, color: colorScheme.onSurfaceVariant, size: 50),
                            )
                          : Center(
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'A',
                                style: TextStyle(fontSize: 36, color: colorScheme.primary, fontWeight: FontWeight.bold),
                              ),
                            ),
                    ),
                  ),
                ),
                const Spacer(),
                if (widget.viewUid == null || widget.viewUid == FirebaseAuth.instance.currentUser?.uid)
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          if (_userDocumentId == null) return;
                          final updated = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProfileEditScreen(
                                userDocumentId: _userDocumentId!,
                                instituteId: widget.instituteId,
                              ),
                            ),
                          );
                          if (updated == true && _userDocumentId != null && mounted) {
                            setState(() => _isLoading = true);
                            await _loadProfile(_userDocumentId!);
                          }
                        },
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text("Edit Profile"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.primary,
                          side: BorderSide(color: colorScheme.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.sm)),
                        ),
                      ),
                      AppSpacing.gapSm,
                      IconButton(
                        icon: Icon(Icons.settings, color: colorScheme.onSurfaceVariant),
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(instituteId: widget.instituteId)));
                        },
                      ),
                    ],
                  )
                else
                  ElevatedButton.icon(
                    onPressed: () {
                      // Navigate to messaging
                    },
                    icon: const Icon(Icons.message, size: 16),
                    label: const Text("Message"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.sm)),
                    ),
                  ),
              ],
            ),
          ),
          // Info Section
          Container(
            transform: Matrix4.translationValues(0.0, -20.0, 0.0),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                AppSpacing.gapXs,
                Text(
                  isAlumni 
                    ? (_profile?.company?.isNotEmpty == true ? _profile!.company! : "Alumni Professional")
                    : (_profile?.year?.isNotEmpty == true ? "Class of ${_profile!.year}" : "Student"),
                  style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                AppSpacing.gapSm,
                Row(
                  children: [
                    Icon(Icons.email_outlined, size: 16, color: colorScheme.onSurfaceVariant),
                    AppSpacing.gapXs,
                    Text(_profile?.email ?? "No email provided", style: textTheme.bodyMedium),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(ThemeData theme, {required String title, required List<Widget> children}) {
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(AppSpacing.md),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          AppSpacing.gapMd,
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(ThemeData theme, String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: AppLoadingView(message: "Loading profile..."));
    if (_errorMessage != null || _profile == null) {
      return Scaffold(
        appBar: widget.isNested ? null : AppBar(title: const Text("Profile")),
        body: AppErrorState(message: _errorMessage ?? "Profile not found."),
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: widget.isNested ? null : AppBar(
        title: const Text("Profile"),
        elevation: 0,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(instituteId: widget.instituteId)));
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildProfileHeader(theme),
            
            // Professional Details
            if (_profile?.company?.isNotEmpty == true || _profile?.rollNo?.isNotEmpty == true || _profile?.year?.isNotEmpty == true)
              _buildSectionCard(
                theme,
                title: "Professional Details",
                children: [
                  _buildInfoRow(theme, "Organization", _profile?.company),
                  _buildInfoRow(theme, "Graduating Class", _profile?.year),
                  _buildInfoRow(theme, "Roll Number", _profile?.rollNo),
                ],
              ),

            // About Section
            if (_profile?.bio?.isNotEmpty == true)
              _buildSectionCard(
                theme,
                title: "About",
                children: [
                  Text(
                    _profile!.bio!,
                    style: textTheme.bodyLarge?.copyWith(height: 1.5),
                  ),
                ],
              ),

            // Skills & Interests
            if (_profile?.interest?.isNotEmpty == true)
              _buildSectionCard(
                theme,
                title: "Skills & Interests",
                children: [
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: _profile!.interest!.split(',').map((skill) {
                      final trimmed = skill.trim();
                      if (trimmed.isEmpty) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppSpacing.sm),
                        ),
                        child: Text(
                          trimmed,
                          style: textTheme.bodySmall?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.w600),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),

            // QR Code
            if (widget.viewUid != null && widget.viewUid != FirebaseAuth.instance.currentUser?.uid)
              _buildSectionCard(
                theme,
                title: "Connect Instantly",
                children: [
                  Center(
                    child: QrImageView(
                      data: _profile?.email ?? '',
                      version: QrVersions.auto,
                      size: 150,
                      eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: colorScheme.primary),
                      dataModuleStyle: QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: colorScheme.primary),
                    ),
                  ),
                ],
              ),

            AppSpacing.gapXl,
          ],
        ),
      ),
    );
  }
}
