import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _auth = AuthService();
  bool _loading = false;

  void _msg(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _loading = true);
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      _msg(e.message ?? e.code);
    } catch (e) {
      _msg(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _login() => _run(() async {
        await _auth.login(_email.text.trim(), _password.text.trim());
      });

  Future<void> _google() => _run(() async {
        await _auth.signInWithGoogle();
      });

  Future<void> _forgot() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      _msg('Type your email first');
      return;
    }
    await _run(() async {
      await _auth.sendPasswordReset(email);
      _msg('Reset link sent. Check your email.');
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Regidor')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                    labelText: 'Email', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Password', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              if (_loading)
                const CircularProgressIndicator()
              else ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                      onPressed: _login, child: const Text('Login')),
                ),
                TextButton(
                  onPressed: _forgot,
                  child: const Text('Forgot your password?'),
                ),
                const Divider(),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _google,
                    icon: const Icon(Icons.g_mobiledata, size: 32),
                    label: const Text('Sign in with Google'),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterPage()),
                  ),
                  child: const Text("Don't have an account? Register"),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}