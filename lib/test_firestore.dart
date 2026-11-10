import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    debugPrint('Firebase berhasil diinisialisasi!');

    final firestore = FirebaseFirestore.instance;

    final doc = await firestore.collection('connection_test').add({
      'message': 'Koneksi Flutter ke Firestore berhasil',
      'createdAt': FieldValue.serverTimestamp(),
    });

    debugPrint('BERHASIL menyimpan data ke Firestore!');
    debugPrint('ID dokumen: ${doc.id}');
  } catch (e, stackTrace) {
    debugPrint('Pengujian Firestore gagal: $e');
    debugPrintStack(stackTrace: stackTrace);
  }
}