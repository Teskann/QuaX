// Set by tool/update_chrome.py at each release, which finds this exact line. To bump Chrome by hand, change only it.
const chromeFullVersion = '157.0.8103.78';

final _chromeMajorVersion = _majorOf(chromeFullVersion);

// Chrome's user agent hides all but the major version, and always says "Android 10; K":
// https://www.chromium.org/updates/ua-reduction/
final chromeUserAgent =
    'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$_chromeMajorVersion.0.0.0 Mobile Safari/537.36';

/// Sent with every request to X, so that all of them look like the Chrome on Android that logged in.
final Map<String, String> chromeHeaders = Map.unmodifiable({
  'user-agent': chromeUserAgent,
  'sec-ch-ua': chromeSecChUa(chromeFullVersion),
  'sec-ch-ua-mobile': '?1',
  'sec-ch-ua-platform': '"Android"',
});

typedef ChromeBrand = ({String name, String majorVersion, String fullVersion});

String chromeSecChUa(String fullVersion) =>
    chromeBrands(fullVersion).map((brand) => '"${brand.name}";v="${brand.majorVersion}"').join(', ');

/// The brands of Chrome's `sec-ch-ua`, as `GenerateBrandVersionList()` lists them: https://chromium.googlesource.com/chromium/src/+/refs/tags/157.0.8103.78/components/embedder_support/user_agent_utils.cc#511
List<ChromeBrand> chromeBrands(String fullVersion) {
  // The orders of GetRandomOrder(): https://chromium.googlesource.com/chromium/src/+/refs/tags/157.0.8103.78/components/embedder_support/user_agent_utils.cc#214
  const brandSlots = [
    [0, 1, 2],
    [0, 2, 1],
    [1, 0, 2],
    [1, 2, 0],
    [2, 0, 1],
    [2, 1, 0],
  ];

  final major = _majorOf(fullVersion);
  final brands = [
    _greaseBrand(major),
    (name: 'Chromium', majorVersion: '$major', fullVersion: fullVersion),
    (name: 'Google Chrome', majorVersion: '$major', fullVersion: fullVersion),
  ];
  // slots[i] is where brands[i] goes, as in ShuffleBrandList(): https://chromium.googlesource.com/chromium/src/+/refs/tags/157.0.8103.78/components/embedder_support/user_agent_utils.cc#242
  final slots = brandSlots[major % brandSlots.length];
  return List.generate(brands.length, (slot) => brands[slots.indexOf(slot)]);
}

/// The fake brand Chrome adds so that servers do not rely on the list, e.g. "Not_A Brand", as
/// `GetGreasedUserAgentBrandVersion()` builds it: https://chromium.googlesource.com/chromium/src/+/refs/tags/157.0.8103.78/components/embedder_support/user_agent_utils.cc#535
ChromeBrand _greaseBrand(int major) {
  const characters = [' ', '(', ':', '-', '.', '/', ')', ';', '=', '?', '_'];
  const versions = ['8', '99', '24'];

  final version = versions[major % versions.length];
  return (
    name: 'Not${characters[major % characters.length]}A${characters[(major + 1) % characters.length]}Brand',
    majorVersion: version,
    fullVersion: '$version.0.0.0',
  );
}

int _majorOf(String fullVersion) => int.parse(fullVersion.split('.').first);
