function s = htmlEscape(s)
%htmlEscape  Text made safe to put inside HTML (& < > " ').
s = string(s);
s = replace(s, "&", "&amp;");
s = replace(s, "<", "&lt;");
s = replace(s, ">", "&gt;");
s = replace(s, """", "&quot;");
s = replace(s, "'", "&#39;");
end
