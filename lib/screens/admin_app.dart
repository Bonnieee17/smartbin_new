import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../state/models.dart';
import '../theme/pal.dart';
import '../widgets/common.dart';
import 'user_app.dart' show Logo, boardCard;

// ---------- shared portal chrome ----------
class GateScreen extends StatefulWidget {
  final String title, hint;
  final Future<String?> Function(String user, String password, bool remember) onLogin;
  final String defaultUser;
  final String defaultPw;
  final bool defaultRemember;
  const GateScreen({
    super.key,
    required this.title,
    required this.hint,
    required this.onLogin,
    this.defaultUser = '',
    this.defaultPw = '',
    this.defaultRemember = true,
  });
  @override
  State<GateScreen> createState() => _GateScreenState();
}

class _GateScreenState extends State<GateScreen> {
  late final u = TextEditingController(text: widget.defaultUser);
  late final p = TextEditingController(text: widget.defaultPw);
  late bool remember = widget.defaultUser.isNotEmpty && widget.defaultPw.isNotEmpty && widget.defaultRemember;
  String err = '';
  bool busy = false;
  @override
  void dispose() {
    u.dispose();
    p.dispose();
    super.dispose();
  }

  Future<void> go() async {
    if (busy) return;
    if (u.text.isEmpty || p.text.isEmpty) {
      setState(() => err = 'Enter your ID and password');
      return;
    }
    setState(() {
      err = '';
      busy = true;
    });
    final e = await widget.onLogin(u.text.trim(), p.text, remember);
    if (!mounted) return;
    setState(() {
      busy = false;
      err = e ?? '';
    });
  }

  @override
  Widget build(BuildContext c) {
    final pal = palOf(c);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        Logo(widget.title),
        NInput(ctrl: u, hint: widget.hint),
        const SizedBox(height: 14),
        NInput(ctrl: p, hint: 'Password', password: true, onSubmitted: (_) => go()),
        const SizedBox(height: 10),
        Row(children: [
          Checkbox(
            value: remember,
            activeColor: pal.g,
            onChanged: (v) => setState(() => remember = v ?? true),
          ),
          GestureDetector(
            onTap: () => setState(() => remember = !remember),
            child: const Text('Remember me', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ]),
        if (err.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(err, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red))),
        const SizedBox(height: 18),
        FractionallySizedBox(widthFactor: .8, child: NBtn(primary: true, expand: true, label: 'Login', onTap: go)),
      ]),
    );
  }
}

/// Top nav card + body, used by Admin and PSITS.
class PortalLayout extends StatelessWidget {
  final String current;
  final List<List<String>> tabs; // [key,label]
  final ValueChanged<String> onTab;
  final VoidCallback onLogout;
  final Widget body;
  final Widget? leading;
  const PortalLayout({super.key, required this.current, required this.tabs, required this.onTab, required this.onLogout, required this.body, this.leading});
  @override
  Widget build(BuildContext c) {
    final p = palOf(c);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(18), boxShadow: p.raise),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (leading != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: leading!),
            Wrap(spacing: 10, runSpacing: 12, children: [
              for (final t in tabs) NBtn(selected: current == t[0], label: t[1], onTap: () => onTab(t[0])),
              NBtn(label: '⎋ Logout', onTap: onLogout),
            ]),
          ]),
        ),
        if (current != 'dash') BackBtn(() => onTab('dash')),
        body,
      ]),
    );
  }
}

Widget statCard(String label, String value) => Builder(builder: (c) {
      return StatTile(label, value);
    });

int avgFill(AppState s) {
  final cs = [for (final b in s.bins) ...b.comps];
  return cs.isEmpty ? 0 : (cs.fold<int>(0, (a, x) => a + x.fill) / cs.length).round();
}

Widget labeled(String label, Widget field) => NRow(left: Text(label), right: field);

