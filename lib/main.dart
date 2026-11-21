import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/admin_app.dart';
import 'screens/psits_app.dart';
import 'screens/user_app.dart';
import 'state/app_state.dart';
import 'widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://bzppqqmwqlzgmsimxdwj.supabase.co',
    publishableKey: 'sb_publishable_1oAad_qIPTgewm1HprVbuw_oqh-xBeX',
  );
  runApp(const SmartBinApp());
}

class SmartBinApp extends StatefulWidget {
  const SmartBinApp({super.key});
  @override
  State<SmartBinApp> createState() => _SmartBinAppState();
}

class _SmartBinAppState extends State<SmartBinApp> {
  final state = AppState();
  @override
  void dispose() {
    state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final p = state.pal;
          final base = ThemeData(brightness: state.dark ? Brightness.dark : Brightness.light, useMaterial3: true);
          return MaterialApp(
            title: 'SmartBin',
            debugShowCheckedModeBanner: false,
            scaffoldMessengerKey: messengerKey,
            theme: base.copyWith(
              scaffoldBackgroundColor: p.bg,
              colorScheme: ColorScheme.fromSeed(seedColor: p.g, brightness: base.brightness, surface: p.bg),
              textTheme: base.textTheme.apply(bodyColor: p.tx, displayColor: p.tx),
              dataTableTheme: DataTableThemeData(headingTextStyle: TextStyle(color: p.mut, fontWeight: FontWeight.w700), dataTextStyle: TextStyle(color: p.tx)),
              snackBarTheme: SnackBarThemeData(backgroundColor: p.tx, contentTextStyle: TextStyle(color: p.bg)),
            ),
            builder: (ctx, child) => MediaQuery(
              data: MediaQuery.of(ctx).copyWith(textScaler: TextScaler.linear(state.textScale)),
              child: AppScope(state: state, child: child!),
            ),
            home: const _Root(),
          );
        },
      );
}

   /// Header (logo + portal switch + theme) and the active portal.
class _Root extends StatelessWidget {
  const _Root();
  @override
  Widget build(BuildContext c) {
    final s = AppScope.of(c);
    final p = s.pal;
    return Scaffold(

      backgroundColor: p.bg,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: p.bg, boxShadow: [BoxShadow(color: p.shD, blurRadius: 16, offset: const Offset(0, 8), spreadRadius: -8)]),
            child: Row(children: [
              Image.asset('assets/images/icon.png', width: 30, height: 30),
              const SizedBox(width: 8),
              const Text('SmartBin', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const Spacer(),
              PopupMenuButton<Portal>(
                tooltip: 'Switch portal',
                color: p.bg,
                onSelected: s.setPortal,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: Portal.user, child: Text('📱 User App')),
                  PopupMenuItem(value: Portal.admin, child: Text('🛠 Admin')),
                  PopupMenuItem(value: Portal.psits, child: Text('📊 PSITS')),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(14), boxShadow: p.raise),
                  child: Text(
                    switch (s.portal) {
                      Portal.user => '📱 User App ▾',
                      Portal.admin => '🛠 Admin ▾',
                      Portal.psits => '📊 PSITS ▾',
                    },
                    style: TextStyle(color: p.tx, fontWeight: FontWeight.w500, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              NBtn(small: true, label: s.dark ? '☀️' : '🌙', onTap: s.toggleTheme),
            ]),
          ),
          Expanded(
            child: switch (s.portal) {
              Portal.user => const UserApp(),
              Portal.admin => const AdminApp(),
              Portal.psits => const PsitsApp(),
            },
          ),
        ]),
      ),
    );
  }
}
