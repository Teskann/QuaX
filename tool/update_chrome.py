"""Sets chromeFullVersion in lib/client/chrome.dart to the Chrome build most Android users run.

Run: python3 tool/update_chrome.py
A failure only prints a warning, so the QuaX release still goes on with the Chrome version already in the code.
"""

import json
import pathlib
import re
import urllib.request

# https://developer.chrome.com/docs/web-platform/versionhistory/guide
LIVE_RELEASES_URL = (
    "https://versionhistory.googleapis.com/v1/chrome/platforms/android/channels/stable/versions/all/releases"
    "?filter=endtime=none"
)
CHROME_DART_PATH = pathlib.Path(__file__).parent.parent / "lib" / "client" / "chrome.dart"
FULL_VERSION_LINE = re.compile(r"const chromeFullVersion = '[\d.]+';")
FULL_VERSION_PATTERN = re.compile(r"^\d+\.\d+\.\d+\.\d+$")


def major_of(version: str) -> str:
    return version.split(".")[0]


def most_used_full_version() -> str:
    with urllib.request.urlopen(LIVE_RELEASES_URL, timeout=30) as response:
        releases = json.load(response)["releases"]
    # Fractions only add up within a group, and the newest group is the current rollout
    newest_group = max(int(release["fractionGroup"]) for release in releases)
    rollout = [release for release in releases if int(release["fractionGroup"]) == newest_group]
    # A major version can be split over several builds and still be the most used one
    majors = {major_of(release["version"]) for release in rollout}
    share_by_major = {
        major: sum(release.get("fraction", 0) for release in rollout if major_of(release["version"]) == major)
        for major in majors
    }
    major = max(share_by_major, key=share_by_major.get)
    releases_of_major = [release for release in rollout if major_of(release["version"]) == major]
    return max(releases_of_major, key=lambda release: release.get("fraction", 0))["version"]


def main() -> None:
    try:
        full_version = most_used_full_version()
        if not FULL_VERSION_PATTERN.match(full_version):
            raise ValueError(f"unexpected Chrome version {full_version!r}")
        source = CHROME_DART_PATH.read_text()
        if not FULL_VERSION_LINE.search(source):
            raise ValueError(f"no chromeFullVersion in {CHROME_DART_PATH}")
        CHROME_DART_PATH.write_text(FULL_VERSION_LINE.sub(f"const chromeFullVersion = '{full_version}';", source))
        print(f"chromeFullVersion set to {full_version}")
    except Exception as error:
        # A GitHub Actions annotation, shown in the summary of the run
        print(f"::warning title=Chrome version not updated::{error}")


if __name__ == "__main__":
    main()