// ---------- admin ----------
class AdminApp extends StatelessWidget {
  const AdminApp({super.key});
  @override
  Widget build(BuildContext c) {
    final s = AppScope.of(c);
    if (!s.adminIn) {
      return GateScreen(
        title: 'Admin Portal',
        hint: 'Admin ID',
        defaultUser: s.savedAdminId,
        defaultPw: s.savedAdminPw,
        defaultRemember: s.rememberAdmin,
        onLogin: (id, pw, remember) => s.staffLogin(id, pw, admin: true, remember: remember),
      );
    }
    Widget body;
    switch (s.a) {
      case 'bins': body = const _AdminBins(); break;
      case 'badges': body = const _AdminBadges(); break;
      case 'rew': body = const _AdminRewards(); break;
      case 'rules': body = rulesCard(s); break;
      case 'students': body = const _AdminStudents(); break;
      default: body = const _AdminDash();
    }
    return PortalLayout(
      current: s.a,
      tabs: const [
        ['dash', '📊 Dashboard'],
        ['bins', '🗑 Bins'],
        ['badges', '🏅 Badges'],
        ['rew', '⚙ Rewards'],
        ['students', '👥 Registered Students'],
        ['rules', '📜 Rules']
      ],
      onTab: (k) => s.update(() => s.a = k),
      onLogout: s.logoutAdmin,
      body: body,
    );
  }
}

class _AdminStudents extends StatefulWidget {
  const _AdminStudents();
  @override
  State<_AdminStudents> createState() => _AdminStudentsState();
}

class _AdminStudentsState extends State<_AdminStudents> {
  String q = '';
  String? selectedId;

  @override
  Widget build(BuildContext c) {
    final s = AppScope.of(c);
    final users = s.users;
    final filtered = users.where((u) => q.isEmpty || '${u.name} ${u.id}'.toLowerCase().contains(q.toLowerCase())).toList();

    if (selectedId != null) {
      final u = users.where((x) => x.id == selectedId).firstOrNull;
      if (u == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => setState(() => selectedId = null));
        return const SizedBox.shrink();
      }
      final uActs = s.act.where((a) => a.uid == u.id).toList();
      final uVouchers = s.vl.where((v) => v.uid == u.id).toList();
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        BackBtn(() => setState(() => selectedId = null)),
        NCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            H3('Student Details: ${u.gender == 'Girl' ? '👧' : u.gender == 'Boy' ? '👦' : ''} ${u.name}'),
            kv('Full Name', u.name),
            kv('School ID Center No.', u.id),
            kv('Gender', u.gender.isEmpty ? '—' : u.gender),
            kv('Current Points', '${u.points}'),
            kv('Lifetime Points', '${u.life}'),
            kv('Items Deposited', '${u.items}'),
          ]),
        ),
        NCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const H3('Student Activity History'),
            if (uActs.isEmpty)
              const Mut('No activity recorded')
            else
              for (final a in uActs)
                NRow(
                  left: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(a.title), Mut(a.date)]),
                  right: Text(a.pts != 0 ? '${a.pts > 0 ? '+' : ''}${a.pts}' : 'Badge', style: TextStyle(fontWeight: FontWeight.w700, color: a.pts >= 0 ? s.pal.g : Pal.red)),
                ),
          ]),
        ),
        NCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const H3('Student Vouchers'),
            if (uVouchers.isEmpty)
              const Mut('No vouchers generated')
            else
              for (final v in uVouchers)
                NRow(
                  left: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Bold('₱${v.pesos} printing'), Mut('${v.shortCode} · status: ${v.state}')]),
                  right: NBtn(small: true, label: 'Show QR', onTap: () => showVoucherDialog(c, v)),
                ),
          ]),
        ),
      ]);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const H3('Registered Students'),
      StatRow([StatTile('Total Students', '${users.length}')]),
      NCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          NInput(hint: 'Search by Full Name or School ID Center No.', onChanged: (v) => setState(() => q = v)),
        ]),
      ),
      NCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Bold('Student Directory'),
            Mut('Showing ${filtered.length} of ${users.length}'),
          ]),
          const SizedBox(height: 10),
          if (filtered.isEmpty)
            const Mut('No registered students found')
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 36,
                columns: const [
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('School ID (Center No.)')),
                  DataColumn(label: Text('Gender')),
                  DataColumn(label: Text('Points')),
                  DataColumn(label: Text('Items')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: [
                  for (final u in filtered)
                    DataRow(cells: [
                      DataCell(Text('${u.gender == 'Girl' ? '👧' : u.gender == 'Boy' ? '👦' : ''} ${u.name}')),
                      DataCell(Text(u.id)),
                      DataCell(Text(u.gender.isEmpty ? '—' : u.gender)),
                      DataCell(Text('${u.points}')),
                      DataCell(Text('${u.items}')),
                      DataCell(
                        NBtn(small: true, label: 'View Details', onTap: () => setState(() => selectedId = u.id)),
                      ),
                    ]),
                ],
              ),
            ),
        ]),
      ),
    ]);
  }
}

