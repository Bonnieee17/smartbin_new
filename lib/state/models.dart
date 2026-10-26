enum PasswordStrength { weak, fair, strong }

(PasswordStrength, String) evaluatePassword(String p) {
  if (p.length < 8) {
    return (PasswordStrength.weak, 'Weak password — please create a stronger password.');
  }
  final lower = p.toLowerCase();
  const common = ['123456', '12345678', '123456789', 'password', 'qwerty', 'admin', 'abc123', 'iloveyou', 'welcome'];
  if (common.any((c) => lower.contains(c)) || RegExp(r'^(.)\1+$').hasMatch(p) || RegExp(r'0123|1234|2345|3456|4567|5678|6789|abcd|bcde').hasMatch(lower)) {
    return (PasswordStrength.weak, 'Weak password — please create a stronger password.');
  }
  final hasUpper = p.contains(RegExp(r'[A-Z]'));
  final hasLower = p.contains(RegExp(r'[a-z]'));
  final hasDigit = p.contains(RegExp(r'[0-9]'));
  if (p.length < 12 || !hasUpper || !hasLower || !hasDigit) {
    return (PasswordStrength.fair, 'Fair password — use a longer and less predictable password.');
  }
  return (PasswordStrength.strong, 'Strong password — you may register.');
}

class UserAcct {
  String name;
  String id;
  String gender;
  int points;
  int life;
  int items;
  String? uuid; // auth.users / profiles id in Supabase
  UserAcct({required this.name, required this.id, this.gender = '', this.points = 0, int? life, this.items = 0})
      : life = life ?? points;
}

class Comp {
  final String k; // 'rec' | 'non'
  int fill;
  int alert;
  Comp(this.k, {this.fill = 0, this.alert = 80});
}

class Bin {
  final int id;
  String name;
  String loc;
  bool on;
  List<Comp> comps;
  Bin(this.id, this.name, this.loc, {this.on = true, List<Comp>? comps})
      : comps = comps ?? [Comp('rec'), Comp('non')];
}

class BadgeItem {
  final int id;
  String name;
  String icon;
  int min;
  BadgeItem(this.id, this.name, this.icon, this.min);
}

class Activity {
  final String uid;
  final String title;
  final int pts;
  final String date;
  final int ts;
  Activity(this.uid, this.title, this.pts, this.date, this.ts);
}

class LogEntry {
  String user;
  final String voucher;
  final String date;
  final int id;
  LogEntry(this.user, this.voucher, this.date, {this.id = 0});
}

class Prices {
  final int bw, col, pic;
  const Prices({this.bw = 3, this.col = 4, this.pic = 5});
  int of(String k) => k == 'bw' ? bw : k == 'col' ? col : pic;
}

class Pages {
  int bw, col, pic;
  Pages({this.bw = 0, this.col = 0, this.pic = 0});
  Pages copy() => Pages(bw: bw, col: col, pic: pic);
  int get(String k) => k == 'bw' ? bw : k == 'col' ? col : pic;
  void set(String k, int v) {
    if (k == 'bw') bw = v;
    if (k == 'col') col = v;
    if (k == 'pic') pic = v;
  }
  int total(Prices r) => bw * r.bw + col * r.col + pic * r.pic;
  String text() {
    final parts = <String>[];
    if (bw > 0) parts.add('$bw B&W');
    if (col > 0) parts.add('$col Colored');
    if (pic > 0) parts.add('$pic Picture');
    return '${parts.join(' · ')} pages';
  }
}

class Voucher {
  final String code; // SBV.XXXXXXXX
  final String uName;
  final String uid;
  final int pesos;
  final Prices prices;
  final Pages? req;
  final int pts;
  final int exp;
  String status; // Active | Claimed
  String date;
  String qr = '';
  String? claimedOn;
  Pages? printed;
  int? cost;
  int? cash;
  Voucher({
    required this.code,
    required this.uName,
    required this.uid,
    required this.pesos,
    required this.prices,
    required this.pts,
    required this.exp,
    required this.date,
    this.req,
    this.status = 'Active',
  });
  String get shortCode => code.length > 4 ? code.substring(4) : code;
  String get state => status == 'Claimed'
      ? 'Claimed'
      : exp < DateTime.now().millisecondsSinceEpoch
          ? 'Expired'
          : 'Active';
}

class VoucherCfg {
  String title = 'SmartBin Reward Voucher';
  String office = 'PSITS Office';
  String note = 'Present this voucher at the PSITS office to claim. One use only.';
  int colorHex = 0xFF1FA443;
  int days = 3, rate = 10, min = 1, max = 100;
}

class BinEvent {
  final String type; // ok | rej | full | off
  final String msg;
  final String bin;
  final int weight;
  final String date;
  final String? token;
  final String? nonce;
  BinEvent(this.type, this.msg, this.bin, this.weight, this.date, {this.token, this.nonce});
}

class ScanRes {
  final bool ok;
  final String msg;
  final List<String> newBadges;
  ScanRes(this.ok, this.msg, [this.newBadges = const []]);
}

class VerifyRes {
  final String? error; // non-null => invalid banner
  final bool ok;
  final String label;
  final Voucher? v;
  final String name, id, lab, code;
  final int exp;
  VerifyRes.bad(this.error)
      : ok = false, label = '', v = null, name = '', id = '', lab = '', code = '', exp = 0;
  VerifyRes({
    required this.ok,
    required this.label,
    required this.v,
    required this.name,
    required this.id,
    required this.lab,
    required this.code,
    required this.exp,
  }) : error = null;
}
