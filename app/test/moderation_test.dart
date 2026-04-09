import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Content moderation logic', () {
    // Simula a lógica que a edge function aplica
    bool containsBlockedWords(String content) {
      final blocked = [
        'político', 'política', 'eleição', 'candidato', 'partido',
        'bolsonaro', 'lula', 'governo',
        'porra', 'caralho', 'merda', 'foda',
      ];
      final lower = content.toLowerCase();
      return blocked.any((word) => lower.contains(word));
    }

    test('clean content passes', () {
      expect(containsBlockedWords('Minha caneca ficou linda!'), false);
      expect(containsBlockedWords('Aula de escultura foi ótima'), false);
      expect(containsBlockedWords('Adorei a queima de esmalte'), false);
    });

    test('political content is flagged', () {
      expect(containsBlockedWords('Esse governo não presta'), true);
      expect(containsBlockedWords('Vote no candidato X'), true);
      expect(containsBlockedWords('Política não deveria entrar aqui'), true);
    });

    test('offensive content is flagged', () {
      expect(containsBlockedWords('Que merda de peça'), true);
    });

    test('case insensitive', () {
      expect(containsBlockedWords('GOVERNO ruim'), true);
      expect(containsBlockedWords('Candidato bom'), true);
    });

    test('empty content passes', () {
      expect(containsBlockedWords(''), false);
    });

    test('moderation result structure', () {
      // Documenta o que a edge function retorna
      final result = {
        'flagged': true,
        'reason': 'Conteúdo político detectado',
        'blocked_word': 'governo',
      };

      expect(result['flagged'], true);
      expect(result['reason'], isNotEmpty);
    });
  });
}
