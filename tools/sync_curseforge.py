"""Copies CHANGELOG.md into the bottom of CURSEFORGE.md (the CurseForge project description).

Run from the addon folder:  python3 tools/sync_curseforge.py            (writes CURSEFORGE.md)
                            python3 tools/sync_curseforge.py --check    (exit 1 if it is out of date)
                            python3 tools/sync_curseforge.py --summary  (print the summary to paste)
Everything between the two markers in CURSEFORGE.md is replaced. Version headings move one level
down (## 4.5 -> ### 4.5) so they sit under the description's own "## Changelog". An "Unreleased"
section is left out: the description shows what people can download.

The top of CURSEFORGE.md holds the text for CurseForge's "Summary" field in a comment, which
stays hidden when the whole file is pasted as the description:
    <!-- summary (CurseForge "Summary" field, at most 256 characters):
    One or two sentences.
    -->
Every run checks that it is there and at most 256 characters long (line breaks count as spaces).
"""
import re
import sys

START, END = "<!-- changelog:start -->", "<!-- changelog:end -->"
SUMMARY = re.compile(r"<!--\s*summary\b[^\n]*\n(.*?)-->", re.S)
SUMMARY_MAX = 256


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


def summary(desc):
    found = SUMMARY.findall(desc)
    if len(found) != 1:
        sys.exit('CURSEFORGE.md needs one <!-- summary ... --> comment at the top, with the text '
                 'for CurseForge\'s "Summary" field on the lines below it.')
    text = " ".join(found[0].split())
    if not text:
        sys.exit("CURSEFORGE.md's summary comment is empty.")
    if len(text) > SUMMARY_MAX:
        sys.exit("CURSEFORGE.md's summary is %d characters; CurseForge allows %d."
                 % (len(text), SUMMARY_MAX))
    return text


def main():
    with open("CHANGELOG.md", encoding="utf-8") as f:
        log = f.read()
    with open("CURSEFORGE.md", encoding="utf-8") as f:
        desc = f.read()
    short = summary(desc)
    if "--summary" in sys.argv:
        print(short)
        return
    new = synced(desc, log)
    if "--check" in sys.argv:
        if new != desc:
            sys.exit("CURSEFORGE.md's changelog is out of date: run python3 tools/sync_curseforge.py")
        print("CURSEFORGE.md changelog is up to date; summary %d/%d characters."
              % (len(short), SUMMARY_MAX))
        return
    with open("CURSEFORGE.md", "w", encoding="utf-8") as f:
        f.write(new)
    print("CURSEFORGE.md changelog updated; summary %d/%d characters." % (len(short), SUMMARY_MAX))


if __name__ == "__main__":
    main()
