"""Write the analysis app's button and section icons as SVG files.

    python tools/makeButtonIcons.py

Each icon below is drawn once, on a 24 x 24 grid in the toolbar icons' style
(analysis/icons/toolbar: 2 px round strokes, shown at 16 px). It is written
twice:

    analysis/icons/buttons/<name>.svg        dark strokes, a blue / red accent,
                                             for the light buttons and the
                                             section headers
    analysis/icons/buttons/light/<name>.svg  all white, for the colored buttons
                                             (primary, confirm, danger) and the
                                             dark supersection headers

The app reads them with buttonIcon(<name>) (analysis/@EphysFigGenApp/private);
styleButton swaps a button's icon to its light/ twin when the button is colored
and back when it is not. Edit an icon here, never the SVG files, and run this
again. Files of names no longer listed are removed.
"""
import os

STROKE = "#2e3a46"   # the toolbar icons' ink
ACCENT = "#2673cc"   # the toolbar icons' blue
DANGER = "#cc4033"   # the toolbar Cancel's red
FACE = "#e3ebf5"     # a light button's face (styleButton "secondary"), to hide what is behind a shape

# name -> SVG elements. {s} the ink, {a} the accent, {r} the red accent, {f} the button face ("none" when light).
ICONS = {
    # --- lists of things: add, remove, copy, move ---
    "add": '<path d="M12 5v14M5 12h14"/>',
    "remove": '<path d="M4 7h16"/><path d="M9.5 7V4h5v3"/><path d="M6 7l1 13h10l1-13"/>'
              '<path d="M10 11v5.5M14 11v5.5" stroke="{r}"/>',
    "duplicate": '<rect x="8" y="8" width="13" height="13" rx="2"/>'
                 '<path d="M16 8V5a2 2 0 0 0-2-2H5a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h3"/>',
    "up": '<path d="M12 20V4M5 11l7-7 7 7"/>',
    "down": '<path d="M12 4v16M5 13l7 7 7-7"/>',
    "edit": '<path d="M4 20h4L19 9l-4-4L4 16z"/><path d="M13 7l4 4"/>',
    "checkAll": '<rect x="3" y="3" width="18" height="18" rx="3"/><path d="M7.5 12.5l3 3 6-7" stroke="{a}"/>',
    "checkNone": '<rect x="3" y="3" width="18" height="18" rx="3"/>',
    "checkInvert": '<rect x="3" y="3" width="18" height="18" rx="3"/>'
                   '<path d="M7 18h9a2 2 0 0 0 2-2V7z" fill="{a}" stroke="none"/>',
    "checklist": '<path d="M11 6h10M11 12h10M11 18h10"/><path d="M3 6l2 2 3.5-3.5M3 12l2 2 3.5-3.5" stroke="{a}"/>'
                 '<path d="M4 18h3"/>',
    "copySettings": '<path d="M9 5H7a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h4"/><path d="M15 5h2a2 2 0 0 1 2 2v3"/>'
                    '<rect x="9" y="3" width="6" height="4" rx="1"/><path d="M8.5 11h5M8.5 15h2"/>'
                    '<path d="M14 17h7M18 14l3 3-3 3" stroke="{a}"/>',
    "applyLast": '<path d="M4 20L14 10"/><path d="M14 10l2.5-2.5 2 2L16 12z"/>'
                 '<path d="M18 2.5v3M16.5 4h3M20.5 12v2.5M19.25 13.25h2.5M9.5 3.5v2.5M8.25 4.75h2.5" stroke="{a}"/>',
    "applyAll": '<rect x="2" y="9" width="6" height="6" rx="1" fill="{a}" stroke="{a}"/>'
                '<path d="M8 12h3M11 5v14M11 5h3M11 12h3M11 19h3"/>'
                '<rect x="15" y="3" width="6" height="4" rx="1"/><rect x="15" y="10" width="6" height="4" rx="1"/>'
                '<rect x="15" y="17" width="6" height="4" rx="1"/>',
    "link": '<path d="M10 13.5a4.5 4.5 0 0 0 6.4.4l3-3a4.5 4.5 0 0 0-6.4-6.4l-1.6 1.6"/>'
            '<path d="M14 10.5a4.5 4.5 0 0 0-6.4-.4l-3 3a4.5 4.5 0 0 0 6.4 6.4l1.6-1.6"/>',
    # --- files and folders ---
    "browse": '<path d="M3 19V6a2 2 0 0 1 2-2h4l2 2h6a2 2 0 0 1 2 2v2"/><path d="M3 19l3-8h15l-3 8z"/>',
    "folderAdd": '<path d="M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>'
                 '<path d="M12 10.5v6M9 13.5h6" stroke="{a}"/>',
    "figureFolder": '<path d="M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>'
                    '<path d="M8 16.5v-3M12 16.5v-5M16 16.5v-2" stroke="{a}"/>',
    "openFile": '<path d="M14 3H6a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V9z"/><path d="M14 3v6h6"/>'
                '<path d="M8.5 17.5l5-5M10 12.5h3.5V16" stroke="{a}"/>',
    "save": '<path d="M5 3h11l5 5v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2z"/><path d="M7 3v5h8V3"/>'
            '<path d="M7 21v-7h10v7"/>',
    "update": '<path d="M4 9V5a2 2 0 0 1 2-2h8l6 6v10a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2v-2"/><path d="M14 3v6h6"/>'
              '<path d="M2 13h9M8 10l3 3-3 3" stroke="{a}"/>',
    "import": '<path d="M12 3v11M7.5 9.5L12 14l4.5-4.5" stroke="{a}"/>'
              '<path d="M4 14v5a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-5"/>',
    "export": '<path d="M12 14V3M7.5 7.5L12 3l4.5 4.5" stroke="{a}"/>'
              '<path d="M4 14v5a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-5"/>',
    "report": '<path d="M14 3H6a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V9z"/><path d="M14 3v6h6"/>'
              '<path d="M7.5 17.5l3-3.5 2.5 2 3.5-4" stroke="{a}"/>',
    # --- data, scanning and signals ---
    "scan": '<path d="M3 5h12M3 10h7M3 15h5"/><circle cx="15.5" cy="14.5" r="4.5"/><path d="M18.8 17.8L21.5 20.5"/>',
    "filter": '<path d="M3 4h18l-7 8.5V19l-4 2v-8.5z"/>',
    "downsample": '<path d="M2 12c1.5-5 3.5-5 5 0s3.5 5 5 0"/>'
                  '<circle cx="2.8" cy="10" r="1.3" fill="{a}" stroke="{a}" stroke-width="1"/>'
                  '<circle cx="7" cy="12" r="1.3" fill="{a}" stroke="{a}" stroke-width="1"/>'
                  '<circle cx="11.2" cy="14" r="1.3" fill="{a}" stroke="{a}" stroke-width="1"/>'
                  '<path d="M18.5 4v14M15.5 15l3 3 3-3"/>',
    "probe": '<path d="M9 2h6v13l-3 7-3-7z"/>'
             '<circle cx="12" cy="6" r="1" fill="{a}" stroke="{a}"/><circle cx="12" cy="9.5" r="1" fill="{a}" stroke="{a}"/>'
             '<circle cx="12" cy="13" r="1" fill="{a}" stroke="{a}"/>',
    # --- checking and running ---
    "validate": '<circle cx="12" cy="12" r="9"/><path d="M8 12.5l2.5 2.5 5.5-6" stroke="{a}"/>',
    "plan": '<rect x="5" y="4" width="14" height="18" rx="2"/><rect x="9" y="2" width="6" height="4" rx="1"/>'
            '<path d="M9 11h6M9 15h6M9 19h4"/>',
    "test": '<path d="M9 3h6M10 3v6l-5.4 9.5A1.7 1.7 0 0 0 6 21h12a1.7 1.7 0 0 0 1.4-2.5L14 9V3"/>'
            '<path d="M7.2 15h9.6" stroke="{a}"/>',
    "run": '<path d="M7 4l13 8-13 8z" fill="{a}" stroke="{a}"/>',
    "stop": '<rect x="5" y="5" width="14" height="14" rx="2" fill="{r}" stroke="{r}"/>',
    # --- the preview ---
    "preview": '<path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3" fill="{a}" stroke="{a}"/>',
    "redraw": '<path d="M20 11a8 8 0 0 0-14.3-4.9L4 8"/><path d="M4 3v5h5"/>'
              '<path d="M4 13a8 8 0 0 0 14.3 4.9L20 16"/><path d="M20 21v-5h-5"/>',
    "exportPreview": '<rect x="3" y="7" width="13" height="13" rx="2"/><path d="M5.5 17l3-3.5 2.5 2 2.5-2.5"/>'
                     '<path d="M14 3h7v7M21 3l-8 8" stroke="{a}"/>',
    "code": '<path d="M8 7l-5 5 5 5M16 7l5 5-5 5"/><path d="M14 4l-4 16" stroke="{a}"/>',
    "openWindow": '<rect x="3" y="4" width="18" height="16" rx="2"/><path d="M3 8h18"/>'
                  '<path d="M9.5 16.5l5-5M11 11.5h3.5V15" stroke="{a}"/>',
    "arrange": '<path d="M12 3v18M3 12h18"/><path d="M9 6l3-3 3 3M9 18l3 3 3-3M6 9l-3 3 3 3M18 9l3 3-3 3"/>',
    "templateApply": '<path d="M10 3h4v5l-1 2h5a2 2 0 0 1 2 2v3H4v-3a2 2 0 0 1 2-2h5l-1-2z"/>'
                     '<path d="M4 20h16" stroke="{a}"/>',
    # --- panels on the page ---
    "newPanel": '<rect x="3" y="3" width="18" height="18" rx="2"/><path d="M10 3v18"/>'
                '<path d="M15.5 9v6M12.5 12h6" stroke="{a}"/>',
    "panelType": '<rect x="3" y="3" width="18" height="18" rx="2"/><path d="M11 3v18M3 12h8"/>'
                 '<path d="M16 7.6l1.3 2.6 2.7.4-2 1.9.5 2.8-2.5-1.3-2.5 1.3.5-2.8-2-1.9 2.7-.4z" '
                 'fill="{a}" stroke="{a}" stroke-width="1"/>',
    "corners": '<path d="M3 9V3h6M21 15v6h-6"/><path d="M8 8l8 8" stroke="{a}" stroke-dasharray="2 3"/>',
    "bringForward": '<rect x="3" y="9" width="12" height="12" rx="2"/>'
                    '<rect x="9" y="3" width="12" height="12" rx="2" fill="{a}" stroke="{a}"/>',
    "sendBack": '<rect x="9" y="3" width="12" height="12" rx="2" fill="{a}" stroke="{a}"/>'
                '<rect x="3" y="9" width="12" height="12" rx="2" fill="{f}"/>',
    "addLine": '<path d="M3 3v18h18"/><path d="M10 5v12" stroke="{a}"/><path d="M17 3.5v6M14 6.5h6"/>',
    "addPatch": '<path d="M3 3v18h18"/><rect x="8" y="5" width="5" height="12" fill="{a}" stroke="none" opacity="0.5"/>'
                '<path d="M8 5v12M13 5v12" stroke="{a}"/><path d="M18 3.5v6M15 6.5h6"/>',
    "firstSpike": '<path d="M4 3v18" stroke-dasharray="2 2.5"/><path d="M15 4v4M19 4v4M14 10v4M19.5 10v4M16.5 16v4M20.5 16v4"/>'
                  '<circle cx="9" cy="6" r="1.8" fill="{a}" stroke="{a}"/><circle cx="8" cy="12" r="1.8" fill="{a}" stroke="{a}"/>'
                  '<circle cx="11" cy="18" r="1.8" fill="{a}" stroke="{a}"/>',
    "boxPlot": '<path d="M3 12h4M17 12h4M3 9v6M21 9v6"/><rect x="7" y="7" width="10" height="10" rx="1"/>'
               '<path d="M12 7v10" stroke="{a}"/>',
    # --- looks ---
    "palette": '<path d="M12 3a9 9 0 1 0 0 18c1.1 0 1.8-.8 1.8-1.8 0-.5-.2-.9-.5-1.2-.3-.3-.5-.8-.5-1.2 '
               '0-1 .8-1.8 1.8-1.8h1.9a4.5 4.5 0 0 0 4.5-4.5C21 6.5 17 3 12 3z"/>'
               '<circle cx="7.5" cy="11" r="1.4" fill="{a}" stroke="none"/><circle cx="10" cy="7" r="1.4" fill="{a}" stroke="none"/>'
               '<circle cx="15" cy="7.5" r="1.4" fill="{a}" stroke="none"/>',
    "designSave": '<g transform="translate(-1 -1) scale(0.85)"><path d="M12 3a9 9 0 1 0 0 18c1.1 0 1.8-.8 1.8-1.8 '
                  '0-.5-.2-.9-.5-1.2-.3-.3-.5-.8-.5-1.2 0-1 .8-1.8 1.8-1.8h1.9a4.5 4.5 0 0 0 4.5-4.5C21 6.5 17 3 12 3z"/>'
                  '<circle cx="7.5" cy="11" r="1.4" fill="{s}" stroke="none"/><circle cx="10" cy="7" r="1.4" fill="{s}" stroke="none"/>'
                  '<circle cx="15" cy="7.5" r="1.4" fill="{s}" stroke="none"/></g>'
                  '<path d="M19 15v7M15.5 18.5h7" stroke="{a}"/>',
    "brush": '<path d="M18.5 3l2.5 2.5-9.5 9.5L9 12.5z"/>'
             '<path d="M9 12.5c-2.5 0-4 1.6-4 4 0 1.5-1 2.5-2 3 3.6.6 8.3-1 8.5-5" fill="{a}" stroke="{a}"/>',
    "forget": '<path d="M9 20h11"/><path d="M4.6 15.4l9-9a2 2 0 0 1 2.8 0l3.2 3.2a2 2 0 0 1 0 2.8L13 19H8.2z"/>'
              '<path d="M9.5 10.5l6 6" stroke="{a}"/>',
    # --- the figure editor's section headers (formSection Icon=) ---
    "panel": '<rect x="3" y="3" width="18" height="18" rx="2"/><path d="M7 16l3-4 3 2 4-6" stroke="{a}"/>',
    "observations": '<circle cx="12" cy="12" r="7.5"/><circle cx="12" cy="12" r="2.5" fill="{a}" stroke="{a}"/>'
                    '<path d="M12 2v3M12 19v3M2 12h3M19 12h3"/>',
    "align": '<path d="M2 8h7l2-3 2 6 2-3h7M2 17h7l2-3 2 6 2-3h7"/><path d="M12 2v20" stroke="{a}" stroke-dasharray="2 2"/>',
    "layout": '<rect x="3" y="3" width="18" height="18" rx="2"/><path d="M3 10h18M10 10v11"/>',
    "latency": '<circle cx="12" cy="13.5" r="7.5"/><path d="M12 13.5V9.5" stroke="{a}"/><path d="M9.5 2.5h5M12 2.5v3.5"/>'
               '<path d="M18.5 6.5l1.5-1.5"/>',
    "sessions": '<rect x="3" y="5" width="18" height="16" rx="2"/><path d="M3 10h18M8 3v4M16 3v4"/>'
                '<path d="M7 14h2M11 14h2M15 14h2M7 17.5h2M11 17.5h2" stroke="{a}"/>',
    "panelAlign": '<rect x="3" y="3" width="18" height="18" rx="2"/><path d="M6 15l3-3 3 3 3-6 3 3"/>'
                  '<path d="M12 5.5v13" stroke="{a}" stroke-dasharray="2 2"/>',
    "layers": '<path d="M12 3l9 5-9 5-9-5z" fill="{f}"/><path d="M3 12.5l9 5 9-5" /><path d="M3 16.5l9 5 9-5" stroke="{a}"/>',
    "analysis": '<path d="M18 6.5V4H6l6.5 8L6 20h12v-2.5"/>',
    "display": '<path d="M3 3v18h18"/><path d="M6 16c3-1 4-8 7-8s3.5 5 7 4" stroke="{a}"/>',
    "axes": '<path d="M6 3v15h15"/><path d="M3 6h3M3 10h3M3 14h3M10 18v3M14 18v3M18 18v3"/>',
    "waveform": '<path d="M2 10h5c1 0 1.5 9.5 3 9.5s2.2-14 4-14S15.5 10 22 10" stroke="{a}"/>',
    "annotations": '<path d="M4 5h16v11H9.5L4 20z"/><path d="M8 9h8M8 12.5h5" stroke="{a}"/>',
}


def svg(body, light):
    """One icon's file: BODY with the dark ink and accents, or all in white (LIGHT)."""
    ink = "#ffffff" if light else STROKE
    colors = dict(s=ink, a="#ffffff" if light else ACCENT, r="#ffffff" if light else DANGER,
                  f="none" if light else FACE)
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" '
            f'stroke="{ink}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">\n'
            + body.format(**colors) + '\n</svg>\n')


def main():
    root = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "analysis", "icons", "buttons")
    for light in (False, True):
        folder = os.path.join(root, "light") if light else root
        os.makedirs(folder, exist_ok=True)
        for f in os.listdir(folder):
            if f.endswith(".svg") and f[:-4] not in ICONS:
                os.remove(os.path.join(folder, f))
        for name, body in ICONS.items():
            with open(os.path.join(folder, name + ".svg"), "w", encoding="utf-8", newline="\n") as fh:
                fh.write(svg(body, light))
    print(f"{len(ICONS)} icons, dark and light, in {root}")


if __name__ == "__main__":
    main()
