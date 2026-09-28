import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The bundled fonts' licences (SIL OFL), shown on the licences page next to the packages' ones
/// (Profile > About > View licenses). Registered in main().
Stream<LicenseEntry> fontLicences() async* {
  for (final (file, name) in [('Sora', 'Sora font'), ('PlusJakartaSans', 'Plus Jakarta Sans font')]) {
    yield LicenseEntryWithLineBreaks([name], await rootBundle.loadString('assets/fonts/OFL-$file.txt'));
  }
}
