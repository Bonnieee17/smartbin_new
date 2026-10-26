import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../state/app_state.dart';
import '../state/models.dart';
import '../theme/pal.dart';

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);
  static AppState of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

Pal palOf(BuildContext c) => AppScope.of(c).pal;

// ---------- text helpers ----------
class Mut extends StatelessWidget {
  final String t;
  final TextAlign? align;
  const Mut(this.t, {super.key, this.align});
  @override
  Widget build(BuildContext c) => Text(t, textAlign: align, style: TextStyle(color: palOf(c).mut, fontSize: 12));
}

class H3 extends StatelessWidget {
  final String t;
  const H3(this.t, {super.key});
  @override
  Widget build(BuildContext c) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 10),
        child: Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      );
}

class Bold extends StatelessWidget {
  final String t;
  final double? size;
  final Color? color;
  const Bold(this.t, {super.key, this.size, this.color});
  @override
  Widget build(BuildContext c) => Text(t, style: TextStyle(fontWeight: FontWeight.w700, fontSize: size, color: color));
}

// ---------- card ----------
class NCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double bottom;
  final CrossAxisAlignment align;
  const NCard({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.bottom = 18, this.align = CrossAxisAlignment.start});
  @override
  Widget build(BuildContext c) {
    final p = palOf(c);
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: bottom),
      padding: padding,
      decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(18), boxShadow: p.raise),
      child: Column(crossAxisAlignment: align, mainAxisSize: MainAxisSize.min, children: [child]),
    );
  }
}

/// A raised tile used in the 3-up stat rows.
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  const StatTile(this.label, this.value, {super.key});
  @override
  Widget build(BuildContext c) {
    final p = palOf(c);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(18), boxShadow: p.raise),
      child: Column(children: [
        Text(label, textAlign: TextAlign.center, style: TextStyle(color: p.mut, fontSize: 12)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class StatRow extends StatelessWidget {
  final List<StatTile> tiles;
  const StatRow(this.tiles, {super.key});
  @override
  Widget build(BuildContext c) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Row(children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: tiles[i]),
          ]
        ]),
      );
}

class NRow extends StatelessWidget {
  final Widget left;
  final Widget? right;
  final bool border;
  const NRow({super.key, required this.left, this.right, this.border = true});
  @override
  Widget build(BuildContext c) {
    final p = palOf(c);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(border: border ? Border(bottom: BorderSide(color: p.line)) : null),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(child: left),
        if (right != null) ...[const SizedBox(width: 8), right!],
      ]),
    );
  }
}

/// label on the left, bold value on the right
Widget kv(String k, String v, {Color? color, bool mutLabel = false}) => Builder(builder: (c) {
      final p = palOf(c);
      return NRow(
        left: Text(k, style: mutLabel ? TextStyle(color: p.mut) : null),
        right: Text(v, textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
      );
    });

// ---------- buttons ----------
class NBtn extends StatefulWidget {
  final String? label;
  final Widget? child;
  final VoidCallback? onTap;
  final bool primary, danger, selected, expand, small;
  const NBtn({super.key, this.label, this.child, this.onTap, this.primary = false, this.danger = false, this.selected = false, this.expand = false, this.small = false});
  @override
  State<NBtn> createState() => _NBtnState();
}

class _NBtnState extends State<NBtn> {
  bool down = false;
  @override
  Widget build(BuildContext c) {
    final p = palOf(c);
    final w = widget;
    final pressedLook = down || w.selected;
    final fg = w.primary ? Colors.white : w.danger ? Pal.red : w.selected ? p.g : p.tx;
    final deco = w.primary
        ? BoxDecoration(gradient: p.priGrad, borderRadius: BorderRadius.circular(14), boxShadow: down ? null : p.raise)
        : pressedLook
            ? p.inset(14)
            : BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(14), boxShadow: p.raise);
    final content = w.child ?? Text(w.label ?? '', textAlign: TextAlign.center, style: TextStyle(color: fg, fontWeight: w.selected ? FontWeight.w700 : FontWeight.w500));
    return Opacity(
      opacity: w.onTap == null ? .5 : 1,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => down = true),
        onTapCancel: () => setState(() => down = false),
        onTapUp: (_) => setState(() => down = false),
        onTap: w.onTap,
        child: Container(
          width: w.expand ? double.infinity : null,
          padding: EdgeInsets.symmetric(horizontal: w.small ? 10 : 16, vertical: w.small ? 6 : 11),
          decoration: deco,
          child: DefaultTextStyle.merge(style: TextStyle(color: fg), child: Center(widthFactor: w.expand ? null : 1, child: content)),
        ),
      ),
    );
  }
}

