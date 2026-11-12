function p = buttonIcon(name, variant)
%buttonIcon  The file of a button's or a section header's icon: analysis/icons/buttons/<NAME>.svg.
%   P = buttonIcon(NAME) is the dark icon, for a light button or a section's
%   pale header ("Icon", buttonIcon("add")). P = buttonIcon(NAME, "light")
%   is its white twin, light/<NAME>.svg, for a dark face. A colored button
%   (styleButton "primary", "confirm" or "danger") takes the white twin by
%   itself, and goes back to the dark one when it loses the color, so a
%   builder always passes the dark one.
%
%   tools/makeButtonIcons.py draws every icon (16 px, as the toolbar's);
%   edit them there, not the files. An unknown NAME is an error.
%
%   See also styleButton, formSection.
arguments
    name (1,1) string
    variant (1,1) string {mustBeMember(variant, ["dark" "light"])} = "dark"
end
persistent root
if isempty(root)
    root = fullfile(fileparts(fileparts(fileparts(mfilename("fullpath")))), "icons", "buttons");
end
if variant == "light"
    p = fullfile(root, "light", name + ".svg");
else
    p = fullfile(root, name + ".svg");
end
if ~isfile(p)
    error("EphysFigGenApp:buttonIcon", "There is no icon %s (tools/makeButtonIcons.py draws them).", p);
end
end
