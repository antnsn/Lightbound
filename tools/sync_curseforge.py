"""Copies CHANGELOG.md into the bottom of CURSEFORGE.md (the CurseForge project description).

Run from the addon folder:  python3 tools/sync_curseforge.py          (writes CURSEFORGE.md)
                            python3 tools/sync_curseforge.py --check  (exit 1 if it is out of date)
Everything between the two markers in CURSEFORGE.md is replaced. Version headings move one level
down (## 4.5 -> ### 4.5) so they sit under the description's own "## Changelog". An "Unreleased"
section is left out: the description shows what people can download.
"""
import re
import sys

START, END = "<!-- changelog:start -->", "<!-- changelog:end -->"


def changelog_body(text):
    body = text.split("\n", 1)[1] if text.startswith("# ") else text  # drop the "# ..." title
    sections = re.split(r"(?m)^(?=## )", body.strip())
    kept = [s.strip() for s in sections if s.strip() and not s.startswith("## Unreleased")]
    return re.sub(r"(?m)^(#{2,5}) ", r"#\1 ", "\n\n".join(kept))


def synced(desc, log):
    if desc.count(START) != 1 or desc.count(END) != 1 or desc.index(START) > desc.index(END):
        sys.exit("CURSEFORGE.md needs one %s and one %s marker, in that order." % (START, END))
    head, rest = desc.split(START, 1)
    tail = rest.split(END, 1)[1]
    return head + START + "\n" + changelog_body(log) + "\n" + END + tail


def main():
    with open("CHANGELOG.md", encoding="utf-8") as f:
        log = f.read()
    with open("CURSEFORGE.md", encoding="utf-8") as f:
        desc = f.read()
    new = synced(desc, log)
    if "--check" in sys.argv:
        if new != desc:
            sys.exit("CURSEFORGE.md's changelog is out of date: run python3 tools/sync_curseforge.py")
        print("CURSEFORGE.md changelog is up to date.")
        return
    with open("CURSEFORGE.md", "w", encoding="utf-8") as f:
        f.write(new)
    print("CURSEFORGE.md changelog updated.")


if __name__ == "__main__":
    main()
