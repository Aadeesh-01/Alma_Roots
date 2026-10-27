import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cs261_project/theme/app_colors.dart';
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

  InputDecoration _fieldDecoration(String label, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      suffixIcon: suffix,
    );
  }

  Widget _buildHero(ThemeData theme) {
    final topInset = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, topInset + 36, 24, 96),
      decoration: const BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Soft decorative rings echoing the tree canopy
          Positioned(
            right: -70,
            top: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.18), width: 1.5),
              ),
            ),
          ),
          Positioned(
            left: -90,
            bottom: -110,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.gold, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
                  ),
                ),
                AppSpacing.gapMd,
                Text(
                  'Alma Roots',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontSize: 38,
                  ),
                ),
                AppSpacing.gapXs,
                Text(
                  'Reconnect. Network. Grow together.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                ),
                AppSpacing.gapMd,
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: const ['Mentorship', 'Events', 'Alumni', 'Messaging']
                      .map((f) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
                            ),
                            child: Text(
                              f,
                              style: const TextStyle(
                                color: Color(0xFFF4E3B5),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoButton(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 6),
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }

  Widget _buildFormCard(ThemeData theme) {
    final cs = theme.colorScheme;
    return Container(
      constraints: const BoxConstraints(maxWidth: 460),
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: theme.brightness == Brightness.dark ? 0.4 : 0.08),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Welcome back', style: theme.textTheme.headlineSmall),
            AppSpacing.gapXs,
            Text(
              'Sign in to your institute network',
              style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            AppSpacing.gapLg,
            DropdownButtonFormField<String>(
              value: _selectedInstituteId,
              isExpanded: true,
              borderRadius: BorderRadius.circular(14),
              dropdownColor: cs.surface,
              items: _institutes
                  .map((inst) => DropdownMenuItem<String>(
                        value: inst['id'],
                        child: Text(inst['name']),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedInstituteId = v),
              decoration: _fieldDecoration('Institute', Icons.account_balance_outlined),
              validator: (v) => v == null ? 'Please select an institute' : null,
            ),
            AppSpacing.gapMd,
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              decoration: _fieldDecoration('Email', Icons.mail_outline_rounded),
              validator: (v) => v!.isEmpty ? 'Please enter your email' : null,
            ),
            AppSpacing.gapMd,
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscurePassword,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) {
                if (!_isLoading) _loginUser();
              },
              decoration: _fieldDecoration(
                'Password',
                Icons.lock_outline_rounded,
                suffix: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (v) => v!.isEmpty ? 'Please enter your password' : null,
            ),
            AppSpacing.gapLg,
            SizedBox(
              height: 54,
              child: _isLoading
                  ? const AppLoadingView()
                  : FilledButton(
                      onPressed: _loginUser,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Sign in'),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
                    ),
            ),
            AppSpacing.gapLg,
            Row(
              children: [
                Expanded(child: Divider(color: cs.outlineVariant, height: 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'DEMO ACCESS',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: cs.outlineVariant, height: 1)),
              ],
            ),
            AppSpacing.gapMd,
            Row(
              children: [
                _buildDemoButton(Icons.school_outlined, 'Student',
                    () => _fillDemo('demo.student@demo.edu', 'Demo@123')),
                const SizedBox(width: 8),
                _buildDemoButton(Icons.workspace_premium_outlined, 'Alumni',
                    () => _fillDemo('demo.alumni@demo.edu', 'Demo@123')),
                const SizedBox(width: 8),
                _buildDemoButton(Icons.admin_panel_settings_outlined, 'Admin',
                    () => _fillDemo('adminabc@email.com', '123456')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHero(theme),
              Transform.translate(
                offset: const Offset(0, -64),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Center(child: _buildFormCard(theme)),
                    ),
                  ),
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -40),
                child: Column(
                  children: [
                    Text(
                      'Accounts are created by your institute admin.',
                      style: theme.textTheme.bodySmall,
                    ),
                    AppSpacing.gapXs,
                    Text(
                      'Alma Roots v1.0.0',
                      style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