class BackBtn extends StatelessWidget {
  final VoidCallback onTap;
  const BackBtn(this.onTap, {super.key});
  @override
  Widget build(BuildContext c) {
    final p = palOf(c);
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: p.g2, shape: BoxShape.circle, boxShadow: p.raise),
            child: const Icon(Icons.arrow_back_rounded),
          ),
        ),
      ),
    );
  }
}

/// Delete button that asks "Sure?" on first tap.
class DelBtn extends StatefulWidget {
  final VoidCallback onConfirm;
  final String label;
  const DelBtn({super.key, required this.onConfirm, this.label = 'Delete'});
  @override
  State<DelBtn> createState() => _DelBtnState();
}

class _DelBtnState extends State<DelBtn> {
  bool ask = false;
  @override
  Widget build(BuildContext c) => NBtn(
        danger: true,
        small: true,
        label: ask ? 'Sure?' : widget.label,
        onTap: () {
          if (!ask) {
            setState(() => ask = true);
          } else {
            widget.onConfirm();
          }
        },
      );
}

// ---------- inputs ----------
class NInput extends StatefulWidget {
  final TextEditingController? ctrl;
  final String hint;
  final bool password;
  final TextInputType? type;
  final double? width;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextAlign align;
  const NInput({super.key, this.ctrl, this.hint = '', this.password = false, this.type, this.width, this.onChanged, this.onSubmitted, this.align = TextAlign.start});
  @override
  State<NInput> createState() => _NInputState();
}

class _NInputState extends State<NInput> {
  bool hide = true;
  @override
  Widget build(BuildContext c) {
    final p = palOf(c);
    return Container(
      width: widget.width,
      decoration: p.inset(14),
      child: TextField(
        controller: widget.ctrl,
        obscureText: widget.password && hide,
        keyboardType: widget.type,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        textAlign: widget.align,
        textAlignVertical: TextAlignVertical.center,
        style: TextStyle(color: p.tx),
        decoration: InputDecoration(
          isDense: true,
          hintText: widget.hint,
          hintStyle: TextStyle(color: p.mut),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          suffixIcon: widget.password
              ? IconButton(
                  icon: Icon(hide ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: p.mut),
                  onPressed: () => setState(() => hide = !hide))
              : null,
        ),
      ),
    );
  }
}

class Seg extends StatelessWidget {
  final String value;
  final List<List<String>> options; // [key,label]
  final ValueChanged<String> onChange;
  const Seg({super.key, required this.value, required this.options, required this.onChange});
  @override
  Widget build(BuildContext c) {
    final p = palOf(c);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(4),
      decoration: p.inset(14),
      child: Row(children: [
        for (final o in options)
          Expanded(
            child: GestureDetector(
              onTap: () => onChange(o[0]),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: o[0] == value ? BoxDecoration(color: p.g, borderRadius: BorderRadius.circular(11), boxShadow: p.raiseSm) : null,
                child: Text(o[1], textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: o[0] == value ? Colors.white : p.tx, fontWeight: o[0] == value ? FontWeight.w700 : FontWeight.w500)),
              ),
            ),
          ),
      ]),
    );
  }
}

