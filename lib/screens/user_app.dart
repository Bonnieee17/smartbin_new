import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../state/app_state.dart';
import '../state/models.dart';
import '../theme/pal.dart';
import '../widgets/common.dart';

class Logo extends StatelessWidget {
  final String title; // 'SmartBin' | 'PSITS Dashboard' | other
  const Logo(this.title, {super.key});
  @override
  Widget build(BuildContext c) {
    final p = palOf(c);
    final ps = title == 'PSITS Dashboard';
    return Column(children: [
      const SizedBox(height: 10),
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(ps ? 'assets/images/psits.webp' : 'assets/images/logo.webp', width: ps ? 220 : 200, fit: BoxFit.contain),
      ),
      const SizedBox(height: 14),
      if (title != 'SmartBin')
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(ps ? 'PSITS Portal' : title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.g)),
        ),
    ]);
  }
}

class UserApp extends StatelessWidget {
  const UserApp({super.key});
  @override
  Widget build(BuildContext c) {
    final s = AppScope.of(c);
    if (s.adminIn || s.psitsIn) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: NCard(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const H3('Staff Portal Mode'),
              const SizedBox(height: 8),
              Mut('You are logged in as ${s.adminIn ? 'Admin' : 'PSITS Staff'}. The User App is intended for students.'),
              const SizedBox(height: 16),
              NBtn(
                primary: true,
                expand: true,
                label: 'Switch to ${s.adminIn ? 'Admin' : 'PSITS'} Portal',
                onTap: () => s.setPortal(s.adminIn ? Portal.admin : Portal.psits),
              ),
            ]),
          ),
        ),
      );
    }
    if (s.me == null) {
      return s.splash ? const _Splash() : const AuthScreen();
    }
    return const _UserShell();
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext c) {
    final s = AppScope.of(c);
    final p = s.pal;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [p.g2, p.bg])),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Logo('SmartBin'),
        const SizedBox(height: 10),
        NBtn(primary: true, label: 'Get Started', onTap: () => s.update(() => s.splash = false)),
      ]),
    );
  }
}

