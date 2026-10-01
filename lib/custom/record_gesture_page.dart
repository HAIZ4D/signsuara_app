import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../glove/glove_ble.dart';
import '../glove/glove_session.dart';
import '../ml/gesture_classifier.dart';
import '../speech/sign_words.dart';
import '../theme/app_theme.dart';
import '../ui/finger_bend.dart';
import '../ui/widgets/brand.dart';
import '../ui/widgets/glove_card.dart';
import '../ui/widgets/gradient_button.dart';
import '../ui/widgets/notice.dart';
import 'custom_gesture.dart';
import 'custom_gestures.dart';
import 'gesture_category_ui.dart';

/// Create a custom gesture: phrase, category and Still/Moving, then 5 recordings of 3 s (like
/// record_v2.py).
class RecordGesturePage extends StatefulWidget {
  const RecordGesturePage({
    super.key,
    required this.gestures,
    required this.session,
    this.ble,
    this.category = GestureCategory.personal,
  });

  final CustomGestures gestures;
  final GloveSession session;
  final GloveBle? ble; // optional: lets the page offer a Connect button
  final GestureCategory category; // chosen first (e.g. the category the Gestures tab shows)

  @override
  State<RecordGesturePage> createState() => _RecordGesturePageState();
}

class _RecordGesturePageState extends State<RecordGesturePage> {
  final _malay = TextEditingController();
  final _english = TextEditingController();
  var _moving = false;
  late var _category = widget.category;

  var _recording = false;
  var _message = '';
  double? _progress; // share of the 3 s captured, null while counting down
  final _recordings = <List<List<double>>>[];
  void Function()? _stopCapture;

  GloveSession get _session => widget.session;
  bool get _connected => _session.link == GloveLink.connected;

  @override
  void initState() {
    super.initState();
    _session.addListener(_stopIfDisconnected);
  }

  @override
  void dispose() {
    _stopCapture?.call();
    _session.removeListener(_stopIfDisconnected);
    if (_session.recognitionPaused) _session.recognitionPaused = false;
    _malay.dispose();
    _english.dispose();
    super.dispose();
  }

  void _stopIfDisconnected() {
    if (_recording && !_connected) _cancel('Glove disconnected. Connect it and try again.');
  }

  void _show(String message, {double? progress}) {
    if (!mounted) return;
    setState(() {
      _message = message;
      _progress = progress;
    });
  }

  void _cancel([String message = '']) {
    _stopCapture?.call();
    if (!mounted) return;
    setState(() {
      _recording = false;
      _message = message;
    });
  }

