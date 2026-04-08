import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../modules/auth/login_screen.dart';
import '../modules/auth/signup_screen.dart';
import '../modules/auth/policy_acceptance_screen.dart';
import '../modules/auth/pending_approval_screen.dart';
import '../modules/auth/admin_approval_screen.dart';
import '../modules/auth/profile_screen.dart';
import '../modules/agenda/home_screen.dart';
import '../modules/agenda/my_agenda_screen.dart';
import '../modules/agenda/aula_detail_screen.dart';
import '../modules/agenda/teacher_dashboard_screen.dart';
import '../modules/agenda/admin_turmas_screen.dart';
import '../modules/agenda/reposition_screen.dart';
import '../services/auth_service.dart';
import 'supabase_client.dart';

final routerProvider = Provider<GoRouter>((ref) {
  ref.watch(authStateProvider);

  return GoRouter(
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
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/agenda',
        builder: (context, state) => const MyAgendaScreen(),
      ),
      GoRoute(
        path: '/aula/:id',
        builder: (context, state) => AulaDetailScreen(
          aulaId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/teacher/dashboard',
        builder: (context, state) => const TeacherDashboardScreen(),
      ),
      GoRoute(
        path: '/admin/approvals',
        builder: (context, state) => const AdminApprovalScreen(),
      ),
      GoRoute(
        path: '/reposition',
        builder: (context, state) => const RepositionScreen(),
      ),
      GoRoute(
        path: '/admin/turmas',
        builder: (context, state) => const AdminTurmasScreen(),
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