Widget _binFillRows(Bin b) => Column(children: [
      for (final cp in b.comps)
        NRow(
          left: Row(children: [
            Expanded(flex: 5, child: Text(kCN[cp.k]!)),
            Expanded(flex: 4, child: Meter(cp.fill.toDouble())),
          ]),
          right: SizedBox(width: 44, child: Text('${cp.fill}%', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700))),
        ),
    ]);

class _AdminDash extends StatelessWidget {
  const _AdminDash();
  @override
  Widget build(BuildContext c) {
    final s = AppScope.of(c);
    final it = s.users.fold<int>(0, (a, u) => a + u.items);
    final pi = s.users.fold<int>(0, (a, u) => a + u.life);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      StatRow([StatTile('Items accepted', '$it'), StatTile('Rejected', '${s.rej}'), StatTile('Points issued', '$pi')]),
      if (s.bins.isEmpty)
        NCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const H3('Getting started'),
            const Mut('Load an example bin (2 compartments), badges, vouchers and point rules.'),
            const SizedBox(height: 10),
            NBtn(primary: true, label: 'Load example data', onTap: () => s.seed()),
          ]),
        )
      else
        for (final b in s.bins)
          NCard(
            child: Column(children: [
              NRow(left: Bold('🗑 ${b.name}'), right: Bulbs(b.comps.map((x) => x.fill).reduce((a, b) => a > b ? a : b)), border: false),
              _binFillRows(b),
            ]),
          ),
      StatRow([StatTile('Bins', '${s.bins.length}'), StatTile('Users', '${s.users.length}'), StatTile('Vouchers issued', '${s.log.length}')]),
      NCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const H3('Average Fill Level'), Donut(avgFill(s))])),
      boardCard(s),
    ]);
  }
}

// ---- bins ----
class _AdminBins extends StatefulWidget {
  const _AdminBins();
  @override
  State<_AdminBins> createState() => _AdminBinsState();
}

class _AdminBinsState extends State<_AdminBins> {
  final n = TextEditingController(), l = TextEditingController();
  @override
  void dispose() {
    n.dispose();
    l.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final s = AppScope.of(c);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      NCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const H3('Manage Bins'),
          NInput(ctrl: n, hint: 'Bin name'),
          const SizedBox(height: 10),
          NInput(ctrl: l, hint: 'Location'),
          const SizedBox(height: 10),
          NBtn(
            primary: true,
            label: '+ Add Bin',
            onTap: () {
              s.addBin(n.text, l.text);
              n.clear();
              l.clear();
            },
          ),
          const SizedBox(height: 8),
          const Mut('Each bin has 2 compartments (Recyclable, Non-biodegradable) and a reject passage for invalid waste.'),
          const SizedBox(height: 12),
          for (final b in s.bins) _BinCard(b, key: ValueKey(b.id)),
        ]),
      ),
      const _BinTest(),
    ]);
  }
}

class _BinCard extends StatefulWidget {
  final Bin b;
  const _BinCard(this.b, {super.key});
  @override
  State<_BinCard> createState() => _BinCardState();
}

