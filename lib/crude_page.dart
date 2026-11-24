import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// CRUD screen. Each user's items are stored in:
/// users/{uid}/items/{itemId}  ->  { name: String, quantity: int, createdAt: Timestamp }
class CrudPage extends StatefulWidget {
  const CrudPage({super.key});

  @override
  State<CrudPage> createState() => _CrudPageState();
}

class _CrudPageState extends State<CrudPage> {
  final _user = FirebaseAuth.instance.currentUser!;

  CollectionReference<Map<String, dynamic>> get _items => FirebaseFirestore
      .instance
      .collection('users')
      .doc(_user.uid)
      .collection('items');

  // ---------- CREATE ----------
  Future<void> _addItem(String name, int quantity) async {
    await _items.add({
      'name': name,
      'quantity': quantity,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------- UPDATE ----------
  Future<void> _updateItem(String id, String name, int quantity) async {
    await _items.doc(id).update({'name': name, 'quantity': quantity});
  }

  // ---------- DELETE ----------
  Future<void> _deleteItem(String id) async {
    await _items.doc(id).delete();
  }

  // ---------- DIALOG (used for both Add and Edit) ----------
  Future<void> _showItemDialog({String? id, String? name, int? quantity}) async {
    final isEdit = id != null;
    final nameCtrl = TextEditingController(text: name ?? '');
    final qtyCtrl = TextEditingController(text: quantity?.toString() ?? '');
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFF4EFF7),
        title: Text(isEdit ? 'Edit item' : 'Add item'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a name'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    int.tryParse(value?.trim() ?? '') == null
                        ? 'Enter a whole number'
                        : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isEdit ? Colors.orange : Colors.teal,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final n = nameCtrl.text.trim();
              final q = int.tryParse(qtyCtrl.text.trim());
              if (q == null) return;
              Navigator.pop(ctx, {'name': n, 'quantity': q});
            },
            child: Text(isEdit ? 'Update' : 'Save'),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
    qtyCtrl.dispose();

    if (result == null || !mounted) return;
    try {
      final savedName = result['name'] as String;
      final savedQuantity = result['quantity'] as int;
      if (isEdit) {
        await _updateItem(id!, savedName, savedQuantity);
      } else {
        await _addItem(savedName, savedQuantity);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save item: $error')),
      );
    }
  }

  Future<void> _confirmDelete(String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete item'),
        content: Text('Delete "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) await _deleteItem(id);
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Regidor'),
        centerTitle: true,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            
            },
          ),
        ],
      ),
      // ---------- READ ----------
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _items.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No items yet. Tap + to add.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data();
              final name = data['name'] ?? '';
              final qty = data['quantity'] ?? 0;
              return Card(
                color: const Color(0xFFF4EFF7),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  title: Text(name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('Quantity $qty'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.orange),
                        onPressed: () => _showItemDialog(
                            id: doc.id, name: name, quantity: qty),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmDelete(doc.id, name),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        onPressed: () => _showItemDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
