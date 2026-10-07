import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show FilteringTextInputFormatter, LengthLimitingTextInputFormatter;

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/responsive.dart';
import '../../../theme/app_theme.dart';

/// Sample line shown inside the picker so a color is judged on real text.
///
/// Do not translate or invent these. They are the real first line of
/// `ratanattaya-vandana` copied from `assets/data/prayers-th.json` — a color is
/// being chosen for liturgical text, so the sample has to be that text, and
/// content stays Thai for every UI language.
const _sampleChant = 'อะระหัง สัมมาสัมพุทโธ ภะคะวา,';
const _sampleRoman = 'Arahaṃ sammāsambuddho bhagavā,';
const _sampleMeaning = 'พระผู้มีพระภาคเจ้า เป็นพระอรหันต์';

/// Sample text for [lane], so each lane previews the kind of text it colors.
String sampleFor(ReadingLane lane) => switch (lane) {
  ReadingLane.chant => _sampleChant,
  ReadingLane.roman => _sampleRoman,
  ReadingLane.meaning => _sampleMeaning,
};

/// Opens the color picker for one reading lane.
///
/// Returns the new [ReadingColor], or null when dismissed. [brightness] is the
/// theme currently on screen: a custom pick applies to that theme only, because
/// one color cannot be readable on both cream and near-black.
Future<ReadingColor?> showReadingColorPicker({
  required BuildContext context,
  required ReadingLane lane,
  required ReadingColor current,
  required Brightness brightness,
  Color? background,
}) {
  return showDialog<ReadingColor>(
    context: context,
    builder: (_) => _ReadingColorDialog(
      lane: lane,
      current: current,
      brightness: brightness,
      background: background ?? readingBackground(brightness),
    ),
  );
}

class _ReadingColorDialog extends StatefulWidget {
  const _ReadingColorDialog({
    required this.lane,
    required this.current,
    required this.brightness,
    required this.background,
  });

  final ReadingLane lane;
  final ReadingColor current;
  final Brightness brightness;

  /// The page this color will actually be read against.
  ///
  /// Passed in rather than derived from [brightness] because the reader now
  /// has its own paper: warning about contrast against cream while the user
  /// reads on sepia would be checking the wrong thing.
  final Color background;

  @override
  State<_ReadingColorDialog> createState() => _ReadingColorDialogState();
}

class _ReadingColorDialogState extends State<_ReadingColorDialog> {
  /// The preset selected, or null once the user moves to a custom color.
  AppTextColor? _preset;

  /// Working color for the theme being edited. Kept as HSV, not [Color], so
  /// dragging through black or white does not lose the hue the user picked.
  late HSVColor _hsv;

  late final TextEditingController _hexCtl;

  /// Set while the hex field is the thing driving the color, so rewriting the
  /// field from the swatch does not fight the cursor mid-typing.
  bool _editingHex = false;
  bool _hexValid = true;

  @override
  void initState() {
    super.initState();
    _preset = widget.current.preset;
    final start =
        widget.current.resolve(widget.brightness) ??
        defaultReadingText(widget.brightness);
    _hsv = HSVColor.fromColor(start);
    _hexCtl = TextEditingController(text: _hexOf(start));
  }

  @override
  void dispose() {
    _hexCtl.dispose();
    super.dispose();
  }

  static String _hexOf(Color color) => (color.toARGB32() & 0xFFFFFF)
      .toRadixString(16)
      .padLeft(6, '0')
      .toUpperCase();

  /// Color currently shown, whichever way it was chosen.
  Color get _effective =>
      _preset?.resolve(widget.brightness) ??
      (_preset == AppTextColor.auto
          ? defaultReadingText(widget.brightness)
          : _hsv.toColor());

  void _selectPreset(AppTextColor preset) {
    setState(() {
      _preset = preset;
      // Move the wheel to the preset so fine-tuning continues from it rather
      // than from wherever the wheel happened to be.
      final resolved =
          preset.resolve(widget.brightness) ??
          defaultReadingText(widget.brightness);
      _hsv = HSVColor.fromColor(resolved);
      _hexValid = true;
      _hexCtl.text = _hexOf(resolved);
    });
  }

