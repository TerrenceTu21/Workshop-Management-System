import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dashboard.dart';
import 'job_notifier.dart';
import 'login_page.dart';
import 'models/job.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
      url: supabaseUrl,
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ2bGJ2eHZrdHBsYmhjeHJ0eW5uIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgwOTI1MzMsImV4cCI6MjA3MzY2ODUzM30.PV1tv_OGidCRQUt4siH9xxDiElo3PqjzK8vdMpt815s',
  );
  runApp(
    // Wrap the app with a ChangeNotifierProvider
    ChangeNotifierProvider(
      create: (context) => JobNotifier(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Your App Name',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      // Use a StreamBuilder to listen for auth state changes
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.active) {
            final session = snapshot.data?.session;
            if (session == null) {
              // If no session, show the login page
              return const LoginPage();
            } else {
              // If a session exists, show the main app content
              return const DashboardPage();
            }
          }
          // Show a loading indicator while checking the session
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        },
      ),
    );
  }
}
