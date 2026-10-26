import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../state/models.dart';
import '../theme/pal.dart';
import '../widgets/common.dart';
import 'admin_app.dart' show GateScreen, PortalLayout;
import 'user_app.dart' show QrScannerBox, boardCard;

String vSum(Voucher v) => v.req != null ? v.req!.text() : '${AppState.pgLine(v.pesos, v.prices)} pages';

class PsitsApp extends StatelessWidget {
  const PsitsApp({super.key});
  @override
  Widget build(BuildContext c) {
    final s = AppScope.of(c);
    if (!s.psitsIn) {
      return GateScreen(
        title: 'PSITS Dashboard',
        hint: 'Psits ID',
        defaultUser: s.savedPsitsId,
        defaultPw: s.savedPsitsPw,
        defaultRemember: s.rememberPsits,
        onLogin: (id, pw, remember) => s.staffLogin(id, pw, admin: false, remember: remember),
      );
    }
    Widget body;
    switch (s.p) {
      case 'vou': body = const _PsVouchers(); break;
      case 'log': body = const _PsLogs(); break;
      case 'usr': body = const _PsUsers(); break;
      case 'scan': body = const _PsScanner(); break;
      case 'rules': body = rulesCard(s); break;
      default: body = const _PsDash();
    }
    return PortalLayout(
      current: s.p,
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
        child: Image.asset('assets/images/psits.webp', height: 44, fit: BoxFit.contain),
      ),
      tabs: const [['dash', '📊 Dashboard'], ['vou', '🎟 Vouchers'], ['log', '🧾 Logs'], ['usr', '👥 Users'], ['scan', '▣ Scanner'], ['rules', '📜 Rules']],
      onTab: (k) => s.update(() => s.p = k),
      onLogout: s.logoutPsits,
      body: body,
    );
  }
}

class _PsDash extends StatelessWidget {
  const _PsDash();
  @override
  Widget build(BuildContext c) {
    final s = AppScope.of(c);
    final pend = s.vl.where((v) => v.state == 'Active').toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      StatRow([StatTile('Students', '${s.users.length}'), StatTile('Pending vouchers', '${pend.length}'), StatTile('Claimed', '${s.vl.where((v) => v.status == 'Claimed').length}')]),
      NCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const H3('Waiting to be claimed'),
          if (pend.isEmpty) const Mut('No vouchers waiting') else for (final v in pend.take(5)) NRow(left: Text('${v.shortCode} · ${v.uName}'), right: Text('₱${v.pesos} printing')),
        ]),
      ),
      StatRow([StatTile('Voucher logs', '${s.log.length}'), StatTile('Rejected waste', '${s.rej}')]),
      NCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const H3('Items by weekday'), WeekBars(s.week)])),
      boardCard(s),
    ]);
  }
}

class _PsVouchers extends StatelessWidget {
  const _PsVouchers();
  @override
  Widget build(BuildContext c) {
    final s = AppScope.of(c);
    final vc = s.vc;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      rulesCard(s),
      NCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const H3('Printing voucher settings (Read-Only)'),
          const Mut('Configured by administrator in the Admin Portal.'),
          const SizedBox(height: 8),
          kv('Points per ₱1', '${vc.rate} pts'),
          kv('Minimum voucher value', '₱${vc.min}'),
          kv('Maximum voucher value', '₱${vc.max}'),
          kv('Voucher validity', '${vc.days} days'),
          const SizedBox(height: 6),
          Mut('Example: ₱50 prints ${AppState.pgLine(50, kPrices)} pages'),
        ]),
      ),
      NCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const H3('Issued Vouchers'),
          const Mut('Vouchers can only be claimed by scanning the voucher QR of the student in the Scanner tab.'),
          const SizedBox(height: 8),
          if (s.vl.isEmpty)
            const Mut('No vouchers issued yet')
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 36,
                columns: const [DataColumn(label: Text('Code')), DataColumn(label: Text('Student')), DataColumn(label: Text('Amount')), DataColumn(label: Text('Status')), DataColumn(label: Text('Expires')), DataColumn(label: Text('Printed'))],
                rows: [
                  for (final v in s.vl)
                    DataRow(cells: [
                      DataCell(Text(v.shortCode)),
                      DataCell(Text(v.uName)),
                      DataCell(Text('₱${v.pesos} printing')),
                      DataCell(Text(v.state)),
                      DataCell(Text(dateStr(v.exp))),
                      DataCell(Text(v.printed != null ? '${v.printed!.text()} · ₱${v.cost}' : '')),
                    ]),
                ],
              ),
            ),
        ]),
      ),
    ]);
  }
}