// ---------------- auth ----------------
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool reg = false;
  String err = '';
  String successMsg = '';
  String gender = '';
  String passwordVal = '';
  bool busy = false;
  bool rememberMe = false;
  bool initialized = false;
  final name = TextEditingController(), id = TextEditingController(), pw = TextEditingController(), pw2 = TextEditingController();

  @override
  void dispose() {
    for (final x in [name, id, pw, pw2]) {
      x.dispose();
    }
    super.dispose();
  }

  Future<void> submit(AppState s) async {
    if (busy) return;
    setState(() {
      err = '';
      successMsg = '';
    });
    if (reg) {
      if (gender.isEmpty) {
        setState(() => err = 'Please select a gender');
        return;
      }
      final (strength, msg) = evaluatePassword(pw.text);
      if (strength != PasswordStrength.strong) {
        setState(() => err = msg);
        return;
      }
      if (pw.text != pw2.text) {
        setState(() => err = 'Passwords do not match');
        return;
      }
      setState(() => busy = true);
      final e = await s.register(name.text, id.text, gender, pw.text, pw2.text);
      if (!mounted) return;
      setState(() => busy = false);
      if (e != null) {
        setState(() => err = e);
      } else {
        setState(() {
          successMsg = 'Registration successful! Please log in using your registered credentials.';
          reg = false;
          pw.clear();
          pw2.clear();
          name.clear();
          id.clear();
          gender = '';
        });
      }
    } else {
      setState(() => busy = true);
      final e = await s.login(id.text, pw.text, remember: rememberMe);
      if (!mounted) return;
      setState(() => busy = false);
      if (e != null) {
        setState(() => err = e);
      }
    }
  }

  @override
  Widget build(BuildContext c) {
    final s = AppScope.of(c);
    final p = s.pal;
    if (!initialized) {
      if (s.savedUserId.isNotEmpty) id.text = s.savedUserId;
      if (s.savedUserPw.isNotEmpty) pw.text = s.savedUserPw;
      rememberMe = s.savedUserId.isNotEmpty && s.savedUserPw.isNotEmpty && s.rememberUser;
      initialized = true;
    }
    final (strength, strengthMsg) = evaluatePassword(passwordVal);
    final strengthColor = strength == PasswordStrength.weak
        ? Pal.red
        : strength == PasswordStrength.fair
            ? Colors.orange
            : p.g;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          BackBtn(() {
            if (reg) {
              setState(() {
                reg = false;
                err = '';
                successMsg = '';
              });
            } else {
              s.update(() => s.splash = true);
            }
          }),
          Center(child: const Logo('SmartBin')),
          if (reg) const Padding(padding: EdgeInsets.only(bottom: 10), child: Text('Create account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
          if (err.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(err, style: const TextStyle(color: Pal.red))),
          if (successMsg.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(successMsg, textAlign: TextAlign.center, style: TextStyle(color: p.g, fontWeight: FontWeight.w600))),

          if (reg) ...[
            const Text('Full Name', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 4),
            NInput(ctrl: name, hint: 'e.g., Juan Dela Cruz'),
            const SizedBox(height: 4),
            const Mut('Enter your real full name exactly as shown on your official school ID.'),
            const SizedBox(height: 14),

            const Text('School ID Center Number', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 4),
            NInput(ctrl: id, hint: 'e.g., 1234', type: TextInputType.number),
            const SizedBox(height: 4),
            const Mut('Enter only the numbers in the center of your school ID. Example: POB-1234-BB → enter 1234.'),
            const SizedBox(height: 14),

            const Text('Gender', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => gender = 'Girl'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    decoration: gender == 'Girl'
                        ? BoxDecoration(color: const Color(0xFFE91E63), borderRadius: BorderRadius.circular(14), boxShadow: p.raiseSm)
                        : p.inset(14),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const GenderAvatar('Girl', size: 28),
                      const SizedBox(width: 8),
                      Text('Girl', style: TextStyle(fontWeight: FontWeight.w700, color: gender == 'Girl' ? Colors.white : p.tx)),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => gender = 'Boy'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    decoration: gender == 'Boy'
                        ? BoxDecoration(color: const Color(0xFF2196F3), borderRadius: BorderRadius.circular(14), boxShadow: p.raiseSm)
                        : p.inset(14),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const GenderAvatar('Boy', size: 28),
                      const SizedBox(width: 8),
                      Text('Boy', style: TextStyle(fontWeight: FontWeight.w700, color: gender == 'Boy' ? Colors.white : p.tx)),
                    ]),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 14),

            const Text('Password', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 4),
            NInput(
              ctrl: pw,
              hint: 'Create a strong password',
              password: true,
              onChanged: (v) => setState(() => passwordVal = v),
            ),
            const SizedBox(height: 4),
            const Mut('Use at least 12 characters, including uppercase and lowercase letters and numbers. A longer, less predictable password is safer.'),
            if (pw.text.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(strengthMsg, style: TextStyle(color: strengthColor, fontSize: 12, fontWeight: FontWeight.w700)),
            ],
            const SizedBox(height: 14),

            const Text('Confirm Password', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 4),
            NInput(ctrl: pw2, hint: 'Re-enter your password', password: true, onSubmitted: (_) => submit(s)),
            if (pw2.text.isNotEmpty && pw2.text != pw.text) ...[
              const SizedBox(height: 4),
              const Text('Passwords do not match', style: TextStyle(color: Pal.red, fontSize: 12, fontWeight: FontWeight.w700)),
            ],
            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: p.inset(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Bold('Example Guide'),
                const SizedBox(height: 4),
                const Mut('• Full Name: Juan Dela Cruz\n• School ID printed: POB-1234-BB\n• Center Number to enter: 1234\n• Gender: Boy or Girl\n• Password: Min 12 chars with upper, lower, & numbers.'),
              ]),
            ),
            const SizedBox(height: 14),
          ] else ...[
            const Text('School ID Center Number', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 4),
            NInput(ctrl: id, hint: 'e.g., 1234', type: TextInputType.number),
            const SizedBox(height: 14),
            const Text('Password', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 4),
            NInput(ctrl: pw, hint: 'Password', password: true, onSubmitted: (_) => submit(s)),
            const SizedBox(height: 10),
            Row(children: [
              Checkbox(
                value: rememberMe,
                activeColor: p.g,
                onChanged: (v) => setState(() => rememberMe = v ?? true),
              ),
              GestureDetector(
                onTap: () => setState(() => rememberMe = !rememberMe),
                child: const Text('Remember me', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ]),
            const SizedBox(height: 14),
          ],

          Center(
            child: FractionallySizedBox(
              widthFactor: .8,
              child: NBtn(
                primary: true,
                expand: true,
                label: reg ? 'Register' : 'Login',
                onTap: busy ? null : () => submit(s),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Mut(reg ? 'Already have an account? ' : 'No account yet? '),
            GestureDetector(
              onTap: () => setState(() {
                reg = !reg;
                err = '';
                successMsg = '';
              }),
              child: Text(reg ? 'Login' : 'Register', style: TextStyle(color: p.g, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ---------------- shell ----------------
class _UserShell extends StatelessWidget {
  const _UserShell();
  @override
  Widget build(BuildContext c) {
    final s = AppScope.of(c);
    final p = s.pal;
    final u = s.u;
    Widget body;
    Widget? back;
    switch (u) {
      case 'home': body = const _Home(); break;
      case 'board': body = const _Board(); back = BackBtn(() => s.goBack('home')); break;
      case 'more': body = const _More(); back = BackBtn(() => s.goBack('home')); break;
      case 'prof': body = const _Profile(); back = BackBtn(() => s.goBack('home')); break;
      case 'scan': body = const ScanScreen(); back = BackBtn(() => s.goBack(s.bk)); break;
      case 'rewards': body = const RewardsScreen(); back = BackBtn(() => s.goBack(s.bk)); break;
      case 'badges': body = const _Badges(); back = BackBtn(() => s.goBack(s.bk == 'prof' ? 'prof' : 'home')); break;
      case 'act': body = const _ActivityScreen(); back = BackBtn(() => s.goBack(s.bk == 'prof' ? 'prof' : 'home')); break;
      default: body = _SubPage(u); back = BackBtn(() => s.goBack('prof'));
    }
    Widget navBtn(String k, IconData i, String l) {
      final on = s.u == k;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => s.goU(k),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(i, color: on ? p.g : p.mut),
              Text(l, style: TextStyle(fontSize: 11, color: on ? p.g : p.mut)),
            ]),
          ),
        ),
      );
    }

    return SafeArea(
      child: Column(children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [if (back != null) back, body]),
          ),
        ),
        Container(
          decoration: BoxDecoration(color: p.bg, boxShadow: [BoxShadow(color: p.shD, blurRadius: 16, offset: const Offset(0, -8), spreadRadius: -10)]),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            navBtn('home', Icons.home_rounded, 'Home'),
            navBtn('rewards', Icons.card_giftcard_rounded, 'Rewards'),
            Expanded(
              child: Transform.translate(
                offset: const Offset(0, -16),
                child: GestureDetector(
                  onTap: () => s.goU('scan'),
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(shape: BoxShape.circle, gradient: p.priGrad, boxShadow: p.raise),
                    child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
                  ),
                ),
              ),
            ),
            navBtn('badges', Icons.military_tech_rounded, 'Badges'),
            navBtn('act', Icons.history_rounded, 'History'),
          ]),
        ),
      ]),
    );
  }
}

