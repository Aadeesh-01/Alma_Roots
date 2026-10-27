import 'package:cs261_project/theme/app_colors.dart';
import 'package:cs261_project/widget/app_avatar.dart';
import 'package:cs261_project/widget/app_section.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cs261_project/model/participant_model.dart';
import 'package:cs261_project/screen/message/chat_screen.dart';
import 'package:cs261_project/screen/profile/profile_screen.dart';
import 'package:cs261_project/service/profile_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class StartConversationScreen extends StatefulWidget {
  final String instituteId;
  const StartConversationScreen({super.key, required this.instituteId});

  @override
  State<StartConversationScreen> createState() => _StartConversationScreenState();
}

class _StartConversationScreenState extends State<StartConversationScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final String _currentUserId;
  late final ProfileService _profileService;
  
  ParticipantModel? _myProfile;
  List<ParticipantModel> _allParticipants = [];
  List<ParticipantModel> _displayParticipants = [];
  bool _isLoading = true;

  String _searchQuery = '';
  String _selectedFilter = 'All';

  final List<String> _filters = [
    'All', 'Students', 'Alumni', 'Admins', 'Mentors', 'Hiring', 'Networking'
  ];

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser!.uid;
    _profileService = ProfileService(instituteId: widget.instituteId);
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      _myProfile = await _profileService.getProfile(_currentUserId);
      
      // Fetch all participants to allow robust local searching and filtering
      // Since it's restricted to current institute, it scales reasonably well.
      final snapshot = await _firestore
          .collection('institutes')
          .doc(widget.instituteId)
          .collection('participants')
          .orderBy('name')
          .get();

      _allParticipants = snapshot.docs
          .map((doc) => ParticipantModel.fromFirestore(doc))
          .where((p) => p.uid != _currentUserId && !p.isDeleted && p.status != 'deleted') // exclude self and deleted users
          .toList();
          
      _updateDisplayParticipants();

    } catch (e) {
      debugPrint("Error fetching participants: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _updateDisplayParticipants() {
    _displayParticipants = _allParticipants.where((p) {
      // Apply Quick Filter
      bool passesFilter = true;
      switch (_selectedFilter) {
        case 'Students': passesFilter = p.role == 'student'; break;
        case 'Alumni': passesFilter = p.role == 'alumni'; break;
        case 'Admins': passesFilter = p.role == 'admin'; break;
        case 'Mentors': passesFilter = p.isMentor; break;
        case 'Hiring': passesFilter = p.isHiring; break;
        case 'Networking': passesFilter = p.openToNetworking; break;
      }
      if (!passesFilter) return false;

      // Apply Local Text Search
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final name = p.name.toLowerCase();
        final dept = (p.department ?? '').toLowerCase();
        final role = p.role.toLowerCase();
        final year = (p.year ?? '').toLowerCase();
        
        return name.contains(query) || 
               dept.contains(query) || 
               role.contains(query) || 
               year.contains(query);
      }
      return true;
    }).toList();
  }

  String _displayName(ParticipantModel p) =>
      p.name.isNotEmpty ? p.name : (p.email.isNotEmpty ? p.email.split('@').first : 'Member');

  String _subtitle(ParticipantModel p) {
    if (p.role == 'alumni') return p.company?.isNotEmpty == true ? p.company! : 'Alumni';
    if (p.role == 'admin') return 'Administrator';
    final parts = [
      if (p.department?.isNotEmpty == true) p.department!,
      if (p.year?.isNotEmpty == true) 'Class of ${p.year}',
    ];
    return parts.isEmpty ? 'Student' : parts.join(' · ');
  }

  void _showProfilePreview(ParticipantModel p) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final name = _displayName(p);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppAvatar(name: name, imageUrl: p.profileImage, radius: 40, ring: true),
                const SizedBox(height: 14),
                Text(name, style: textTheme.headlineSmall, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                RoleBadge(role: p.role),
                const SizedBox(height: 8),
                Text(_subtitle(p), style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                if (p.bio != null && p.bio!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    p.bio!,
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium,
                  ),
                ],
                if (p.isMentor || p.isHiring || p.openToNetworking) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      if (p.isMentor) _buildBadge('Mentor', AppColors.forest),
                      if (p.isHiring) _buildBadge('Hiring', AppColors.clay),
                      if (p.openToNetworking) _buildBadge('Open to connect', AppColors.goldDeep),
                    ],
                  ),
                ],
                const SizedBox(height: 22),
                Divider(height: 1, color: colorScheme.outlineVariant),
                const SizedBox(height: 18),
                Text("How would you like to start?", style: textTheme.titleMedium),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _introChip(p, 'Say hi 👋', null, Icons.waving_hand_outlined),
                    _introChip(p, 'Request Mentorship', 'Request Mentorship', Icons.volunteer_activism_outlined),
                    _introChip(p, 'Career Guidance', 'Career Guidance', Icons.explore_outlined),
                    _introChip(p, 'Referral Request', 'Referral Request', Icons.badge_outlined),
                    _introChip(p, 'Project Collaboration', 'Project Collaboration', Icons.code_rounded),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => ProfileScreen(instituteId: widget.instituteId, viewUid: p.uid),
                      ));
                    },
                    child: const Text('View full profile'),
                  ),
                )
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildBadge(String label, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Color.lerp(color, Colors.white, 0.45)! : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.22 : 0.10),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }

  Widget _introChip(ParticipantModel p, String label, String? introType, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;

    return ActionChip(
      avatar: Icon(icon, size: 18, color: colorScheme.primary),
      label: Text(label),
      onPressed: () {
        Navigator.pop(context); // Close bottom sheet

        String? initialMessage;
        if (introType != null && _myProfile != null) {
          initialMessage = "👋 Hi! I'd like to connect regarding $introType.\n\n"
              "Here's a quick intro:\n"
              "• Name: ${_myProfile!.name}\n"
              "• Role: ${_myProfile!.role.toUpperCase()}\n"
              "• Department: ${_myProfile!.department ?? 'N/A'}\n"
              "• Graduation: ${_myProfile!.year ?? 'N/A'}\n\n"
              "Looking forward to chatting!";
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              otherUserId: p.uid,
              otherUserName: _displayName(p),
              instituteId: widget.instituteId,
              initialMessage: initialMessage,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('New conversation')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: TextField(
              controller: _searchController,
              autofocus: false,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                  _updateDisplayParticipants();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search by name, department or year',
                prefixIcon: const Icon(Icons.search_rounded),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(100),
                  borderSide: BorderSide(color: colorScheme.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(100),
                  borderSide: BorderSide(color: colorScheme.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(100),
                  borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final filter = _filters[i];
                return ChoiceChip(
                  label: Text(filter),
                  selected: _selectedFilter == filter,
                  showCheckmark: false,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedFilter = filter;
                        _updateDisplayParticipants();
                      });
                    }
                  },
                );
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _displayParticipants.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(color: colorScheme.secondaryContainer, shape: BoxShape.circle),
                                child: Icon(Icons.person_search_outlined, size: 32, color: colorScheme.onSecondaryContainer),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                _searchQuery.isNotEmpty || _selectedFilter != 'All'
                                    ? "No one matches that"
                                    : "No one to chat with yet",
                                style: textTheme.titleMedium,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: _displayParticipants.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final p = _displayParticipants[index];
                          final name = _displayName(p);
                          return AppSurfaceCard(
                            padding: const EdgeInsets.all(12),
                            onTap: () => _showProfilePreview(p),
                            child: Row(
                              children: [
                                AppAvatar(name: name, imageUrl: p.profileImage, radius: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(name, style: textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                                          ),
                                          const SizedBox(width: 8),
                                          RoleBadge(role: p.role, dense: true),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(_subtitle(p), style: textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chat_bubble_outline_rounded, size: 20, color: colorScheme.primary),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
