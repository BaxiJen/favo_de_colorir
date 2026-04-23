import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error_handler.dart';
import '../../core/theme.dart';
import '../../core/widgets/user_avatar.dart';
import '../../models/profile.dart';
import '../../services/profile_service.dart';

final allProfilesProvider = FutureProvider<List<Profile>>((ref) {
  return ref.read(profileServiceProvider).getAllProfiles();
});

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  String _roleFilter = 'all';
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profilesAsync = ref.watch(allProfilesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Gestão de Usuários')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar por nome ou e-mail',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      ),
              ),
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
            ),
          ),
          const SizedBox(height: 8),
          // Filter chips
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                _buildChip('Todos', 'all'),
                _buildChip('Admin', 'admin'),
                _buildChip('Professora', 'teacher'),
                _buildChip('Estudante', 'student'),
                _buildChip('Assistente', 'assistant'),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: profilesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(friendlyError(e))),
              data: (profiles) {
                var filtered = profiles;
                if (_roleFilter != 'all') {
                  filtered = filtered
                      .where((p) => p.role.name == _roleFilter)
                      .toList();
                }
                if (_searchQuery.isNotEmpty) {
                  final q = _searchQuery.toLowerCase();
                  filtered = filtered
                      .where((p) =>
                          p.fullName.toLowerCase().contains(q) ||
                          p.email.toLowerCase().contains(q))
                      .toList();
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        _searchQuery.isNotEmpty
                            ? 'Nenhum resultado pra "$_searchQuery"'
                            : 'Nenhum usuário',
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => ref.refresh(allProfilesProvider.future),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) =>
                        _UserCard(profile: filtered[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, String value) {
    final selected = _roleFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _roleFilter = value),
      ),
    );
  }
}

class _UserCard extends ConsumerWidget {
  final Profile profile;

  const _UserCard({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: FavoColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ExpansionTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: UserAvatar(
          avatarUrl: profile.avatarUrl,
          name: profile.fullName,
          radius: 20,
          backgroundColor: _roleColor(profile.role).withAlpha(30),
          foregroundColor: _roleColor(profile.role),
        ),
        title:
            Text(profile.fullName, style: Theme.of(context).textTheme.titleSmall),
        subtitle: Row(
          children: [
            _RoleBadge(profile.role),
            const SizedBox(width: 6),
            Icon(
              profile.isActive ? Icons.check_circle : Icons.hourglass_empty,
              size: 14,
              color: profile.isActive ? FavoColors.success : FavoColors.primary,
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.email,
                    style: Theme.of(context).textTheme.bodySmall),
                if (profile.phone != null)
                  Text(profile.phone!,
                      style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 16),
                Text('Alterar papel:',
                    style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: UserRole.values.map((role) {
                    return ChoiceChip(
                      label: Text(_roleLabel(role)),
                      selected: profile.role == role,
                      onSelected: profile.role == role
                          ? null
                          : (_) => _changeRole(context, ref, role),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Text('Status:',
                    style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: UserStatus.values.map((status) {
                    return ChoiceChip(
                      label: Text(_statusLabel(status)),
                      selected: profile.status == status,
                      onSelected: profile.status == status
                          ? null
                          : (_) => _changeStatus(context, ref, status),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => _resetPassword(context, ref),
                  icon: const Icon(Icons.vpn_key_outlined, size: 18),
                  label: const Text('Gerar nova senha'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changeRole(
      BuildContext context, WidgetRef ref, UserRole newRole) async {
    final ok = await _confirm(
      context,
      title: 'Mudar papel?',
      body:
          '${profile.fullName} passa de "${_roleLabel(profile.role)}" pra "${_roleLabel(newRole)}".',
    );
    if (!ok) return;
    try {
      await ref
          .read(profileServiceProvider)
          .updateProfile(profile.id, {'role': newRole.name});
      ref.invalidate(allProfilesProvider);
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, e);
    }
  }

  Future<void> _changeStatus(
      BuildContext context, WidgetRef ref, UserStatus status) async {
    final destructive = status == UserStatus.blocked ||
        status == UserStatus.inactive;
    if (destructive) {
      final ok = await _confirm(
        context,
        title: status == UserStatus.blocked
            ? 'Bloquear ${profile.fullName}?'
            : 'Desativar ${profile.fullName}?',
        body: status == UserStatus.blocked
            ? 'A pessoa não vai conseguir entrar no app enquanto estiver bloqueada.'
            : 'A pessoa não aparece em turmas e listagens ativas. Dá pra reativar depois.',
        confirmLabel: status == UserStatus.blocked ? 'Bloquear' : 'Desativar',
        destructive: true,
      );
      if (!ok) return;
    }
    try {
      await ref
          .read(profileServiceProvider)
          .updateProfile(profile.id, {'status': status.name});
      ref.invalidate(allProfilesProvider);
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, e);
    }
  }

  Future<void> _resetPassword(BuildContext context, WidgetRef ref) async {
    final ok = await _confirm(
      context,
      title: 'Gerar nova senha?',
      body:
          'A senha atual de ${profile.fullName} vai deixar de funcionar. Você recebe a nova pra repassar.',
      confirmLabel: 'Gerar',
    );
    if (!ok) return;
    try {
      final newPassword = await ref
          .read(profileServiceProvider)
          .resetUserPassword(profile.id);
      if (!context.mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Nova senha'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Envia pra ${profile.fullName}:',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: FavoColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        newPassword,
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 16),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: newPassword));
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Senha copiada!')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK')),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, e);
    }
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    String confirmLabel = 'Confirmar',
    bool destructive = false,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: destructive
                    ? ElevatedButton.styleFrom(
                        backgroundColor: FavoColors.error,
                      )
                    : null,
                child: Text(confirmLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  Color _roleColor(UserRole role) => switch (role) {
        UserRole.admin => FavoColors.secondary,
        UserRole.teacher => FavoColors.primary,
        UserRole.assistant => FavoColors.onSurfaceVariant,
        UserRole.student => FavoColors.outline,
      };

  String _roleLabel(UserRole role) => switch (role) {
        UserRole.admin => 'Admin',
        UserRole.teacher => 'Professora',
        UserRole.assistant => 'Assistente',
        UserRole.student => 'Estudante',
      };

  String _statusLabel(UserStatus status) => switch (status) {
        UserStatus.active => 'Ativo',
        UserStatus.pending => 'Pendente',
        UserStatus.inactive => 'Inativo',
        UserStatus.blocked => 'Bloqueado',
      };
}

class _RoleBadge extends StatelessWidget {
  final UserRole role;
  const _RoleBadge(this.role);

  @override
  Widget build(BuildContext context) {
    final color = switch (role) {
      UserRole.admin => FavoColors.secondary,
      UserRole.teacher => FavoColors.primary,
      _ => FavoColors.outline,
    };
    final label = switch (role) {
      UserRole.admin => 'Admin',
      UserRole.teacher => 'Prof',
      UserRole.assistant => 'Assist',
      UserRole.student => 'Estudante',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
