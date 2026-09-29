import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The bundled fonts' licences (SIL OFL) and the signer character's credit, shown on the
/// licences page next to the packages' ones (Profile > About > View licenses). Registered in main().
Stream<LicenseEntry> appLicences() async* {
  for (final (file, name) in [('Sora', 'Sora font'), ('PlusJakartaSans', 'Plus Jakarta Sans font')]) {
    yield LicenseEntryWithLineBreaks([name], await rootBundle.loadString('assets/fonts/OFL-$file.txt'));
  }
  yield const LicenseEntryWithLineBreaks(['BIM signer character'], signerCredit);
}

/// Credit required by the signer character's licence (README "Signer").
const signerCredit = 'The BIM signer is the character "FREE MODEL 青髪三つ編みメガネっ子" by 水銀メイド, '
    'from VRoid Hub, used under the conditions its author set there (credit required). '
    'The app contains only rendered pictures of the character, not the model itself.';
