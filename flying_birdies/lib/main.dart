import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

import 'app/theme.dart';
import 'app/theme_controller.dart';
import 'app/service_locator.dart';
import 'services/local_auth.dart';
import 'state/connection_state_notifier.dart';

// Backend services
import 'services/ble_service.dart';

// screens
import 'features/onboarding/welcome_screen.dart';
import 'features/shell/home_shell.dart';
import 'features/auth/login_screen.dart';
import 'features/history/history_page.dart';
import 'features/profile/profile_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL', defaultValue: ''),
    anonKey:
        const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: ''),
  );

  // load saved theme preference (system / light / dark)
  await ThemeController.instance.load();

  // Initialize backend services
  // Request BLE permissions early
  await BleService.instance.requestPermissions();

  // ❌ remove this – it was forcing you logged out every launch
  // await LocalAuth.instance.signOut();

  runApp(const StrikeProApp());
}

class StrikeProApp extends StatefulWidget {
  const StrikeProApp({super.key});

  @override
  State<StrikeProApp> createState() => _StrikeProAppState();
}

class _StrikeProAppState extends State<StrikeProApp>
    with WidgetsBindingObserver {
  // Global key to access the navigator context
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // When app resumes from background, verify connection state
    if (state == AppLifecycleState.resumed) {
      _verifyConnectionState();
    }
  }

  Future<void> _verifyConnectionState() async {
    try {
      // Get the current context from the navigator
      final context = _navigatorKey.currentContext;
      if (context == null) return;

      // Get the connection notifier from Provider
      final connectionNotifier = context.read<ConnectionStateNotifier>();
      final currentState = connectionNotifier.state;

      // If we think we're connected, log it
      // The BLE service will automatically emit connection state changes
      // through its stream if the connection is lost
      if (currentState == DeviceConnectionState.connected) {
        debugPrint('App resumed - current connection state: connected');
      } else {
        debugPrint('App resumed - current connection state: $currentState');
      }
    } catch (e) {
      debugPrint('Error verifying connection state on resume: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Wrap the entire app with MultiProvider for dependency injection
    return MultiProvider(
      providers: ServiceLocator.createProviders(),
      child: AnimatedBuilder(
        animation: ThemeController.instance,
        builder: (context, _) {
          return MaterialApp(
            navigatorKey: _navigatorKey,
            debugShowCheckedModeBanner: false,
            title: 'StrikePro',

            // light / dark themes
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: ThemeController.instance.mode,

            // 🔑 Let AuthGate decide where to start
            home: const AuthGate(),

            // named routes used in the app
            routes: {
              '/auth': (_) => const LoginScreen(),
              '/history': (_) => const HistoryPage(),
              '/profile': (_) => const ProfileScreen(),
            },
          );
        },
      ),
    );
  }
}

/// Decides what to show when the app launches.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<_AuthState> _load() async {
    final loggedIn = await LocalAuth.instance.isLoggedIn();
    final hasAcct = await LocalAuth.instance.hasAccount();
    return _AuthState(loggedIn: loggedIn, hasAccount: hasAcct);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AuthState>(
      future: _load(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final s = snapshot.data!;

        if (s.loggedIn) {
          // ✅ already logged in -> go straight into the app
          return const HomeShell();
        }

        if (s.hasAccount) {
          // has account but logged out -> show login screen
          return const LoginScreen();
        }

        // first time user -> pretty welcome screen
        return const WelcomeScreen();
      },
    );
  }
}

class _AuthState {
  final bool loggedIn;
  final bool hasAccount;
  _AuthState({required this.loggedIn, required this.hasAccount});
}
