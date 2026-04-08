import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/supabase_client.dart';

final policyServiceProvider = Provider<PolicyService>((ref) {
  return PolicyService();
});

final activePoliciesProvider = FutureProvider<List<Policy>>((ref) {
  return ref.read(policyServiceProvider).getActivePolicies();
});

final hasAcceptedAllPoliciesProvider = FutureProvider<bool>((ref) async {
  final userId = SupabaseConfig.auth.currentUser?.id;
  if (userId == null) return false;
  return ref.read(policyServiceProvider).hasAcceptedAll(userId);
});

class Policy {
  final String id;
  final String title;
  final String content;
  final int version;
  final DateTime publishedAt;

  const Policy({
    required this.id,
    required this.title,
    required this.content,
    required this.version,
    required this.publishedAt,
  });

  factory Policy.fromJson(Map<String, dynamic> json) {
    return Policy(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      version: json['version'] as int,
      publishedAt: DateTime.parse(json['published_at'] as String),
    );
  }
}

class PolicyService {
  final _client = SupabaseConfig.client;

  Future<List<Policy>> getActivePolicies() async {
    final data = await _client
        .from('policies')
        .select()
        .eq('is_active', true)
        .order('published_at');
    return data.map((json) => Policy.fromJson(json)).toList();
  }

  Future<List<Map<String, dynamic>>> getUserAcceptances(String userId) async {
    return await _client
        .from('policy_acceptances')
        .select()
        .eq('user_id', userId);
  }

  Future<bool> hasAcceptedAll(String userId) async {
    final policies = await getActivePolicies();
    if (policies.isEmpty) return true;

    final acceptances = await getUserAcceptances(userId);
    final acceptedIds = acceptances
        .map((a) => a['policy_id'] as String)
        .toSet();

    return policies.every((p) => acceptedIds.contains(p.id));
  }

  Future<void> acceptPolicy(String userId, String policyId) async {
    await _client.from('policy_acceptances').upsert({
      'user_id': userId,
      'policy_id': policyId,
    });
  }

  Future<void> acceptAllPolicies(String userId) async {
    final policies = await getActivePolicies();
    for (final policy in policies) {
      await acceptPolicy(userId, policy.id);
    }
  }
}
