import 'dart:ui' as ui;

import 'package:signsuara_app/signer/sign_clips.dart';
import 'package:signsuara_app/signer/sign_player.dart';
import 'package:signsuara_app/signer/signer.dart';

/// A made-up clip: [frames] copies of [image], 40 ms each.
class FakeClip implements ClipReader {
  FakeClip(this.image, this.frames);

  final ui.Image image;
  final int frames;

  @override
  int get frameCount => frames;

  @override
  Future<(ui.Image, Duration)> nextFrame() async => (image.clone(), const Duration(milliseconds: 40));

  @override
  void dispose() {}
}

/// A signer whose app "contains" clips for [ids] (3 frames each = 120 ms per sign).
Signer fakeSigner(ui.Image image, Set<String> ids) => Signer(
      library: Future.value(SignClipLibrary(ids)),
      player: SignPlayer(open: (id) async => ids.contains(id) ? FakeClip(image, 3) : null),
    );
