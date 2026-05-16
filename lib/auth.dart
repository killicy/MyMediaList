import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'config.dart';

class MalAuth {
  static const _authorizeUrl = 'https://myanimelist.net/v1/oauth2/authorize';
  static const _tokenUrl = 'https://myanimelist.net/v1/oauth2/token';
  static const _redirectUri = 'mymedialist://oauth/callback';
  static const _callbackScheme = 'mymedialist';

  // MAL historically only accepts `plain` code_challenge_method, so
  // code_challenge == code_verifier. Keep this until MAL confirms S256.
  static const _challengeMethod = 'plain';

  static const _storage = FlutterSecureStorage();
  static const _kAccess = 'mal_access_token';
  static const _kRefresh = 'mal_refresh_token';
  static const _kExpiry = 'mal_expiry_epoch_ms';

  static String? _cachedAccess;

  static Future<String?> get accessToken async {
    if (_cachedAccess != null) return _cachedAccess;
    _cachedAccess = await _storage.read(key: _kAccess);
    return _cachedAccess;
  }

  static Future<bool> get isSignedIn async => (await accessToken) != null;

  static Future<void> signIn() async {
    final verifier = _generateVerifier();
    final state = _generateState();

    final authorize = Uri.parse(_authorizeUrl).replace(queryParameters: {
      'response_type': 'code',
      'client_id': malClientId,
      'code_challenge': verifier, // plain method
      'code_challenge_method': _challengeMethod,
      'redirect_uri': _redirectUri,
      'state': state,
    });

    final result = await FlutterWebAuth2.authenticate(
      url: authorize.toString(),
      callbackUrlScheme: _callbackScheme,
    );

    final callback = Uri.parse(result);
    final code = callback.queryParameters['code'];
    final returnedState = callback.queryParameters['state'];
    final error = callback.queryParameters['error'];

    if (error != null) {
      throw Exception('MAL auth error: $error');
    }
    if (code == null) {
      throw Exception('MAL auth: no code returned');
    }
    if (returnedState != state) {
      throw Exception('MAL auth: state mismatch');
    }

    final res = await http.post(
      Uri.parse(_tokenUrl),
      body: {
        'client_id': malClientId,
        'code': code,
        'code_verifier': verifier,
        'grant_type': 'authorization_code',
        'redirect_uri': _redirectUri,
      },
    );
    if (res.statusCode != 200) {
      throw Exception('MAL token exchange ${res.statusCode}: ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    await _persist(body);
  }

  static Future<void> signOut() async {
    _cachedAccess = null;
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
    await _storage.delete(key: _kExpiry);
  }

  static Future<void> _persist(Map<String, dynamic> token) async {
    final access = token['access_token'] as String;
    final refresh = token['refresh_token'] as String?;
    final expiresIn = (token['expires_in'] as num?)?.toInt() ?? 3600;
    final expiry = DateTime.now()
        .add(Duration(seconds: expiresIn))
        .millisecondsSinceEpoch;
    _cachedAccess = access;
    await _storage.write(key: _kAccess, value: access);
    if (refresh != null) {
      await _storage.write(key: _kRefresh, value: refresh);
    }
    await _storage.write(key: _kExpiry, value: '$expiry');
  }

  static String _generateVerifier() {
    // 96 random bytes -> 128 char URL-safe string (within 43–128 limit)
    final rand = Random.secure();
    final bytes = List<int>.generate(96, (_) => rand.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  static String _generateState() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}
