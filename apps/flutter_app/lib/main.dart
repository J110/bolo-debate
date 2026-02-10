import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bolo_debate/core/theme/app_theme.dart';
import 'package:bolo_debate/core/services/router_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Allow Google Fonts to fetch fonts at runtime (for Hindi/Devanagari support)
  GoogleFonts.config.allowRuntimeFetching = true;
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    const ProviderScope(
      child: BoloDebateApp(),
    ),
  );
}

class BoloDebateApp extends ConsumerWidget {
  const BoloDebateApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Bolo Debate',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light, // Always use light theme
      routerConfig: router,
    );
  }
}
