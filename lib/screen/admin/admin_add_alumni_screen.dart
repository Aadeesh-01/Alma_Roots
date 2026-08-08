import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cs261_project/service/search_service.dart';

class AdminAddAlumniScreen extends StatefulWidget {
  const AdminAddAlumniScreen({super.key});

  @override
  State<AdminAddAlumniScreen> createState() => _AdminAddAlumniScreenState();
}

class _AdminAddAlumniScreenState extends State<AdminAddAlumniScreen> {
  final _nameController = TextEditingController();
  final _yearController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _selectedInstituteId;
  List<Map<String, dynamic>> _institutes = [];
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadInstitutes();
  }

  Future<void> _loadInstitutes() async {
    final snapshot = await FirebaseFirestore.instance.collection('institutes').get();
    setState(() {
      _institutes = snapshot.docs
          .map((doc) => {'id': doc.id, 'name': doc['name']})
          .toList();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _yearController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _createAlumni() async {
    if (_nameController.text.trim().isEmpty ||
        _yearController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Please fill in all fields."),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    if (_selectedInstituteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Please select an institute."),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Bypass native Flutter Firebase SDK to prevent session hijacking
      // by using the Firebase Identity Toolkit REST API directly.
      final apiKey = Firebase.app().options.apiKey;
      final url = Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text.trim(),
          'password': _passwordController.text.trim(),
          'returnSecureToken': true,
        }),
      );

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['error']['message'] ?? 'Failed to create alumni';
        throw Exception(errorMessage);
      }

      final responseData = jsonDecode(response.body);
      final uid = responseData['localId'];

      final String role = 'alumni';
      final List<String> searchKeywords = [
        ...SearchService.generateSearchKeywords(_nameController.text.trim()),
        ...SearchService.generateSearchKeywords(_emailController.text.trim()),
        ...SearchService.generateSearchKeywords(_yearController.text.trim()),
        ...SearchService.generateSearchKeywords(role),
      ].toSet().toList();

      // Add entry to unified participants collection under selected institute
      await FirebaseFirestore.instance
          .collection('institutes')
          .doc(_selectedInstituteId)
          .collection('participants')
          .doc(uid)
          .set({
        'uid': uid,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'year': _yearController.text.trim(),
        'role': role,
        'instituteId': _selectedInstituteId,
        'profileImage': '',
        'searchKeywords': searchKeywords,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Alumni added successfully!"),
          backgroundColor: Colors.green, // keeping green for success
        ),
      );

      _nameController.clear();
      _yearController.clear();
      _emailController.clear();
      _passwordController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          "Add Alumni",
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Card(
          elevation: 0,
          color: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.dividerColor),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Alumni Details",
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  value: _selectedInstituteId,
                  items: _institutes
                      .map(
                        (inst) => DropdownMenuItem<String>(
                          value: inst['id'] as String,
                          child: Text(inst['name']),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _selectedInstituteId = value),
                  decoration: InputDecoration(
                    labelText: 'Select Institute',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: "Full Name",
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _yearController,
                  decoration: InputDecoration(
                    labelText: "Graduation Year",
                    prefixIcon: const Icon(Icons.calendar_today_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: "Email",
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: "Password",
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  obscureText: _obscurePassword,
                ),
                const SizedBox(height: 32),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _createAlumni,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          minimumSize: const Size(double.infinity, 54),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Add Alumni",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