class _PsLogs extends StatelessWidget {
  const _PsLogs();
  @override
  Widget build(BuildContext c) {
    final s = AppScope.of(c);
    final csv = 'user,voucher,date\n${s.log.map((l) => [l.user, l.voucher, l.date].join(',')).join('\n')}';
    return NCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const H3('Redemption Logs'),
        Wrap(spacing: 10, runSpacing: 10, children: [
          NBtn(small: true, label: 'Export CSV', onTap: () => copyText(c, csv, 'CSV copied to clipboard')),
          DelBtn(label: 'Clear all', onConfirm: s.clearLog),
        ]),
        const SizedBox(height: 8),
        if (s.log.isEmpty) const Mut('No logs yet'),
        for (final l in s.log.toList())
          NRow(
            left: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Bold(l.user), Text(l.voucher), Mut(l.date)]),
            right: DelBtn(onConfirm: () => s.deleteLog(l)),
          ),
      ]),
    );
  }
}

class _PsUsers extends StatefulWidget {
  const _PsUsers();
  @override
  State<_PsUsers> createState() => _PsUsersState();
}

class _PsUsersState extends State<_PsUsers> {
  String q = '';
  @override
  Widget build(BuildContext c) {
    final s = AppScope.of(c);
    final l = s.users.where((u) => q.isEmpty || '${u.name} ${u.id}'.toLowerCase().contains(q.toLowerCase())).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      NCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const H3('Users'),
          NRow(left: NInput(hint: 'Search name or ID', onChanged: (v) => setState(() => q = v)), right: Mut('${l.length} of ${s.users.length}'), border: false),
        ]),
      ),
      NCard(
        child: l.isEmpty
            ? const Mut('No users')
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowHeight: 36,
                  columns: const [DataColumn(label: Text('Name')), DataColumn(label: Text('Student ID')), DataColumn(label: Text('Points'))],
                  rows: [for (final u in l) DataRow(cells: [DataCell(Text(u.name)), DataCell(Text(u.id)), DataCell(Text('${u.points}'))])],
                ),
              ),
      ),
    ]);
  }
}

class _PsScanner extends StatefulWidget {
  const _PsScanner();
  @override
  State<_PsScanner> createState() => _PsScannerState();
}

class _PsScannerState extends State<_PsScanner> {
  String? code;
  VerifyRes? vr;
  Pages cp = Pages();
  String? cpCode;
  bool busy = false;
  final manual = TextEditingController();
  @override
  void dispose() {
    manual.dispose();
    super.dispose();
  }

  Future<void> handle(AppState s, String raw) async {
    if (vr != null || busy) return;
    busy = true;
    final c = raw.trim();
    final r = await s.verify(c);
    busy = false;
    if (!mounted) return;
    setState(() {
      code = c;
      vr = r;
    });
  }

  void reset() => setState(() {
        vr = null;
        code = null;
        cpCode = null;
      });

