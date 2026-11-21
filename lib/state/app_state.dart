import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/pal.dart';
import 'models.dart';

enum Portal { user, admin, psits }

const kCN = {'rec': '♻ Recyclable', 'non': '🚫 Non-biodegradable'};
const kPrices = Prices(bw: 3, col: 4, pic: 5);

/// Lets AppState show SnackBars (server errors) without needing a BuildContext.
final messengerKey = GlobalKey<ScaffoldMessengerState>();

SupabaseClient get _db => Supabase.instance.client;

/// Supabase Auth needs an email, and it REJECTS made-up domains (it checks that the
/// domain can receive mail), so '123@smartbin.app' never creates a user.
/// Fix: every Student ID becomes a "plus address" on ONE real mailbox you own:
///     <kAuthMailbox>+<student id>@<kAuthDomain>
/// e.g. kAuthMailbox = 'juan.smartbin'  ->  juan.smartbin+20240001@gmail.com
/// Each student is still a separate Supabase user, and no email is ever sent
/// (keep "Confirm email" OFF). Use lowercase letters only.
const kAuthMailbox = 'smartbinapp'; // <-- CHANGE: the part before @gmail.com
const kAuthDomain = 'gmail.com';
String _email(String studentId) => '$kAuthMailbox+${studentId.trim().toLowerCase()}@$kAuthDomain';

const _netErr = 'Could not reach the server. Check your internet connection.';

String _two(int n) => n.toString().padLeft(2, '0');
String _fmtDate(DateTime d) => '${d.month}/${d.day}/${d.year} ${_two(d.hour)}:${_two(d.minute)}';
String nowStr() => _fmtDate(DateTime.now());
String _fmt(dynamic iso) {
  final d = DateTime.tryParse('$iso');
  return d == null ? '' : _fmtDate(d.toLocal());
}

int _ms(dynamic iso) => (DateTime.tryParse('$iso') ?? DateTime.now()).millisecondsSinceEpoch;
int _int(dynamic v, [int d = 0]) => v is num ? v.toInt() : (int.tryParse('$v') ?? d);

String dateStr(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.month}/${d.day}/${d.year}';
}

class AppState extends ChangeNotifier {
  AppState() {
    _restore();
  }

  Timer? _poll;
  RealtimeChannel? _channel;
  @override
  void dispose() {
    _poll?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }

