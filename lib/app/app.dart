import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter_localizations/flutter_localizations.dart'
    hide GlobalMaterialLocalizations, GlobalCupertinoLocalizations;
import 'package:cupertino_ui/cupertino_ui.dart'
    show GlobalCupertinoLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth.dart';
import '../features/home/home.dart';
import '../features/expenses/expenses.dart';
import '../features/receipts/receipts.dart';
import '../features/receipts/ocr_service.dart';
import '../features/assistant/assistant.dart';
import '../features/assistant/assistant_service.dart';
import '../shared/ui.dart';
import '../core/local_store.dart';

final router = GoRouter(
  initialLocation: '/',
  refreshListenable: LocalStore.instance.session,
  redirect: (context, state) {
    if (LocalStore.instance.session.value == null &&
        !['/', '/crear', '/recuperar'].contains(state.uri.path)) {
      return '/';
    }
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (_, _) => const LoginScreen()),
    GoRoute(path: '/crear', builder: (_, _) => const RegisterScreen()),
    GoRoute(path: '/recuperar', builder: (_, _) => const RecoveryScreen()),
    GoRoute(path: '/inicio', builder: (_, _) => const HomeScreen()),
    GoRoute(path: '/registros', builder: (_, _) => const RecordsScreen()),
    GoRoute(path: '/asistente', builder: (_, _) => const AssistantScreen()),
    GoRoute(
      path: '/gasto',
      builder: (_, state) => ExpenseForm(
        image: state.extra is Uint8List
            ? state.extra as Uint8List
            : (state.extra is ReceiptDraft
                  ? (state.extra as ReceiptDraft).image
                  : null),
        draft: state.extra is ReceiptDraft ? state.extra as ReceiptDraft : null,
        assistantDraft: state.extra is AssistantDraft
            ? state.extra as AssistantDraft
            : null,
      ),
    ),
    GoRoute(path: '/escanear', builder: (_, _) => const ScanScreen()),
    GoRoute(
      path: '/revisar',
      builder: (_, state) => ReviewScreen(
        image: state.extra is Uint8List ? state.extra as Uint8List : null,
      ),
    ),
  ],
);

class KechApp extends StatelessWidget {
  const KechApp({super.key});
  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: blue,
      primary: blue,
      secondary: green,
      surface: Colors.white,
    );
    return MaterialApp.router(
      title: 'Kech',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      locale: const Locale('es', 'MX'),
      supportedLocales: const [Locale('es', 'MX')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: background,
        fontFamily: 'Plus Jakarta Sans',
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: ink,
          displayColor: ink,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          foregroundColor: ink,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xffedf2fc),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 17,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: blue),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

void mainApp() => runApp(const ProviderScope(child: KechApp()));