  @override
  Widget build(BuildContext c) {
    final s = AppScope.of(c);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      NCard(

        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const H3('QR Scanner'),
          if (vr == null) ...[
            QrScannerBox(onCode: (v) => handle(s, v), height: 260),
            const SizedBox(height: 10),
            NInput(ctrl: manual, hint: 'or paste voucher QR text', onSubmitted: (v) => handle(s, manual.text)),
            const SizedBox(height: 10),
            NBtn(label: 'Verify code', onTap: () => handle(s, manual.text)),
            const SizedBox(height: 8),
            const Mut('Scan the voucher QR shown by the student.'),
          ] else
            NBtn(primary: true, label: 'Scan another', onTap: reset),
        ]),
      ),
      if (vr != null) _result(c, s, vr!),
    ]);
  }

  Widget _result(BuildContext c, AppState s, VerifyRes r) {
    if (r.error != null) return Banner2(r.error!, bad: true);
    final v = r.v;
    final p = s.pal;
    if (v != null && cpCode != v.code) {
      cp = v.req?.copy() ?? Pages();
      cpCode = v.code;
    }
    final usr = s.users.where((x) => x.id == r.id).firstOrNull;
    final genderIcon = usr?.gender == 'Girl' ? '👧' : usr?.gender == 'Boy' ? '👦' : '';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Banner2(r.label, bad: !r.ok),
      NCard(child: Column(children: [
        kv('Student', '$genderIcon ${r.name}'),
        kv('School ID Center No.', r.id),
        if (usr != null && usr.gender.isNotEmpty) kv('Gender', usr.gender),
        kv('Value', '${r.lab}${v != null && v.pesos > 0 ? ' · ${vSum(v)}' : ''}'),
        kv('Expires', '${dateStr(r.exp)}'),
        kv('Code', r.code.length > 4 ? r.code.substring(4) : r.code),
        if (v?.claimedOn != null) kv('Claimed on', v!.claimedOn!),
      ])),
      if (v?.printed != null)
        NCard(child: Column(children: [
          kv('Printed', '${v!.printed!.text()} · ₱${v.cost}'),
          if ((v.cash ?? 0) > 0) kv('Paid in cash', '₱${v.cash}'),
        ])),
      if (r.ok && v != null) ...[
        NCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Bold('Check before claiming'),
            Steps([
              'Status is Active (now: ${v.state})',
              'Not expired (expires ${dateStr(v.exp)})',
              'Student ID matches ${v.uid} (${v.uName})',
              v.req != null ? 'Print: ${v.req!.text()} (₱${v.pesos})' : 'Allow printing up to ₱${v.pesos} (${AppState.priceText(v.prices)})',
              'Add the pages to print below, then confirm',
            ]),
          ]),
        ),
        _claimPanel(c, s, v, p),
      ],
    ]);
  }

  Widget _claimPanel(BuildContext c, AppState s, Voucher v, Pal p) {
    final r = v.prices;
    final t = cp.total(r);
    final left = v.pesos - t;
    final good = t > 0;
    return NCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Bold('Pages to print'),
        Mut('Add how many pages the student wants. Anything over the voucher value (₱${v.pesos}) is paid in cash by the student.'),
        for (final x in [['bw', 'B&W page'], ['col', 'Colored page'], ['pic', 'Picture page']])
          NRow(
            left: Row(children: [Text(x[1]), const SizedBox(width: 6), Mut('₱${r.of(x[0])}')]),
            right: Row(mainAxisSize: MainAxisSize.min, children: [
              NBtn(small: true, label: '−', onTap: () => setState(() => cp.set(x[0], (cp.get(x[0]) - 1).clamp(0, 99).toInt()))),
              SizedBox(width: 34, child: Text('${cp.get(x[0])}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700))),
              NBtn(small: true, label: '+', onTap: () => setState(() => cp.set(x[0], (cp.get(x[0]) + 1).clamp(0, 99).toInt()))),
            ]),
          ),
        kv('Printing total', '₱$t'),
        kv('Voucher value', '₱${v.pesos}'),
        kv('Free credit used', '₱${t < v.pesos ? t : v.pesos}'),
        kv(left < 0 ? 'Student pays in cash' : 'Left (not refunded)', '₱${left.abs()}', color: left < 0 ? Pal.red : null),
        const SizedBox(height: 10),
        NBtn(
          primary: true,
          expand: true,
          label: left < 0 ? 'Collect ₱${-left} cash, print & mark as claimed' : 'Confirm print & mark as claimed',
          onTap: good
              ? () async {
                  final err = await s.claim(v, cp);
                  if (err != null) s.toast(err);
                  final r = await s.verify(code!);
                  if (!mounted) return;
                  setState(() {
                    cpCode = null;
                    vr = r;
                  });
                }
              : null,
        ),
      ]),
    );
  }
}