// ---------------- shared bits ----------------
Widget actRow(Activity a) => Builder(builder: (c) {
      final p = palOf(c);
      return NRow(
        left: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(a.title), Mut(a.date)]),
        right: Text(a.pts > 0 ? '+${a.pts}' : a.pts != 0 ? '${a.pts}' : 'Badge', style: TextStyle(fontWeight: FontWeight.w700, color: a.pts >= 0 ? p.g : Pal.red)),
      );
    });

Widget boardRow(AppState s, ({UserAcct u, int v}) r, int i) {
  final isMe = s.me != null && r.u.id == s.me!.id;
  return Builder(builder: (c) {
    final p = palOf(c);
    final medal = i < 3 ? ['🥇', '🥈', '🥉'][i] : '${i + 1}.';
    return NRow(
      left: Text('$medal ${r.u.name}${isMe ? ' (you)' : ''}', style: TextStyle(fontWeight: isMe ? FontWeight.w700 : null, color: isMe ? p.g : null)),
      right: Text('${r.v}', style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  });
}

Widget boardCard(AppState s) {
  final b = s.board(5);
  return NCard(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const H3('CICI Campus Leaderboard'),
      if (b.isEmpty) const Mut('No students yet') else for (var i = 0; i < b.length; i++) boardRow(s, b[i], i),
    ]),
  );
}

class BadgeTile extends StatelessWidget {
  final BadgeItem b;
  final bool earned;
  final bool compact;
  const BadgeTile(this.b, this.earned, {super.key, this.compact = false});
  @override
  Widget build(BuildContext c) {
    final p = palOf(c);
    return Opacity(
      opacity: earned ? 1 : .4,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: compact ? 6 : 12, horizontal: 4),
        decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(18), boxShadow: p.raise),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(b.icon, style: TextStyle(fontSize: compact ? 20 : 28)),
          if (!compact) ...[
            Text(b.name, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
            Mut(earned ? 'Earned' : 'Needs ${b.min} pts'),
          ],
        ]),
      ),
    );
  }
}

