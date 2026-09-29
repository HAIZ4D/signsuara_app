import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'sign_player.dart';

/// Shows the [player]'s current picture (transparent, so the stage shows through) and gives it
/// the screen's clock while it plays.
class SignPlayerView extends StatefulWidget {
  const SignPlayerView({super.key, required this.player});

  final SignPlayer player;

  @override
  State<SignPlayerView> createState() => _SignPlayerViewState();
}

class _SignPlayerViewState extends State<SignPlayerView> with SingleTickerProviderStateMixin {
  // A slow screen frame moves the signing on by at most this much, so no part is skipped.
  static const _maxStep = Duration(milliseconds: 100);

  late final Ticker _ticker = createTicker(_tick);
  var _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    widget.player.addListener(_update);
    _update();
  }

  @override
  void didUpdateWidget(SignPlayerView old) {
    super.didUpdateWidget(old);
    if (old.player != widget.player) {
      old.player.removeListener(_update);
      widget.player.addListener(_update);
      _update();
    }
  }

  void _update() {
    if (!mounted) return;
    final playing = widget.player.playing;
    if (playing && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!playing && _ticker.isActive) {
      _ticker.stop();
    }
    setState(() {});
  }

  void _tick(Duration elapsed) {
    final step = elapsed - _last;
    _last = elapsed;
    widget.player.advance(step > _maxStep ? _maxStep : step);
  }

  @override
  void dispose() {
    widget.player.removeListener(_update);
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RawImage(image: widget.player.frame, fit: BoxFit.contain);
}
