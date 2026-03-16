import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/view/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ureyrsnpcqcqvpxxvhanqj.supabase.co',
    anonKey: 'sb_publishable_lfkp3C_g_nCJgQen1XfkJA_kXqdMnAF',
  );

  runApp(const StockApp());
}