// ---------------- home ----------------
class _Home extends StatelessWidget {
  const _Home();
  @override
  Widget build(BuildContext c) {
    final s = AppScope.of(c);
    final p = s.pal;
    final m = s.cur;
    final lf = m.life;
    final sorted = s.badges.where((b) => lf < b.min).toList()..sort((a, b) => a.min.compareTo(b.min));
    final nx = sorted.firstOrNull;
    final earned = s.badges.where((b) => lf >= b.min).toList();
    final today = DateTime.now();
    final midnight = DateTime(today.year, today.month, today.day).millisecondsSinceEpoch;
    final rate = s.vc.rate;
    final recent = s.mine().take(3).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      HeroCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('Hello, ${s.me!.name}')),
            GestureDetector(
              onTap: () => s.goU('prof'),
              child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.person_rounded, color: Colors.white, size: 20)),
            ),
          ]),
          const SizedBox(height: 4),
          const Text('Total Points', style: TextStyle(color: Color(0xFFD9F5DF), fontSize: 12)),
          Text('${s.pts}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
          Text('= ₱${(s.pts / rate).toStringAsFixed(2)}'),
        ]),
      ),
      StatRow([
        StatTile('Today', '${s.ptsSince(midnight)}'),
        StatTile('This Week', '${s.ptsSince(DateTime.now().millisecondsSinceEpoch - 604800000)}'),
        StatTile('Items', '${m.items}'),
      ]),
      NCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Bold('Next badge'),
          const SizedBox(height: 4),
          if (nx != null) ...[
            NRow(left: Text('${nx.icon} ${nx.name}'), right: Mut('$lf / ${nx.min} pts'), border: false),
            Meter((lf / nx.min * 100).clamp(0, 100).toDouble()),
          ] else
            Mut(s.badges.isNotEmpty ? 'All badges earned' : 'No badges yet'),
        ]),
      ),
      NCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Bold('Badges earned (${earned.length}/${s.badges.length})'),
          const SizedBox(height: 8),
          if (s.badges.isEmpty)
            const Mut('No badges yet')
          else
            GridView.count(
              crossAxisCount: 6,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [for (final b in s.badges) BadgeTile(b, lf >= b.min, compact: true)],
            ),
          const SizedBox(height: 8),
          NBtn(label: 'All badges ›', onTap: () => s.goU('badges')),
        ]),
      ),
      NCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Bold('Items by weekday'),
          const SizedBox(height: 6),
          WeekBars(s.week, height: 80),
        ]),
      ),
      NCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Bold('Recent Activity'),
          if (recent.isEmpty) const Padding(padding: EdgeInsets.only(top: 6), child: Mut('No activity yet')) else ...recent.map(actRow),
        ]),
      ),
      NBtn(expand: true, label: '🏆 Campus Leaderboard ›', onTap: () => s.goU('board')),
      const SizedBox(height: 12),
      NBtn(expand: true, label: 'More details ›', onTap: () => s.goU('more')),
      const SizedBox(height: 12),
    ]);
  }
}

class _Board extends StatelessWidget {
  const _Board();
  @override
  Widget build(BuildContext c) {
    final s = AppScope.of(c);
    final all = s.board(999);
    final rk = all.indexWhere((r) => r.u.id == s.me!.id);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const H3('CICI Campus Leaderboard'),
      Seg(value: s.lb, options: const [['p', 'Points'], ['i', 'Items']], onChange: (v) => s.update(() => s.lb = v)),
      NCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (all.isEmpty) const Mut('No students yet') else for (var i = 0; i < all.length && i < 10; i++) boardRow(s, all[i], i),
      ])),
      if (rk > 9) NCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Mut('Your rank'), boardRow(s, all[rk], rk)])),
    ]);
  }
}

class _More extends StatelessWidget {
  const _More();
  @override
  Widget build(BuildContext c) {
    final s = AppScope.of(c);
    final rate = s.vc.rate;
    final conversionList = [10, 50, 100, 200, 500, 1000];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const H3('More details'),
      NCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Bold('Points to Peso Conversion List'),
            const SizedBox(height: 6),
            const Mut('Minimum: 10 pts (₱1) · Maximum: 1000 pts (₱100)'),
            const SizedBox(height: 10),
            for (final pts in conversionList)
              NRow(
                left: Text('$pts points'),
                right: Text('₱${pts ~/ rate}', style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
          ],
        ),
      ),
    ]);
  }
}

