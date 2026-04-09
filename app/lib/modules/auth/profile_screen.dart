import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

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
  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Erro: $error')),
          data: (profile) {
            if (profile == null) {
              return const Center(child: Text('Perfil não encontrado'));
            }
            return _buildProfile(context, profile);
          },
        ),
      ),
    );
  }

  Widget _buildProfile(BuildContext context, Profile profile) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        // Header
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: FavoColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.local_florist,
                  color: FavoColors.onPrimary, size: 16),
            ),
            const SizedBox(width: 8),
            Text('Favo de Colorir',
                style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
        const SizedBox(height: 24),

        // Avatar (tap to change)
        Center(
          child: GestureDetector(
            onTap: () => _pickAvatar(context, ref, profile),
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: FavoColors.primaryContainer,
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
                            color: FavoColors.onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: FavoColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: FavoColors.surface, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt,
                        size: 16, color: FavoColors.onPrimary),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(profile.fullName,
              style: Theme.of(context).textTheme.headlineMedium),
        ),
        const SizedBox(height: 4),
        Center(
          child:
              Text(profile.email, style: Theme.of(context).textTheme.bodyMedium),
        ),
        const SizedBox(height: 16),

        // Plan badge
        Center(
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: FavoColors.primary,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              _roleLabel(profile.role),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: FavoColors.onPrimary,
                  ),
            ),
          ),
        ),
        const SizedBox(height: 28),

        // Notification settings
        Text('Configurações de Notificação',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),

        _SettingToggle(
          icon: Icons.calendar_today_outlined,
          label: 'Confirmações de aula',
          value: true,
          onChanged: (_) {},
        ),
        _SettingToggle(
          icon: Icons.receipt_long_outlined,
          label: 'Pagamentos e cobranças',
          value: true,
          onChanged: (_) {},
        ),
        const SizedBox(height: 20),

        // Menu items
        _MenuItem(
          icon: Icons.notifications_outlined,
          label: 'Notificações',
          onTap: () => context.push('/notifications'),
        ),
        const SizedBox(height: 24),

        // Logout
        Center(
          child: TextButton.icon(
            onPressed: () async {
              await ref.read(authServiceProvider).signOut();
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Sair'),
            style: TextButton.styleFrom(
              foregroundColor: FavoColors.error,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // LGPD
        Center(
          child: TextButton(
            onPressed: () => _deleteAccount(context, ref, profile),
            child: Text(
              'Excluir minha conta',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: FavoColors.onSurfaceVariant.withAlpha(128),
                    decoration: TextDecoration.underline,
                  ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickAvatar(
      BuildContext context, WidgetRef ref, Profile profile) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      imageQuality: 85,
    );

    if (image == null) return;

    try {
      await ref.read(profileServiceProvider).uploadAvatar(
            profile.id,
            File(image.path),
          );
      ref.invalidate(currentProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto atualizada!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar foto: $e')),
        );
      }
    }
  }

  Future<void> _deleteAccount(
      BuildContext context, WidgetRef ref, Profile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir conta'),
        content: const Text(
          'Isso vai remover permanentemente todos os seus dados. '
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
      await ref.read(profileServiceProvider).deleteAccount(profile.id);
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
      UserRole.student => 'Mensal',
    };
  }
}

class _SettingToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingToggle({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: FavoColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: FavoColors.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child:
                  Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: FavoColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: FavoColors.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
              const Icon(Icons.chevron_right,
                  size: 20, color: FavoColors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
