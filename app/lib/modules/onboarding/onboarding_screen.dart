import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/error_handler.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../services/profile_service.dart';

class OnboardingSlide {
  final IconData icon;
  final String title;
  final String body;
  final Color accent;

  const OnboardingSlide({
    required this.icon,
    required this.title,
    required this.body,
    required this.accent,
  });
}

const _slides = <OnboardingSlide>[
  OnboardingSlide(
    icon: Icons.local_florist,
    title: 'Bem-vindo ao Favo',
    body:
        'Esse app é seu canto do ateliê no celular. Em 1 minuto te mostro onde fica cada coisa.',
    accent: FavoColors.primary,
  ),
  OnboardingSlide(
    icon: Icons.calendar_today_outlined,
    title: 'Sua próxima aula',
    body:
        'Logo que você abre o app, aparece qual é a próxima aula. Toque nela pra avisar se vai ou não — é um toque só.',
    accent: FavoColors.primary,
  ),
  OnboardingSlide(
    icon: Icons.swap_horiz,
    title: 'Faltou? Repõe',
    body:
        'Na aba Agenda tem "Repor Aula". Escolhe outro dia da semana com vaga e marca — sem cobrar taxa, sem papel.',
    accent: FavoColors.secondary,
  ),
  OnboardingSlide(
    icon: Icons.receipt_long_outlined,
    title: 'Cobranças no seu ritmo',
    body:
        'Sua mensalidade aparece na aba Pagamentos. Paga pelo Pix direto no app, ou manda o comprovante que a Débora confirma.',
    accent: FavoColors.success,
  ),
  OnboardingSlide(
    icon: Icons.forum_outlined,
    title: 'Comunidade e conversas',
    body:
        'A aba Comunidade é só entre quem faz aula aqui. Mostra peça, pede dica, chama no chat — sem rede social.',
    accent: FavoColors.primary,
  ),
  OnboardingSlide(
    icon: Icons.person_outline,
    title: 'Seu perfil',
    body:
        'Toca em Perfil pra colocar uma foto, escrever uma bio e ajustar notificações. Se um dia quiser rever este tour, tá ali também.',
    accent: FavoColors.secondary,
  ),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _index = 0;
  bool _finishing = false;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    try {
      final userId = SupabaseConfig.auth.currentUser?.id;
      if (userId != null) {
        await ref.read(profileServiceProvider).markOnboarded(userId);
        ref.invalidate(currentProfileProvider);
      }
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) {
        setState(() => _finishing = false);
        showErrorSnackBar(context, e);
      }
    }
  }

  void _next() {
    if (_index < _slides.length - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _slides.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _finishing ? null : _finish,
                    child: const Text('Pular'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => _SlideContent(slide: _slides[i]),
              ),
            ),
            // Dots
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_slides.length, (i) {
                  final selected = i == _index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: selected ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: selected
                          ? FavoColors.primary
                          : FavoColors.outline.withAlpha(100),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _finishing ? null : _next,
                  child: _finishing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(isLast ? 'Começar a usar' : 'Próximo'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideContent extends StatelessWidget {
  final OnboardingSlide slide;
  const _SlideContent({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: slide.accent.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: Icon(slide.icon, color: slide.accent, size: 54),
          ),
          const SizedBox(height: 40),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          Text(
            slide.body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: FavoColors.onSurfaceVariant,
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }
}
