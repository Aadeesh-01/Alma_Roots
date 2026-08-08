import 'package:cs261_project/screen/admin/admin_home_screen.dart';
import 'package:cs261_project/screen/student/user_home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cs261_project/screen/auth/account_deactivated_screen.dart';

class UserRoleDispatcher extends StatefulWidget {
  final String instituteId;
  const UserRoleDispatcher({super.key, required this.instituteId});

  @override
  State<UserRoleDispatcher> createState() => _UserRoleDispatcherState();
}

class _UserRoleDispatcherState extends State<UserRoleDispatcher> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _role;
  Map<String, dynamic>? _participantData;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print("❌ No logged-in user found.");
        setState(() => _loading = false);
        return;
      }

      print("🔍 Fetching role for UID: ${user.uid} in ${widget.instituteId}");

      final doc = await _firestore
          .collection('institutes')
          .doc(widget.instituteId)
          .collection('participants')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        print("🚨 No participant document found for this user.");
        // Clear cached state before signing out
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('lastInstituteId');
        await _auth.signOut();
        return;
      }

      if (doc.data()?['isDeleted'] == true || doc.data()?['status'] == 'deleted') {
        print("🚨 Account deactivated.");
        _role = 'deactivated';
        _participantData = doc.data();
        return;
      }

      _role = doc['role'] ?? 'student';
      print("✅ Role fetched: $_role");
    } catch (e) {
      print("❌ Error loading user role: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_role == null) {
      return const Scaffold(
        body: Center(child: Text("Unable to determine user role.")),
      );
    }

    switch (_role) {
      case 'deactivated':
        return AccountDeactivatedScreen(
          instituteId: widget.instituteId,
          participantData: _participantData ?? {},
        );
      case 'admin':
        return AdminHomeScreen(instituteId: widget.instituteId);
      case 'student':
      case 'alumni':
      default:
        return UserHomeScreen(instituteId: widget.instituteId);
    }
  }
}
