import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../modules/auth/login_screen.dart';
import '../modules/auth/signup_screen.dart';
import '../modules/auth/policy_acceptance_screen.dart';
import '../modules/auth/pending_approval_screen.dart';
import '../modules/auth/admin_approval_screen.dart';
import '../modules/auth/admin_users_screen.dart';
import '../modules/auth/profile_screen.dart';
import '../modules/agenda/home_screen.dart';
import '../modules/agenda/my_agenda_screen.dart';
import '../modules/agenda/aula_detail_screen.dart';
import '../modules/agenda/teacher_dashboard_screen.dart';
import '../modules/agenda/admin_turmas_screen.dart';
import '../modules/agenda/reposition_screen.dart';
import '../modules/cobranca/admin_billing_screen.dart';
import '../modules/cobranca/my_payments_screen.dart';
import '../modules/feed/feed_screen.dart';
import '../modules/materiais/register_materials_screen.dart';
import '../modules/shell/app_shell.dart';
import '../services/auth_service.dart';
import 'supabase_client.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  ref.watch(authStateProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: _AuthNotifier(ref),
    redirect: (context, state) {
      final session = SupabaseConfig.auth.currentSession;
      final isAuthenticated = session != null;
      final location = state.matchedLocation;

      final publicRoutes = ['/login', '/signup'];
      final isPublicRoute = publicRoutes.contains(location);

      if (!isAuthenticated && !isPublicRoute) {
        return '/login';
      }

      if (isAuthenticated && isPublicRoute) {
        return '/';
      }

      return null;
    },
    routes: [
      // Auth routes (sem bottom nav)
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/policies',
        builder: (context, state) => const PolicyAcceptanceScreen(),
      ),
      GoRoute(
        path: '/pending',
        builder: (context, state) => const PendingApprovalScreen(),
      ),

      // App com bottom nav
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          // Tab 0: Início
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          // Tab 1: Agenda
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/agenda',
                builder: (context, state) => const MyAgendaScreen(),
                routes: [
                  GoRoute(
                    path: 'aula/:id',
                    builder: (context, state) => AulaDetailScreen(
                      aulaId: state.pathParameters['id']!,
                    ),
                  ),
                  GoRoute(
                    path: 'reposition',
                    builder: (context, state) => const RepositionScreen(),
                  ),
                ],
              ),
            ],
          ),
          // Tab 2: Feed
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/feed',
                builder: (context, state) => const FeedScreen(),
              ),
            ],
          ),
          // Tab 3: Pagamentos
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/payments',
                builder: (context, state) => const MyPaymentsScreen(),
              ),
            ],
          ),
          // Tab 4: Perfil
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // Rotas admin (full screen, sem bottom nav)
      GoRoute(
        path: '/admin/users',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AdminUsersScreen(),
      ),
      GoRoute(
        path: '/admin/approvals',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AdminApprovalScreen(),
      ),
      GoRoute(
        path: '/admin/turmas',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AdminTurmasScreen(),
      ),
      GoRoute(
        path: '/admin/billing',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AdminBillingScreen(),
      ),
      GoRoute(
        path: '/teacher/dashboard',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const TeacherDashboardScreen(),
      ),
      GoRoute(
        path: '/materiais/:aulaId/:studentId/:studentName',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => RegisterMaterialsScreen(
          aulaId: state.pathParameters['aulaId']!,
          studentId: state.pathParameters['studentId']!,
          studentName:
              Uri.decodeComponent(state.pathParameters['studentName']!),
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Página não encontrada: ${state.uri}'),
      ),
    ),
  );
});

class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier(Ref ref) {
    ref.listen(authStateProvider, (_, _) {
      notifyListeners();
    });
  }
}
