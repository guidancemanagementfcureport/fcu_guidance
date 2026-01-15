import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'package:toastification/toastification.dart';
import 'routes/app_router.dart';
import 'providers/auth_provider.dart';
import 'providers/anonymous_chat_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/support_chat_provider.dart';
import 'services/supabase_service.dart';
import 'config/supabase_config.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  try {
    await SupabaseService().initialize(
      supabaseUrl: SupabaseConfig.supabaseUrl,
      supabaseAnonKey: SupabaseConfig.supabaseAnonKey,
    );
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Supabase initialization error: $e');
      debugPrint('Please update SupabaseConfig with your credentials');
      // For web, this might be a network/WebAssembly issue
      if (kIsWeb) {
        debugPrint(
          'WebAssembly error detected. This may be a network issue. '
          'Try refreshing the page or check your internet connection.',
        );
      }
    }
    // Continue app initialization even if Supabase fails
    // The app will show errors when trying to use Supabase features
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AnonymousChatProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => SupportChatProvider()),
      ],
      child: ToastificationWrapper(
        child: Consumer<AuthProvider>(
          builder: (context, authProvider, _) {
            return MaterialApp.router(
              title: 'FCU Guidance Management System',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              routerConfig: AppRouter.getRouter(authProvider),
            );
          },
        ),
      ),
    );
  }
}

