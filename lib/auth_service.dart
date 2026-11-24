import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authChanges => _auth.authStateChanges();

  Future<UserCredential> login(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> register(String email, String password) {
    return _auth.createUserWithEmailAndPassword(
        email: email, password: password);
  }
  bool _googleInitialized = false;
  Future<UserCredential> signInWithGoogle() async {
  final googleSignIn = GoogleSignIn.instance;
  if (!_googleInitialized) {
    await googleSignIn.initialize(
      serverClientId: '13552845518-qsih40t2errjr3597v1800bh8ipq7790.apps.googleusercontent.com',
    );
    _googleInitialized = true;
  }
  final account = await googleSignIn.authenticate();
  final idToken = account.authentication.idToken;
  final credential = GoogleAuthProvider.credential(idToken: idToken);
  return _auth.signInWithCredential(credential);
}

  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() => _auth.signOut();
}