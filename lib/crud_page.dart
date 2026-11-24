import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'crud_service.dart';

class CrudPage extends StatefulWidget {
  const CrudPage({super.key});

  @override
  State<CrudPage> createState() => _CrudPageState();
}

class _CrudPageState extends State<CrudPage> {
  final _service = CrudService();
  bool _favoritesOnly = false;
  bool _isSaving = false;

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // ---------- DIALOG (used for both Add and Edit) ----------
  Future<void> _showItemDialog({
    String? id,
    String? name,
    int? quantity,
    String? imageUrl,
  }) async {
    final isEdit = id != null;
    final nameCtrl = TextEditingController(text: name ?? '');
    final qtyCtrl = TextEditingController(text: quantity?.toString() ?? '');
    String? validationError;
    File? pickedImage;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFFF4EFF7),
          title: Text(isEdit ? 'Edit item' : 'Add item'),
          content: SingleChildScrollView(
            child: Column(
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
                const SizedBox(height: 12),
                // Image preview (new pick, or the existing image when editing)
                if (pickedImage != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(pickedImage!,
                        height: 100, width: 100, fit: BoxFit.cover),
                  )
                else if (imageUrl != null && imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(imageUrl,
                        height: 100, width: 100, fit: BoxFit.cover),
                  ),
                TextButton.icon(
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Upload image'),
                  onPressed: () async {
                    final file = await _service.pickImageForAddItem();
                    if (file != null) {
                      setDialogState(() => pickedImage = file);
                    }
                  },
                ),
                if (validationError != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      validationError!,
                      style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                    ),
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
              onPressed: () {
                final n = nameCtrl.text.trim();
                final q = int.tryParse(qtyCtrl.text.trim());
                if (n.isEmpty || q == null) {
                  setDialogState(() =>
                      validationError = 'Enter a name and a valid quantity');
                  return;
                }
                // Only return the values. Uploading/saving happens below.
                Navigator.pop(ctx, {
                  'name': n,
                  'quantity': q,
                  'image': pickedImage,
                });
              },
              child: Text(isEdit ? 'Update' : 'Save'),
            ),
          ],
        ),
      ),
    );

    // NOTE: do not dispose the controllers here (dialog is still closing).

    if (result == null || !mounted) return;

    setState(() => _isSaving = true);
    try {
      String? newImageUrl;
      final image = result['image'] as File?;
      if (image != null) {
        newImageUrl = await _service.uploadImage(image); // Cloudinary
      }

      final savedName = result['name'] as String;
      final savedQuantity = result['quantity'] as int;
      if (isEdit) {
        await _service.updateItem(id!, savedName, savedQuantity,
            imageUrl: newImageUrl);
      } else {
        await _service.addItem(savedName, savedQuantity,
            imageUrl: newImageUrl);
      }
    } catch (error) {
      _showMessage('Could not save item: $error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
    if (ok == true) {
      try {
        await _service.deleteItem(id);
      } catch (error) {
        _showMessage('Could not delete: $error');
      }
    }
  }

  Widget _buildLeading(String imageUrl) {
    if (imageUrl.isEmpty) return const SizedBox(width: 0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        imageUrl,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.broken_image, size: 40, color: Colors.grey),
      ),
    );
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
        bottom: _isSaving
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      // ---------- READ ----------
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _service.items.snapshots(),
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
              ? allDocs.where((d) => d.data()['isFavorite'] == true).toList()
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
                  onSelectionChanged: (s) =>
                      setState(() => _favoritesOnly = s.first),
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
                      final imageUrl = (data['imageUrl'] ?? '') as String;
                      final isFavorite = data['isFavorite'] == true;
                      return Card(
                        color: const Color(0xFFF4EFF7),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: imageUrl.isEmpty
                              ? null
                              : _buildLeading(imageUrl),
                          title: Text(name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text('Quantity $qty'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  isFavorite ? Icons.star : Icons.star_border,
                                  color: isFavorite
                                      ? Colors.amber.shade800
                                      : Colors.grey,
                                ),
                                onPressed: () => _service
                                    .toggleFavorite(doc.id, isFavorite),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit,
                                    color: Colors.orange),
                                onPressed: () => _showItemDialog(
                                  id: doc.id,
                                  name: name,
                                  quantity: qty,
                                  imageUrl: imageUrl,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete,
                                    color: Colors.red),
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
