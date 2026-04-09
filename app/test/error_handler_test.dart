import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:favo/core/error_handler.dart';

void main() {
  group('friendlyError', () {
    test('translates AuthException Invalid login credentials', () {
      final error = AuthException('Invalid login credentials');
      expect(friendlyError(error), 'E-mail ou senha incorretos');
    });

    test('translates AuthException Email not confirmed', () {
      final error = AuthException('Email not confirmed');
      expect(friendlyError(error), 'Confirme seu e-mail antes de entrar');
    });

    test('translates AuthException User already registered', () {
      final error = AuthException('User already registered');
      expect(friendlyError(error), 'Este e-mail já está cadastrado');
    });

    test('passes through unknown AuthException message', () {
      final error = AuthException('Some other error');
      expect(friendlyError(error), 'Some other error');
    });

    test('translates PostgrestException 23505 unique violation', () {
      final error = PostgrestException(
        message: 'duplicate key value',
        code: '23505',
      );
      expect(friendlyError(error), 'Este registro já existe');
    });

    test('translates PostgrestException 42501 permission denied', () {
      final error = PostgrestException(
        message: 'permission denied',
        code: '42501',
      );
      expect(friendlyError(error), 'Você não tem permissão para esta ação');
    });

    test('passes through other PostgrestException messages', () {
      final error = PostgrestException(
        message: 'column not found',
        code: '42703',
      );
      expect(friendlyError(error), 'column not found');
    });

    test('detects SocketException as network error', () {
      final error = Exception('SocketException: Connection refused');
      expect(friendlyError(error), 'Sem conexão com a internet');
    });

    test('detects ClientException as network error', () {
      final error = Exception('ClientException: Connection reset');
      expect(friendlyError(error), 'Sem conexão com a internet');
    });

    test('returns generic message for unknown errors', () {
      final error = Exception('something weird happened');
      expect(friendlyError(error), 'Erro inesperado. Tente novamente.');
    });

    test('handles String error', () {
      expect(friendlyError('raw string error'),
          'Erro inesperado. Tente novamente.');
    });
  });
}
