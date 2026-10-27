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
import 'package:cs261_project/screen/message/chat_screen.dart';
import 'package:cs261_project/theme/app_colors.dart';
import 'package:cs261_project/widget/app_avatar.dart';
import 'package:cs261_project/widget/app_section.dart';

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

  bool get _isOwnProfile =>
      widget.viewUid == null || widget.viewUid == FirebaseAuth.instance.currentUser?.uid;

  Future<void> _openEdit() async {
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
  }

  void _openChat() {
    final p = _profile;
    if (p == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          otherUserId: p.uid,
          otherUserName: p.name,
          instituteId: widget.instituteId,
        ),
      ),
    );
  }

  Widget _buildProfileHeader(ThemeData theme) {
    final p = _profile!;
    final name = p.name.isNotEmpty ? p.name : p.email.split('@').first;
    final pictureUrl = p.profileImage;
    final hasPicture = pictureUrl != null && pictureUrl.trim().isNotEmpty;
    final cs = theme.colorScheme;
    final text = theme.textTheme;

    final subtitle = p.role == 'alumni'
        ? (p.company?.isNotEmpty == true ? p.company! : 'Alumni')
        : (p.year?.isNotEmpty == true ? 'Class of ${p.year}' : (p.role == 'admin' ? 'Administrator' : 'Student'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: 132,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -30,
                    top: -40,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.gold.withValues(alpha: 0.25), width: 1.5),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 60,
                    bottom: -50,
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 32,
              bottom: -48,
              child: GestureDetector(
                onTap: hasPicture ? () => _showImageDialog(pictureUrl) : null,
                child: AppAvatar(name: name, imageUrl: pictureUrl, radius: 48, ring: true),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_isOwnProfile) ...[
                FilledButton.tonalIcon(
                  onPressed: _openEdit,
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit profile'),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Settings',
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(instituteId: widget.instituteId)));
                  },
                  icon: const Icon(Icons.settings_outlined, size: 20),
                ),
              ] else
                FilledButton.icon(
                  onPressed: _openChat,
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  label: const Text('Message'),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: text.headlineMedium),
              const SizedBox(height: 4),
              Text(subtitle, style: text.titleMedium?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  RoleBadge(role: p.role),
                  if (p.isMentor) _buildFlag(theme, Icons.volunteer_activism_outlined, 'Mentor'),
                  if (p.isHiring) _buildFlag(theme, Icons.work_outline_rounded, 'Hiring'),
                  if (p.email.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.mail_outline_rounded, size: 15, color: cs.onSurfaceVariant),
                        const SizedBox(width: 5),
                        Text(p.email, style: text.bodySmall),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFlag(ThemeData theme, IconData icon, String label) {
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: cs.onSecondaryContainer),
          const SizedBox(width: 4),
          Text(label, style: theme.textTheme.labelSmall?.copyWith(color: cs.onSecondaryContainer)),
        ],
      ),
    );
  }

  Widget _buildSectionCard(ThemeData theme, {required String title, IconData? icon, required List<Widget> children}) {
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: AppSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: cs.primary),
                  const SizedBox(width: 8),
                ],
                Text(title, style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(ThemeData theme, IconData icon, String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Icon(icon, size: 18, color: cs.onSurfaceVariant),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodySmall),
                Text(value, style: theme.textTheme.titleSmall),
              ],
            ),
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
    final p = _profile!;

    return Scaffold(
      appBar: widget.isNested ? null : AppBar(title: const Text("Profile")),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 32),
        children: [
          _buildProfileHeader(theme),
          const SizedBox(height: 24),

          if (p.company?.isNotEmpty == true || p.rollNo?.isNotEmpty == true || p.year?.isNotEmpty == true)
            _buildSectionCard(
              theme,
              title: "Details",
              icon: Icons.badge_outlined,
              children: [
                _buildInfoRow(theme, Icons.apartment_rounded, "Organization", p.company),
                _buildInfoRow(theme, Icons.school_outlined, "Graduating class", p.year),
                _buildInfoRow(theme, Icons.tag_rounded, "Roll number", p.rollNo),
                _buildInfoRow(theme, Icons.account_tree_outlined, "Department", p.department),
              ],
            ),

          if (p.bio?.isNotEmpty == true)
            _buildSectionCard(
              theme,
              title: "About",
              icon: Icons.notes_rounded,
              children: [
                Text(p.bio!, style: textTheme.bodyLarge?.copyWith(height: 1.6)),
              ],
            ),

          if (p.interest?.isNotEmpty == true)
            _buildSectionCard(
              theme,
              title: p.role == 'alumni' ? "Expertise" : "Skills & interests",
              icon: Icons.auto_awesome_outlined,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: p.interest!
                      .split(',')
                      .map((s) => s.trim())
                      .where((s) => s.isNotEmpty)
                      .map((skill) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              skill,
                              style: textTheme.labelMedium?.copyWith(color: colorScheme.onPrimaryContainer),
                            ),
                          ))
                      .toList(),
                ),
              ],
            ),

          if (_isOwnProfile && p.bio?.isNotEmpty != true && p.interest?.isNotEmpty != true)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: AppSurfaceCard(
                onTap: _openEdit,
                color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline_rounded, color: colorScheme.onSecondaryContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Add a bio and your skills so alumni can find you.',
                        style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSecondaryContainer),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: colorScheme.onSecondaryContainer),
                  ],
                ),
              ),
            ),

          if (p.email.isNotEmpty)
            _buildSectionCard(
              theme,
              title: _isOwnProfile ? "Your QR code" : "Scan to connect",
              icon: Icons.qr_code_2_rounded,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: QrImageView(
                      data: p.email,
                      version: QrVersions.auto,
                      size: 160,
                      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.forest),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: AppColors.forest,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    _isOwnProfile
                        ? 'Others can scan this from Network to find you.'
                        : 'Scan from Network to open this profile.',
                    style: textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
