import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_client.dart';
import '../models/profile.dart';

final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService();
});

final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  final userId = SupabaseConfig.auth.currentUser?.id;
  if (userId == null) return null;
  return ref.read(profileServiceProvider).getProfile(userId);
});

final pendingProfilesProvider = FutureProvider<List<Profile>>((ref) {
  return ref.read(profileServiceProvider).getPendingProfiles();
});

class ProfileService {
  SupabaseClient get _client => SupabaseConfig.client;

  Future<Profile?> getProfile(String userId) async {
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (data == null) return null;
    return Profile.fromJson(data);
  }

  Future<void> updateProfile(String userId, Map<String, dynamic> updates) async {
    await _client
        .from('profiles')
        .update(updates)
        .eq('id', userId);
  }

  Future<String> uploadAvatar(String userId, File file) async {
    final ext = file.path.split('.').last;
    final path = '$userId/avatar.$ext';

    await SupabaseConfig.storage
        .from('avatars')
        .upload(path, file, fileOptions: const FileOptions(upsert: true));

    final publicUrl = SupabaseConfig.storage
        .from('avatars')
        .getPublicUrl(path);

    await updateProfile(userId, {'avatar_url': publicUrl});

    return publicUrl;
  }

  Future<List<Profile>> getAllProfiles() async {
    final data = await _client
        .from('profiles')
        .select()
        .order('role')
        .order('full_name');
    return data.map((json) => Profile.fromJson(json)).toList();
  }

  Future<List<Profile>> getPendingProfiles() async {
    final data = await _client
        .from('profiles')
        .select()
        .eq('status', 'pending')
        .order('created_at');
    return data.map((json) => Profile.fromJson(json)).toList();
  }

  Future<void> approveProfile(String userId) async {
    await updateProfile(userId, {'status': 'active'});
    await _auditLog('approve_profile', userId);
  }

  Future<void> rejectProfile(String userId) async {
    await updateProfile(userId, {'status': 'blocked'});
    await _auditLog('reject_profile', userId);
  }

  /// Fire-and-forget registro de auditoria (nunca throw).
  Future<void> _auditLog(String action, String resourceId,
      {Map<String, dynamic>? changes}) async {
    try {
      final actorId = SupabaseConfig.auth.currentUser?.id;
      await _client.from('audit_logs').insert({
        'actor_id': actorId,
        'action': action,
        'resource_type': 'profile',
        'resource_id': resourceId,
        'changes': changes,
      });
    } catch (_) {}
  }

  /// Admin cria aluna via edge function
  Future<Map<String, dynamic>> createUser({
    required String email,
    required String fullName,
    String? phone,
    String? password,
    String role = 'student',
    List<String> turmaIds = const [],
  }) async {
    final response = await _client.functions.invoke(
      'criar-aluna',
      body: {
        'email': email,
        'full_name': fullName,
        // ignore: use_null_aware_elements
        if (phone != null) 'phone': phone,
        // ignore: use_null_aware_elements
        if (password != null) 'password': password,
        'role': role,
        'turma_ids': turmaIds,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// Marca o onboarding como concluído (chamado quando aluna termina o
  /// tutorial ou clica "pular"). Pode ser reexecutado pra revisitar.
  Future<void> markOnboarded(String userId) async {
    await updateProfile(userId, {
      'onboarded_at': DateTime.now().toIso8601String(),
    });
  }

  /// Limpa o flag de onboarding (usado pra "revisitar tutorial").
  Future<void> resetOnboarding(String userId) async {
    await updateProfile(userId, {'onboarded_at': null});
  }

  Future<void> deleteAccount(String userId) async {
    await _client.rpc('delete_user_account', params: {
      'p_user_id': userId,
    });
  }

  /// Admin dispara email de boas-vindas com magic link pra nova aluna/aluno.
  /// Retorna map com 'email' e 'magic_link'.
  Future<Map<String, dynamic>> sendCredentialsByEmail(String userId) async {
    final response = await _client.functions.invoke(
      'enviar-credenciais',
      body: {'user_id': userId},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Admin gera nova senha temporária. Retorna a senha gerada.
  Future<String> resetUserPassword(String userId) async {
    final response = await _client.functions.invoke(
      'reset-senha-usuario',
      body: {'user_id': userId},
    );
    final data = response.data as Map<String, dynamic>;
    if (data.containsKey('error')) {
      throw Exception(data['error']);
    }
    return data['password'] as String;
  }

  Future<void> rejectProfileWithReason(String userId, String reason) async {
    await updateProfile(userId, {
      'status': 'blocked',
      'rejection_reason': reason,
    });
    // Notifica a pessoa
    await _client.from('notifications').insert({
      'user_id': userId,
      'title': 'Cadastro não aprovado',
      'body': reason.isEmpty
          ? 'Seu cadastro não foi aprovado.'
          : 'Seu cadastro não foi aprovado: $reason',
      'type': 'approval',
    });
    await _auditLog('reject_profile', userId,
        changes: {'reason': reason});
  }
}