class NSwitch extends StatelessWidget {
  final bool on;
  final ValueChanged<bool> onChanged;
  const NSwitch({super.key, required this.on, required this.onChanged});
  @override
  Widget build(BuildContext c) {
    final p = palOf(c);
    return GestureDetector(
      onTap: () => onChanged(!on),
      child: Container(
        width: 46,
        height: 26,
        decoration: p.inset(99),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 150),
          alignment: on ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.all(3),
            width: 20,
            height: 20,
            decoration: BoxDecoration(shape: BoxShape.circle, color: on ? p.g : p.bg, boxShadow: p.raiseSm),
          ),
        ),
      ),
    );
  }
}

// ---------- small visuals ----------
class Pill extends StatelessWidget {
  final String t;
  final bool block;
  const Pill(this.t, {super.key, this.block = false});
  @override
  Widget build(BuildContext c) {
    final p = palOf(c);
    return Container(
      width: block ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: p.inset(99),
      child: Text(t, textAlign: TextAlign.center, style: TextStyle(color: p.g, fontSize: 12)),
    );
  }
}

class Banner2 extends StatelessWidget {
  final String t;
  final bool bad;
  final Widget? extra;
  const Banner2(this.t, {super.key, this.bad = false, this.extra});
  @override
  Widget build(BuildContext c) {
    final p = palOf(c);
    final col = bad ? Pal.red : p.g;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(18), boxShadow: p.raise),
      child: Column(children: [
        Text(t, textAlign: TextAlign.center, style: TextStyle(color: col, fontWeight: FontWeight.w700)),
        if (extra != null) extra!,
      ]),
    );
  }
}

class Meter extends StatelessWidget {
  final double pct;
  const Meter(this.pct, {super.key});
  @override
  Widget build(BuildContext c) {
    final p = palOf(c);
    return Container(
      height: 10,
      decoration: p.inset(8),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: (pct / 100).clamp(0.0, 1.0),
        child: Container(decoration: BoxDecoration(color: p.g, borderRadius: BorderRadius.circular(8))),
      ),
    );
  }
}

class Donut extends StatelessWidget {
  final int pct;
  const Donut(this.pct, {super.key});
  @override
  Widget build(BuildContext c) {
    final p = palOf(c);
    return Center(
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: p.raise, color: p.bg),
        child: CustomPaint(
          painter: _DonutPainter(pct / 100, p.g, p.g2),
          child: Center(
            child: Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(shape: BoxShape.circle, color: p.bg, boxShadow: [BoxShadow(color: p.shD.withOpacity(.4), blurRadius: 4, offset: const Offset(2, 2))]),
              alignment: Alignment.center,
              child: Text('$pct%', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double v;
  final Color fg, bg;
  _DonutPainter(this.v, this.fg, this.bg);
  @override
  void paint(Canvas canvas, Size s) {
    final r = Rect.fromCircle(center: s.center(Offset.zero), radius: s.width / 2 - 8);
    final base = Paint()..style = PaintingStyle.stroke..strokeWidth = 14..color = bg;
    final arc = Paint()..style = PaintingStyle.stroke..strokeWidth = 14..color = fg..strokeCap = StrokeCap.round;
    canvas.drawArc(r, 0, math.pi * 2, false, base);
    if (v > 0) canvas.drawArc(r, -math.pi / 2, math.pi * 2 * v, false, arc);
  }

  @override
  bool shouldRepaint(_DonutPainter o) => o.v != v || o.fg != fg;
}

class WeekBars extends StatelessWidget {
  final List<int> week;
  final double height;
  const WeekBars(this.week, {super.key, this.height = 130});
  @override
  Widget build(BuildContext c) {
    final p = palOf(c);
    final mx = math.max(1, week.reduce(math.max));
    const d = 'SMTWTFS';
    return SizedBox(
      height: height + 20,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Container(height: math.max(4.0, week[i] / mx * height), decoration: BoxDecoration(color: p.g, borderRadius: const BorderRadius.vertical(top: Radius.circular(6)))),
                const SizedBox(height: 4),
                Text(d[i], style: TextStyle(fontSize: 11, color: p.mut)),
              ]),
            ),
          ),
      ]),
    );
  }
}

