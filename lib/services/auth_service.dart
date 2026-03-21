import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  static const _userIdKey = 'auth_user_id';
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _userId = '';

  String get userId => _userId;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getString(_userIdKey) ?? '';
      if (_auth.currentUser == null) {
        await _auth
            .signInAnonymously()
            .timeout(const Duration(seconds: 2));
      }
      final uid = _auth.currentUser?.uid ?? '';
      if (uid.isNotEmpty && uid != _userId) {
        _userId = uid;
        await prefs.setString(_userIdKey, uid);
      }
    } catch (_) {
      return;
    }
  }

  Future<String> ensureUserId() async {
    if (_userId.isNotEmpty) return _userId;
    try {
      await init().timeout(const Duration(seconds: 2));
    } catch (_) {
      return _userId;
    }
    return _userId;
  }
}
