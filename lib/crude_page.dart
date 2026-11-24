import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// CRUD screen. Each user's items are stored in:
/// users/{uid}/items/{itemId}
///   -> { name: String, quantity: int, isFavorite: bool, createdAt: Timestamp }
class CrudPage extends StatefulWidget {
  const CrudPage({super.key});

  @override
  State<CrudPage> createState() => _CrudPageState();
}

class _CrudPageState extends State<CrudPage> {
  final _user = FirebaseAuth.instance.currentUser!;
  bool _favoritesOnly = false;

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
      'isFavorite': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------- UPDATE ----------
  Future<void> _updateItem(String id, String name, int quantity) async {
    await _items.doc(id).update({'name': name, 'quantity': quantity});
  }

  Future<void> _toggleFavorite(String id, bool isFavorite) async {
    try {
      await _items.doc(id).update({'isFavorite': !isFavorite});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update favorite: $error')),
      );
    }
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
    String? validationError;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFFF4EFF7),
          title: Text(isEdit ? 'Edit item' : 'Add item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
                ),
              ),
              if (validationError != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    validationError!,
                    style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                  ),
                ),
              ],
            ],
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
              onPressed: () {
                final n = nameCtrl.text.trim();
                final q = int.tryParse(qtyCtrl.text.trim());
                if (n.isEmpty || q == null) {
                  setDialogState(() =>
                      validationError = 'Enter a name and a valid quantity');
                  return;
                }
                // Only return the values. Saving happens below.
                Navigator.pop(ctx, {'name': n, 'quantity': q});
              },
              child: Text(isEdit ? 'Update' : 'Save'),
            ),
          ],
        ),
      ),
    );

    // NOTE: do not dispose the controllers here. The dialog is still
    // animating out and disposing them causes the red error screen.

    if (result == null || !mounted) return;
    try {
      final savedName = result['name'] as String;
      final savedQuantity = result['quantity'] as int;
      if (isEdit) {
        await _updateItem(id, savedName, savedQuantity);
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
          final allDocs = snapshot.data!.docs;
          if (allDocs.isEmpty) {
            return const Center(child: Text('No items yet. Tap + to add.'));
          }
          final docs = _favoritesOnly
              ? allDocs.where((doc) => doc.data()['isFavorite'] == true).toList()
              : allDocs;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('All')),
                    ButtonSegment(
                      value: true,
                      label: Text('Favorites'),
                      icon: Icon(Icons.star),
                    ),
                  ],
                  selected: {_favoritesOnly},
                  onSelectionChanged: (selection) {
                    setState(() => _favoritesOnly = selection.first);
                  },
                ),
              ),
              if (docs.isEmpty)
                const Expanded(
                  child: Center(
                      child: Text('No favorites yet. Star an item to save it.')),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final doc = docs[i];
                      final data = doc.data();
                      final name = data['name'] ?? '';
                      final qty = data['quantity'] ?? 0;
                      final isFavorite = data['isFavorite'] == true;
                      return Card(
                        color: const Color(0xFFF4EFF7),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          title: Text(name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('Quantity $qty'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: isFavorite
                                    ? 'Remove favorite'
                                    : 'Add favorite',
                                icon: Icon(
                                  isFavorite ? Icons.star : Icons.star_border,
                                  color: isFavorite
                                      ? Colors.amber.shade800
                                      : Colors.grey,
                                ),
                                onPressed: () =>
                                    _toggleFavorite(doc.id, isFavorite),
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.edit, color: Colors.orange),
                                onPressed: () => _showItemDialog(
                                    id: doc.id, name: name, quantity: qty),
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _confirmDelete(doc.id, name),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
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

