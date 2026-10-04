#!/usr/bin/env python3
"""Render the app icon and the welcome tile from design/icon/ (m5-release spec §4.2, §5.1). Provenance only, not a build step.

Usage: python3 docs/tools/make-app-icon.py

Reads the artwork in design/icon/ (the only copy; a future artwork change = edit there and rerun this script) and writes
exactly four files, which are never hand-edited:

  HomeGymLog/Assets.xcassets/AppIcon.appiconset/AppIcon-Light.png   HomeGymLog-icon.svg, flattened on #E11D48 (RGB, no alpha:
                                                                    the App Store icon, ITMS-90717 rejects alpha)
  HomeGymLog/Assets.xcassets/AppIcon.appiconset/AppIcon-Dark.png    HomeGymLog-icon-dark.svg minus its #0F0E10 field rect
                                                                    (transparent, the system draws the dark background)
  HomeGymLog/Assets.xcassets/AppIcon.appiconset/AppIcon-Tinted.png  HomeGymLog-icon-tinted.svg as drawn
  HomeGymLog/Assets.xcassets/WelcomeTile.imageset/WelcomeTile.svg   a byte copy of HomeGymLog-icon.svg

All renders are 1024 x 1024 with rsvg-convert (Homebrew librsvg), which emits RGB PNGs; qlmanage and sips emit RGBA. The
edited dark SVG is written to a temporary directory and deleted: any file left under HomeGymLog/ would become a bundle
resource. Both Contents.json files are written by hand, not by this script.
"""
import os
import re
import shutil
import subprocess
import sys
import tempfile

RSVG = "/opt/homebrew/bin/rsvg-convert"
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ICON = os.path.join(ROOT, "design", "icon")
CATALOG = os.path.join(ROOT, "HomeGymLog", "Assets.xcassets")
ICON_SET = os.path.join(CATALOG, "AppIcon.appiconset")
TILE = os.path.join(CATALOG, "WelcomeTile.imageset", "WelcomeTile.svg")
ACCENT = "#E11D48"
FIELD_RECT = re.compile(r'<rect[^>]*fill="#0F0E10"[^>]*>\s*</rect>|<rect[^>]*fill="#0F0E10"[^>]*/>')


def without_dark_field(svg):
    """The dark SVG with its one opaque #0F0E10 field rect removed; exits unless there is exactly one."""
    found = FIELD_RECT.findall(svg)
    if len(found) != 1:
        sys.exit(f"expected exactly one #0F0E10 field rect in HomeGymLog-icon-dark.svg, found {len(found)}")
    return svg.replace(found[0], "", 1)


def render(source, out, background=None):
    command = [RSVG, "-w", "1024", "-h", "1024"]
    if background:
        command += ["-b", background]
    subprocess.run(command + ["-o", out, source], check=True)


def main():
    if not os.path.exists(RSVG):
        sys.exit(f"{RSVG} not found: brew install librsvg")
    tmp = tempfile.mkdtemp()
    try:
        with open(os.path.join(ICON, "HomeGymLog-icon-dark.svg"), encoding="utf-8") as f:
            dark = without_dark_field(f.read())
        dark_path = os.path.join(tmp, "dark.svg")
        with open(dark_path, "w", encoding="utf-8") as f:
            f.write(dark)
        # Render into tmp first, then move all four at once, so a failing rsvg-convert never leaves a mixed old/new set.
        outputs = {
            os.path.join(ICON_SET, "AppIcon-Light.png"): os.path.join(tmp, "AppIcon-Light.png"),
            os.path.join(ICON_SET, "AppIcon-Dark.png"): os.path.join(tmp, "AppIcon-Dark.png"),
            os.path.join(ICON_SET, "AppIcon-Tinted.png"): os.path.join(tmp, "AppIcon-Tinted.png"),
            TILE: os.path.join(tmp, "WelcomeTile.svg"),
        }
        render(os.path.join(ICON, "HomeGymLog-icon.svg"), outputs[os.path.join(ICON_SET, "AppIcon-Light.png")], ACCENT)
        render(dark_path, outputs[os.path.join(ICON_SET, "AppIcon-Dark.png")])
        render(os.path.join(ICON, "HomeGymLog-icon-tinted.svg"), outputs[os.path.join(ICON_SET, "AppIcon-Tinted.png")])
        shutil.copyfile(os.path.join(ICON, "HomeGymLog-icon.svg"), outputs[TILE])
        for final, staged in outputs.items():
            shutil.move(staged, final)
    finally:
        shutil.rmtree(tmp)


if __name__ == "__main__":
    main()
