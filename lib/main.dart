import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';

import 'theme.dart';
import 'state/chat_state.dart';
import 'screens/sidebar.dart';
import 'screens/chat_page.dart';
import 'screens/research/research_tool.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  
  final chatState = ChatState();
  await chatState.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: chatState),
      ],
      child: const OllamaChatApp(),
    ),
  );
}

class OllamaChatApp extends StatelessWidget {
  const OllamaChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ChatState>();
    return MaterialApp(
      title: 'GovGen Research Suite',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: OhadaTheme.primary,
        colorScheme: ColorScheme.fromSeed(
          seedColor: OhadaTheme.primary,
          brightness: Brightness.light,
          surface: OhadaTheme.lightSurface,
        ),
        scaffoldBackgroundColor: OhadaTheme.lightBackground,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: OhadaTheme.primary,
        colorScheme: ColorScheme.fromSeed(
          seedColor: OhadaTheme.primary,
          brightness: Brightness.dark,
          surface: OhadaTheme.surface,
        ),
        scaffoldBackgroundColor: OhadaTheme.background,
        useMaterial3: true,
      ),
      themeMode: state.themeMode,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''),
        Locale('th', ''),
        Locale('ru', ''),
        Locale('zh', ''),
      ],
      home: const MainLayout(),
    );
  }
}

class MainLayout extends StatelessWidget {
  const MainLayout({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ChatState>();
    
    return Scaffold(
      body: Stack(
        children: [
          Row(
            children: [
              const Sidebar(),
              const Expanded(child: ChatPage()),
            ],
          ),
          Positioned(
            top: 20,
            right: 20,
            child: FloatingActionButton.small(
              heroTag: 'theme_switcher',
              onPressed: () => state.toggleTheme(),
              backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
              child: Icon(
                state.themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode,
                color: OhadaTheme.accent,
                size: 20,
              ),
            ),
          ),
          if (state.isResearchHubOpen)
             const MiniAppContainer(child: ResearchTool()),
        ],
      ),
    );
  }
}

class MiniAppContainer extends StatelessWidget {
  final Widget child;
  const MiniAppContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.95,
          height: MediaQuery.of(context).size.height * 0.95,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 15,
                spreadRadius: 5,
              )
            ],
            border: Border.all(color: OhadaTheme.accent.withValues(alpha: 0.3), width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: child,
          ),
        ),
      ),
    );
  }
}