// ---------------- profile ----------------
class _Profile extends StatelessWidget {
  const _Profile();
  @override
  Widget build(BuildContext c) {
    final s = AppScope.of(c);
    final p = s.pal;
    Widget rows(List<List<String>> a) => NCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(children: [
            for (final x in a)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => s.goU(x[0]),
                child: NRow(left: Text('${x[1]}  ${s.tt(x[0])}'), right: Icon(Icons.chevron_right_rounded, color: p.mut), border: x != a.last),
              ),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      H3(s.tt('prof')),
      NCard(align: CrossAxisAlignment.center, child: Column(children: [
        GenderAvatar(s.me!.gender, size: 54),
        const SizedBox(height: 8),
        Bold(s.me!.name, size: 16),
        Mut('Student ID: ${s.me!.id}')
      ])),
      rows([['info', '👤'], ['act', '🕘'], ['badges', '🏆'], ['how', '❓'], ['about', 'ℹ️'], ['help', '🛟'], ['priv', '🛡']]),
      rows([['pw', '🔑'], ['fs', '🔠'], ['lang', '🌐']]),
      NBtn(danger: true, expand: true, label: s.tt('out'), onTap: s.logoutUser),
      const SizedBox(height: 12),
    ]);
  }
}

class _Badges extends StatefulWidget {
  const _Badges();
  @override
  State<_Badges> createState() => _BadgesState();
}

class _BadgesState extends State<_Badges> {
  String t = 'e';
  @override
  Widget build(BuildContext c) {
    final s = AppScope.of(c);
    final lf = s.cur.life;
    final list = s.badges.where((b) => t == 'a' || lf >= b.min).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const H3('My Badges'),
      Seg(value: t, options: const [['e', 'Earned'], ['a', 'All Badges']], onChange: (v) => setState(() => t = v)),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.2,
        children: [for (final b in list) BadgeTile(b, lf >= b.min)],
      ),
    ]);
  }
}

class _ActivityScreen extends StatelessWidget {
  const _ActivityScreen();
  @override
  Widget build(BuildContext c) {
    final s = AppScope.of(c);
    final l = s.mine();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const H3('Activity History'),
      NCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [if (l.isEmpty) const Mut('No activity yet') else ...l.map(actRow)])),
    ]);
  }
}

