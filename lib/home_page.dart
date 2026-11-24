import 'package:flutter/material.dart';

import 'auth_service.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    final user = auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Regidor')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (user?.photoURL != null)
              CircleAvatar(
                  radius: 36, backgroundImage: NetworkImage(user!.photoURL!)),
            const SizedBox(height: 12),
            const Text('Signed in as'),
            Text(user?.displayName ?? user?.email ?? 'Unknown',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: auth.signOut,
              child: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}