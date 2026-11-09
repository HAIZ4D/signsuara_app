import 'package:flutter/foundation.dart';

import 'sign_clips.dart';
import 'sign_player.dart';
import 'sign_translator.dart';

/// Signs the hearing person's latest words: words → signs → clips → player (README "Signer").
/// Until the app contains clips, [hasClips] is false and the screens show the words as text only.
class Signer extends ChangeNotifier {
  Signer({SignTranslator? translator, Future<SignClipLibrary>? library, SignPlayer? player})
      : translator = translator ?? SignTranslator(),
        player = player ?? SignPlayer() {
    this.player.addListener(_onPlayer);
    (library ?? SignClipLibrary.fromAssets()).then(_useLibrary);
  }

  final SignTranslator translator;
  final SignPlayer player;

  var _library = const SignClipLibrary({});
  var _sentence = '';
  List<SignStep> _steps = const [];
  List<int> _stepOfClip = const [];
  Set<int> _signedSteps = const {};

  /// The words being signed, and how (see [SignTranslator]).
  String get sentence => _sentence;
  List<SignStep> get steps => _steps;

  /// True once the app contains any sign clip: then the avatar is shown.
  bool get hasClips => !_library.isEmpty;

  /// Which signs have a clip (empty until the app's clip list is read). Learn mode asks from it.
  SignClipLibrary get library => _library;

  /// True while the avatar is signing a sentence (not while standing at rest).
  bool get signing => player.playing && _stepOfClip.isNotEmpty;

  /// The word (step) being signed now, to highlight it; null when not signing.
  int? get currentStep => signing && player.index < _stepOfClip.length ? _stepOfClip[player.index] : null;

  /// True when word (step) [step] has clips, so the avatar really signs it.
  bool isSigned(int step) => _signedSteps.contains(step);

  /// True when these words have something to sign again.
  bool get canReplay => _stepOfClip.isNotEmpty;

  bool get slow => player.speed < 1;
  void toggleSlow() => player.speed = slow ? 1 : 0.5;

  // The player reports every new picture (its view listens to it directly); the screens only need
  // to hear when what they show changes: signing or not, which sign, the speed. Passing on every
  // picture rebuilt the whole app 24 times a second while she signed (README "Smoothness").
  (bool, int, double)? _told;

  void _onPlayer() {
    final now = (signing, player.index, player.speed);
    if (now == _told) return;
    _told = now;
    notifyListeners();
  }

  /// Signs [sentence]. The same sentence again does not start over (that is [replay]).
  void show(String sentence) {
    if (sentence == _sentence) return;
    _sentence = sentence;
    _steps = translator.translate(sentence);
    _start();
    notifyListeners();
  }

  /// Signs [sentence] from the start, even when it is the one shown now (a tap on their bubble).
  Future<void> signAgain(String sentence) async {
    if (sentence == _sentence) return replay();
    show(sentence);
  }

  Future<void> replay() async {
    if (_stepOfClip.isNotEmpty) await player.replay();
  }

  void _start() {
    final plan = _library.plan(_steps);
    _stepOfClip = [for (final (_, step) in plan) step];
    _signedSteps = _stepOfClip.toSet();
    if (plan.isNotEmpty) {
      player.play([for (final (clip, _) in plan) clip]);
    } else if (player.playing) {
      player.stop(); // nothing to sign for these words: the avatar goes back to standing still
    }
  }

  void _useLibrary(SignClipLibrary library) {
    _library = library;
    if (_steps.isNotEmpty) {
      _start(); // words arrived before the clip list was read
    } else if (library.ids.contains(SignClipLibrary.rest)) {
      player.play(const [SignClipLibrary.rest]); // show the avatar standing, ready
    }
    notifyListeners();
  }

  @override
  void dispose() {
    player.removeListener(_onPlayer);
    player.dispose();
    super.dispose();
  }
}