/// info / how / about / help / priv / pw / fs / lang
class _SubPage extends StatelessWidget {
  final String k;
  const _SubPage(this.k);
  @override
  Widget build(BuildContext c) {
    final s = AppScope.of(c);
    final p = s.pal;
    Widget q(String a, String b) => NCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Bold(a), const SizedBox(height: 4), Mut(b)]));
    Widget cardList(String t, List<String> a) => NCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Bold(t), Steps(a, ordered: false)]));
    Widget body;
    switch (k) {
      case 'info':
        body = NCard(align: CrossAxisAlignment.center, child: Column(children: [
          GenderAvatar(s.me!.gender, size: 64),
          const SizedBox(height: 10),
          Bold(s.me!.name, size: 18),
          const SizedBox(height: 4),
          Mut('Student ID: ${s.me!.id}'),
          const Divider(height: 24),
          kv('Gender', s.me!.gender.isEmpty ? '—' : s.me!.gender),
          kv('Points', '${s.pts}'),
          kv('Items deposited', '${s.cur.items}'),
        ]));
        break;
      case 'how':
        body = howBody(s);
        break;
      case 'about':
        body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          NCard(align: CrossAxisAlignment.center, child: Column(children: [
            const Bold('SmartBin', size: 18),
            const Mut('Smart Solution · Cleaner Tomorrow'),
            const SizedBox(height: 8),
            const Pill('Developed by: BLNTS @2025: Built Together'),
          ])),
          NCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Bold('What is SmartBin?'),
            const SizedBox(height: 6),
            const Text('SmartBin is a smart waste bin for our campus. It recognizes recyclable and non-biodegradable waste using our own trained dataset, shows how full each compartment is, and rewards students for throwing waste the right way.'),
            const SizedBox(height: 8),
            const Text('Points you earn can be converted into free printing at the PSITS office, so cleaner habits turn into something useful for school.'),
          ])),
          NCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Bold('Developed by BLNTS'),
            const SizedBox(height: 6),
            const Text('SmartBin was designed and built by students, the BLNTS 2025 team. Every deposit, scan and free printing credit is part of a cleaner campus that we are building together.'),
          ])),
          NCard(
            child: Column(
              children: [
                const Bold('Parts of the system'),
                NRow(left: const Text('User App'), right: Mut('earn and redeem')),
                NRow(left: const Text('Admin Portal'), right: Mut('bins, badges, users')),
                NRow(left: const Text('PSITS Portal'), right: Mut('voucher scanner')),
                NRow(left: const Text('Waste recognition'), right: Mut('trained on our own dataset')),
              ],
            ),
          ),
        ]);
        break;
      case 'help':
        body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          q('My points did not update', 'Scan the reward QR before it expires (2 minutes) and only once. Check Activity History to see if it was already counted.'),
          q('The bin QR will not scan', 'Hold your phone steady, clean the camera and raise the screen brightness. You can also paste the QR code text in the Scan screen.'),
          q('My voucher says Expired or Already redeemed', 'Vouchers last ${s.vc.days} days and work once. Expired or used vouchers are not replaced and points are not refunded.'),
          q('I lost or damaged my voucher', 'Lost, copied, edited or unreadable vouchers are not replaced. Open Rewards, then My Vouchers, to show the QR again while it is still valid.'),
          q('Wrong points or wrong voucher value', 'Visit the ${s.vc.office} with your Student ID and your voucher QR so staff can check it.'),
          NCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Bold('Contact support'), const SizedBox(height: 4), Text('Visit the ${s.vc.office} during office hours and bring your Student ID.')])),
        ]);
        break;
      case 'priv':
        body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          cardList('Privacy: what we keep', [
            'Your name and Student ID, your points, badges and activity history, and the vouchers you create (code, value and expiry date).',
            'The bin records each deposit (which bin, result and weight) to calculate your points.',
            'Your voucher QR contains your name, Student ID, value and expiry so PSITS can check it. Do not share it with others.',
          ]),
          cardList('Privacy: how it is used', [
            'To give you points, badges and vouchers, and to let PSITS check and claim a voucher.',
            'To show bin fill levels and totals to the SmartBin admin and PSITS staff. The campus leaderboard shows names and counts only.',
            'We do not sell your information or use it for advertising. Only the school staff who run SmartBin can see your records.',
            'You can ask the PSITS office to correct or delete your record.',
          ]),
          cardList('Terms of use', [
            "Use SmartBin for real waste only. Tampering with bins, sensors or QR codes, or scanning another person's reward QR, is not allowed and may remove your points.",
            'Points have no cash value. They can only be converted to printing vouchers at the rate set by the school.',
            'Vouchers: ${s.voucherRules().sublist(2).join(' ')}',
          ]),
          const Center(child: Mut('Last updated October 2026')),
        ]);
        break;
      case 'pw':
        body = const _PasswordForm();
        break;
      default: // fs | lang
        final isFs = k == 'fs';
        final opts = isFs
            ? [['s', 'Small'], ['n', 'Normal'], ['l', 'Large'], ['x', 'Extra Large']]
            : [['en', 'English'], ['fil', 'Filipino'], ['hil', 'Hiligaynon']];
        final cur = isFs ? s.fs : s.lang;
        body = NCard(child: Column(children: [
          for (final o in opts)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => s.update(() => isFs ? s.fs = o[0] : s.lang = o[0]),
              child: NRow(left: Row(children: [Icon(cur == o[0] ? Icons.radio_button_checked : Icons.radio_button_off, color: p.g, size: 20), const SizedBox(width: 10), Text(o[1])])),
            ),
          Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => s.goBack('prof'), child: Text(s.tt('close'), style: TextStyle(color: p.g)))),
        ]));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [H3(s.tt(k)), body]);
  }
}

class _PasswordForm extends StatefulWidget {
  const _PasswordForm();
  @override
  State<_PasswordForm> createState() => _PasswordFormState();
}

class _PasswordFormState extends State<_PasswordForm> {
  final a = TextEditingController(), b = TextEditingController();
  bool ok = false;
  String msg = '';
  @override
  void dispose() {
    a.dispose();
    b.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final s = AppScope.of(c);
    final p = s.pal;
    return NCard(
      align: CrossAxisAlignment.center,
      child: Column(children: [
        if (msg.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(msg, style: TextStyle(color: ok ? p.g : Pal.red))),
        NInput(ctrl: a, hint: s.tt('np'), password: true),
        const SizedBox(height: 14),
        NInput(ctrl: b, hint: s.tt('cp'), password: true),
        const SizedBox(height: 18),
        FractionallySizedBox(
          widthFactor: .8,
          child: NBtn(
            primary: true,
            expand: true,
            label: s.tt('upd'),
            onTap: () async {
              final e = await s.changePassword(a.text, b.text);
              if (!mounted) return;
              setState(() {
                ok = e == null;
                msg = e ?? 'Password updated';
              });
            },
          ),
        ),
      ]),
    );
  }
}

