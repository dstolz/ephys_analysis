function S = formShow(S, key, tf)
%formShow  Show or hide the rows of form sections that hold KEY.
%   S = formShow(S, KEY, TF) sets S(i).Shown for every row of the sections
%   S (a struct array from formSection) registered with KEY (formRow); the
%   change takes effect with formLayout.
%
%   See also formRow, formLayout.
for i = 1:numel(S)
    for r = 1:numel(S(i).Keys)
        if any(S(i).Keys{r} == key)
            S(i).Shown(r) = tf;
        end
    end
end
end
