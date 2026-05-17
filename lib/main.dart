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
      locale: state.locale,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''),
        Locale('fr', ''),
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

  String _getFlagEmoji(String langCode) {
    switch (langCode) {
      case 'fr':
        return '🇫🇷';
      case 'th':
        return '🇹🇭';
      case 'ru':
        return '🇷🇺';
      case 'zh':
        return '🇨🇳';
      case 'en':
      default:
        return '🇺🇸';
    }
  }

  PopupMenuItem<String> _buildLanguageItem(String code, String name, String currentCode) {
    final bool isActive = code == currentCode;
    return PopupMenuItem<String>(
      value: code,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            name,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (isActive)
            const Icon(
              Icons.check_circle,
              color: OhadaTheme.accent,
              size: 16,
            ),
        ],
      ),
    );
  }

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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Language Selector
                Theme(
                  data: Theme.of(context).copyWith(
                    cardColor: Theme.of(context).colorScheme.surface,
                  ),
                  child: PopupMenuButton<String>(
                    tooltip: 'Change Language',
                    onSelected: (String langCode) {
                      state.setLocale(langCode);
                    },
                    offset: const Offset(0, 45),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: OhadaTheme.accent.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _getFlagEmoji(state.locale.languageCode),
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      _buildLanguageItem('en', '🇺🇸 English', state.locale.languageCode),
                      _buildLanguageItem('fr', '🇫🇷 Français', state.locale.languageCode),
                      _buildLanguageItem('th', '🇹🇭 ภาษาไทย', state.locale.languageCode),
                      _buildLanguageItem('ru', '🇷🇺 Русский', state.locale.languageCode),
                      _buildLanguageItem('zh', '🇨🇳 中文', state.locale.languageCode),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Theme Switcher Button
                FloatingActionButton.small(
                  heroTag: 'theme_switcher',
                  onPressed: () => state.toggleTheme(),
                  backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                  child: Icon(
                    state.themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode,
                    color: OhadaTheme.accent,
                    size: 20,
                  ),
                ),
              ],
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