class _BinCardState extends State<_BinCard> {
  bool open = false, edit = false;
  late final en = TextEditingController(text: widget.b.name);
  late final el = TextEditingController(text: widget.b.loc);
  @override
  void dispose() {
    en.dispose();
    el.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final s = AppScope.of(c);
    final b = widget.b;
    return NCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Bold('🗑 ${b.name}'), Mut(b.loc)])),
          Bulbs(b.comps.map((x) => x.fill).reduce((a, b) => a > b ? a : b)),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          NBtn(small: true, label: 'Config', onTap: () => setState(() => open = !open)),
          NBtn(small: true, label: 'Edit', onTap: () => setState(() => edit = !edit)),
          DelBtn(onConfirm: () => s.deleteBin(b)),
        ]),
        if (edit) ...[
          const SizedBox(height: 10),
          NInput(ctrl: en, hint: 'Name'),
          const SizedBox(height: 8),
          NInput(ctrl: el, hint: 'Location'),
          const SizedBox(height: 8),
          Row(children: [
            NBtn(
              primary: true,
              small: true,
              label: 'Save',
              onTap: () {
                if (en.text.trim().isEmpty) return;
                s.saveBin(b, en.text.trim(), el.text.trim().isEmpty ? '—' : el.text.trim());
                setState(() => edit = false);
              },
            ),
            const SizedBox(width: 8),
            NBtn(small: true, label: 'Cancel', onTap: () => setState(() => edit = false)),
          ]),
        ],
        _binFillRows(b),
        NRow(left: const Mut('Reject passage (invalid waste)'), right: Text('${s.rej} items', style: const TextStyle(fontWeight: FontWeight.w700)), border: false),
        if (open) ...[
          NRow(left: const Text('Active'), right: NSwitch(on: b.on, onChanged: (v) => s.setBinOn(b, v))),
          for (final cp in b.comps)
            NRow(
              left: Text('${kCN[cp.k]} fill %'),
              right: NInput(
                key: ValueKey('${b.id}${cp.k}${cp.fill}'),
                ctrl: TextEditingController(text: '${cp.fill}'),
                type: TextInputType.number,
                width: 80,
                onSubmitted: (v) => s.setFill(b, cp, (int.tryParse(v) ?? 0).clamp(0, 100).toInt()),
              ),
            ),
        ],
      ]),
    );
  }
}

class _BinTest extends StatefulWidget {
  const _BinTest();
  @override
  State<_BinTest> createState() => _BinTestState();
}

class _BinTestState extends State<_BinTest> {
  int? binId;
  String item = 'rec';
  final w = TextEditingController(text: '25');
  @override
  void dispose() {
    w.dispose();
    super.dispose();
  }

  Widget dd<T>(BuildContext c, T value, List<DropdownMenuItem<T>> items, ValueChanged<T?> on) {
    final p = palOf(c);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: p.inset(14),
      child: DropdownButtonHideUnderline(child: DropdownButton<T>(value: value, items: items, onChanged: on, isExpanded: true, dropdownColor: p.bg, style: TextStyle(color: p.tx))),
    );
  }

  @override
  Widget build(BuildContext c) {
    final s = AppScope.of(c);
    final l = s.lastBin;
    final cur = s.bins.where((b) => b.id == binId).firstOrNull ?? s.bins.firstOrNull;
    return Column(children: [
      NCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const H3('Bin Test'),
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange)),
            child: const Text('Simulation Mode: This is a test deposit. It will not award real points or generate real rewards.\nSIMULATED TEST — NOT A REAL DEPOSIT', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w700, fontSize: 12)),
          ),
          const Mut('Simulates a bin result after the waste is recognized. Remove in production.'),
          const SizedBox(height: 10),
          if (s.bins.isEmpty)
            const Mut('Add a bin first')
          else ...[
            dd<int>(c, cur!.id, [for (final b in s.bins) DropdownMenuItem(value: b.id, child: Text(b.name))], (v) => setState(() => binId = v)),
            const SizedBox(height: 10),
            dd<String>(c, item, const [
              DropdownMenuItem(value: 'rec', child: Text('Recyclable item')),
              DropdownMenuItem(value: 'non', child: Text('Non-biodegradable item')),
              DropdownMenuItem(value: 'bad', child: Text('Invalid waste')),
            ], (v) => setState(() => item = v!)),
            const SizedBox(height: 10),
            Row(children: [
              NInput(ctrl: w, type: TextInputType.number, width: 90),
              const SizedBox(width: 8),
              const Text('g'),
              const Spacer(),
              NBtn(primary: true, label: 'Drop item', onTap: () => s.binTest(cur, item, int.tryParse(w.text) ?? 0)),
            ]),
          ],
        ]),
      ),
      NCard(
        align: CrossAxisAlignment.center,
        child: Column(children: [
          const H3('Bin screen preview'),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 240, maxWidth: 320),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFF0B1510), borderRadius: BorderRadius.circular(12)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (l == null)
                const Text('Waiting for waste...', style: TextStyle(color: Colors.white))
              else ...[
                if (l.token != null) QrBox(l.token!, size: 150),
                const SizedBox(height: 8),
                Text(l.msg, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
                if (l.token != null) ...[
                  const SizedBox(height: 8),
                  // demo helper: copy the QR text so you can paste it on the Scan screen without a second device
                  NBtn(small: true, label: 'Copy QR text', onTap: () => copyText(c, l.token!, 'Reward QR copied')),
                ],
              ],
            ]),
          ),
        ]),
      ),
    ]);
  }
}

