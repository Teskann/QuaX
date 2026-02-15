import sys
from pathlib import Path


class Commit:
    def __init__(self, git_log: str):
        self.sha, self.author, self.message = git_log.split("\n", 2)
        if not self._is_from_owner():
            self._set_name_to_github_username()

    def _is_from_owner(self) -> bool:
        return self.author.lower() == "teskann"

    def _set_name_to_github_username(self) -> None:
        import os
        import requests

        url = f"https://api.github.com/repos/teskann/quax/commits/{self.sha}"
        github_token = os.getenv('GITHUB_TOKEN')
        headers = {
            "Accept": "application/vnd.github+json",
        }
        if github_token is not None:
            headers["Authorization"] = f"Bearer {github_token}"

        response = requests.get(url, headers=headers)
        if response.status_code == 200:
            data = response.json()
            try:
                self.author = f'@{data['author']['login']}'
            except (KeyError, ValueError):
                pass

    def _get_credits(self) -> str:
        if self._is_from_owner():
            return ""
        return f" (by {self.author})"

    def __repr__(self) -> str:
        return f"  - {self.message}{self._get_credits()} <sup>[[view modified code]](https://github.com/teskann/quax/commit/{self.sha})</sup>"


def generate_changelog_content(commits: list[Commit]) -> str:
    version = sys.argv[1]
    changelog_content = f"## QuaX v{version}\n\nWhat's new in QuaX v{version}:\n"
    for commit in commits:
        changelog_content += f"{commit}\n"
    return changelog_content


def prepend_to_changelog_file(changelog_content: str) -> None:
    changelog_path = Path("./changelog.md")
    existing_content = changelog_path.read_text() if changelog_path.exists() else ""
    changelog_path.write_text(changelog_content + "\n" + existing_content)


def update_changelog(commits: list[Commit]) -> None:
    changelog_content = generate_changelog_content(commits)
    prepend_to_changelog_file(changelog_content)


def generate_release_notes_content(commits: list[Commit]) -> str:
    release_notes_content = f"""{generate_changelog_content(commits)}

APK Certificate fingerprints:
```text
{Path("./certificate-fingerprints.txt").read_text()}
```

Missed an update ? See [full changelog](https://github.com/teskann/quax/blob/master/changelog.md) for more details.
    """
    return release_notes_content


def create_release_notes_file(commits: list[Commit]) -> None:
    release_notes_path = Path("./release-notes.md")
    release_notes_path.write_text(generate_release_notes_content(commits))


def parse_commits() -> list[Commit]:
    return [Commit(log) for log in sys.argv[2].split("\n\n")]


if __name__ == "__main__":
    new_commits = parse_commits()
    update_changelog(new_commits)
    create_release_notes_file(new_commits)
