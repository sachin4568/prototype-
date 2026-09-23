import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/app_state.dart';
import 'theme/whatsapp_theme.dart';
import 'screens/mode_selection_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Lock to portrait on mobile for authentic WhatsApp feel
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const WhatsAppChatbotApp());
}

class WhatsAppChatbotApp extends StatelessWidget {
  const WhatsAppChatbotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: 'WhatsApp Chatbot Prototype',
        debugShowCheckedModeBanner: false,
        theme: buildWhatsAppTheme(),
        home: const ModeSelectionScreen(),
      ),
    );
  }
}