class Bulbs extends StatelessWidget {
  final int fill;
  const Bulbs(this.fill, {super.key});
  @override
  Widget build(BuildContext c) {
    final lvl = fill >= 100 ? 2 : fill >= 80 ? 1 : fill >= 30 ? 0 : -1;
    const cols = [Colors.green, Colors.orange, Colors.red];
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < 3; i++)
        Container(
          width: 14,
          height: 14,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(shape: BoxShape.circle, color: cols[i].withOpacity(i == lvl ? 1 : .2), boxShadow: i == lvl ? [BoxShadow(color: cols[i], blurRadius: 8)] : null),
        ),
    ]);
  }
}

class QrBox extends StatelessWidget {
  final String data;
  final double size;
  const QrBox(this.data, {super.key, this.size = 150});
  @override
  Widget build(BuildContext c) => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFDDDDDD))),
        child: QrImageView(data: data, size: size, backgroundColor: Colors.white, padding: EdgeInsets.zero),
      );
}

class HeroCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const HeroCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});
  @override
  Widget build(BuildContext c) {
    final p = palOf(c);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: p.raise,
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [p.g, p.gDark]),
      ),
      child: DefaultTextStyle.merge(style: const TextStyle(color: Colors.white), child: child),
    );
  }
}

class Steps extends StatelessWidget {
  final List<String> items;
  final bool ordered;
  const Steps(this.items, {super.key, this.ordered = true});
  @override
  Widget build(BuildContext c) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 22, child: Text(ordered ? '${i + 1}.' : '•')),
                Expanded(child: Text(items[i])),
              ]),
            ),
        ]),
      );
}

class GenderAvatar extends StatelessWidget {
  final String gender;
  final double size;
  const GenderAvatar(this.gender, {super.key, this.size = 54});

  @override
  Widget build(BuildContext c) {
    final isGirl = gender.toLowerCase() == 'girl';
    final col = isGirl ? const Color(0xFFE91E63) : const Color(0xFF2196F3);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: col.withOpacity(0.15),
        shape: BoxShape.circle,
        border: Border.all(color: col, width: 2.5),
        boxShadow: palOf(c).raiseSm,
      ),
      child: Icon(
        isGirl ? Icons.face_3_rounded : Icons.face_rounded,
        color: col,
        size: size * 0.65,
      ),
    );
  }
}

void snack(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m), duration: const Duration(seconds: 2)));

Future<void> copyText(BuildContext c, String t, String msg) async {
  await Clipboard.setData(ClipboardData(text: t));
  if (c.mounted) snack(c, msg);
}

// ---------- voucher ticket ----------
class _Dashed extends CustomPainter {
  final Color color;
  _Dashed(this.color);
  @override
  void paint(Canvas canvas, Size s) {
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & s, const Radius.circular(14)));
    final paint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2;
    for (final m in path.computeMetrics()) {
      double d = 0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, math.min(d + 7, m.length)), paint);
        d += 12;
      }
    }
  }

  @override
  bool shouldRepaint(_Dashed o) => o.color != color;
}