// ---- badges ----
class _AdminBadges extends StatefulWidget {
  const _AdminBadges();
  @override
  State<_AdminBadges> createState() => _AdminBadgesState();
}

class _AdminBadgesState extends State<_AdminBadges> {
  final n = TextEditingController(), m = TextEditingController();
  @override
  void dispose() {
    n.dispose();
    m.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final s = AppScope.of(c);
    return NCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const H3('Manage Badges'),
        const Mut("A badge is earned when a user's lifetime points reach its minimum. Spending points on vouchers never removes a badge."),
        const SizedBox(height: 10),
        NInput(ctrl: n, hint: 'Badge name'),
        const SizedBox(height: 10),
        NInput(ctrl: m, hint: 'Min points', type: TextInputType.number),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 10, children: [
          NBtn(
            primary: true,
            label: '+ Add Badge',
            onTap: () {
              final pts = (int.tryParse(m.text.trim()) ?? 0).clamp(0, 1000000);
              if (n.text.trim().isEmpty) return;
              s.addBadge(n.text, pts);
              n.clear();
              m.clear();
            },
          ),
        ]),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: .95,
          children: [for (final b in s.badges) _BadgeAdminTile(b, key: ValueKey(b.id))],
        ),
      ]),
    );
  }
}

class _BadgeAdminTile extends StatefulWidget {
  final BadgeItem b;
  const _BadgeAdminTile(this.b, {super.key});
  @override
  State<_BadgeAdminTile> createState() => _BadgeAdminTileState();
}

class _BadgeAdminTileState extends State<_BadgeAdminTile> {
  bool edit = false;
  late final n = TextEditingController(text: widget.b.name);
  late final i = TextEditingController(text: widget.b.icon);
  late final m = TextEditingController(text: '${widget.b.min}');
  @override
  void dispose() {
    n.dispose();
    i.dispose();
    m.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final p = palOf(c);
    final s = AppScope.of(c);
    final b = widget.b;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(18), boxShadow: p.raise),
      child: edit
          ? SingleChildScrollView(
              child: Column(children: [
                NInput(ctrl: n, hint: 'Name'),
                const SizedBox(height: 6),
                Row(children: [Expanded(child: NInput(ctrl: i, hint: 'Icon')), const SizedBox(width: 6), Expanded(child: NInput(ctrl: m, type: TextInputType.number, hint: 'Pts'))]),
                const SizedBox(height: 6),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  NBtn(
                    primary: true,
                    small: true,
                    label: 'Save',
                    onTap: () {
                      if (n.text.trim().isEmpty) return;
                      final pts = (int.tryParse(m.text.trim()) ?? 0).clamp(0, 1000000);
                      s.saveBadge(b, n.text.trim(), i.text.trim().isEmpty ? '🏆' : i.text.trim(), pts);
                      setState(() => edit = false);
                    },
                  ),
                  const SizedBox(width: 6),
                  NBtn(small: true, label: 'Cancel', onTap: () => setState(() => edit = false)),
                ]),
              ]),
            )
          : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(b.icon, style: const TextStyle(fontSize: 28)),
              Text(b.name, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
              Mut('${b.min} pts'),
              const SizedBox(height: 8),
              Wrap(spacing: 6, alignment: WrapAlignment.center, children: [NBtn(small: true, label: 'Edit', onTap: () => setState(() => edit = true)), DelBtn(onConfirm: () => s.deleteBadge(b))]),
            ]),
    );
  }
}