  Future<void> _record() async {
    FocusScope.of(context).unfocus();
    setState(() => _recording = true);
    _recordings.clear();
    _session.recognitionPaused = true; // practice movements must not be spoken
    try {
      while (_recordings.length < CustomGesture.recordingsNeeded) {
        final n = _recordings.length + 1;
        for (final count in ['3', '2', '1']) {
          if (!_recording) return;
          _show('Recording $n of ${CustomGesture.recordingsNeeded}\n\nGet ready… $count');
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
        if (!_recording) return;
        _show('GO! Do the gesture now', progress: 0);
        final rows = await _captureRows();
        if (rows == null) return; // cancelled or disconnected
        if (rows.any(GestureClassifier.isDeadRow)) {
          _show('Motion sensor dropped out.\nThis recording is done again.');
          await Future<void>.delayed(const Duration(seconds: 2));
          continue;
        }
        _recordings.add(rows);
      }
      await _finish();
    } finally {
      _session.recognitionPaused = false;
    }
  }

  /// Collects the next 75 rows (3 s) from the glove, or null if stopped first.
  Future<List<List<double>>?> _captureRows() {
    final rows = <List<double>>[];
    final done = Completer<List<List<double>>?>();
    void onRow(List<double> row) {
      rows.add(row);
      _show('GO! Do the gesture now', progress: rows.length / CustomGesture.recordingRows);
      if (rows.length == CustomGesture.recordingRows && !done.isCompleted) done.complete(rows);
    }

    _session.addRowListener(onRow);
    _stopCapture = () {
      if (!done.isCompleted) done.complete(null);
    };
    return done.future.whenComplete(() {
      _session.removeRowListener(onRow);
      _stopCapture = null;
    });
  }

  Future<void> _finish() async {
    final gesture = CustomGesture(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      malay: _malay.text.trim(),
      english: _english.text.trim(),
      moving: _moving,
      category: _category,
      recordings: List.of(_recordings),
    );
    final similar = widget.gestures.matcher.tooSimilarTo(gesture);
    if (similar != null && mounted) {
      final name = wordsFor(similar).malay;
      final keep = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text('Looks like "$name"'),
          content: Text('The built-in sign "$name" is closer to these recordings than they are to '
              'each other, so this gesture would rarely be recognised. '
              'Try a gesture that is more different.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Save anyway')),
            FilledButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Record again')),
          ],
        ),
      );
      if (keep != true) return _cancel('Not saved. Change the gesture and record again.');
    }
    await widget.gestures.add(gesture);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ListenableBuilder(
        listenable: _session,
        builder: (context, _) => Scaffold(
          backgroundColor: AppColors.blue,
          body: DecoratedBox(
            decoration: const BoxDecoration(gradient: AppGradients.deep),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SheetHeader(recording: _recording),
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                    ),
                    child: SafeArea(top: false, child: _recording ? _recordingView(context) : _form(context)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _form(BuildContext context) {
    final canStart = _connected && _malay.text.trim().isNotEmpty;
    final ble = widget.ble;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      children: [
        const _Grip(),
        Text('Teach a new gesture', style: AppText.section.copyWith(fontSize: 22)),
        const SizedBox(height: 6),
        Text(
          'Give it a phrase, then sign it ${CustomGesture.recordingsNeeded} times. '
          'Make it clearly different from the built-in signs.',
          style: AppText.body.copyWith(color: AppColors.inkSoft),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _malay,
          onChanged: (_) => setState(() {}),
          textCapitalization: TextCapitalization.sentences,
          style: AppText.strong.copyWith(color: AppColors.ink, fontSize: 16),
          decoration: _field('Phrase in Malay *', 'Saya lapar'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _english,
          textCapitalization: TextCapitalization.sentences,
          style: AppText.strong.copyWith(color: AppColors.ink, fontSize: 16),
          decoration: _field('Phrase in English (optional)', 'I am hungry'),
        ),
        const SizedBox(height: 20),
        Text('What is it about?', style: AppText.label.copyWith(color: AppColors.inkSoft)),
        const SizedBox(height: 8),
        CategoryPicker(selected: _category, onSelect: (category) => setState(() => _category = category)),
        const SizedBox(height: 20),
        Text('How is it signed?', style: AppText.label.copyWith(color: AppColors.inkSoft)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: _KindOption(
              icon: Icons.back_hand_rounded,
              title: 'Still',
              subtitle: 'You hold a hand shape',
              selected: !_moving,
              onTap: () => setState(() => _moving = false),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _KindOption(
              icon: Icons.swipe_rounded,
              title: 'Moving',
              subtitle: 'It includes a movement',
              selected: _moving,
              onTap: () => setState(() => _moving = true),
            ),
          ),
        ]),
        const SizedBox(height: 20),
        const _StepsHint(total: CustomGesture.recordingsNeeded),
        if (_message.isNotEmpty) ...[
          const SizedBox(height: 16),
          Notice(message: _message),
        ],
        const SizedBox(height: 20),
        GradientButton(
          label: 'Start recording',
          icon: Icons.fiber_manual_record_rounded,
          onTap: canStart ? _record : null,
        ),
        if (!_connected) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text('Connect the glove first.',
                    style: AppText.small.copyWith(color: AppColors.inkFaint, fontSize: 13)),
              ),
              if (ble != null) ...[
                const SizedBox(width: 10),
                GloveActionButton(link: _session.link, ble: ble),
              ],
            ],
          ),
        ],
      ],
    );
  }

  InputDecoration _field(String label, String hint) {
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: AppColors.surface2,
      border: border(AppColors.line, 1),
      enabledBorder: border(AppColors.line, 1),
      focusedBorder: border(AppColors.turq, 1.5),
    );
  }

  Widget _recordingView(BuildContext context) {
    final done = _recordings.length;
    const total = CustomGesture.recordingsNeeded;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      children: [
        const _Grip(),
        Text('Record gesture', style: AppText.section.copyWith(fontSize: 22)),
        const SizedBox(height: 6),
        Text(
          _moving
              ? 'Do the whole movement in the middle of the 3 seconds.'
              : 'Hold the hand shape steady until the bar is full.',
          style: AppText.body.copyWith(color: AppColors.inkSoft),
        ),
        const SizedBox(height: 16),
        Container(
          height: 210,
          decoration: BoxDecoration(gradient: AppGradients.stage, borderRadius: BorderRadius.circular(AppRadius.lg)),
          foregroundDecoration: BoxDecoration(
            gradient: AppGradients.stageGlow,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          alignment: Alignment.center,
          child: HandSensor(bends: fingerBend(_session.lastRow), active: _connected, size: 150),
        ),
        const SizedBox(height: 16),
        Semantics(
          label: '$done of $total recordings done',
          excludeSemantics: true,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < total; i++) ...[
                if (i > 0) const SizedBox(width: 9),
                AnimatedContainer(
                  duration: AppMotion.medium,
                  width: 36,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i < done ? AppColors.turq : (i == done ? AppColors.yellow : AppColors.line),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        Semantics(
          liveRegion: true,
          child: Text(_message, textAlign: TextAlign.center, style: AppText.section.copyWith(fontSize: 20, height: 1.35)),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 10,
          child: _progress == null
              ? null
              : ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 10,
                    color: AppColors.turq,
                    backgroundColor: AppColors.surface2,
                  ),
                ),
        ),
        const SizedBox(height: 28),
        OutlinedButton(
          onPressed: _cancel,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.inkSoft,
            side: const BorderSide(color: AppColors.line, width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          ),
          child: Text('Cancel', style: AppText.strong),
        ),
      ],
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.recording});

  final bool recording;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 10, 16, 16),
        child: Row(children: [
          if (!recording) ...[
            Material(
              color: AppColors.glass,
              borderRadius: BorderRadius.circular(13),
              child: InkWell(
                onTap: () => Navigator.of(context).maybePop(),
                borderRadius: BorderRadius.circular(13),
                child: const SizedBox.square(
                  dimension: 40,
                  child: Icon(Icons.arrow_back_rounded, color: AppColors.onDark, semanticLabel: 'Back'),
                ),
              ),
            ),
            const SizedBox(width: 14),
          ],
          Text('New gesture', style: AppText.cardTitle),
        ]),
      );
}

