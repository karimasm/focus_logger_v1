import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/sync_service.dart';
import 'services/flow_seeder_service.dart';
import 'app.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize Supabase
  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  try {
    if (supabaseUrl.isNotEmpty && supabaseUrl != 'YOUR_SUPABASE_URL') {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
      
      // Start background sync only if Supabase is configured
      SyncService().startBackgroundSync();
      
      // Seed default flows to database (runs once on first install)
      await FlowSeederService.seedDefaultFlows();
      
      debugPrint('✅ Supabase initialized successfully');
    } else {
      debugPrint('⚠️ Supabase credentials not set. Sync will not work.');
    }
  } catch (e) {
    debugPrint('❌ Failed to initialize Supabase: $e');
  }

  runApp(const FocusLoggerApp());
}
