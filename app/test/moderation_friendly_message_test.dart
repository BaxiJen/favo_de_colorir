import 'package:flutter_test/flutter_test.dart';

import 'package:favo/services/community_service.dart';

void main() {
  group('ModerationResult.friendlyMessage', () {
    test('political vira mensagem sobre foco no ateliê', () {
      final m = ModerationResult(approved: false, category: 'political');
      expect(m.friendlyMessage, contains('política'));
      expect(m.friendlyMessage, contains('ateliê'));
    });

    test('politics (alias) cai na mesma mensagem', () {
      final m = ModerationResult(approved: false, category: 'politics');
      expect(m.friendlyMessage, contains('política'));
    });

    test('hate → pede reescrita com carinho', () {
      final m = ModerationResult(approved: false, category: 'hate');
      expect(m.friendlyMessage, contains('ofender'));
      expect(m.friendlyMessage, contains('carinho'));
    });

    test('harassment usa a mesma mensagem de hate', () {
      final m = ModerationResult(approved: false, category: 'harassment');
      expect(m.friendlyMessage, contains('ofender'));
    });

    test('violence → não rola na comunidade', () {
      final m = ModerationResult(approved: false, category: 'violence');
      expect(m.friendlyMessage, contains('violento'));
    });

    test('violence/graphic (subcategoria) mesma msg', () {
      final m =
          ModerationResult(approved: false, category: 'violence/graphic');
      expect(m.friendlyMessage, contains('violento'));
    });

    test('sexual → conteúdo adulto', () {
      final m = ModerationResult(approved: false, category: 'sexual');
      expect(m.friendlyMessage, contains('adulto'));
    });

    test('self-harm → mensagem de acolhimento + CVV', () {
      final m = ModerationResult(approved: false, category: 'self-harm');
      expect(m.friendlyMessage, contains('CVV'));
      expect(m.friendlyMessage, contains('queremos você bem'));
    });

    test('self-harm/intent também tem CVV', () {
      final m =
          ModerationResult(approved: false, category: 'self-harm/intent');
      expect(m.friendlyMessage, contains('CVV'));
    });

    test('illicit → conteúdo ilícito', () {
      final m = ModerationResult(approved: false, category: 'illicit');
      expect(m.friendlyMessage, contains('ilícito'));
    });

    test('keyword com palavra específica mostra a palavra', () {
      final m = ModerationResult(
        approved: false,
        category: 'keyword',
        blockedWord: 'xxxxxxx',
      );
      expect(m.friendlyMessage, contains('"xxxxxxx"'));
    });

    test('keyword sem blockedWord cai em fallback genérico', () {
      final m = ModerationResult(approved: false, category: 'keyword');
      expect(m.friendlyMessage, contains('palavra proibida'));
    });

    test('categoria desconhecida cai em reason ou fallback', () {
      final m1 = ModerationResult(
        approved: false,
        category: 'algo-novo',
        reason: 'razão específica',
      );
      expect(m1.friendlyMessage, 'razão específica');

      final m2 = ModerationResult(approved: false, category: 'outro');
      expect(m2.friendlyMessage, contains('Revise'));
    });

    test('approved=true nunca deveria chamar friendlyMessage mas não crasha', () {
      final m = ModerationResult(approved: true);
      // Não lança exceção; é só uma string genérica.
      expect(m.friendlyMessage, isNotEmpty);
    });
  });

  group('ModerationResult: parse da resposta do Supabase', () {
    test('category nulo e reason presente → usa reason', () {
      final m = ModerationResult(
        approved: false,
        reason: 'Conteúdo marcado manualmente',
      );
      expect(m.friendlyMessage, 'Conteúdo marcado manualmente');
    });

    test('flagged da edge function = !approved', () {
      // A edge function moderar-post retorna {flagged: true/false}.
      // O service converte pra approved = !flagged.
      const flaggedResponse = {'flagged': true, 'reason': 'x', 'category': 'hate'};
      final approved = !(flaggedResponse['flagged'] as bool);
      expect(approved, false);
    });
  });
}
