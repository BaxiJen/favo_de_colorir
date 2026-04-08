import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/theme.dart';
import 'core/router.dart';
import 'core/supabase_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');
  await SupabaseConfig.initialize();
  await initializeDateFormatting('pt_BR', null);

  runApp(const ProviderScope(child: FavoApp()));
}

class FavoApp extends ConsumerWidget {
  const FavoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Favo de Colorir',
      theme: FavoTheme.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
