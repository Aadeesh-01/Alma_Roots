import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminInstituteListScreen extends StatefulWidget {
  const AdminInstituteListScreen({super.key});

  @override
  State<AdminInstituteListScreen> createState() =>
      _AdminInstituteListScreenState();
}

class _AdminInstituteListScreenState extends State<AdminInstituteListScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _instituteNameController = TextEditingController();
  bool _isAdding = false;

  Future<void> _addInstitute() async {
    final name = _instituteNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Institute name cannot be empty"),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    setState(() => _isAdding = true);

    try {
      await _firestore.collection('institutes').add({
        'name': name,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _instituteNameController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Institute added successfully!"),
          backgroundColor: Colors.green, // Success
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _deleteInstitute(String id) async {
    try {
      await _firestore.collection('institutes').doc(id).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Institute deleted"),
          backgroundColor: Colors.red, // Deletion is red
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  void dispose() {
    _instituteNameController.dispose();
    super.dispose();
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
          "Manage Institutes",
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        surfaceTintColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _instituteNameController,
                    decoration: InputDecoration(
                      labelText: "Institute Name",
                      prefixIcon: const Icon(Icons.account_balance_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _isAdding
                    ? const SizedBox(
                        height: 54,
                        width: 54,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : ElevatedButton(
                        onPressed: _addInstitute,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          minimumSize: const Size(80, 54),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Add",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
              ],
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Institute List",
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('institutes')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text("No institutes added yet."),
                    );
                  }

                  final institutes = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: institutes.length,
                    itemBuilder: (context, index) {
                      final doc = institutes[index];
                      final name = doc['name'] ?? 'Unnamed';
                      final id = doc.id;

                      return Card(
                        color: colorScheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: theme.dividerColor),
                        ),
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.account_balance,
                                color: colorScheme.primary),
                          ),
                          title: Text(name,
                              style:
                                  textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                          trailing: IconButton(
                            icon: Icon(Icons.delete_outline, color: colorScheme.error),
                            onPressed: () => _deleteInstitute(id),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
