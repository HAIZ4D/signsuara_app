# Sign clips

One clip per sign, named after its id in `lib/signer/bim_signs.dart` (`terima_kasih.webp`,
`letter_a.webp`, `number_3.webp`), plus `rest.webp` (the avatar standing ready) and
`spell_in.webp` / `spell_out.webp` (the hand rising to where letters are signed, and back down).
Letter and number clips start and end with the hand up at that place; all others start and end
in the rest pose.
The app finds the clips here by itself: adding a file is all it takes.

- Animated WebP with a transparent background, 560 px, 24 fps; the bottom tenth fades out
  (the picture is cut at the skirt). `tools/make_sign_clips.py` makes them from the renders.
- Each clip starts and ends in the pose given above, so clips join without a jump.
- A held handshape can be a single picture (it is shown 0.4 s).
- Only signs checked by a fluent BIM signer go here.
