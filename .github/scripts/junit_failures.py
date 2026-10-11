"""List the failed and errored tests of a JUnit XML report (run_all_tests' JUnit=).

Usage: python junit_failures.py <junit.xml>

Prints each failed test with its messages, so they sit at the end of the CI
log, and appends the same to the job summary ($GITHUB_STEP_SUMMARY) when set.
"""
import os
import sys
import xml.etree.ElementTree as ET

MAX_CHARS = 6000   # per test, so one noisy suite cannot fill the summary


def failures(path):
    """(test name, [message, ...]) for every test case with a failure or error."""
    out = []
    for case in ET.parse(path).getroot().iter("testcase"):
        msgs = []
        for el in case:
            if el.tag in ("failure", "error"):
                text = "\n".join(t for t in (el.get("message", ""), el.text or "") if t.strip())
                msgs.append(f"[{el.tag}] " + text.strip())
        if msgs:
            name = case.get("name", "")
            cls = case.get("classname", "")
            out.append((f"{cls}/{name}" if cls else name, msgs))
    return out


def main():
    found = failures(sys.argv[1])
    lines = [f"{len(found)} failed test(s)"]
    md = [f"### {len(found)} failed test(s)", ""]
    for name, msgs in found:
        body = "\n\n".join(msgs)
        if len(body) > MAX_CHARS:
            body = body[:MAX_CHARS] + f"\n... ({len(body) - MAX_CHARS} more characters in the JUnit report)"
        lines += ["", "=" * 80, name, "=" * 80, body]
        md += [f"<details><summary><code>{name}</code></summary>", "", "```", body.replace("```", "'''"), "```",
               "</details>", ""]
    print("\n".join(lines))
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as f:
            f.write("\n".join(md) + "\n")


if __name__ == "__main__":
    main()
