import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'auth_notifier.dart';
import '../../gigs/edit_gig_page.dart';
import '../../home/home_shell.dart';
import '../../features/auth/login_page.dart';
import '../../features/auth/register_page.dart';
import '../../gigs/create_gig_page.dart';
import '../../gigs/gig_detail_page.dart';

final authNotifier = AuthNotifier();

final appRouter = GoRouter(
  refreshListenable: authNotifier,
  initialLocation: '/',
  redirect: (context, state) {
    final user = FirebaseAuth.instance.currentUser;
    final loc = state.uri.path;

    final authPages = ['/login', '/register'];

    // ✅ Auth guard only
    if (user == null && !authPages.contains(loc)) return '/login';
    if (user != null && authPages.contains(loc)) return '/';

    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeShell(),
    ),
    GoRoute(
      path: '/create-gig',
      builder: (context, state) => const CreateGigPage(),
    ),
    GoRoute(
      path: '/gig/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return GigDetailPage(gigId: id);
      },
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterPage(),
    ),

    GoRoute(
  path: '/edit-gig/:id',
  builder: (context, state) {
    final id = state.pathParameters['id']!;
    return EditGigPage(gigId: id);
  },
),

  ],
);


