import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// Shows the accents of the bold or italic Unicode letters, which the fonts of the system lack
const mathFontFamily = 'NotoSansMathAccents';

// Android has no "Roboto" family, the one of the text theme: without "sans-serif" first, the math font would
// replace the system one
const appFontFamilyFallback = ['sans-serif', mathFontFamily];

void registerMathFontLicense() => LicenseRegistry.addLicense(_license);

Stream<LicenseEntry> _license() async* {
  yield LicenseEntryWithLineBreaks(['Noto Sans Math'], await rootBundle.loadString('assets/fonts/OFL.txt'));
}
