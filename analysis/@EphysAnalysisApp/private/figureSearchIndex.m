function X = figureSearchIndex(S, U)
%figureSearchIndex  The figure editor's searchable rows, read from the editor as built: the supersections, the sections and every row's label.
%   X = figureSearchIndex(S, U) takes the editor's sections S (formSection,
%   after formLayout found each row's controls) and supersections U, and
%   returns one entry per thing a search can go to, in the editor's order:
%     a supersection         Section "", Super its name, Row -2
%     a section's header     Row 0 (its title is read when listed: "PSTH
%                            options")
%     a control in a header  Row -1: "Use default", "Same as the figure"
%     a form row (formRow)   Row r: its label (a row without one: the text
%                            of its first check box or button); rows of
%                            text only (a summary, a note) are left out
%     a row of a body another builder filled (the event reference, epoch
%                            window, trial selection and panel alignment
%                            controls)   Row -1: each label ("Line:")
%                            with the control right of it, each check box
%                            and button with a text
%   Fields: Section, Super, Row, Label (as shown, without its colon), Words
%   (lower case: the label, the row's other labels and texts, then its
%   controls' tooltips, for the match), LabelWords (lower case: the
%   label's), Target (the control the search focuses), Flash (what it
%   highlights: the label, else the control) and Keys (the row's formRow
%   keys: why a hidden row is hidden, figureRowReason). New rows join
%   without a change here.
%
%   See also EphysAnalysisApp.onFigureSearch, EphysAnalysisApp.gotoFigureRow, formRow.
X = struct('Section', {}, 'Super', {}, 'Row', {}, 'Label', {}, 'Words', {}, 'LabelWords', {}, 'Target', {}, ...
    'Flash', {}, 'Keys', {});
for u = 1:numel(U)
    X(end+1) = entry("", U(u).Name, -2, U(u).Title, "", U(u).Header, U(u).Header, strings(1, 0)); %#ok<AGROW>
end
names = [S.Name];
for name = ordered(names, U)
    s = S(names == name);
    if s.Title ~= ""
        X(end+1) = entry(s.Name, s.Super, 0, s.Title, "", s.Toggle, s.Toggle, strings(1, 0)); %#ok<AGROW>
        for c = interactive(allIn(s.HeaderGrid))
            if c == s.Toggle || ~isprop(c, 'Text'); continue; end
            X(end+1) = entry(s.Name, s.Super, -1, string(c.Text), tipOf(c), c, c, strings(1, 0)); %#ok<AGROW>
        end
    end
    if ~isempty(s.Heights)   % a form: its rows as formRow made them
        for r = 1:numel(s.Heights)
            [label, lab, ctl, more] = rowParts(s.Items{r});
            if isempty(ctl) || label == ""; continue; end
            flash = ctl;
            if ~isempty(lab); flash = lab; end
            X(end+1) = entry(s.Name, s.Super, r, label, more, ctl, flash, s.Keys{r}); %#ok<AGROW>
        end
    else   % a body another builder filled: its labels, check boxes and buttons
        for c = allIn(s.Body)
            if ~strcmp(c.Visible, 'on'); continue; end   % (the panel alignment's own Epoch Diagram button is never shown)
            if isa(c, 'matlab.ui.control.Label')
                label = clean(c.Text);
                if ~endsWith(strtrim(strjoin(string(c.Text), " ")), ":") || strlength(label) < 3; continue; end   % a label, not a value shown ("none")
                ctl = rightOf(c);
                if isempty(ctl); continue; end
                X(end+1) = entry(s.Name, s.Super, -1, label, tipOf(ctl), ctl, c, strings(1, 0)); %#ok<AGROW>
            elseif (isa(c, 'matlab.ui.control.CheckBox') || isa(c, 'matlab.ui.control.Button')) && strlength(clean(c.Text)) >= 3 ...
                    && ~startsWith(string(c.Text), "Edit")
                X(end+1) = entry(s.Name, s.Super, -1, clean(c.Text), tipOf(c), c, c, strings(1, 0)); %#ok<AGROW>
            end
        end
    end
end
end


function e = entry(section, super, row, label, more, target, flash, keys)
label = clean(label);
e = struct('Section', string(section), 'Super', string(super), 'Row', row, 'Label', label, ...
    'Words', lower(label + " " + string(more)), 'LabelWords', lower(label), 'Target', target, 'Flash', flash, 'Keys', keys);
end


function n = ordered(names, U)
%ordered  The sections' names in the editor's order: those in no supersection first, then each supersection's.
inU = [U.Sections];
n = [names(~ismember(names, inU)) inU(ismember(inU, names))];
end


function [label, lab, ctl, more] = rowParts(items)
%rowParts  A form row's label (and its uilabel), the first control to focus, and its other words (inline labels, texts, tooltips).
label = "";
lab = [];
ctl = [];
texts = strings(1, 0);
tips = strings(1, 0);
for c = reshape(items, 1, [])
    if isa(c, 'matlab.ui.control.Label') && isequal(c.Layout.Column, 1)
        label = clean(c.Text);
        lab = c;
        continue
    end
    for d = [c allIn(c)]
        if isa(d, 'matlab.ui.control.Label')
            texts(end+1) = clean(d.Text); %#ok<AGROW>
        elseif ~isempty(interactive(d))
            if isempty(ctl); ctl = d; end
            if isprop(d, 'Text'); texts(end+1) = clean(d.Text); end %#ok<AGROW>
            tips(end+1) = tipOf(d); %#ok<AGROW>
        end
    end
end
if label == "" && ~isempty(texts)
    t = texts(texts ~= "");
    if ~isempty(t); label = t(1); end   % a check box's or a button's text names the row
end
more = strjoin([texts tips], " ");
end


function c = allIn(h)
%allIn  Every UI component inside H (not H), in creation order within each container.
c = gobjects(1, 0);
if isempty(h) || ~isprop(h, 'Children'); return; end
for k = reshape(h.Children, 1, [])
    c = [c k allIn(k)]; %#ok<AGROW>
end
end


function c = interactive(h)
%interactive  The controls of H that take the keyboard focus (edit fields, drop-downs, spinners, check boxes, buttons, lists).
keep = arrayfun(@(x) isa(x, 'matlab.ui.control.EditField') || isa(x, 'matlab.ui.control.NumericEditField') ...
    || isa(x, 'matlab.ui.control.DropDown') || isa(x, 'matlab.ui.control.Spinner') || isa(x, 'matlab.ui.control.CheckBox') ...
    || isa(x, 'matlab.ui.control.Button') || isa(x, 'matlab.ui.control.StateButton') || isa(x, 'matlab.ui.control.ListBox') ...
    || isa(x, 'matlab.ui.control.TextArea'), h);
c = h(keep);
end


function ctl = rightOf(lab)
%rightOf  The control right of a label in its grid row (the alignment controls' layout), else [].
ctl = [];
g = lab.Parent;
if ~isa(g, 'matlab.ui.container.GridLayout'); return; end
r = lab.Layout.Row(1);
col = lab.Layout.Column(1);
best = Inf;
for c = interactive(reshape(g.Children, 1, []))
    cc = c.Layout.Column(1);
    if c.Layout.Row(1) == r && cc > col && cc < best
        best = cc;
        ctl = c;
    end
end
end


function t = tipOf(c)
t = "";
if isprop(c, 'Tooltip'); t = strjoin(string(c.Tooltip), " "); end
end


function s = clean(s)
%clean  A label as shown in a list: one line, no colon at its end.
s = strjoin(string(s), " ");
s = strtrim(regexprep(s, '\s+', ' '));
s = regexprep(s, ':$', '');
end