class VoucherTicket extends StatelessWidget {
  final Voucher v;
  const VoucherTicket(this.v, {super.key});
  @override
  Widget build(BuildContext c) {
    final s = AppScope.of(c);
    final cfg = s.vc;
    final col = Color(cfg.colorHex);
    const dark = Color(0xFF111111);
    final r = v.prices;
    final pages = v.req != null
        ? Text.rich(TextSpan(children: [const TextSpan(text: 'Pages to print: '), TextSpan(text: v.req!.text(), style: const TextStyle(fontWeight: FontWeight.w700))]), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: dark))
        : Column(children: [
            Text.rich(TextSpan(children: [TextSpan(text: 'B&W (₱${r.bw}): '), TextSpan(text: '${v.pesos ~/ r.bw} pages', style: const TextStyle(fontWeight: FontWeight.w700))]), style: const TextStyle(fontSize: 12, color: dark)),
            Text.rich(TextSpan(children: [TextSpan(text: 'Colored (₱${r.col}): '), TextSpan(text: '${v.pesos ~/ r.col} pages', style: const TextStyle(fontWeight: FontWeight.w700))]), style: const TextStyle(fontSize: 12, color: dark)),
            Text.rich(TextSpan(children: [TextSpan(text: 'Picture (₱${r.pic}): '), TextSpan(text: '${v.pesos ~/ r.pic} pages', style: const TextStyle(fontWeight: FontWeight.w700))]), style: const TextStyle(fontSize: 12, color: dark)),
          ]);
    return CustomPaint(
      painter: _Dashed(col),
      child: Container(
        margin: const EdgeInsets.all(1),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: DefaultTextStyle(
          style: const TextStyle(color: dark, fontSize: 14),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: double.infinity, color: col, padding: const EdgeInsets.all(10), child: Text(cfg.title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                Text('₱${v.pesos}.00', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: col)),
                Text('FREE PRINTING CREDIT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: col)),
                const SizedBox(height: 4),
                pages,
                const SizedBox(height: 8),
                Text('${v.uName} · ID ${v.uid}'),
                const SizedBox(height: 8),
                QrBox(v.qr.isEmpty ? v.code : v.qr, size: 150),
                const SizedBox(height: 6),
                Text(v.shortCode, style: const TextStyle(fontFamily: 'monospace')),
                const SizedBox(height: 6),
                Text('Status: ${v.state} · Expires ${dateStr(v.exp)}', style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                Text('${cfg.note}\nClaim at: ${cfg.office}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Color(0xFF444444))),
                const Divider(height: 18),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Rules', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF444444))),
                    for (var i = 0; i < s.voucherRules().length; i++)
                      Padding(padding: const EdgeInsets.only(top: 3), child: Text('${i + 1}. ${s.voucherRules()[i]}', style: const TextStyle(fontSize: 10, color: Color(0xFF444444)))),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

Future<void> showVoucherDialog(BuildContext c, Voucher v, {bool staff = false}) => showDialog(
      context: c,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            VoucherTicket(v),
            const SizedBox(height: 12),
            const Text('Show this QR to PSITS staff. It works once.', style: TextStyle(color: Colors.white, fontSize: 12)),
            const SizedBox(height: 8),
            NBtn(primary: true, label: 'Close', onTap: () => Navigator.pop(ctx)),
          ]),
        ),
      ),
    );

/// Shared "How it works" / rules cards (user app + PSITS portal)
Widget priceRows() => Builder(builder: (c) => Column(children: [
      kv('B&W page', '₱${kPrices.bw}'),
      kv('Colored page', '₱${kPrices.col}'),
      kv('Picture page', '₱${kPrices.pic}'),
    ]));

Widget howBody(AppState s) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      NCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Bold('Earn points'),
        const Steps([
          'Drop recyclable or non-biodegradable waste into a SmartBin.',
          'The bin recognizes the waste using our trained dataset. A valid item shows a reward QR on its screen; an invalid item shows a message and no QR.',
          'Open Scan in the app and scan that QR. Each reward QR works once and expires after 2 minutes.',
          'Your points and badges update right away.',
        ]),
      ])),
      NCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Bold('Turn points into free printing'),
        Steps([
          'Go to Rewards, then Get Voucher.',
          'Choose how many pages you want to print (B&W, colored or picture), or type how many pesos to convert (${s.vc.rate} points = ₱1, maximum ₱${s.vc.max}). The app shows the total.',
          'Get your voucher. It is a unique QR code with your name, Student ID, value and expiry date.',
          'Show it with your Student ID at the ${s.vc.office} within ${s.vc.days} days.',
          'PSITS scans the QR. If it is available they print for you and mark it claimed. It cannot be used again.',
        ]),
      ])),
      NCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Bold('PSITS printing prices'),
            priceRows(),
            Mut('Your voucher is a peso credit. ₱50 prints ${AppState.pgLine(50, kPrices)} pages, or a mix up to ₱50.'),
          ],
        ),
      ),
    ]);

Widget rulesCard(AppState s) => Column(children: [
      const NCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Bold('⚠ Important', size: 16),
        Mut('Please read before you convert your points.'),
      ])),
      howBody(s),
    ]);