class _Grip extends StatelessWidget {
  const _Grip();

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 42,
          height: 5,
          margin: const EdgeInsets.only(bottom: 18),
          decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(4)),
        ),
      );
}

/// Still / Moving choice card.
class _KindOption extends StatelessWidget {
  const _KindOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: '$title: $subtitle',
        excludeSemantics: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.md),
            // Chosen: filled, like the category picker above it.
            child: AnimatedContainer(
              duration: AppMotion.reduced(context) ? Duration.zero : AppMotion.fast,
              padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
              decoration: BoxDecoration(
                color: selected ? AppColors.turqDeep : AppColors.surface2,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: selected ? AppColors.turqDeep : AppColors.line, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(icon, size: 20, color: selected ? AppColors.onDark : AppColors.turqDeep),
                    const Spacer(),
                    if (selected) const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.onDark),
                  ]),
                  const SizedBox(height: AppSpace.s),
                  Text(title,
                      style: AppText.strong.copyWith(color: selected ? AppColors.onDark : AppColors.ink, fontSize: 14.5)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppText.small.copyWith(color: selected ? AppColors.onDark : AppColors.inkSoft)),
                ],
              ),
            ),
          ),
        ),
      );
}

/// "5 times: 3-2-1, then 3 s" explained with little bars.
class _StepsHint extends StatelessWidget {
  const _StepsHint({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpace.m),
        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(AppRadius.md)),
        child: Row(children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: 5),
            Container(
              width: 14,
              height: 6,
              decoration: BoxDecoration(color: AppColors.turq, borderRadius: BorderRadius.circular(3)),
            ),
          ],
          const SizedBox(width: AppSpace.m),
          Expanded(
            child: Text('$total times: 3-2-1, then 3 seconds of signing',
                style: AppText.small.copyWith(color: AppColors.inkSoft, fontSize: 12.5)),
          ),
        ]),
      );
}
