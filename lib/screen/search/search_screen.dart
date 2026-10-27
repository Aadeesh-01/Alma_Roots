import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cs261_project/service/search_service.dart';
import 'package:cs261_project/screen/profile/profile_screen.dart';
import 'package:cs261_project/screen/search/qr_scanner_screen.dart';
import 'package:cs261_project/theme/app_colors.dart';
import 'package:cs261_project/widget/app_avatar.dart';
import 'package:cs261_project/widget/app_section.dart';
import 'package:cs261_project/widget/app_empty_state.dart';
import 'package:cs261_project/widget/app_error_state.dart';

class SearchScreen extends StatefulWidget {
  final String instituteId;
  final bool isNested;
  const SearchScreen({super.key, required this.instituteId, this.isNested = false});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _currentSearchQuery = "";
  final Map<String, List<Map<String, dynamic>>> _searchCache = {};

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final query = _searchController.text.trim();
      if (query.isNotEmpty) {
        _performSearch(query);
      } else {
        if (mounted) {
          setState(() {
            _searchResults = [];
            _errorMessage = null;
          });
        }
      }
    });
  }

  Future<void> _performSearch(String queryText) async {
    if (queryText.isEmpty) return;

    final lowercaseQuery = queryText.toLowerCase().trim();
    _currentSearchQuery = lowercaseQuery;

    if (_searchCache.containsKey(lowercaseQuery)) {
      if (mounted) {
        setState(() {
          _searchResults = _searchCache[lowercaseQuery]!;
          _isLoading = false;
          _errorMessage = null;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _searchResults = [];
      });
    }

    try {
      final results = await SearchService.searchParticipants(
        queryText: lowercaseQuery,
        instituteId: widget.instituteId,
      );

      if (_currentSearchQuery != lowercaseQuery) return;
      _searchCache[lowercaseQuery] = results;

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (_currentSearchQuery != lowercaseQuery) return;
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Failed to load results. Please try again.";
        });
      }
    }
  }

  Future<void> _scanQr() async {
    final scannedCode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QRScannerScreen()),
    );
    if (scannedCode != null && scannedCode.isNotEmpty) {
      _searchController.text = scannedCode;
      await _performSearch(scannedCode);
    }
  }

  void _quickSearch(String term) {
    _searchController.text = term;
    _searchController.selection = TextSelection.collapsed(offset: term.length);
    _performSearch(term);
  }

  Widget _buildSearchBar(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              textInputAction: TextInputAction.search,
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  _performSearch(value.trim());
                }
              },
              decoration: InputDecoration(
                hintText: 'Search name, skill, company…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _searchController,
                  builder: (_, value, __) => value.text.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () => _searchController.clear(),
                        ),
                ),
                filled: true,
                fillColor: colorScheme.surface,
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
          const SizedBox(width: 10),
          IconButton.filled(
            tooltip: 'Scan QR code',
            onPressed: _scanQr,
            style: IconButton.styleFrom(minimumSize: const Size(50, 50)),
            icon: const Icon(Icons.qr_code_scanner_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildIntro(ThemeData theme) {
    final cs = theme.colorScheme;
    final text = theme.textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Find your people', style: text.titleLarge?.copyWith(color: Colors.white)),
                    const SizedBox(height: 6),
                    Text(
                      'Search alumni and students by name, skill, company or year, or scan a profile QR code.',
                      style: text.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.78)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.gold, width: 1.5),
                ),
                child: const Icon(Icons.diversity_3_rounded, color: AppColors.gold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('Quick searches', style: text.titleMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (icon, label, term) in [
              (Icons.workspace_premium_outlined, 'Alumni', 'alumni'),
              (Icons.school_outlined, 'Students', 'student'),
              (Icons.admin_panel_settings_outlined, 'Admins', 'admin'),
            ])
              ActionChip(
                avatar: Icon(icon, size: 18, color: cs.primary),
                label: Text(label),
                onPressed: () => _quickSearch(term),
              ),
            ActionChip(
              avatar: Icon(Icons.qr_code_scanner_rounded, size: 18, color: cs.primary),
              label: const Text('Scan a QR code'),
              onPressed: _scanQr,
            ),
          ],
        ),
        const SizedBox(height: 24),
        AppSurfaceCard(
          color: cs.surfaceContainerLow,
          child: Row(
            children: [
              Icon(Icons.tips_and_updates_outlined, color: cs.secondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Tip: type the start of a name or skill, like "and" for Android or "goo" for Google.',
                  style: text.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultItem(ThemeData theme, Map<String, dynamic> hit) {
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final skillsRaw = hit['skills'] ?? hit['interest'];
    final skills = (skillsRaw is List)
        ? skillsRaw.map((s) => s.toString().trim()).where((s) => s.isNotEmpty).take(3).toList()
        : (skillsRaw?.toString() ?? '').split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).take(3).toList();

    final role = hit['role']?.toString().toLowerCase() ?? 'student';
    String subtitle;
    if (role == 'alumni') {
      final company = hit['company']?.toString() ?? '';
      subtitle = company.isNotEmpty ? company : 'Alumni';
    } else if (role == 'admin') {
      subtitle = 'Administrator';
    } else {
      final year = hit['year']?.toString() ?? '';
      subtitle = year.isNotEmpty ? 'Class of $year' : 'Student';
    }

    final rawName = (hit['name'] ?? '').toString().trim();
    final email = (hit['email'] ?? '').toString();
    final name = rawName.isNotEmpty ? rawName : (email.isNotEmpty ? email.split('@').first : 'Member');
    final image = (hit['profileImage'] ?? hit['picture'])?.toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppSurfaceCard(
        padding: const EdgeInsets.all(14),
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => ProfileScreen(
              instituteId: widget.instituteId,
              viewUid: hit['uid'] ?? hit['id'],
            ),
          ));
        },
        child: Row(
          children: [
            AppAvatar(name: name, imageUrl: image, radius: 26),
            const SizedBox(width: 14),
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
                      RoleBadge(role: role, dense: true),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (skills.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: skills
                          .map((s) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: colorScheme.outlineVariant),
                                ),
                                child: Text(s, style: textTheme.labelSmall),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget body;
    if (_isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_errorMessage != null) {
      body = AppErrorState(message: _errorMessage!);
    } else if (_searchResults.isEmpty && _searchController.text.isNotEmpty) {
      body = const AppEmptyState(
        icon: Icons.search_off_rounded,
        title: 'No matches',
        message: 'Try a shorter word, a skill, or a company name.',
      );
    } else if (_searchResults.isEmpty) {
      body = _buildIntro(theme);
    } else {
      body = ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: _searchResults.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10, left: 4),
              child: Text(
                '${_searchResults.length} ${_searchResults.length == 1 ? 'person' : 'people'}',
                style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            );
          }
          return _buildResultItem(theme, _searchResults[index - 1]);
        },
      );
    }

    return Scaffold(
      appBar: widget.isNested ? null : AppBar(title: const Text('Network')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSearchBar(theme),
          Expanded(child: body),
        ],
      ),
    );
  }
}
