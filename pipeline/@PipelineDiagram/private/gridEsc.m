function s = gridEsc(s)
%gridEsc  HTML-escape, then typeset the ASCII arrows / comparisons / units.
s = string(s);
s = replace(s, "&", "&amp;");
s = replace(s, "<", "&lt;");
s = replace(s, ">", "&gt;");
s = replace(s, """", "&quot;");
s = replace(s, "-&gt;", "&rarr;");
s = replace(s, "&gt;=", "&ge;");
s = replace(s, "&lt;=", "&le;");
s = replace(s, "+/-", "&plusmn;");
s = regexprep(s, " u([Vm])\>", " &micro;$1");
end


