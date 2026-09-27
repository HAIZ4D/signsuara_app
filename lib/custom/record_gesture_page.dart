import 'dart:async';

import 'package:flutter/material.dart';

import '../glove/glove_session.dart';
import '../ml/gesture_classifier.dart';
import '../speech/sign_words.dart';
import 'custom_gesture.dart';
import 'custom_gestures.dart';

/// Create a custom gesture: phrase + Still/Moving, then 5 recordings of 3 s (like record_v2.py).
class RecordGesturePage extends StatefulWidget {
  const RecordGesturePage({super.key, required this.gestures, required this.session});

  final CustomGestures gestures;
  final GloveSession session;

  @override
  State<RecordGesturePage> createState() => _RecordGesturePageState();
}

class _RecordGesturePageState extends State<RecordGesturePage> {
  final _malay = TextEditingController();
  final _english = TextEditingController();
  var _moving = false;

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
    return ListenableBuilder(
      listenable: _session,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('New gesture')),
        body: SafeArea(child: _recording ? _recordingView(context) : _form(context)),
      ),
    );
  }

  Widget _form(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final canStart = _connected && _malay.text.trim().isNotEmpty;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _malay,
          onChanged: (_) => setState(() {}),
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Phrase in Malay *', hintText: 'Saya lapar'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _english,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
              labelText: 'Phrase in English (optional)', hintText: 'I am hungry'),
        ),
        const SizedBox(height: 24),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, icon: Icon(Icons.back_hand), label: Text('Still')),
            ButtonSegment(value: true, icon: Icon(Icons.swipe), label: Text('Moving')),
          ],
          selected: {_moving},
          onSelectionChanged: (choice) => setState(() => _moving = choice.first),
        ),
        const SizedBox(height: 8),
        Text('Still = you hold a hand shape.  Moving = the gesture includes a movement.',
            style: text.bodySmall),
        const SizedBox(height: 24),
        Text('You will do the gesture ${CustomGesture.recordingsNeeded} times: 3-2-1, then 3 seconds '
            'of recording each time. Make it clearly different from the built-in signs.'),
        if (_message.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(_message, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: canStart ? _record : null,
          icon: const Icon(Icons.fiber_manual_record),
          label: const Text('Start recording'),
        ),
        if (!_connected) ...[
          const SizedBox(height: 8),
          Text('Connect the glove first (on the main screen).',
              textAlign: TextAlign.center, style: text.bodySmall),
        ],
      ],
    );
  }

  Widget _recordingView(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${'●' * _recordings.length}${'○' * (CustomGesture.recordingsNeeded - _recordings.length)}',
            textAlign: TextAlign.center,
            style: text.headlineSmall,
          ),
          const SizedBox(height: 32),
          Text(_message, textAlign: TextAlign.center, style: text.headlineMedium),
          const SizedBox(height: 32),
          if (_progress != null) LinearProgressIndicator(value: _progress, minHeight: 12),
          const SizedBox(height: 48),
          OutlinedButton(onPressed: _cancel, child: const Text('Cancel')),
        ],
      ),
    );
  }
}
