function s = svgText(txt, prefix)
%svgText  SVG text ready to inline in HTML, its ids made unique.
%   S = svgText(TXT, PREFIX) drops the XML prolog and DOCTYPE and prefixes
%   every id (and the url(#...) / href="#..." references to them) with
%   PREFIX, so several inlined figures' clip paths do not collide.
s = string(txt);
s = regexprep(s, '<\?xml[^>]*\?>', '');
s = regexprep(s, '<!DOCTYPE[^>]*>', '');
s = regexprep(s, 'id="([^"]+)"', ['id="' char(prefix) '$1"']);
s = regexprep(s, 'url\(#([^)]+)\)', ['url(#' char(prefix) '$1)']);
s = regexprep(s, 'href="#([^"]+)"', ['href="#' char(prefix) '$1"']);
s = strtrim(s);
end
