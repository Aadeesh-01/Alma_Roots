import 'package:cs261_project/screen/admin/admin_home_screen.dart';
import 'package:cs261_project/screen/student/user_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cs261_project/service/user_role_dispatcher.dart';
import 'package:cs261_project/utils/email_validator.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import package

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final _formKey = GlobalKey<FormState>();
  bool _isLogin = true;
  bool _isLoading = false;

  String _email = '';
  String _password = '';
  String? _selectedInstituteId;
  String? _selectedRole;
  List<Map<String, dynamic>> _institutes = [];

  @override
  void initState() {
    super.initState();
    _loadInstitutes();
  }

  /// 🔹 Load all institutes from Firestore
  Future<void> _loadInstitutes() async {
    final snapshot = await _firestore.collection('institutes').get();
    setState(() {
      _institutes = snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          'name': doc['name'],
        };
      }).toList();
    });
  }

  /// 🔹 Handle login
  Future<void> _loginUser() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isLoading = true);

    try {
      final userCred = await _auth.signInWithEmailAndPassword(
        email: _email.trim(),
        password: _password.trim(),
      );

      final user = userCred.user!;
      final email = user.email;

      // 🔥 HARD-CODED admin mapping
      final Map<String, String> adminInstituteMap = {
        "adminabc@email.com": "INSTITUTE_ID_1",
        "adminxyz@email.com": "INSTITUTE_ID_2",
        // add more...
      };

      // 🔥 Check if user is an admin based on email
      if (email != null && adminInstituteMap.containsKey(email)) {
        final instId = adminInstituteMap[email]!;

        print("🔥 Admin detected → $email → Institute: $instId");

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('lastInstituteId', instId);

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AdminHomeScreen(instituteId: instId),
          ),
        );

        return; // STOP further processing
      }

      // 🔹 Normal Student / Alumni login
      if (_selectedInstituteId == null) {
        throw Exception("Please select your institute.");
      }

      final participantDoc = await _firestore
          .collection('institutes')
          .doc(_selectedInstituteId!)
          .collection('participants')
          .doc(user.uid)
          .get();

      if (!participantDoc.exists) {
        throw Exception("User not registered under this institute.");
      }

      final data = participantDoc.data() as Map<String, dynamic>;
      if (data['isDeleted'] == true || data['status'] == 'deleted') {
        await _auth.signOut();
        throw Exception("Your account has been deactivated by an administrator.");
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lastInstituteId', _selectedInstituteId!);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              UserRoleDispatcher(instituteId: _selectedInstituteId!),
        ),
      );
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 🔹 Handle registration — only allowed for Admins
  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) {
      print("DEBUG: auth_service _formKey.currentState!.validate() returned false");
      return;
    }
    _formKey.currentState!.save();
    
    print("DEBUG: auth_service Original email entered: '$_email'");
    final normalizedEmail = _email.trim().toLowerCase();
    print("DEBUG: auth_service Normalized email: '$normalizedEmail'");
    final validationResult = EmailValidator.isValid(_email);
    print("DEBUG: auth_service Email validation result (isValid): $validationResult");

    setState(() => _isLoading = true);

    try {
      if (!EmailValidator.isValid(_email)) {
        throw Exception("Please enter a valid email address.");
      }

      print("DEBUG: auth_service Cloud Function is called");
      // Get the callable function from your backend
      final createParticipant =
          FirebaseFunctions.instanceFor(region: 'asia-south1')
              .httpsCallable('createParticipantAccount');

      final result = await createParticipant.call({
        'email': _email.trim().toLowerCase(),
        'password': _password.trim(),
        'role': _selectedRole,
        'instituteId': _selectedInstituteId,
        'name': '', // Optional: you can add a name field to the form
      });
      if (mounted) {
        _showSuccess(result.data['message'] ?? 'User registered successfully!');
        setState(() => _isLogin = true);
      }
    } on FirebaseFunctionsException catch (e, stackTrace) {
      print("DEBUG: auth_service Flutter exception type: FirebaseFunctionsException");
      print("DEBUG: auth_service Flutter exception code: ${e.code}");
      print("DEBUG: auth_service Flutter exception message: ${e.message}");
      print("DEBUG: auth_service Flutter exception details: ${e.details}");
      print("DEBUG: auth_service Full stack trace:\n$stackTrace");

      String message = "Unable to create account. Please try again.";
      if (e.code == 'invalid-email' || e.code == 'invalid-argument') {
        message = "Please enter a valid email address.";
      } else if (e.code == 'EMAIL_EXISTS' || e.code == 'email-already-exists' || e.code == 'already-exists') {
        message = "This email is already registered.";
      } else if (e.code == 'weak-password') {
        message = "Password must meet minimum requirements.";
      } else if (e.code != 'internal' && e.code != 'unknown' && e.message != null && e.message!.isNotEmpty) {
        message = e.message!;
      }
      print("DEBUG: auth_service Displayed Message: $message");
      _showError(message);
    } catch (e, stackTrace) {
      print("DEBUG: auth_service Flutter exception type: ${e.runtimeType}");
      print("DEBUG: auth_service Flutter exception string: ${e.toString()}");
      print("DEBUG: auth_service Full stack trace:\n$stackTrace");
      print("DEBUG: auth_service Displayed Message: ${e.toString().replaceAll('Exception: ', '')}");
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// 🔹 Display error messages
  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text(message)),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.green, content: Text(message)),
      );
    }
  }

  /// 🔹 Form submit handler
  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    if (_isLogin) {
      _loginUser();
    } else {
      _registerUser();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'Login' : 'Register'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Card(
            elevation: 6,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    /// 🔹 Institute dropdown
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
                      decoration: InputDecoration(
                        labelText: 'Select Institute',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() => _selectedInstituteId = value);
                      },
                      validator: (value) =>
                          value == null ? 'Please select an institute' : null,
                    ),
                    const SizedBox(height: 15),

                    if (!_isLogin)
                      DropdownButtonFormField<String>(
                        value: _selectedRole,
                        items: const [
                          DropdownMenuItem(
                              value: 'student', child: Text('Student')),
                          DropdownMenuItem(
                              value: 'alumni', child: Text('Alumni')),
                          DropdownMenuItem(
                              value: 'admin', child: Text('Admin')),
                        ],
                        onChanged: (value) =>
                            setState(() => _selectedRole = value),
                        decoration: InputDecoration(
                          labelText: 'Select Role',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) =>
                            value == null ? 'Please select a role' : null,
                      ),
                    const SizedBox(height: 15),

                    TextFormField(
                      key: const ValueKey('email'),
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter your email';
                        if (!_isLogin && !EmailValidator.isValid(value)) return 'Please enter a valid email address';
                        return null;
                      },
                      onSaved: (value) => _email = value!,
                    ),
                    const SizedBox(height: 15),

                    TextFormField(
                      key: const ValueKey('password'),
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      validator: (value) => value!.length < 6
                          ? 'Password must be at least 6 characters'
                          : null,
                      onSaved: (value) => _password = value!,
                    ),
                    const SizedBox(height: 25),

                    _isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                            onPressed: _submit,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                              backgroundColor: Colors.green,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(_isLogin ? 'Login' : 'Register'),
                          ),
                    const SizedBox(height: 12),

                    TextButton(
                      onPressed: () => setState(() => _isLogin = !_isLogin),
                      child: Text(_isLogin
                          ? 'Create new account (Admin only)'
                          : 'Already have an account? Login'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