class QrScannerBox extends StatefulWidget {
  final void Function(String) onCode;
  final double height;
  const QrScannerBox({super.key, required this.onCode, this.height = 240});
  @override
  State<QrScannerBox> createState() => _QrScannerBoxState();
}

class _QrScannerBoxState extends State<QrScannerBox> {
  late final MobileScannerController ctrl = MobileScannerController(facing: CameraFacing.back, detectionSpeed: DetectionSpeed.noDuplicates);
  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final p = palOf(c);
    return Container(
      height: widget.height,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: p.g, width: 3), color: Colors.black),
      clipBehavior: Clip.antiAlias,
      child: MobileScanner(
        controller: ctrl,
        onDetect: (cap) {
          final raw = cap.barcodes.firstOrNull?.rawValue;
          if (raw != null && raw.isNotEmpty) widget.onCode(raw);
        },
        errorBuilder: (ctx, err, _) => const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('Camera blocked or unavailable.\nPaste the code below instead.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white)))),
      ),
    );
  }
}

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  ScanRes? res;
  bool fetching = true;
  bool busy = false;
  final manual = TextEditingController();
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => fetching = false);
    });
  }

  @override
  void dispose() {
    manual.dispose();
    super.dispose();
  }

  Future<void> handle(AppState s, String code) async {
    if (res != null || busy) return;
    busy = true;
    final r = await s.redeemQR(code);
    busy = false;
    if (!mounted) return;
    setState(() => res = r);
  }

  @override
  Widget build(BuildContext c) {
    final s = AppScope.of(c);
    final p = s.pal;
    final r = res;
    final lv = s.vl.where((x) => x.uid == s.me!.id).firstOrNull;
    final st = lv?.state ?? 'None';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      NCard(
        align: CrossAxisAlignment.center,
        child: Column(children: [
          const H3('Scan Reward QR'),
          if (r != null) ...[
            Banner2(r.ok ? 'Success! ${r.msg}' : r.msg, bad: !r.ok, extra: r.newBadges.isEmpty ? null : Text('New badge: ${r.newBadges.join(', ')}')),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              NBtn(primary: true, label: 'Scan again', onTap: () => setState(() => res = null)),
              const SizedBox(width: 12),
              NBtn(label: 'Done', onTap: () => s.goBack('home')),
            ]),
          ] else ...[
            QrScannerBox(onCode: (v) => handle(s, v)),
            const SizedBox(height: 10),
            const Mut('Point your camera at the QR code on the bin'),
            const SizedBox(height: 10),
            NInput(ctrl: manual, hint: 'or paste reward QR text', onSubmitted: (v) => handle(s, v)),
            const SizedBox(height: 10),
            NBtn(label: 'Submit code', onTap: () => handle(s, manual.text)),
          ],
        ]),
      ),
      NCard(
        child: fetching
            ? Center(child: Column(children: [SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3, color: p.g)), const SizedBox(height: 10), const Mut('Fetching voucher details...')]))
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('VOUCHER DETAILS', style: TextStyle(color: p.g, fontWeight: FontWeight.w700, letterSpacing: 1)),
                const SizedBox(height: 6),
                kv('Voucher Code:', lv?.shortCode ?? '---', mutLabel: true),
                kv('Current Balance:', '₱${(s.pts / s.vc.rate).toStringAsFixed(2)}', color: p.g, mutLabel: true),
                kv('Status:', st, color: st == 'Active' ? const Color(0xFF2F6FE4) : Pal.red, mutLabel: true),
                kv('Expiry Date:', lv != null ? dateStr(lv.exp) : 'N/A', mutLabel: true),
              ]),
      ),
    ]);
  }
}

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});
  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  String rt = 'v', vm = 'g';
  final pg = Pages();
  final pesos = TextEditingController();
  String err = '';
  bool busy = false;
  @override
  void dispose() {
    pesos.dispose();
    super.dispose();
  }

  void adj(String k, int d) => setState(() => pg.set(k, (pg.get(k) + d).clamp(0, 99).toInt()));

  Future<void> gen(AppState s) async {
    if (busy) return;
    final gm = vm == 'g';
    final rawPesos = pesos.text.trim();
    final amt = gm ? pg.total(kPrices) : (int.tryParse(rawPesos) ?? 0);
    if (gm && amt == 0) {
      setState(() => err = 'Choose at least 1 page');
      return;
    }
    if (amt <= 0 || amt > 100 || amt < s.vc.min || amt > s.vc.max || (amt * s.vc.rate) < 10 || (amt * s.vc.rate) > 1000) {
      setState(() => err = 'Warning! Limit Exceeded! Pesos must be 1–100 and points must be 10–1000.');
      return;
    }
    if (amt * s.vc.rate > s.pts) {
      setState(() => err = 'Not enough points (need ${amt * s.vc.rate})');
      return;
    }
    busy = true;
    final (v, e) = await s.generateVoucher(amt, gm ? pg.copy() : null);
    busy = false;
    if (!mounted) return;
    if (e != null) {
      setState(() => err = e);
      return;
    }
    setState(() {
      err = '';
      pg.bw = pg.col = pg.pic = 0;
    });
    showVoucherDialog(context, v!);
  }

  @override
  Widget build(BuildContext c) {
    final s = AppScope.of(c);
    final p = s.pal;
    final rate = s.vc.rate;
    final total = pg.total(kPrices);
    final pv = int.tryParse(pesos.text.trim()) ?? 0;
    final mine = s.vl.where((v) => v.uid == s.me!.id).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const H3('Rewards'),
      HeroCard(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${s.pts} pts', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          Text('= ₱${(s.pts / rate).toStringAsFixed(2)} ($rate pts = ₱1)'),
        ]),
      ),
      Seg(value: rt, options: const [['v', 'Get Voucher'], ['h', 'My Vouchers']], onChange: (v) => setState(() => rt = v)),
      if (rt == 'h') ...[
        if (mine.isEmpty) const Mut('No vouchers yet'),
        for (final v in mine)
          NCard(
            child: NRow(
              border: false,
              left: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Flexible(child: Bold('₱${v.pesos} printing')), const SizedBox(width: 8), Pill(v.state)]),
                Mut('${v.shortCode} · expires ${dateStr(v.exp)}'),
              ]),
              right: NBtn(small: true, label: 'Show QR', onTap: () => showVoucherDialog(context, v)),
            ),
          ),
      ] else ...[
        NCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Bold('Convert points to free printing'),
            const SizedBox(height: 6),
            Mut('Printing prices: ${AppState.priceText(kPrices)}. Choose how many pages to print (or type pesos): maximum ₱${s.vc.max} per voucher, valid ${s.vc.days} days. Show the QR at the ${s.vc.office} to claim it.'),
            const SizedBox(height: 12),
            Seg(value: vm, options: const [['g', 'By pages'], ['p', 'By pesos']], onChange: (v) => setState(() => vm = v)),
            if (vm == 'g') ...[
              const Mut('How many pages do you want to print?'),
              for (final x in [['bw', 'B&W page'], ['col', 'Colored page'], ['pic', 'Picture page']])
                NRow(
                  left: Row(children: [Text(x[1]), const SizedBox(width: 6), Mut('₱${kPrices.of(x[0])} each')]),
                  right: Row(mainAxisSize: MainAxisSize.min, children: [
                    NBtn(small: true, label: '−', onTap: () => adj(x[0], -1)),
                    SizedBox(width: 34, child: Text('${pg.get(x[0])}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700))),
                    NBtn(small: true, label: '+', onTap: () => adj(x[0], 1)),
                  ]),
                ),
              const SizedBox(height: 8),
              Pill(total > 0 ? 'Total ₱$total · ${total * rate} points' : 'Choose at least 1 page', block: true),
            ] else ...[
              NRow(left: const Text('Pesos'), right: NInput(ctrl: pesos, type: TextInputType.number, width: 100, hint: '${(s.pts ~/ rate).clamp(s.vc.min, s.vc.max)}', onChanged: (_) => setState(() {})), border: false),
              Pill(pv > 0 ? '₱$pv prints ${AppState.pgLine(pv, kPrices)} pages · ${pv * rate} points' : 'Enter pesos to convert', block: true),
            ],
            const SizedBox(height: 8),
            if (err.isNotEmpty) Text(err, style: const TextStyle(color: Pal.red)),
            const SizedBox(height: 8),
            NBtn(primary: true, expand: true, label: 'Generate voucher QR', onTap: () => gen(s)),
          ]),
        ),
        rulesCard(s),
      ],
    ]);
  }
}
