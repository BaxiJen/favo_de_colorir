import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/profile.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  bool _isEditing = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu Perfil'),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
            ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erro: $error')),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Perfil não encontrado'));
          }

          if (!_isEditing) {
            return _buildProfileView(context, profile);
          }

          _nameController.text = profile.fullName;
          _phoneController.text = profile.phone ?? '';

          return _buildProfileEdit(context, profile);
        },
      ),
    );
  }

  Widget _buildProfileView(BuildContext context, Profile profile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Avatar
          CircleAvatar(
            radius: 48,
            backgroundColor: FavoColors.honeyLight,
            backgroundImage: profile.avatarUrl != null
                ? NetworkImage(profile.avatarUrl!)
                : null,
            child: profile.avatarUrl == null
                ? Text(
                    profile.fullName.isNotEmpty
                        ? profile.fullName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 36,
                      color: FavoColors.honeyDark,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            profile.fullName,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          Text(
            profile.email,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Chip(
            label: Text(
              _roleLabel(profile.role),
              style: const TextStyle(fontSize: 12),
            ),
            backgroundColor: FavoColors.honeyLight,
          ),
          const SizedBox(height: 32),

          // Info cards
          _InfoTile(icon: Icons.phone, label: 'Telefone', value: profile.phone ?? 'Não informado'),
          _InfoTile(
            icon: Icons.cake,
            label: 'Nascimento',
            value: profile.birthDate != null
                ? '${profile.birthDate!.day.toString().padLeft(2, '0')}/${profile.birthDate!.month.toString().padLeft(2, '0')}/${profile.birthDate!.year}'
                : 'Não informado',
          ),
          _InfoTile(icon: Icons.badge, label: 'Status', value: _statusLabel(profile.status)),

          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await ref.read(authServiceProvider).signOut();
                if (context.mounted) context.go('/login');
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sair da conta'),
              style: OutlinedButton.styleFrom(
                foregroundColor: FavoColors.error,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () => _deleteAccount(context, ref, profile),
              icon: const Icon(Icons.delete_forever, size: 18),
              label: const Text('Excluir minha conta (LGPD)'),
              style: TextButton.styleFrom(
                foregroundColor: FavoColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileEdit(BuildContext context, Profile profile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nome completo',
              prefixIcon: Icon(Icons.person_outlined),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Telefone',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _isEditing = false),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () => _save(profile.id),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Salvar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _save(String userId) async {
    setState(() => _isLoading = true);

    try {
      await ref.read(profileServiceProvider).updateProfile(userId, {
        'full_name': _nameController.text.trim(),
        'phone': _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : null,
      });

      ref.invalidate(currentProfileProvider);
      setState(() => _isEditing = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil atualizado!')),
        );
      }
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

  Future<void> _deleteAccount(
      BuildContext context, WidgetRef ref, Profile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir conta'),
        content: const Text(
          'Isso vai remover permanentemente todos os seus dados: '
          'perfil, presenças, materiais, feed e pagamentos. '
          'Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: FavoColors.error),
            child: const Text('Excluir permanentemente'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref
          .read(profileServiceProvider)
          .deleteAccount(profile.id);
      await ref.read(authServiceProvider).signOut();
      if (context.mounted) context.go('/login');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir: $e')),
        );
      }
    }
  }

  String _roleLabel(UserRole role) {
    return switch (role) {
      UserRole.admin => 'Administradora',
      UserRole.teacher => 'Professora',
      UserRole.assistant => 'Assistente',
      UserRole.student => 'Aluna',
    };
  }

  String _statusLabel(UserStatus status) {
    return switch (status) {
      UserStatus.active => 'Ativa',
      UserStatus.pending => 'Pendente',
      UserStatus.inactive => 'Inativa',
      UserStatus.blocked => 'Bloqueada',
    };
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: FavoColors.warmGray),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              Text(value, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ],
      ),
    );
  }
}
