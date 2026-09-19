function h = htmlTable(T, cls)
%htmlTable  A table as an HTML <table> (numbers to 6 significant digits).
if nargin < 2; cls = ""; end
if ~istable(T) || width(T) == 0
    h = "";
    return
end
names = string(T.Properties.VariableNames);
head = "<tr>" + join("<th>" + htmlEscape(names) + "</th>", "") + "</tr>";
rows = strings(height(T), 1);
for r = 1:height(T)
    cells = strings(1, width(T));
    for c = 1:width(T)
        cells(c) = cellText(T{r, c});
    end
    rows(r) = "<tr>" + join("<td>" + htmlEscape(cells) + "</td>", "") + "</tr>";
end
h = "<table class=""" + cls + """>" + head + join(rows, "") + "</table>";
end


function s = cellText(x)
if iscell(x); x = x{1}; end
if isstring(x) || ischar(x)
    s = strjoin(string(x), ", ");
elseif islogical(x) && isscalar(x)
    if x; s = "yes"; else; s = "no"; end
elseif isnumeric(x)
    if isempty(x)
        s = "";
    else
        s = strjoin(compose("%.6g", double(x(:).')), " ");
    end
elseif isdatetime(x)
    s = string(x);
elseif iscategorical(x)
    s = string(x);
else
    s = "[" + class(x) + "]";
end
if ismissing(s); s = ""; end
end
