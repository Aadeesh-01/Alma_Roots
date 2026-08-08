import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cs261_project/service/search_service.dart';
import 'package:cs261_project/screen/profile/profile_screen.dart';
import 'package:cs261_project/screen/search/qr_scanner_screen.dart';
import 'package:cs261_project/theme/app_spacing.dart';
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

  Widget _buildSearchBar(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return Container(
      color: colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
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
                hintText: 'Search people, skills, companies...',
                prefixIcon: Icon(Icons.search, color: colorScheme.onSurfaceVariant),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.sm),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.sm),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 0),
              ),
            ),
          ),
          AppSpacing.gapSm,
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(AppSpacing.sm),
              border: Border.all(color: theme.dividerColor),
            ),
            child: IconButton(
              icon: Icon(Icons.qr_code_scanner, color: colorScheme.primary),
              onPressed: () async {
                final scannedCode = await Navigator.of(context).push<String>(
                  MaterialPageRoute(builder: (_) => const QRScannerScreen()),
                );
                if (scannedCode != null && scannedCode.isNotEmpty) {
                  _searchController.text = scannedCode;
                  await _performSearch(scannedCode);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultItem(ThemeData theme, Map<String, dynamic> hit) {
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final skillsRaw = hit['skills'] ?? hit['interest'];
    final skills = (skillsRaw is List)
        ? skillsRaw.take(3).join(' • ')
        : (skillsRaw?.toString() ?? '');

    final role = hit['role']?.toString().toLowerCase() ?? 'student';
    String subtitle = 'Student';
    
    if (role == 'alumni') {
      subtitle = hit['company'] ?? 'Alumni';
    } else if (role == 'admin') {
      subtitle = 'Administrator';
    } else {
      final year = hit['year'];
      subtitle = year != null && year.isNotEmpty ? 'Class of $year' : 'Student';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppSpacing.md),
        leading: CircleAvatar(
          backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
          radius: 24,
          child: Text(
            (hit['name'] ?? 'N').toString().isNotEmpty 
              ? (hit['name'] ?? 'N').substring(0, 1).toUpperCase()
              : 'N',
            style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary),
          ),
        ),
        title: Text(
          hit['name'] ?? 'Unknown User',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSpacing.gapXs,
            Text(subtitle, style: textTheme.bodyMedium),
            if (skills.isNotEmpty) ...[
              AppSpacing.gapXs,
              Text(skills, style: textTheme.bodySmall?.copyWith(color: colorScheme.primary), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
        trailing: OutlinedButton(
          onPressed: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => ProfileScreen(
                instituteId: widget.instituteId,
                viewUid: hit['uid'] ?? hit['id'],
              ),
            ));
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: colorScheme.primary,
            side: BorderSide(color: colorScheme.primary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 0),
          ),
          child: const Text("View"),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: widget.isNested ? null : AppBar(
        title: const Text('Network'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSearchBar(theme),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? AppErrorState(message: _errorMessage!)
                    : _searchResults.isEmpty && _searchController.text.isNotEmpty
                        ? const AppEmptyState(
                            icon: Icons.search_off,
                            title: 'No Results Found',
                            message: 'Try adjusting your search terms or checking for typos.',
                          )
                        : _searchResults.isEmpty
                            ? const AppEmptyState(
                                icon: Icons.person_search,
                                title: 'Find Connections',
                                message: 'Search for alumni by name, skills, company, or department.',
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                itemCount: _searchResults.length,
                                itemBuilder: (context, index) {
                                  return _buildResultItem(theme, _searchResults[index]);
                                },
                              ),
          ),
        ],
      ),
    );
  }
}