// ---- rewards ----
class _AdminRewards extends StatefulWidget {
  const _AdminRewards();
  @override
  State<_AdminRewards> createState() => _AdminRewardsState();
}

class _AdminRewardsState extends State<_AdminRewards> {
  final rateCtrl = TextEditingController();
  final minCtrl = TextEditingController();
  final maxCtrl = TextEditingController();
  final daysCtrl = TextEditingController();
  final titleCtrl = TextEditingController();
  final officeCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  final recCtrl = TextEditingController();
  final nonCtrl = TextEditingController();

  bool initialized = false;
  bool loading = false;
  String msg = '';
  bool isSuccess = false;
  bool confirmReset = false;

  @override
  void dispose() {
    for (final c in [rateCtrl, minCtrl, maxCtrl, daysCtrl, titleCtrl, officeCtrl, noteCtrl, recCtrl, nonCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  void initVals(AppState s) {
    if (initialized) return;
    rateCtrl.text = '${s.vc.rate}';
    minCtrl.text = '${s.vc.min}';
    maxCtrl.text = '${s.vc.max}';
    daysCtrl.text = '${s.vc.days}';
    titleCtrl.text = s.vc.title;
    officeCtrl.text = s.vc.office;
    noteCtrl.text = s.vc.note;
    recCtrl.text = '${s.pp['rec'] ?? 10}';
    nonCtrl.text = '${s.pp['non'] ?? 10}';
    initialized = true;
  }

  void save(AppState s) {
    setState(() {
      msg = '';
      loading = true;
    });

    final rate = int.tryParse(rateCtrl.text.trim()) ?? 0;
    final min = int.tryParse(minCtrl.text.trim()) ?? 0;
    final max = int.tryParse(maxCtrl.text.trim()) ?? 0;
    final days = int.tryParse(daysCtrl.text.trim()) ?? 0;
    final rec = int.tryParse(recCtrl.text.trim()) ?? 0;
    final non = int.tryParse(nonCtrl.text.trim()) ?? 0;

    if (rate <= 0 || rate > 100 || min <= 0 || min > 100 || max <= 0 || max > 100 || days <= 0 || days > 365 || rec <= 0 || rec > 1000 || non <= 0 || non > 1000) {
      setState(() {
        loading = false;
        isSuccess = false;
        msg = 'Error: Pesos must be 1–100, Rate 1–100, Days 1–365, Points/Item 1–1000.';
      });
      return;
    }
    if (max < min) {
      setState(() {
        loading = false;
        isSuccess = false;
        msg = 'Error: Maximum voucher value must be greater than or equal to minimum value.';
      });
      return;
    }

    Future(() async {
      s.update(() {
        s.vc.rate = rate;
        s.vc.min = min;
        s.vc.max = max;
        s.vc.days = days;
        s.vc.title = titleCtrl.text.trim();
        s.vc.office = officeCtrl.text.trim();
        s.vc.note = noteCtrl.text.trim();
        s.pp['rec'] = rec;
        s.pp['non'] = non;
      });
      final err = await s.pushSettings();
      if (!mounted) return;
      setState(() {
        loading = false;
        isSuccess = err == null;
        msg = err == null ? 'Changes saved successfully to the database!' : 'Error: $err';
      });
    });
  }

  void cancel(AppState s) {
    setState(() {
      initialized = false;
      msg = '';
      confirmReset = false;
    });
    initVals(s);
  }

  void resetDefaults(AppState s) {
    setState(() {
      loading = true;
      msg = '';
    });
    Future(() async {
      s.update(() {
        s.vc.rate = 10;
        s.vc.min = 1;
        s.vc.max = 100;
        s.vc.days = 3;
        s.vc.title = 'SmartBin Reward Voucher';
        s.vc.office = 'PSITS Office';
        s.vc.note = 'Present this voucher at the PSITS office to claim. One use only.';
        s.pp['rec'] = 10;
        s.pp['non'] = 10;
      });
      final err = await s.pushSettings();
      if (!mounted) return;
      setState(() {
        initialized = false;
        loading = false;
        isSuccess = err == null;
        confirmReset = false;
        msg = err == null ? 'Settings successfully reset to defaults!' : 'Error: $err';
      });
      initVals(s);
    });
  }

  @override
  Widget build(BuildContext c) {
    final s = AppScope.of(c);
    initVals(s);
    final vc = s.vc;
    const swatches = [0xFF1FA443, 0xFF2F6FE4, 0xFFE8873A, 0xFF8E5BD6, 0xFFE04B4B, 0xFF17A2A2];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (msg.isNotEmpty) Banner2(msg, bad: !isSuccess),
      if (loading) const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
      NCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const H3('Points per item'),
          labeled('Recyclable points', NInput(ctrl: recCtrl, type: TextInputType.number, width: 90, onChanged: (v) {
            final n = int.tryParse(v);
            if (n != null) s.update(() => s.pp['rec'] = n);
          })),
          const SizedBox(height: 10),
          labeled('Non-biodegradable points', NInput(ctrl: nonCtrl, type: TextInputType.number, width: 90, onChanged: (v) {
            final n = int.tryParse(v);
            if (n != null) s.update(() => s.pp['non'] = n);
          })),
        ]),
      ),
      NCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const H3('Customize voucher'),
          const Mut('Manage global voucher settings. Only authorized administrators can edit these values.'),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Voucher title'),
              const SizedBox(height: 4),
              NInput(ctrl: titleCtrl, onChanged: (v) => s.update(() => s.vc.title = v)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Claim at'),
              const SizedBox(height: 4),
              NInput(ctrl: officeCtrl, onChanged: (v) => s.update(() => s.vc.office = v)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Terms / message'),
              const SizedBox(height: 4),
              NInput(ctrl: noteCtrl, onChanged: (v) => s.update(() => s.vc.note = v)),
            ]),
          ),
          const Text('Header color'),
          const SizedBox(height: 6),
          Wrap(spacing: 10, children: [
            for (final col in swatches)
              GestureDetector(
                onTap: () => s.update(() => vc.colorHex = col),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Color(col), border: Border.all(color: vc.colorHex == col ? palOf(c).tx : Colors.transparent, width: 3)),
                ),
              ),
          ]),
          const SizedBox(height: 14),
          labeled('Points required per ₱1', NInput(ctrl: rateCtrl, type: TextInputType.number, width: 90, onChanged: (v) {
            final n = int.tryParse(v);
            if (n != null) s.update(() => s.vc.rate = n);
          })),
          const SizedBox(height: 10),
          labeled('Minimum voucher value (₱)', NInput(ctrl: minCtrl, type: TextInputType.number, width: 90, onChanged: (v) {
            final n = int.tryParse(v);
            if (n != null) s.update(() => s.vc.min = n);
          })),
          const SizedBox(height: 10),
          labeled('Maximum voucher value (₱)', NInput(ctrl: maxCtrl, type: TextInputType.number, width: 90, onChanged: (v) {
            final n = int.tryParse(v);
            if (n != null) s.update(() => s.vc.max = n);
          })),
          const SizedBox(height: 10),
          labeled('Voucher validity (days)', NInput(ctrl: daysCtrl, type: TextInputType.number, width: 90, onChanged: (v) {
            final n = int.tryParse(v);
            if (n != null) s.update(() => s.vc.days = n);
          })),
          const SizedBox(height: 18),
          Wrap(spacing: 10, runSpacing: 10, children: [
            NBtn(primary: true, label: 'Save Changes', onTap: loading ? null : () => save(s)),
            NBtn(label: 'Cancel', onTap: loading ? null : () => cancel(s)),
            if (!confirmReset)
              NBtn(danger: true, label: 'Reset to Defaults', onTap: loading ? null : () => setState(() => confirmReset = true))
            else
              NBtn(danger: true, label: 'Confirm Reset?', onTap: loading ? null : () => resetDefaults(s)),
          ]),
        ]),
      ),
      NCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const H3('Preview'),
          VoucherTicket(Voucher(code: 'SBV.PREVIEW', uName: 'Student Name', uid: '0000', pesos: 50, prices: kPrices, pts: 500, exp: DateTime.now().millisecondsSinceEpoch + vc.days * 86400000, date: '')),
        ]),
      ),
    ]);
  }
}
