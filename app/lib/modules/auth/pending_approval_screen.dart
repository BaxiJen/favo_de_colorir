import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/error_handler.dart';
import '../../core/theme.dart';
import '../../core/widgets/user_avatar.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';

/// Tela que aluna nova vê enquanto admin não aprovou cadastro.
/// Em vez de ficar 100% ociosa, deixa ela já deixar a foto + bio prontas
/// — a aluna sente progresso e o admin já vê o perfil completo na hora
/// de aprovar.
class PendingApprovalScreen extends ConsumerStatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  ConsumerState<PendingApprovalScreen> createState() =>
      _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends ConsumerState<PendingApprovalScreen> {
  final _bioCtrl = TextEditingController();
  bool _savingBio = false;
  bool _uploadingAvatar = false;
  bool _bioLoaded = false;

  @override
  void dispose() {
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar(String userId) async {
    final picker = ImagePicker();
    final img = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      imageQuality: 85,
    );
    if (img == null || !mounted) return;
    setState(() => _uploadingAvatar = true);
    try {
      await ref
          .read(profileServiceProvider)
          .uploadAvatar(userId, File(img.path));
      ref.invalidate(currentProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto atualizada!')),
        );
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _saveBio(String userId) async {
    setState(() => _savingBio = true);
    try {
      await ref.read(profileServiceProvider).updateProfile(userId, {
        'bio': _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
      });
      ref.invalidate(currentProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bio salva.')),
        );
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _savingBio = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(friendlyError(e))),
          data: (profile) {
            if (profile == null) {
              return const Center(child: Text('Perfil não encontrado.'));
            }

            if (!_bioLoaded) {
              _bioCtrl.text = profile.bio ?? '';
              _bioLoaded = true;
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(32, 48, 32, 32),
              children: [
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: FavoColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.hourglass_top_rounded,
                      size: 36,
                      color: FavoColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Aguardando\naprovação',
                  style: Theme.of(context).textTheme.headlineLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Seu cadastro chegou! A Débora vai revisar e aprovar em breve. Enquanto isso, deixa seu perfil prontinho:',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Avatar
                Center(
                  child: GestureDetector(
                    onTap: _uploadingAvatar ? null : () => _pickAvatar(profile.id),
                    child: Stack(
                      children: [
                        UserAvatar(
                          avatarUrl: profile.avatarUrl,
                          name: profile.fullName,
                          radius: 48,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: FavoColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: FavoColors.surface, width: 2),
                            ),
                            child: _uploadingAvatar
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: FavoColors.onPrimary,
                                    ),
                                  )
                                : const Icon(Icons.camera_alt,
                                    size: 16, color: FavoColors.onPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Toque pra trocar',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: FavoColors.onSurfaceVariant,
                        ),
                  ),
                ),
                const SizedBox(height: 28),

                // Bio
                Text(
                  'SOBRE VOCÊ (opcional)',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.5,
                      ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _bioCtrl,
                  maxLines: 3,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    hintText: 'O que te trouxe pra cerâmica?',
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _savingBio ? null : () => _saveBio(profile.id),
                    icon: _savingBio
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: const Text('Salvar bio'),
                  ),
                ),
                const SizedBox(height: 28),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: FavoColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.mail_outline,
                          size: 18, color: FavoColors.onSurfaceVariant),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Você vai receber uma notificação quando o ateliê liberar seu acesso. Pode fechar o app — te avisamos.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Center(
                  child: TextButton.icon(
                    onPressed: () async {
                      await ref.read(authServiceProvider).signOut();
                      if (context.mounted) context.go('/login');
                    },
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Sair'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
