import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../core/utils/platform_support.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    // Added for Supabase Google Authn
    // serverClientId: 'YOUR_SERVER_CLIENT_ID', // Optional if using idToken
  );

  /// Migrated to Supabase Google Auth (Removed Firebase)
  Future<AuthResponse?> signInWithGoogle() async {
    if (!PlatformSupport.supportsGoogleSignIn) {
      debugPrint('Google Sign-In is not supported on this platform.');
      return null;
    }

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw 'No ID Token found.';
      }

      return await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
    } catch (e) {
      debugPrint('Error signing in with Google (Supabase): $e');
      return null;
    }
  }

  Future<void> signOut() async {
    if (PlatformSupport.supportsGoogleSignIn) {
      await _googleSignIn.signOut();
    }
    await _supabase.auth.signOut();
  }
}
