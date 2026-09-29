# Sign clips

One clip per sign, named after its id in `lib/signer/bim_signs.dart` (`terima_kasih.webp`,
`letter_a.webp`, `number_3.webp`, and optionally `rest.webp` for the avatar standing still).
The app finds the clips here by itself: adding a file is all it takes.

- Animated WebP with a transparent background, about 400 px, 24 fps.
- Every clip starts and ends in the same rest pose, so clips join without a jump.
- A held handshape can be a single picture (it is shown 0.4 s).
- Only signs checked by a fluent BIM signer go here.