  void _initRealtime() {
    try {
      _channel?.unsubscribe();
      _channel = _db.channel('public:smartbin_realtime')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          callback: (payload) {
            _safeRefresh();
          },
        )
        .subscribe();
    } catch (_) {}
  }

  // ---- global ----
  bool dark = false;
  Portal portal = Portal.user;
  String fs = 'n'; // s n l x
  String lang = 'en'; // en fil hil
  double get textScale => {'s': .86, 'n': 1.0, 'l': 1.14, 'x': 1.3}[fs]!;
  Pal get pal => Pal(dark: dark, psits: portal == Portal.psits);

  void update(void Function() f) {
    f();
    notifyListeners();
  }

  void toggleTheme() => update(() => dark = !dark);
  void setPortal(Portal p) => update(() {
        portal = p;
      });

  void toast(String m) {
    messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  // ---- data (all of it is loaded from Supabase) ----
  final List<UserAcct> users = [];
  final List<Bin> bins = [];
  final List<BadgeItem> badges = [];
  final List<Voucher> vl = [];
  final List<Activity> act = [];
  final List<LogEntry> log = [];
  final List<BinEvent> ev = [];
  final List<({String nonce, String uid})> used = [];
  final VoucherCfg vc = VoucherCfg();
  final Map<String, int> pp = {'rec': 10, 'non': 10};
  final List<int> week = List.filled(7, 0);
  int rej = 0;
  BinEvent? lastBin;
  final Map<String, String> _idByUuid = {}; // profile uuid -> student id

  // ---- auth & remember me ----
  UserAcct? me;
  String role = 'user'; // user | admin | psits
  bool adminIn = false, psitsIn = false;
  bool splash = true;
  String authErr = '';

  bool rememberUser = false;
  bool rememberAdmin = false;
  bool rememberPsits = false;
  String savedUserId = '';
  String savedUserPw = '';
  String savedAdminId = '';
  String savedAdminPw = '';
  String savedPsitsId = '';
  String savedPsitsPw = '';

  UserAcct get cur => me ?? UserAcct(name: '', id: '');
  int get pts => cur.points;

  // ---- user navigation ----
  String u = 'home';
  String bk = 'home';
  String lb = 'p'; // leaderboard p | i
  void goU(String v) => update(() {
        bk = u == 'prof' ? 'prof' : 'home';
        u = v;
      });
  void goBack(String to) => update(() => u = to);

  // ---- admin / psits tabs ----
  String a = 'dash';
  String p = 'dash';

  // ---- translations ----
  static const _tr = {
    'en': {'prof': 'My Profile', 'info': 'Personal Information', 'act': 'Activity History', 'badges': 'My Badges', 'how': 'How It Works', 'about': 'About SmartBin', 'help': 'Help & Support', 'priv': 'Privacy & Terms', 'pw': 'Change Password', 'fs': 'Text Size', 'lang': 'Language', 'out': 'Logout', 'close': 'Close', 'np': 'New password', 'cp': 'Confirm new password', 'upd': 'Update Password'},
    'fil': {'prof': 'Aking Profile', 'info': 'Personal na Impormasyon', 'act': 'Kasaysayan ng Aktibidad', 'badges': 'Aking mga Badge', 'how': 'Paano Ito Gumagana', 'about': 'Tungkol sa SmartBin', 'help': 'Tulong at Suporta', 'priv': 'Privacy at Mga Tuntunin', 'pw': 'Palitan ang Password', 'fs': 'Laki ng Teksto', 'lang': 'Wika', 'out': 'Mag-logout', 'close': 'Isara', 'np': 'Bagong password', 'cp': 'Kumpirmahin ang bagong password', 'upd': 'I-update ang Password'},
    'hil': {'prof': 'Akon Profile', 'info': 'Personal nga Impormasyon', 'act': 'Kasaysayan sang Aktibidad', 'badges': 'Akon nga mga Badge', 'how': 'Paano Ini Nagatrabaho', 'about': 'Parte sa SmartBin', 'help': 'Bulig kag Suporta', 'priv': 'Privacy kag Mga Termino', 'pw': 'Ilisan ang Password', 'fs': 'Kadako sang Teksto', 'lang': 'Pinulongan', 'out': 'Mag-logout', 'close': 'Isara', 'np': 'Bag-o nga password', 'cp': 'Kumpirmaha ang bag-o nga password', 'upd': 'I-update ang Password'},
  };
  String tt(String k) => _tr[lang]?[k] ?? _tr['en']![k] ?? k;

  // =====================================================================
  //  Loading from Supabase & Persistence
  // =====================================================================

  /// Called once at start-up: start all portals logged out.
  Future<void> _restore() async {
    try {
      // Ensure all 3 portals start logged out when you first open the app
      splash = true;
      adminIn = false;
      psitsIn = false;
      me = null;
      try {
        await _db.auth.signOut();
      } catch (_) {}
    } catch (_) {}
    notifyListeners();
  }

  void _startPoll() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 20), (_) {
      if (_db.auth.currentUser != null || adminIn || psitsIn) _safeRefresh();
    });
    _initRealtime();
  }

  Future<void> _safeRefresh() async {
    try {
      await refresh();
    } catch (_) {}
  }

  bool _refreshing = false, _again = false;

  /// Re-reads everything the signed-in account is allowed to see.
  Future<void> refresh() async {
    if (_db.auth.currentUser == null && !adminIn && !psitsIn) return;
    if (_refreshing) {
      _again = true;
      return;
    }
    _refreshing = true;
    try {
      do {
        _again = false;
        await _load();
      } while (_again);
    } finally {
      _refreshing = false;
    }
  }

  UserAcct _acct(Map<String, dynamic> m) => UserAcct(
        name: '${m['name']}',
        id: '${m['student_id']}',
        gender: '${m['gender'] ?? ''}',
        points: _int(m['points']),
        life: _int(m['lifetime_points']),
        items: _int(m['items']),
      )..uuid = '${m['id']}';

  Future<void> _load() async {
    final au = _db.auth.currentUser;
    if (au != null) {
      try {
        final row = await _db.from('profiles').select().eq('id', au.id).maybeSingle();
        if (row != null) {
          role = '${row['role']}';
          final mine = _acct(row);
          me = mine;
          _idByUuid[mine.uuid!] = mine.id;
          if (role == 'admin') adminIn = true;
          if (role == 'admin' || role == 'psits') psitsIn = true;
        }
      } catch (_) {}
    }

    final isStaff = adminIn || psitsIn || role == 'admin' || role == 'psits';

    await Future.wait<void>([_loadSettings(), _loadBins(), _loadBadges()]);

    if (isStaff) {
      await _loadStaff();
    } else if (me != null) {
      await _loadStudent(me!);
    }
    notifyListeners();
  }

  Future<void> _loadSettings() async {
    final rows = await _db.from('settings').select();
    final m = {for (final r in rows) '${r['key']}': r['value']};
    String t(String k, String d) => m[k] is String ? m[k] as String : d;
    vc.rate = _int(m['voucher_rate'], 10);
    vc.min = _int(m['voucher_min'], 1);
    vc.max = _int(m['voucher_max'], 100);
    vc.days = _int(m['voucher_days'], 3);
    vc.title = t('voucher_title', 'SmartBin Reward Voucher');
    vc.office = t('voucher_office', 'PSITS Office');
    vc.note = t('voucher_note', 'Present this voucher at the PSITS office to claim. One use only.');
    vc.colorHex = int.tryParse(t('voucher_color', '0xFF1FA443')) ?? 0xFF1FA443;
    pp['rec'] = _int(m['points_rec'], 10);
    pp['non'] = _int(m['points_non'], 10);
  }

  Future<void> _loadBins() async {
    final rows = await _db.from('bins').select('*, bin_compartments(*)').order('id');
    bins.clear();
    for (final r in rows) {
      final cs = ((r['bin_compartments'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      Comp mk(String k) {
        final c = cs.where((x) => x['kind'] == k).firstOrNull;
        return Comp(k, fill: _int(c?['fill']), alert: _int(c?['alert_at'], 80));
      }

      bins.add(Bin(_int(r['id']), '${r['name']}', '${r['location']}', on: r['is_on'] == true, comps: [mk('rec'), mk('non')]));
    }
  }

  Future<void> _loadBadges() async {
    final rows = await _db.from('badges').select().order('min_points');
    badges
      ..clear()
      ..addAll(rows.map((r) => BadgeItem(_int(r['id']), '${r['name']}', '${r['icon']}', _int(r['min_points']))));
  }

  void _setAct(List<dynamic> rows) {
    act
      ..clear()
      ..addAll(rows.map((r) => Activity(_idByUuid['${r['user_id']}'] ?? '', '${r['title']}', _int(r['points']), _fmt(r['created_at']), _ms(r['created_at']))));
  }

  Future<void> _loadStudent(UserAcct mine) async {
    final acts = await _db.from('activity').select().eq('user_id', mine.uuid!).order('created_at', ascending: false).limit(200);
    _setAct(acts);
    final vs = await _db.from('vouchers').select().eq('user_id', mine.uuid!).order('issued_at', ascending: false).limit(100);
    vl
      ..clear()
      ..addAll(vs.map(_voucher));

    // Leaderboard: the server only exposes name + score, never other users' rows.
    final byPts = (await _db.rpc('get_leaderboard', params: {'p_kind': 'p', 'p_limit': 100})) as List;
    final byItems = (await _db.rpc('get_leaderboard', params: {'p_kind': 'i', 'p_limit': 100})) as List;
    final m = <String, UserAcct>{};
    for (final r in byPts) {
      final x = m.putIfAbsent('${r['student_id']}', () => UserAcct(name: '${r['name']}', id: '${r['student_id']}'));
      x.life = _int(r['value']);
    }
    for (final r in byItems) {
      final x = m.putIfAbsent('${r['student_id']}', () => UserAcct(name: '${r['name']}', id: '${r['student_id']}'));
      x.items = _int(r['value']);
    }
    m[mine.id] = mine;
    users
      ..clear()
      ..addAll(m.values);

    // "my deposits per weekday, last 7 days"
    week.fillRange(0, 7, 0);
    final since = DateTime.now().millisecondsSinceEpoch - 7 * 86400000;
    for (final x in act) {
      if (x.pts > 0 && x.ts >= since && x.title.startsWith('Deposited')) {
        week[DateTime.fromMillisecondsSinceEpoch(x.ts).weekday % 7]++;
      }
    }
    log.clear();
    ev.clear();
    used.clear();
    rej = 0;
  }

  Future<void> _loadStaff() async {
    final ps = await _db.from('profiles').select().order('created_at');
    users.clear();
    for (final r in ps) {
      _idByUuid['${r['id']}'] = '${r['student_id']}';
      if (r['role'] == 'user') users.add(_acct(r));
    }
    final acts = await _db.from('activity').select().order('created_at', ascending: false).limit(500);
    _setAct(acts);
    final vs = await _db.from('vouchers').select().order('issued_at', ascending: false).limit(500);
    vl
      ..clear()
      ..addAll(vs.map(_voucher));
    final lg = await _db.from('voucher_log').select().order('created_at', ascending: false).limit(500);
    log
      ..clear()
      ..addAll(lg.map((r) => LogEntry('${r['user_name']}', '${r['voucher']}', _fmt(r['created_at']), id: _int(r['id']))));
    final evs = await _db.from('bin_events').select().order('created_at', ascending: false).limit(100);
    ev
      ..clear()
      ..addAll(evs.map((r) => BinEvent('${r['type']}', '${r['message']}', '${r['bin_name']}', _int(r['weight']), _fmt(r['created_at']), nonce: r['token_id']?.toString())));
    final tk = await _db.from('deposit_tokens').select('id, used_by').not('used_by', 'is', null).limit(500);
    used
      ..clear()
      ..addAll(tk.map((r) => (nonce: '${r['id']}', uid: _idByUuid['${r['used_by']}'] ?? '')));  // 'nonce' holds the token id here

    final st = await _db.rpc('dashboard_stats');
    rej = st is Map ? _int(st['rejected']) : 0;
    final wk = (await _db.rpc('weekly_deposits')) as List;
    week.fillRange(0, 7, 0);
    for (final r in wk) {
      final d = _int(r['dow']);
      if (d >= 0 && d < 7) week[d] = _int(r['total']);
    }
  }

  Voucher _voucher(Map<String, dynamic> r) {
    int n(String k) => _int(r[k]);
    final hasReq = r['req_bw'] != null || r['req_col'] != null || r['req_pic'] != null;
    final v = Voucher(
      code: '${r['code']}',
      uName: '${r['user_name']}',
      uid: '${r['student_id']}',
      pesos: n('pesos'),
      prices: Prices(bw: n('price_bw'), col: n('price_col'), pic: n('price_pic')),
      pts: n('points_cost'),
      exp: _ms(r['expires_at']),
      date: _fmt(r['issued_at']),
      status: '${r['status']}',
      req: hasReq ? Pages(bw: n('req_bw'), col: n('req_col'), pic: n('req_pic')) : null,
    );
    v.qr = v.code; // the QR is just the voucher code; PSITS looks it up on the server
    if (r['claimed_at'] != null) {
      v.claimedOn = _fmt(r['claimed_at']);
      v.printed = Pages(bw: n('printed_bw'), col: n('printed_col'), pic: n('printed_pic'));
      v.cost = n('cost');
      v.cash = n('cash');
    }
    return v;
  }

  Future<T?> _run<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on PostgrestException catch (e) {
      toast(e.message);
    } on AuthException catch (e) {
      toast(e.message);
    } catch (_) {
      toast(_netErr);
    }
    return null;
  }

  void _clearData() {
    me = null;
    role = 'user';
    adminIn = false;
    psitsIn = false;
    for (final l in [users, bins, badges, vl, act, log, ev, used]) {
      l.clear();
    }
    week.fillRange(0, 7, 0);
    rej = 0;
    lastBin = null;
    _idByUuid.clear();
  }

  // =====================================================================
  //  Auth & Portal Sessions
  // =====================================================================
  Future<String?> login(String id, String pw, {bool remember = true}) async {
    id = id.trim();
    if (id.isEmpty || pw.isEmpty) return 'Invalid Student ID or password';
    try {
      await _db.auth.signInWithPassword(email: _email(id), password: pw);
    } on AuthException catch (e) {
      return e.message.toLowerCase().contains('confirm') ? 'This account is not confirmed yet. Please contact the administrator.' : 'Invalid Student ID or password';
    } catch (_) {
      return _netErr;
    }
    try {
      await refresh();
    } catch (_) {
      return _netErr;
    }
    if (me == null) {
      await _db.auth.signOut();
      return 'Account profile not found. Please contact the administrator.';
    }

    rememberUser = remember;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remember_user', remember);
      if (remember) {
        savedUserId = id;
        savedUserPw = pw;
        await prefs.setString('saved_user_id', id);
        await prefs.setString('saved_user_pw', pw);
      } else {
        savedUserId = '';
        savedUserPw = '';
        await prefs.remove('saved_user_id');
        await prefs.remove('saved_user_pw');
      }
    } catch (_) {}

    _startPoll();
    update(() {
      authErr = '';
      u = 'home';
      splash = false;
    });
    return null;
  }

  String? _pwProblem(String n, String id, String gender, String pw, String q) {
    if (n.isEmpty || id.isEmpty || gender.isEmpty || pw.isEmpty) {
      return 'Please fill in all required fields and select gender';
    }
    if (!RegExp(r'^\d+$').hasMatch(id)) return 'School ID center number must contain numbers only';
    final (strength, msg) = evaluatePassword(pw);
    if (strength != PasswordStrength.strong) return msg;
    if (pw != q) return 'Passwords do not match';
    return null;
  }

  Future<String?> register(String n, String id, String gender, String pw, String q) async {
    n = n.trim();
    id = id.trim();
    final m = _pwProblem(n, id, gender, pw, q) ?? (pw != q ? 'Passwords do not match' : null);
    if (m != null) return m;
    try {
      final r = await _db.auth.signUp(
        email: _email(id),
        password: pw,
        data: {'name': n, 'student_id': id, 'gender': gender},
      );
      if (r.user == null) {
        return 'Sign-up did not create an account. In Supabase open Authentication > Sign In / Providers and make sure Email is enabled.';
      }
      // The UI sends the student to the login screen next, so don't stay signed in.
      if (r.session != null) await _db.auth.signOut();
    } on AuthException catch (e) {
      debugPrint('register AuthException: ${e.message}');
      final t = e.message.toLowerCase();
      if (t.contains('already')) return 'This School ID center number is already registered';
      return e.message; // the real reason from Supabase (invalid email, signups disabled, ...)
    } on PostgrestException catch (e) {
      debugPrint('register PostgrestException: ${e.message}');
      return 'Database error: ${e.message}';
    } catch (e) {
      debugPrint('register failed: $e');
      return 'Could not register: $e';
    }
    return null;
  }

  /// Admin / PSITS gate. Uses the same accounts as students; the `role`
  /// column in `profiles` decides who may enter.
  Future<String?> staffLogin(String id, String pw, {required bool admin, bool remember = true}) async {
    id = id.trim();
    if (id.isEmpty || pw.isEmpty) return 'Enter your ID and password';

    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {}

    // Direct fallback credentials for testing / development
    if (admin) {
      if (id.toLowerCase() == 'psits01') {
        return 'Unauthorized: PSITS staff cannot access the Admin portal.';
      }
      if (id.toLowerCase() == 'pob-blnts25' && pw == 'SB@2025') {
        adminIn = true;
        role = 'admin';
        me = me ?? UserAcct(name: 'Administrator', id: 'POB-BLNTS25', gender: 'Boy', points: 9999);
        rememberAdmin = remember;
        try {
          if (prefs != null) {
            await prefs.setBool('remember_admin', remember);
            if (remember) {
              savedAdminId = id;
              savedAdminPw = pw;
              await prefs.setString('saved_admin_id', id);
              await prefs.setString('saved_admin_pw', pw);
            } else {
              savedAdminId = '';
              savedAdminPw = '';
              await prefs.remove('saved_admin_id');
              await prefs.remove('saved_admin_pw');
            }
          }
        } catch (_) {}
        update(() {
          authErr = '';
          a = 'dash';
          portal = Portal.admin;
        });
        return null;
      }
    } else {
      if (id.toLowerCase() == 'pob-blnts25') {
        return 'Please use the Admin portal for Administrator credentials.';
      }
      if (id.toLowerCase() == 'psits01' && pw == 'PSITS@2025') {
        psitsIn = true;
        role = 'psits';
        me = me ?? UserAcct(name: 'PSITS Staff', id: 'Psits01', gender: 'Girl', points: 9999);
        rememberPsits = remember;
        try {
          if (prefs != null) {
            await prefs.setBool('remember_psits', remember);
            if (remember) {
              savedPsitsId = id;
              savedPsitsPw = pw;
              await prefs.setString('saved_psits_id', id);
              await prefs.setString('saved_psits_pw', pw);
            } else {
              savedPsitsId = '';
              savedPsitsPw = '';
              await prefs.remove('saved_psits_id');
              await prefs.remove('saved_psits_pw');
            }
          }
        } catch (_) {}
        update(() {
          authErr = '';
          p = 'dash';
          portal = Portal.psits;
        });
        return null;
      }
    }

    try {
      await _db.auth.signInWithPassword(email: _email(id), password: pw);
      await refresh();
    } on AuthException {
      return 'Invalid username or password';
    } catch (_) {
      return _netErr;
    }

    if (admin && role != 'admin') {
      await logoutAdmin();
      return 'Only authorized administrators can access the Admin portal.';
    }
    if (!admin && role != 'psits' && role != 'admin') {
      await logoutPsits();
      return 'Only authorized PSITS personnel can access the PSITS portal.';
    }

    if (admin) {
      adminIn = true;
      rememberAdmin = remember;
      try {
        if (prefs != null) {
          await prefs.setBool('remember_admin', remember);
          if (remember) {
            savedAdminId = id;
            savedAdminPw = pw;
            await prefs.setString('saved_admin_id', id);
            await prefs.setString('saved_admin_pw', pw);
          } else {
            savedAdminId = '';
            savedAdminPw = '';
            await prefs.remove('saved_admin_id');
            await prefs.remove('saved_admin_pw');
          }
        }
      } catch (_) {}
      update(() {
        authErr = '';
        a = 'dash';
        portal = Portal.admin;
      });
    } else {
      psitsIn = true;
      rememberPsits = remember;
      try {
        if (prefs != null) {
          await prefs.setBool('remember_psits', remember);
          if (remember) {
            savedPsitsId = id;
            savedPsitsPw = pw;
            await prefs.setString('saved_psits_id', id);
            await prefs.setString('saved_psits_pw', pw);
          } else {
            savedPsitsId = '';
            savedPsitsPw = '';
            await prefs.remove('saved_psits_id');
            await prefs.remove('saved_psits_pw');
          }
        }
      } catch (_) {}
      update(() {
        authErr = '';
        p = 'dash';
        portal = Portal.psits;
      });
    }

    _startPoll();
    notifyListeners();
    return null;
  }

  Future<void> logoutUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      savedUserId = '';
      savedUserPw = '';
      await prefs.remove('saved_user_id');
      await prefs.remove('saved_user_pw');
      await prefs.setBool('remember_user', false);
    } catch (_) {}

    if (!adminIn && !psitsIn) {
      _poll?.cancel();
      try {
        await _db.auth.signOut();
      } catch (_) {}
    }

    update(() {
      _clearData();
      splash = true;
      u = 'home';
    });
  }

  Future<void> logoutAdmin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      savedAdminId = '';
      savedAdminPw = '';
      await prefs.remove('saved_admin_id');
      await prefs.remove('saved_admin_pw');
      await prefs.setBool('remember_admin', false);
    } catch (_) {}

    update(() {
      adminIn = false;
      a = 'dash';
    });
  }

  Future<void> logoutPsits() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      savedPsitsId = '';
      savedPsitsPw = '';
      await prefs.remove('saved_psits_id');
      await prefs.remove('saved_psits_pw');
      await prefs.setBool('remember_psits', false);
    } catch (_) {}

    update(() {
      psitsIn = false;
      p = 'dash';
    });
  }

  Future<String?> changePassword(String a, String b) async {
    if (a.length < 6) return 'Password must be at least 6 characters';
    if (a != b) return 'Passwords do not match';
    try {
      await _db.auth.updateUser(UserAttributes(password: a));
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return _netErr;
    }
    return null;
  }

  // ---- derived ----
  List<Activity> mine() => act.where((x) => x.uid == me?.id).toList();
  int ptsSince(int t) => mine().fold(0, (s, x) => s + (x.pts > 0 && x.ts >= t ? x.pts : 0));
  List<({UserAcct u, int v})> board(int n) {
    final l = users.map((e) => (u: e, v: lb == 'i' ? e.items : e.life)).toList()
      ..sort((x, y) => y.v.compareTo(x.v));
    return l.take(n).toList();
  }

  // =====================================================================
  //  Starter data (admin button on an empty dashboard)
  // =====================================================================
  static const _exb = [
    ['🌱', 'First Drop', 10], ['♻', 'Eco Starter', 50], ['🌿', 'Green Helper', 150],
    ['🏅', 'Recycler Pro', 300], ['🛡', 'Planet Guardian', 600], ['🏆', 'Zero Waste Legend', 1000],
  ];
  Future<void> seed() async {
    await _run(() async {
      if (bins.isEmpty) {
        await _db.from('bins').insert({'name': 'SmartBin 01', 'location': 'CICI Lobby'});
      }
      final have = badges.map((b) => b.name).toSet();
      final rows = [
        for (final x in _exb)
          if (!have.contains(x[1])) {'name': x[1], 'icon': x[0], 'min_points': x[2]}
      ];
      if (rows.isNotEmpty) await _db.from('badges').insert(rows);
    });
    await _safeRefresh();
  }

  // =====================================================================
  //  Bin simulator + reward QR (all logic lives in the database)
  // =====================================================================
  Future<void> binTest(Bin b, String o, int w) async {
    BinEvent r;
    try {
      final res = Map<String, dynamic>.from((await _db.rpc('bin_test_deposit', params: {'p_bin_id': b.id, 'p_kind': o, 'p_weight': w})) as Map);
      r = BinEvent('${res['type']}', '${res['msg']}', b.name, w, nowStr(), token: res['token'] as String?, nonce: res['nonce'] as String?);
    } on PostgrestException catch (e) {
      r = BinEvent('rej', e.message, b.name, w, nowStr());
    } catch (_) {
      r = BinEvent('rej', _netErr, b.name, w, nowStr());
    }
    lastBin = r;
    notifyListeners();
    await _safeRefresh();
  }

  Future<ScanRes> redeemQR(String raw) async {
    ScanRes out;
    try {
      final res = Map<String, dynamic>.from((await _db.rpc('redeem_deposit', params: {'p_code': raw.trim()})) as Map);
      out = ScanRes(res['ok'] == true, '${res['msg'] ?? ''}', [for (final b in (res['new_badges'] as List? ?? const [])) '$b']);
    } on PostgrestException catch (e) {
      return ScanRes(false, e.message);
    } catch (_) {
      return ScanRes(false, _netErr);
    }
    await _safeRefresh();
    return out;
  }

  // ---- vouchers ----
  List<String> voucherRules() => [
        'Value: ${vc.rate} points = ₱1. Minimum ₱${vc.min}, maximum ₱${vc.max} (${vc.max * vc.rate} points) per voucher.',
        'The voucher is for free printing at the PSITS office. PSITS sets the printing prices (${priceText(kPrices)}). The pesos you convert are a printing credit you can spend on any page type.',
        'Use it in one visit. Any unused credit is not refunded, carried over or exchanged for cash, so choose an amount that fits what you need to print. If your printing costs more than your voucher, you pay the extra with your own money.',
        'Valid for ${vc.days} days from the date issued. Expired vouchers cannot be claimed and points are not refunded.',
        'Each voucher has its own unique QR code. One use only: once PSITS staff mark it Claimed it cannot be used again.',
        'Claim at the ${vc.office} by showing your voucher QR code in the app with your Student ID. Vouchers are not transferable.',
        'Lost, copied, edited or unreadable vouchers are not replaced and may be rejected.',
        'Points are deducted when the voucher is generated.',
      ];

  static String priceText(Prices r) => 'B&W ₱${r.bw}, colored ₱${r.col}, picture ₱${r.pic} per page';
  static String pgLine(int p, Prices r) => 'B&W ${p ~/ r.bw} · Colored ${p ~/ r.col} · Picture ${p ~/ r.pic}';

  /// Returns (voucher, error)
  Future<(Voucher?, String?)> generateVoucher(int pesos, Pages? req) async {
    if (pesos <= 0 || pesos > 100 || pesos < vc.min || pesos > vc.max || (pesos * vc.rate) < 10 || (pesos * vc.rate) > 1000) {
      return (null, 'Warning! Limit Exceeded! Pesos must be 1–100 and points must be 10–1000.');
    }
    if (pesos < kPrices.bw) return (null, 'The cheapest page costs ₱${kPrices.bw}');
    if (pesos * vc.rate > pts) return (null, 'Not enough points (need ${pesos * vc.rate})');
    Map<String, dynamic> res;
    try {
      res = Map<String, dynamic>.from((await _db.rpc('generate_voucher', params: {
        'p_pesos': pesos,
        'p_req_bw': req?.bw,
        'p_req_col': req?.col,
        'p_req_pic': req?.pic,
      })) as Map);
    } on PostgrestException catch (e) {
      return (null, e.message);
    } catch (_) {
      return (null, _netErr);
    }
    if (res['ok'] != true) return (null, '${res['error'] ?? 'Could not create the voucher'}');
    final v = _voucher(Map<String, dynamic>.from(res['voucher'] as Map));
    await _safeRefresh();
    return (v, null);
  }

  Voucher? findVoucher(String code) => vl.where((x) => x.code == code).firstOrNull;

  Future<VerifyRes> verify(String c) async {
    c = c.trim();
    // Old QR format "SBV1|<code>|..." still works: only the code is used.
    final code = c.startsWith('SBV1|') && c.split('|').length > 1 ? c.split('|')[1] : c;
    Map<String, dynamic> res;
    try {
      res = Map<String, dynamic>.from((await _db.rpc('verify_voucher', params: {'p_code': code})) as Map);
    } on PostgrestException catch (e) {
      return VerifyRes.bad(e.message);
    } catch (_) {
      return VerifyRes.bad(_netErr);
    }
    if (res['voucher'] == null) return VerifyRes.bad('${res['label'] ?? 'UNKNOWN OR INVALID VOUCHER'}');
    final v = _voucher(Map<String, dynamic>.from(res['voucher'] as Map));
    return VerifyRes(ok: res['ok'] == true, label: '${res['label']}', v: v, name: v.uName, id: v.uid, lab: '₱${v.pesos}', code: v.code, exp: v.exp);
  }

  /// Returns an error message, or null on success.
  Future<String?> claim(Voucher v, Pages pages) async {
    if (v.state != 'Active') return 'Voucher is not active';
    try {
      final res = Map<String, dynamic>.from((await _db.rpc('claim_voucher', params: {
        'p_code': v.code,
        'p_bw': pages.bw,
        'p_col': pages.col,
        'p_pic': pages.pic,
      })) as Map);
      if (res['ok'] != true) return '${res['error'] ?? 'Could not claim the voucher'}';
    } on PostgrestException catch (e) {
      return e.message;
    } catch (_) {
      return _netErr;
    }
    await _safeRefresh();
    return null;
  }

  // =====================================================================
  //  Admin CRUD
  // =====================================================================
  Future<void> addBin(String n, String l) async {
    if (n.trim().isEmpty) return;
    await _run(() async {
      await _db.from('bins').insert({'name': n.trim(), 'location': l.trim().isEmpty ? '—' : l.trim()});
    });
    await _safeRefresh();
  }

  Future<void> deleteBin(Bin b) async {
    await _run(() async {
      await _db.from('bins').delete().eq('id', b.id);
    });
    await _safeRefresh();
  }

  Future<void> saveBin(Bin b, String name, String loc) async {
    await _run(() async {
      await _db.from('bins').update({'name': name, 'location': loc}).eq('id', b.id);
    });
    await _safeRefresh();
  }

  Future<void> setBinOn(Bin b, bool on) async {
    update(() => b.on = on);
    await _run(() async {
      await _db.from('bins').update({'is_on': on}).eq('id', b.id);
    });
    await _safeRefresh();
  }

  Future<void> setFill(Bin b, Comp c, int fill) async {
    update(() => c.fill = fill);
    await _run(() async {
      await _db.from('bin_compartments').update({'fill': fill, 'updated_at': DateTime.now().toUtc().toIso8601String()}).eq('bin_id', b.id).eq('kind', c.k);
    });
    await _safeRefresh();
  }

  Future<void> addBadge(String n, int m) async {
    if (n.trim().isEmpty) return;
    await _run(() async {
      await _db.from('badges').insert({'name': n.trim(), 'icon': '🏆', 'min_points': m});
    });
    await _safeRefresh();
  }

  Future<void> saveBadge(BadgeItem b, String name, String icon, int min) async {
    await _run(() async {
      await _db.from('badges').update({'name': name, 'icon': icon, 'min_points': min}).eq('id', b.id);
    });
    await _safeRefresh();
  }

  Future<void> deleteBadge(BadgeItem b) async {
    await _run(() async {
      await _db.from('badges').delete().eq('id', b.id);
    });
    await _safeRefresh();
  }

  Future<void> deleteLog(LogEntry l) async {
    await _run(() async {
      await _db.from('voucher_log').delete().eq('id', l.id);
    });
    await _safeRefresh();
  }

  Future<void> clearLog() async {
    await _run(() async {
      await _db.from('voucher_log').delete().gt('id', 0);
    });
    await _safeRefresh();
  }

  Future<void> clearEvents() async {
    await _run(() async {
      await _db.from('bin_events').delete().gt('id', 0);
    });
    await _safeRefresh();
  }

  /// Saves the voucher rules + points-per-item (admin only). Returns an error or null.
  Future<String?> pushSettings() async {
    if (vc.rate <= 0 || vc.rate > 100 || vc.min <= 0 || vc.min > 100 || vc.max <= 0 || vc.max > 100 || vc.max < vc.min || vc.days <= 0 || vc.days > 365) {
      return 'Invalid settings limits (Pesos must be 1–100, Rate 1–100, Days 1–365)';
    }
    try {
      await _db.from('settings').upsert([
        {'key': 'voucher_rate', 'value': vc.rate},
        {'key': 'voucher_min', 'value': vc.min},
        {'key': 'voucher_max', 'value': vc.max},
        {'key': 'voucher_days', 'value': vc.days},
        {'key': 'voucher_title', 'value': vc.title},
        {'key': 'voucher_office', 'value': vc.office},
        {'key': 'voucher_note', 'value': vc.note},
        {'key': 'voucher_color', 'value': '0x${vc.colorHex.toRadixString(16).toUpperCase()}'},
        {'key': 'points_rec', 'value': (pp['rec'] ?? 10).clamp(1, 1000)},
        {'key': 'points_non', 'value': (pp['non'] ?? 10).clamp(1, 1000)},
      ]);
      return null;
    } on PostgrestException catch (e) {
      return e.message;
    } catch (_) {
      return _netErr;
    }
  }
}
