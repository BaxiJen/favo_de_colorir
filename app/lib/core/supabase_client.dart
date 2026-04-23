import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Config do Supabase.
///
/// URL e anon key são **públicos por design** — o SDK envia a anon em
/// todo request HTTPS, quem protege os dados é o RLS do Postgres, não
/// o sigilo da chave. Embutir default hardcoded é aceitável pra
/// simplificar distribuição enquanto a gente não configura secrets +
/// `--dart-define` no CI.
///
/// Ordem de resolução:
///   1. `--dart-define=SUPABASE_URL=...` (quando configurar no CI)
///   2. `dotenv` em `app/.env` (dev local)
///   3. defaults hardcoded abaixo (APK do release sem secret)
///
/// Dívida: migrar pra secrets + --dart-define e remover defaults
/// quando tiver mais de um ambiente (staging/prod).
class SupabaseConfig {
  SupabaseConfig._();

  static const _envUrl = String.fromEnvironment('SUPABASE_URL');
  static const _envAnon = String.fromEnvironment('SUPABASE_ANON_KEY');

  // Projeto favo_de_colorir (sa-east-1). Anon key é pública.
  static const _defaultUrl = 'https://fhqklezevuqtqenbhsja.supabase.co';
  static const _defaultAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZocWtsZXpldnVxdHFlbmJoc2phIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU0OTk4NDUsImV4cCI6MjA5MTA3NTg0NX0.HaNUqVu9OvQzN3To9MKpjCK855Hs3ynfF9yEqtp-s10';

  static String get url {
    if (_envUrl.isNotEmpty) return _envUrl;
    final v = dotenv.env['SUPABASE_URL'] ?? '';
    return v.isEmpty ? _defaultUrl : v;
  }

  static String get anonKey {
    if (_envAnon.isNotEmpty) return _envAnon;
    final v = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
    return v.isEmpty ? _defaultAnonKey : v;
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
