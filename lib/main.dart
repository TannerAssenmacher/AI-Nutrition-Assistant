import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';

/// Print all documents from known top-level collections.
Future<void> printAllData() async {
  final db = FirebaseFirestore.instance;

  // List your root collections here
  const rootCollections = ['Users', 'Food'];

  for (final collName in rootCollections) {
    try {
      final snap = await db.collection(collName).get();
      if (snap.docs.isEmpty) {
        print('📂 $collName: (no documents)');
        continue;
      }
      print('📂 $collName:');
      for (final doc in snap.docs) {
        print('  📄 $collName/${doc.id}: ${doc.data()}');
      }
    } catch (e) {
      print('Error reading $collName: $e');
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Print all Firestore data once at startup
  await printAllData();
  
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Nutrition Assistant',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
