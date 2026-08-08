import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// This screen allows an existing authenticated admin
/// to promote a user to Admin role by calling the
/// 'addAdminRole' Cloud Function.
class AddAdminScreen extends StatefulWidget {
  const AddAdminScreen({super.key});

  @override
  State<AddAdminScreen> createState() => _AddAdminScreenState();
}

class _AddAdminScreenState extends State<AddAdminScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  /// Calls the 'addAdminRole' Cloud Function to promote a user to admin.
  Future<void> _makeAdmin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final HttpsCallable callable =
          FirebaseFunctions.instance.httpsCallable('addAdminRole');

      final result = await callable.call<Map<String, dynamic>>({
        'email': _emailController.text.trim(),
      });

      setState(() {
        _successMessage =
            result.data['message'] ?? "Admin role granted successfully!";
        _emailController.clear();
      });
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _errorMessage = e.message ?? "Cloud Function error occurred.";
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Unexpected error: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Promote User to Admin"),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        "Grant Admin Privileges",
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      // Email input field
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: "User Email",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.email),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null ||
                              value.isEmpty ||
                              !value.contains('@')) {
                            return "Enter a valid email";
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 32),

                      // Button or loader
                      _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: _makeAdmin,
                              child: const Text(
                                "Make Admin",
                                style: TextStyle(fontSize: 16),
                              ),
                            ),

                      const SizedBox(height: 20),

                      // Success or error message
                      if (_successMessage != null)
                        Text(
                          _successMessage!,
                          style: const TextStyle(
                            color: Colors.green, // This could be colorScheme.primary but success is usually green
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      if (_errorMessage != null)
                        Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
