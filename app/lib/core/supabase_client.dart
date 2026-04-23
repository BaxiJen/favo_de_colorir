import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Config do Supabase. URL e anon key são lidos de:
/// 1. `--dart-define=SUPABASE_URL=...` (compile-time, vindo de CI secrets)
/// 2. `dotenv` em `app/.env` (dev local)
///
/// Se nenhum dos dois estiver definido, `initialize` lança exceção
/// clara — melhor quebrar rápido do que gerar um APK que tenta falar
/// com URL vazia e dá erro confuso de URI.
class SupabaseConfig {
  SupabaseConfig._();

  static const _envUrl = String.fromEnvironment('SUPABASE_URL');
  static const _envAnon = String.fromEnvironment('SUPABASE_ANON_KEY');

  static String get url {
    if (_envUrl.isNotEmpty) return _envUrl;
    final v = dotenv.env['SUPABASE_URL'] ?? '';
    if (v.isEmpty) {
      throw StateError(
          'SUPABASE_URL não definido. Configure via --dart-define no '
          'build (CI: secrets do repo) ou em app/.env (dev local).');
    }
    return v;
  }

  static String get anonKey {
    if (_envAnon.isNotEmpty) return _envAnon;
    final v = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
    if (v.isEmpty) {
      throw StateError(
          'SUPABASE_ANON_KEY não definido. Configure via --dart-define no '
          'build (CI: secrets do repo) ou em app/.env (dev local).');
    }
    return v;
  }

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => client.auth;
  static SupabaseStorageClient get storage => client.storage;
}
