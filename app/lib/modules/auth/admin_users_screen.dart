import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
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
  String _statusFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final profilesAsync = ref.watch(allProfilesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestão de Usuários'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: Column(
        children: [
          // Filtros
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _roleFilter,
                    decoration: const InputDecoration(
                      labelText: 'Papel',
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('Todos')),
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                      DropdownMenuItem(
                          value: 'teacher', child: Text('Professora')),
                      DropdownMenuItem(
                          value: 'assistant', child: Text('Assistente')),
                      DropdownMenuItem(
                          value: 'student', child: Text('Aluna')),
                    ],
                    onChanged: (v) =>
                        setState(() => _roleFilter = v ?? 'all'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _statusFilter,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('Todos')),
                      DropdownMenuItem(
                          value: 'active', child: Text('Ativo')),
                      DropdownMenuItem(
                          value: 'pending', child: Text('Pendente')),
                      DropdownMenuItem(
                          value: 'inactive', child: Text('Inativo')),
                      DropdownMenuItem(
                          value: 'blocked', child: Text('Bloqueado')),
                    ],
                    onChanged: (v) =>
                        setState(() => _statusFilter = v ?? 'all'),
                  ),
                ),
              ],
            ),
          ),

          // Lista
          Expanded(
            child: profilesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erro: $e')),
              data: (profiles) {
                var filtered = profiles;
                if (_roleFilter != 'all') {
                  filtered = filtered
                      .where((p) => p.role.name == _roleFilter)
                      .toList();
                }
                if (_statusFilter != 'all') {
                  filtered = filtered
                      .where((p) => p.status.name == _statusFilter)
                      .toList();
                }

                if (filtered.isEmpty) {
                  return const Center(
                      child: Text('Nenhum usuário encontrado'));
                }

                return RefreshIndicator(
                  onRefresh: () => ref.refresh(allProfilesProvider.future),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      return _UserCard(profile: filtered[index]);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _UserCard extends ConsumerWidget {
  final Profile profile;

  const _UserCard({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _roleColor(profile.role).withAlpha(30),
          child: Text(
            profile.fullName.isNotEmpty
                ? profile.fullName[0].toUpperCase()
                : '?',
            style: TextStyle(
              color: _roleColor(profile.role),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(profile.fullName),
        subtitle: Row(
          children: [
            _RoleChip(profile.role),
            const SizedBox(width: 8),
            _StatusChip(profile.status),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.email,
                    style: Theme.of(context).textTheme.bodySmall),
                if (profile.phone != null)
                  Text(profile.phone!,
                      style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 16),

                // Mudar papel
                Text('Alterar papel:',
                    style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: UserRole.values.map((role) {
                    final isSelected = profile.role == role;
                    return ChoiceChip(
                      label: Text(_roleLabel(role)),
                      selected: isSelected,
                      onSelected: isSelected
                          ? null
                          : (_) => _changeRole(context, ref, role),
                      selectedColor: _roleColor(role).withAlpha(50),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Mudar status
                Text('Alterar status:',
                    style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: UserStatus.values.map((status) {
                    final isSelected = profile.status == status;
                    return ChoiceChip(
                      label: Text(_statusLabel(status)),
                      selected: isSelected,
                      onSelected: isSelected
                          ? null
                          : (_) => _changeStatus(context, ref, status),
                      selectedColor: _statusColor(status).withAlpha(50),
                    );
                  }).toList(),
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
    try {
      await ref
          .read(profileServiceProvider)
          .updateProfile(profile.id, {'role': newRole.name});
      ref.invalidate(allProfilesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${profile.fullName} agora é ${_roleLabel(newRole)}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }

  Future<void> _changeStatus(
      BuildContext context, WidgetRef ref, UserStatus newStatus) async {
    try {
      await ref
          .read(profileServiceProvider)
          .updateProfile(profile.id, {'status': newStatus.name});
      ref.invalidate(allProfilesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${profile.fullName} agora está ${_statusLabel(newStatus)}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }

  String _roleLabel(UserRole role) {
    return switch (role) {
      UserRole.admin => 'Admin',
      UserRole.teacher => 'Professora',
      UserRole.assistant => 'Assistente',
      UserRole.student => 'Aluna',
    };
  }

  String _statusLabel(UserStatus status) {
    return switch (status) {
      UserStatus.active => 'Ativo',
      UserStatus.pending => 'Pendente',
      UserStatus.inactive => 'Inativo',
      UserStatus.blocked => 'Bloqueado',
    };
  }

  Color _roleColor(UserRole role) {
    return switch (role) {
      UserRole.admin => FavoColors.terracotta,
      UserRole.teacher => FavoColors.honey,
      UserRole.assistant => FavoColors.honeyDark,
      UserRole.student => FavoColors.warmGray,
    };
  }

  Color _statusColor(UserStatus status) {
    return switch (status) {
      UserStatus.active => FavoColors.success,
      UserStatus.pending => FavoColors.honey,
      UserStatus.inactive => FavoColors.warmGray,
      UserStatus.blocked => FavoColors.error,
    };
  }
}

class _RoleChip extends StatelessWidget {
  final UserRole role;
  const _RoleChip(this.role);

  @override
  Widget build(BuildContext context) {
    final color = switch (role) {
      UserRole.admin => FavoColors.terracotta,
      UserRole.teacher => FavoColors.honey,
      UserRole.assistant => FavoColors.honeyDark,
      UserRole.student => FavoColors.warmGray,
    };
    final label = switch (role) {
      UserRole.admin => 'Admin',
      UserRole.teacher => 'Prof',
      UserRole.assistant => 'Assist',
      UserRole.student => 'Aluna',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final UserStatus status;
  const _StatusChip(this.status);

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      UserStatus.active => FavoColors.success,
      UserStatus.pending => FavoColors.honey,
      UserStatus.inactive => FavoColors.warmGray,
      UserStatus.blocked => FavoColors.error,
    };
    final icon = switch (status) {
      UserStatus.active => Icons.check_circle,
      UserStatus.pending => Icons.hourglass_empty,
      UserStatus.inactive => Icons.pause_circle,
      UserStatus.blocked => Icons.block,
    };

    return Icon(icon, size: 16, color: color);
  }
}