  void _selectCustom(HSVColor value) {
    setState(() {
      _preset = null;
      _hsv = value;
      _hexValid = true;
      if (!_editingHex) _hexCtl.text = _hexOf(value.toColor());
    });
  }

  void _onHexChanged(String raw) {
    final parsed = ReadingColor.parseHex(raw);
    setState(() {
      _hexValid = parsed != null;
      if (parsed == null) return;
      _preset = null;
      // Preserve the hue when the typed color is a pure grey, whose HSV hue is
      // an arbitrary 0 and would otherwise reset the hue strip.
      final next = HSVColor.fromColor(parsed);
      _hsv = next.saturation == 0 ? next.withHue(_hsv.hue) : next;
    });
  }

  /// The value this dialog returns: a preset as-is, or a custom pair that keeps
  /// the other theme's color untouched.
  ReadingColor get _result {
    final preset = _preset;
    if (preset != null) return ReadingColor.preset(preset);
    final otherBrightness = widget.brightness == Brightness.dark
        ? Brightness.light
        : Brightness.dark;
    return widget.current.withCustomFor(
      widget.brightness,
      _hsv.toColor(),
      otherFallback: defaultReadingText(otherBrightness),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final color = _effective;
    final background = widget.background;
    final lowContrast = hasLowContrast(color, background);

    return AlertDialog(
      title: Text(widget.lane.label(l10n)),
      content: SizedBox(
        width: responsiveDialogWidth(context, maxWidth: 360),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Preview on the reader's own background, not the dialog's, or the
              // color is judged against a surface it will never appear on.
              Container(
                key: const ValueKey('color_preview'),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Text(
                  sampleFor(widget.lane),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: color,
                    fontSize: 18,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.brightness == Brightness.dark
                    ? l10n.textColorEditingDark
                    : l10n.textColorEditingLight,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (lowContrast) ...[
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.visibility_off_outlined,
                      size: 16,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l10n.textColorLowContrast,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              _SectionLabel(l10n.textColorPalette),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  for (final preset in AppTextColor.values)
                    _PresetSwatch(
                      preset: preset,
                      brightness: widget.brightness,
                      selected: _preset == preset,
                      onTap: () => _selectPreset(preset),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _SectionLabel(l10n.textColorPickCustom),
              const SizedBox(height: 8),
              SaturationValueField(hsv: _hsv, onChanged: _selectCustom),
              const SizedBox(height: 12),
              HueStrip(
                hue: _hsv.hue,
                onChanged: (hue) => _selectCustom(_hsv.withHue(hue)),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('color_hex_field'),
                      controller: _hexCtl,
                      decoration: InputDecoration(
                        labelText: l10n.textColorHexLabel,
                        prefixText: '#',
                        isDense: true,
                        errorText: _hexValid ? null : l10n.textColorHexInvalid,
                      ),
                      // Six hex digits; the field cannot hold anything else, so
                      // the error only ever means "not finished typing yet".
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp('[0-9a-fA-F]'),
                        ),
                        LengthLimitingTextInputFormatter(6),
                      ],
                      onTap: () => _editingHex = true,
                      onTapOutside: (_) => _editingHex = false,
                      onChanged: _onHexChanged,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('color_confirm'),
          onPressed: () => Navigator.of(context).pop(_result),
          child: Text(MaterialLocalizations.of(context).okButtonLabel),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.labelLarge?.copyWith(
        color: theme.colorScheme.secondary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// One preset swatch. `auto` shows the theme's own text color with a glyph,
/// matching how the settings screen already draws it.
class _PresetSwatch extends StatelessWidget {
  const _PresetSwatch({
    required this.preset,
    required this.brightness,
    required this.selected,
    required this.onTap,
  });

  final AppTextColor preset;
  final Brightness brightness;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final swatch = preset.resolve(brightness) ?? defaultReadingText(brightness);
    return Tooltip(
      message: preset.label(l10n),
      child: InkWell(
        key: ValueKey('preset_${preset.name}'),
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: swatch,
            border: Border.all(
              color: selected
                  ? theme.colorScheme.secondary
                  : theme.colorScheme.outlineVariant,
              width: selected ? 3 : 1,
            ),
          ),
          child: Center(
            child: preset == AppTextColor.auto
                ? Text(
                    l10n.fontSizeSample,
                    style: TextStyle(
                      color: readingBackground(brightness),
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : selected
                ? Icon(
                    Icons.check,
                    size: 20,
                    color: readingBackground(brightness),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

/// Saturation (x) and value (y) field for the current hue.
///
/// Hand-written rather than pulled from a package: CLAUDE.md keeps the
/// dependency list short, and this is a gradient stack plus one drag handler.
class SaturationValueField extends StatelessWidget {
  const SaturationValueField({
    super.key,
    required this.hsv,
    required this.onChanged,
  });

  final HSVColor hsv;
  final ValueChanged<HSVColor> onChanged;

  static const _height = 150.0;

  void _emit(Offset local, Size size) {
    final saturation = (local.dx / size.width).clamp(0.0, 1.0);
    final value = 1 - (local.dy / size.height).clamp(0.0, 1.0);
    onChanged(hsv.withSaturation(saturation).withValue(value));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, _height);
        return GestureDetector(
          key: const ValueKey('color_sv_field'),
          behavior: HitTestBehavior.opaque,
          onPanDown: (d) => _emit(d.localPosition, size),
          onPanUpdate: (d) => _emit(d.localPosition, size),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: CustomPaint(
                painter: _SaturationValuePainter(
                  hsv: hsv,
                  border: theme.colorScheme.outlineVariant,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SaturationValuePainter extends CustomPainter {
  const _SaturationValuePainter({required this.hsv, required this.border});

  final HSVColor hsv;
  final Color border;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // Base hue, then white on the left, then black at the bottom: the standard
    // HSV square, built from two gradients over a flat fill.
    canvas.drawRect(
      rect,
      Paint()..color = HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor(),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Colors.white, Colors.transparent],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black, Colors.transparent],
        ).createShader(rect),
    );

    // Thumb: a ring, not a filled dot, so the color under it stays visible.
    final center = Offset(
      hsv.saturation * size.width,
      (1 - hsv.value) * size.height,
    );
    canvas.drawCircle(
      center,
      9,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white,
    );
    canvas.drawCircle(
      center,
      9,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.black.withValues(alpha: 0.5),
    );
  }

  @override
  bool shouldRepaint(_SaturationValuePainter old) =>
      old.hsv != hsv || old.border != border;
}

/// Hue strip, 0–360 degrees.
class HueStrip extends StatelessWidget {
  const HueStrip({super.key, required this.hue, required this.onChanged});

  final double hue;
  final ValueChanged<double> onChanged;

  static const _height = 28.0;

  void _emit(Offset local, double width) {
    onChanged(((local.dx / width).clamp(0.0, 1.0)) * 360);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          key: const ValueKey('color_hue_strip'),
          behavior: HitTestBehavior.opaque,
          onPanDown: (d) => _emit(d.localPosition, width),
          onPanUpdate: (d) => _emit(d.localPosition, width),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              width: width,
              height: _height,
              child: CustomPaint(painter: _HuePainter(hue)),
            ),
          ),
        );
      },
    );
  }
}

class _HuePainter extends CustomPainter {
  const _HuePainter(this.hue);

  final double hue;

  static final _hues = [
    for (var i = 0; i <= 6; i++)
      HSVColor.fromAHSV(1, i * 60.0 % 360, 1, 1).toColor(),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()..shader = LinearGradient(colors: _hues).createShader(rect),
    );
    final x = (hue / 360) * size.width;
    canvas.drawCircle(
      Offset(x, size.height / 2),
      size.height / 2 - 3,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_HuePainter old) => old.hue != hue;
}
