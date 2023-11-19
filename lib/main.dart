import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:roadtrap/homeview.dart';
import 'package:roadtrap/signinview.dart';
import 'package:sqflite/sqflite.dart';

import 'firebase_options.dart';

Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  String path = join(await getDatabasesPath(), "myDatabase.db");
  await deleteDatabase(path);

  await FirebaseAuth.instance.useAuthEmulator('192.168.0.114', 9099);

  await DatabaseHelper.instance.database;

  // FirebaseAuth.instance.signOut();
  final user = FirebaseAuth.instance.currentUser;
  try {
    await user?.reload();
  }
  catch(e){
    FirebaseAuth.instance.signOut();
  }

  // var databasesPath = await getDatabasesPath();
  // String path = join(databasesPath, 'myDatabase.db');
  // Database db = await openDatabase('myDatabase.db');
  // List<Map> list = await db.query('payloads');
  // return;

  runApp(
      MaterialApp(
        home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.active) {
                final user = snapshot.data;
                if (user == null || user.emailVerified == false) {
                  return SignInView();
                }
                return HomeView();
              }

              return CircularProgressIndicator();  // Show a loading indicator until the connection is active
            }
        ),
      )
  );
}