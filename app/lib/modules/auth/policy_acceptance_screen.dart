import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../services/policy_service.dart';

class PolicyAcceptanceScreen extends ConsumerStatefulWidget {
  const PolicyAcceptanceScreen({super.key});

  @override
  ConsumerState<PolicyAcceptanceScreen> createState() =>
      _PolicyAcceptanceScreenState();
}

class _PolicyAcceptanceScreenState
    extends ConsumerState<PolicyAcceptanceScreen> {
  bool _accepted = false;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final policiesAsync = ref.watch(activePoliciesProvider);

    return Scaffold(
      body: SafeArea(
        child: policiesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              Center(child: Text('Erro ao carregar políticas: $error')),
          data: (policies) => Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
                  children: [
                    Text(
                      'Políticas do',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    Text(
                      'Ateliê.',
                      style:
                          Theme.of(context).textTheme.headlineLarge?.copyWith(
                                fontStyle: FontStyle.italic,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Antes de continuar, leia e aceite as políticas do ateliê.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 28),
                    ...policies.map(
                      (policy) => _PolicyCard(
                        title: policy.title,
                        content: policy.content,
                      ),
                    ),
                  ],
                ),
              ),

              // Accept section
              Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                decoration: BoxDecoration(
                  color: FavoColors.surfaceContainerLow,
                ),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _accepted = !_accepted),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: _accepted
                                  ? FavoColors.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              border: _accepted
                                  ? null
                                  : Border.all(
                                      color: FavoColors.outline, width: 1.5),
                            ),
                            child: _accepted
                                ? const Icon(Icons.check,
                                    size: 16, color: FavoColors.onPrimary)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Li e aceito todas as políticas do ateliê',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    color: FavoColors.onSurface,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            _accepted && !_isLoading ? _handleAcceptance : null,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Continuar'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleAcceptance() async {
    setState(() => _isLoading = true);
    try {
      final userId = SupabaseConfig.auth.currentUser!.id;
      await ref.read(policyServiceProvider).acceptAllPolicies(userId);
      if (mounted) context.go('/pending');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

class _PolicyCard extends StatelessWidget {
  final String title;
  final String content;

  const _PolicyCard({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FavoColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(content, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
