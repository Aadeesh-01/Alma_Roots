import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cs261_project/service/user_role_dispatcher.dart';
import 'package:cs261_project/theme/app_spacing.dart';
import 'package:cs261_project/widget/app_loading_view.dart';
import 'package:cs261_project/widget/app_snackbar.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;

  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  String? _selectedInstituteId;
  List<Map<String, dynamic>> _institutes = [];

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _loadInstitutes();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _animController,
            curve: const Interval(0.0, 0.6, curve: Curves.easeIn)));
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _animController,
                curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic)));
    _animController.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadInstitutes() async {
    try {
      final snapshot = await _firestore.collection('institutes').get();
      setState(() {
        _institutes = snapshot.docs
            .map((doc) => {'id': doc.id, 'name': doc['name']})
            .toList();

        // Auto-select institute if requested
        if (_institutes.isNotEmpty && _selectedInstituteId == null) {
          _selectedInstituteId = _institutes.first['id'];
        }
      });
      print("✅ Institutes loaded: ${_institutes.length}");
    } catch (e) {
      print("❌ Failed to load institutes: $e");
      _showError("Failed to load institutes.");
    }
  }

  void _fillDemo(String email, String password) {
    if (_institutes.isNotEmpty) {
      setState(() {
        _selectedInstituteId = _institutes.first['id'];
        _emailCtrl.text = email;
        _passwordCtrl.text = password;
      });
      AppSnackBar.showSuccess(context, "Credentials filled. Press Login to continue.");
    }
  }

  Future<void> _loginUser() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedInstituteId == null) {
      _showError('Please select an institute.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final email = _emailCtrl.text.trim();
      final password = _passwordCtrl.text.trim();

      print("--- LOGIN START ---");
      print("Email: $email");
      print("Institute ID: $_selectedInstituteId");

      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = userCredential.user;
      if (user == null) throw Exception("User is null after login");

      print("✅ Auth success: ${user.uid}");

      final participantRef = _firestore
          .collection('institutes')
          .doc(_selectedInstituteId!)
          .collection('participants')
          .doc(user.uid);

      final participantDoc = await participantRef.get();

      if (!participantDoc.exists) {
        print("🚨 No participant document found for this user.");
        await FirebaseAuth.instance.signOut();
        throw Exception('User not registered under this institute.');
      }

      print("✅ Firestore doc found: ${participantDoc.data()}");

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lastInstituteId', _selectedInstituteId!);
      print("🏫 Saved lastInstituteId: $_selectedInstituteId");

      if (!mounted) return;

      // Profile completion prompt logic
      final data = participantDoc.data() as Map<String, dynamic>;
      final String role = data['role'] ?? 'student';
      final bool isDeactivated = data['isDeleted'] == true || data['status'] == 'deleted';
      
      bool profileIncomplete = false;

      if (role != 'admin' && !isDeactivated) {
        bool hasStr(String key) => data[key] != null && data[key].toString().trim().isNotEmpty;
        
        bool baseComplete = hasStr('name') && hasStr('role') && hasStr('instituteId') && hasStr('bio') && hasStr('interest');
        
        bool roleComplete = false;
        if (role == 'student') {
          roleComplete = hasStr('rollNo') && hasStr('year');
        } else if (role == 'alumni') {
          roleComplete = hasStr('company') && hasStr('year');
        } else {
          roleComplete = true; 
        }

        profileIncomplete = !(baseComplete && roleComplete);
      }

      if (profileIncomplete) {
        await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
                  title: const Text("Complete Your Profile"),
                  content: const Text(
                      "It looks like your profile is incomplete. Completing your profile helps you connect better with others!"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("I'll do it later"),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Got it"),
                    )
                  ],
                ));
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              UserRoleDispatcher(instituteId: _selectedInstituteId!),
        ),
      );
    } on FirebaseAuthException catch (e) {
      print("❌ FirebaseAuth error: ${e.code} - ${e.message}");
      _showError(e.message ?? "Login failed. Check credentials.");
    } catch (e) {
      print("❌ General login error: $e");
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    AppSnackBar.showError(context, message);
  }

  Widget _buildFeatureChips(bool isDark) {
    final features = [
      "💬 Messaging",
      "🎓 Alumni Network",
      "📅 Events",
      "📰 News",
      "🔍 Search",
    ];

    final Color chipBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color chipBorder = isDark ? const Color(0xFF334155) : const Color(0xFFDDE7F2);
    final Color chipText = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF1565C0);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: features
          .map((f) => Chip(
                label: Text(f,
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500, color: chipText)),
                backgroundColor: chipBg,
                side: BorderSide(color: chipBorder),
              ))
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;

    // Colors
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFEAF4FF);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color inputFillColor = isDark ? const Color(0xFF334155) : Colors.white;
    final Color inputBorderColor = isDark ? Colors.transparent : const Color(0xFFDDE7F2);
    final Color primaryColor = isDark ? const Color(0xFF2563EB) : const Color(0xFF1565C0);
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color secondaryTextColor = isDark ? const Color(0xFFCBD5E1) : Colors.grey.shade700;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      // Logo
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      AppSpacing.gapMd,
                      Text(
                        'Alma Roots',
                        style: textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: primaryColor,
                          letterSpacing: -0.5,
                        ),
                      ),
                      AppSpacing.gapXs,
                      Text(
                        'Reconnect. Network. Grow Together.',
                        style: textTheme.titleMedium?.copyWith(
                          color: secondaryTextColor,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      AppSpacing.gapMd,
                      _buildFeatureChips(isDark),
                      AppSpacing.gapLg,
                    ],
                  ),
                ),
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 450),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              DropdownButtonFormField<String>(
                                value: _selectedInstituteId,
                                isExpanded: true,
                                dropdownColor: cardColor,
                                items: _institutes
                                    .map((inst) => DropdownMenuItem<String>(
                                          value: inst['id'],
                                          child: Text(inst['name'], style: TextStyle(color: textColor)),
                                        ))
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _selectedInstituteId = v),
                                decoration: InputDecoration(
                                  labelText: 'Select Institute',
                                  labelStyle: TextStyle(color: secondaryTextColor),
                                  filled: true,
                                  fillColor: inputFillColor,
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: inputBorderColor)),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: inputBorderColor)),
                                  prefixIcon:
                                      Icon(Icons.account_balance, color: secondaryTextColor),
                                ),
                                validator: (v) => v == null
                                    ? 'Please select an institute'
                                    : null,
                              ),
                              AppSpacing.gapLg,
                              TextFormField(
                                controller: _emailCtrl,
                                style: TextStyle(color: textColor),
                                decoration: InputDecoration(
                                  labelText: 'Email',
                                  labelStyle: TextStyle(color: secondaryTextColor),
                                  filled: true,
                                  fillColor: inputFillColor,
                                  prefixIcon:
                                      Icon(Icons.email_outlined, color: secondaryTextColor),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: inputBorderColor)),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: inputBorderColor)),
                                ),
                                keyboardType: TextInputType.emailAddress,
                                validator: (v) => v!.isEmpty
                                    ? 'Please enter your email'
                                    : null,
                              ),
                              AppSpacing.gapLg,
                              TextFormField(
                                controller: _passwordCtrl,
                                style: TextStyle(color: textColor),
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  labelStyle: TextStyle(color: secondaryTextColor),
                                  filled: true,
                                  fillColor: inputFillColor,
                                  prefixIcon: Icon(Icons.lock_outline, color: secondaryTextColor),
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility, color: secondaryTextColor),
                                    onPressed: () => setState(() =>
                                        _obscurePassword = !_obscurePassword),
                                  ),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: inputBorderColor)),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: inputBorderColor)),
                                ),
                                obscureText: _obscurePassword,
                                validator: (v) => v!.isEmpty
                                    ? 'Please enter your password'
                                    : null,
                              ),
                              AppSpacing.gapXl,
                              _isLoading
                                  ? const AppLoadingView()
                                  : ElevatedButton(
                                      onPressed: _loginUser,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryColor,
                                        foregroundColor: Colors.white,
                                        minimumSize:
                                            const Size(double.infinity, 54),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        elevation: 2,
                                      ),
                                      child: const Text('Login',
                                          style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold)),
                                    ),
                              AppSpacing.gapXl,
                              Row(
                                children: [
                                  Expanded(child: Divider(color: inputBorderColor == Colors.transparent ? secondaryTextColor.withValues(alpha: 0.3) : inputBorderColor)),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Text(
                                      "OR",
                                      style: TextStyle(
                                        color: secondaryTextColor,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  Expanded(child: Divider(color: inputBorderColor == Colors.transparent ? secondaryTextColor.withValues(alpha: 0.3) : inputBorderColor)),
                                ],
                              ),
                              AppSpacing.gapLg,
                              Text("Demo Access",
                                  style: textTheme.titleSmall?.copyWith(
                                      color: secondaryTextColor,
                                      fontWeight: FontWeight.w600)),
                              AppSpacing.gapMd,
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                alignment: WrapAlignment.center,
                                children: [
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.school, size: 16),
                                    label: const Text("Student"),
                                    onPressed: () => _fillDemo(
                                        'demo.student@demo.edu', 'Demo@123'),
                                    style: OutlinedButton.styleFrom(
                                        foregroundColor: primaryColor,
                                        side: BorderSide(color: primaryColor.withValues(alpha: 0.5))),
                                  ),
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.work, size: 16),
                                    label: const Text("Alumni"),
                                    onPressed: () =>
                                        _fillDemo('demo.alumni@demo.edu', 'Demo@123'),
                                    style: OutlinedButton.styleFrom(
                                        foregroundColor: primaryColor,
                                        side: BorderSide(color: primaryColor.withValues(alpha: 0.5))),
                                  ),
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.admin_panel_settings,
                                        size: 16),
                                    label: const Text("Admin"),
                                    onPressed: () =>
                                        _fillDemo('adminabc@email.com', '123456'),
                                    style: OutlinedButton.styleFrom(
                                        foregroundColor: primaryColor,
                                        side: BorderSide(color: primaryColor.withValues(alpha: 0.5))),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Text("Alma Roots v1.0.0",
                      style: textTheme.bodySmall
                          ?.copyWith(color: secondaryTextColor)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
