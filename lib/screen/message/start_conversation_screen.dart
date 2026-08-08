import 'package:cached_network_image/cached_network_image.dart';
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

  void _showProfilePreview(ParticipantModel p) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 24,
            top: 24, left: 24, right: 24
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (p.profileImage != null)
                CachedNetworkImage(
                  imageUrl: p.profileImage!,
                  imageBuilder: (context, imageProvider) => CircleAvatar(
                    radius: 40,
                    backgroundImage: imageProvider,
                  ),
                  placeholder: (context, url) => CircleAvatar(
                    radius: 40,
                    backgroundColor: theme.dividerColor,
                    child: const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => CircleAvatar(
                    radius: 40,
                    backgroundColor: theme.dividerColor,
                    child: Icon(Icons.error, color: colorScheme.onSurfaceVariant),
                  ),
                )
              else
                CircleAvatar(
                  radius: 40,
                  backgroundColor: theme.dividerColor,
                  child: Text(p.name.isNotEmpty ? p.name[0].toUpperCase() : '?', style: textTheme.headlineMedium?.copyWith(color: colorScheme.onSurface)),
                ),
              const SizedBox(height: 16),
              Text(p.name, style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              Text(p.role.toUpperCase(), style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              if (p.department != null || p.year != null)
                Text('${p.department ?? ""} ${p.year ?? ""}'.trim(), style: textTheme.bodyLarge),
              if (p.company != null)
                Text('At: ${p.company}', style: textTheme.bodyLarge),
              if (p.bio != null && p.bio!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(p.bio!, textAlign: TextAlign.center, style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  if (p.isMentor) _buildBadge('Mentor', colorScheme.primary),
                  if (p.isHiring) _buildBadge('Hiring', colorScheme.tertiary),
                  if (p.openToNetworking) _buildBadge('Open to Connect', colorScheme.secondary),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Text("Start Conversation", style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _introChip(p, 'Say Hi 👋', null, Icons.chat_bubble_outline),
                  _introChip(p, 'Request Mentorship', 'Request Mentorship', Icons.school),
                  _introChip(p, 'Career Guidance', 'Career Guidance', Icons.work),
                  _introChip(p, 'Referral Request', 'Referral Request', Icons.badge),
                  _introChip(p, 'Project Collaboration', 'Project Collaboration', Icons.code),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ProfileScreen(instituteId: widget.instituteId, viewUid: p.uid),
                    ));
                  },
                  child: const Text('View Full Profile'),
                ),
              )
            ],
          ),
        );
      }
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _introChip(ParticipantModel p, String label, String? introType, IconData icon) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return ActionChip(
      avatar: Icon(icon, size: 16, color: colorScheme.primary),
      label: Text(label),
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.3))),
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
              otherUserName: p.name,
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
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text('New Chat', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      body: Column(
        children: [
          Container(
            color: colorScheme.surface,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                      _updateDisplayParticipants();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by name, dept, or role...',
                    prefixIcon: Icon(Icons.search, color: colorScheme.onSurfaceVariant),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                  ),
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filters.map((filter) {
                      final isSelected = _selectedFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(filter),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedFilter = filter;
                                _updateDisplayParticipants();
                              });
                            }
                          },
                          selectedColor: colorScheme.primary.withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                            color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: isSelected ? colorScheme.primary : theme.dividerColor),
                          ),
                          backgroundColor: colorScheme.surface,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _displayParticipants.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 64, color: colorScheme.onSurfaceVariant),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty || _selectedFilter != 'All'
                                  ? "No participants found matching your criteria"
                                  : "No participants available to chat",
                              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _displayParticipants.length,
                        itemBuilder: (context, index) {
                          final p = _displayParticipants[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            color: colorScheme.surface,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: theme.dividerColor)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(12),
                              leading: p.profileImage != null
                                  ? CachedNetworkImage(
                                      imageUrl: p.profileImage!,
                                      imageBuilder: (context, imageProvider) => CircleAvatar(
                                        radius: 25,
                                        backgroundImage: imageProvider,
                                      ),
                                      placeholder: (context, url) => CircleAvatar(
                                        radius: 25,
                                        backgroundColor: theme.dividerColor,
                                        child: const SizedBox(
                                          width: 16, height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) => CircleAvatar(
                                        radius: 25,
                                        backgroundColor: theme.dividerColor,
                                        child: Icon(Icons.error, color: colorScheme.onSurfaceVariant, size: 20),
                                      ),
                                    )
                                  : CircleAvatar(
                                      radius: 25,
                                      backgroundColor: colorScheme.surfaceContainerHighest,
                                      child: Text(
                                        p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                                        style: TextStyle(fontSize: 18, color: colorScheme.onSurface),
                                      ),
                                    ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      p.name,
                                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (p.isMentor) Icon(Icons.school, size: 14, color: colorScheme.primary),
                                  if (p.isHiring) ...[const SizedBox(width: 4), Icon(Icons.work, size: 14, color: colorScheme.tertiary)],
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    p.role.toUpperCase(),
                                    style: TextStyle(color: colorScheme.primary, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                  if (p.department != null)
                                    Text('${p.department} ${p.year ?? ""}', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
                                ],
                              ),
                              onTap: () => _showProfilePreview(p),
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
