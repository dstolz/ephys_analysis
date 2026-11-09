classdef DatasetVariables
    % DatasetVariables  Every rule about dataset variables: what one is, how a dataset's set is kept, changed, logged and put in the outputs.
    %   A variable is a value the user records on a dataset: the probe's
    %   depth, a drug dose, a cohort number. Each has
    %     name         the name data structures use: a valid MATLAB name
    %                  of at most MaxNameLength characters (probeDepth).
    %                  Two variables of a dataset never share a name, not
    %                  even in another case (probeDepth, ProbeDepth)
    %     label        the name people read ("Probe Depth"), 1 to
    %                  MaxLabelLength characters on one line
    %     value        a finite real number (a double scalar) or text (a
    %                  string scalar, at most MaxTextLength characters)
    %     units        optional ("µm"), "" for none
    %     description  optional text, "" for none
    %     created, updated   when the variable was made and last changed
    %                  ("yyyy-MM-dd HH:mm:ss")
    %   The value is a number or text by what it holds; there is no other
    %   type. A number typed as text ("1200") is text.
    %
    %   A set (the variables of one dataset) is a scalar struct with a field
    %   per name, each field an entry struct (label, value, units,
    %   description, created, updated), in the order they were made;
    %   struct() when there are none. jsonencode writes it as the
    %   manifest's "variables" object; parse reads it back.
    %
    %   The history is a struct column, oldest first, one row per change,
    %   kept as the manifest's "variable_history" list. Fields:
    %     time           when ("yyyy-MM-dd HH:mm:ss")
    %     action         "created" | "updated" | "renamed" | "removed"
    %     name           the variable's name (after a rename, the new one)
    %     previous_name  the name before a rename ("" otherwise)
    %     changed        what an update or a rename changed: a cell row of
    %                    "name", "label", "value", "units", "description"
    %                    ({} for created and removed)
    %     user           who changed it (the computer's user name)
    %   The history says that a variable changed and when, never what it
    %   held: only the latest value is kept anywhere (the set). update
    %   makes the rows; nothing else writes them, so the history of a
    %   dataset is complete.
    %
    %   Outputs carry a dataset's variables three ways: a struct of values
    %   (values: S.probeDepth = 1200, in MAT files and the analysis
    %   structs), a table of their definitions (info: Name, Label, Value,
    %   Units, Description, Created, Updated) and, in tables of datasets or
    %   units, a column per variable named ColumnPrefix + name
    %   (var_probeDepth) with its label and units in the table's
    %   VariableDescriptions and VariableUnits (columns). The prefix keeps
    %   them apart from every other column (subject, depth, tags, ...).
    %
    %   DatasetVariables holds every rule; the dialog (VariableDialog), the
    %   writer (writeManifestVariables), EphysDataset and the outputs call it
    %   and hold none of their own. It never sees a dataset: it works on
    %   sets and histories.
    %
    %   Error ids: DatasetVariables:BadName, :BadLabel, :BadValue, :BadUnits,
    %   :BadDescription, :Duplicate (two variables of one set with a name
    %   that differs only in case), :BadInput.
    %
    %   Reading text:      suggestName, suggestLabel, checkName, checkLabel,
    %                      parseValue, valueText, typeOf
    %   One set:           entry, require, parse, parseHistory, update,
    %                      values, info, toText, displayLabel, names
    %   Several sets:      columns, vocabulary
    %   History:           emptyHistory, historyCell, stamp, user
    %
    %   Example
    %     s = DatasetVariables.require(struct('probeDepth', ...
    %         DatasetVariables.entry("Probe Depth", 1200, Units="µm")));
    %     [s, h] = DatasetVariables.update(struct(), DatasetVariables.emptyHistory(), s);
    %     DatasetVariables.values(s)        % struct('probeDepth', 1200)
    %     DatasetVariables.suggestName("Probe Depth (µm)")   % "probeDepthUm"
    %
    %   See also writeManifestVariables, VariableDialog, EphysDataset.setVariables.

    properties (Constant)
        ColumnPrefix = "var_"              % tables: one column per variable, var_<name>
        MaxNameLength = namelengthmax - 4  % so var_<name> is a valid table column name too
        MaxLabelLength = 80
        MaxUnitsLength = 20
        MaxTextLength = 500                % a text value
        MaxDescriptionLength = 1000
        Fields = ["label" "value" "units" "description"]   % what a person edits; created/updated are kept here
        Actions = ["created" "updated" "renamed" "removed"]
        DisplayDelimiter = "; "            % toText: table cells
        TimeFormat = 'yyyy-MM-dd HH:mm:ss'
    end

    methods (Static)
        %% --- Reading text ------------------------------------------------
        function name = suggestName(label, taken)
            %suggestName  A valid, unused variable name made from a label: lower camel case.
            %   NAME = DatasetVariables.suggestName(LABEL) joins LABEL's words
            %   (runs of letters and digits; µ reads as u) in lower camel
            %   case: "Probe Depth" -> "probeDepth", "LFP power" ->
            %   "lfpPower", "Probe depth (µm)" -> "probeDepthUm". A first
            %   word in capitals is lowercased whole; the other words keep
            %   their case after a capital first letter. A name that would
            %   start with a digit gets an "x" first ("3rd day" ->
            %   "x3rdDay"). It is cut to MaxNameLength. NAME is "" when
            %   LABEL holds no letter or digit.
            %   NAME = suggestName(LABEL, TAKEN) also keeps clear of the
            %   names in TAKEN (any case), adding a number: "probeDepth2".
            arguments
                label
                taken = strings(1, 0)
            end
            s = string(label);
            if ~isscalar(s) || ismissing(s); name = ""; return; end
            s = replace(s, ["µ" "μ"], "u");
            words = regexp(char(s), '[A-Za-z0-9]+', 'match');
            if isempty(words); name = ""; return; end
            w1 = words{1};
            if numel(w1) > 1 && all(isstrprop(w1(isletter(w1)), 'upper'))
                w1 = lower(w1);
            else
                w1(1) = lower(w1(1));
            end
            for k = 2:numel(words)
                words{k}(1) = upper(words{k}(1));
            end
            name = [w1, words{2:end}];
            if ~isletter(name(1)); name = ['x' name]; end
            name = string(name(1:min(end, DatasetVariables.MaxNameLength)));
            taken = lower(string(taken));
            if any(lower(name) == taken)
                base = extractBefore(name, min(strlength(name), DatasetVariables.MaxNameLength - 3) + 1);
                k = 2;
                while any(lower(base + k) == taken); k = k + 1; end
                name = base + k;
            end
        end

        function label = suggestLabel(name)
            %suggestLabel  A label made from a variable name: "probeDepth" -> "Probe Depth".
            %   For a script that sets a variable without a label
            %   (writeManifestVariables). The words of a camel-case or
            %   underscored name, the first capitalized.
            s = char(string(name));
            if isempty(s); label = ""; return; end
            s = regexprep(s, '_+', ' ');
            s = regexprep(s, '([a-z0-9])([A-Z])', '$1 $2');
            s = regexprep(s, '([A-Za-z])([0-9])', '$1 $2');
            s = strtrim(regexprep(s, '\s+', ' '));
            parts = split(string(s), " ");
            for k = 1:numel(parts)
                p = char(parts(k));
                if k == 1 || ~(numel(p) > 1 && all(isstrprop(p(isletter(p)), 'upper')))
                    if k > 1; p = lower(p); end
                    p(1) = upper(p(1));
                end
                parts(k) = string(p);
            end
            label = join(parts, " ");
        end

        function [ok, why] = checkName(name, taken)
            %checkName  Whether NAME can name a variable: [OK, WHY] = checkName(NAME, TAKEN).
            %   A valid MATLAB name (isvarname: a letter first, then
            %   letters, digits and underscores, not a keyword) of at most
            %   MaxNameLength characters, not in TAKEN in any case. WHY is
            %   "" when OK, else a sentence.
            arguments
                name
                taken = strings(1, 0)
            end
            ok = false;
            n = string(name);
            if ~isscalar(n) || ismissing(n) || strlength(n) == 0
                why = "Give the variable a name.";
            elseif ~isvarname(n) && strlength(n) <= namelengthmax
                why = sprintf('"%s" is not a valid name: start with a letter; use letters, digits and _ only (no spaces).', n);
                if iskeyword(n); why = sprintf('"%s" is a MATLAB keyword: choose another name.', n); end
            elseif strlength(n) > DatasetVariables.MaxNameLength
                why = sprintf('The name is %d characters long; at most %d.', strlength(n), DatasetVariables.MaxNameLength);
            elseif any(lower(n) == lower(string(taken)))
                why = sprintf('Another variable is named "%s" already (names differ by more than case).', n);
            else
                ok = true;
                why = "";
            end
            why = string(why);
        end

        function [ok, why] = checkLabel(label)
            %checkLabel  Whether LABEL can be a variable's label: one line of 1 to MaxLabelLength characters.
            ok = false;
            s = string(label);
            if ~isscalar(s) || ismissing(s) || strlength(strtrim(s)) == 0
                why = "Give the variable a label (the name people read).";
            elseif contains(s, [string(newline) string(char(13))])
                why = "The label must fit on one line.";
            elseif strlength(strtrim(s)) > DatasetVariables.MaxLabelLength
                why = sprintf('The label is %d characters long; at most %d.', strlength(strtrim(s)), DatasetVariables.MaxLabelLength);
            else
                ok = true;
                why = "";
            end
            why = string(why);
        end

        function [value, ok, why] = parseValue(text, type)
            %parseValue  A value from what a person typed: [VALUE, OK, WHY] = parseValue(TEXT, TYPE).
            %   TYPE "auto" (default) gives a number when TEXT reads as a
            %   finite real number (str2double: "1200", "-3.5", "1e-3"),
            %   else the text; "number" requires a number; "text" keeps it
            %   as text. TEXT is trimmed. A number already (a double
            %   scalar) is taken as it is under "auto" and "number".
            %   Empty text gives VALUE = [] with OK true: no value (the
            %   variable is not set). WHY is "" when OK.
            arguments
                text
                type (1,1) string {mustBeMember(type, ["auto" "number" "text"])} = "auto"
            end
            ok = true; why = "";
            if isnumeric(text) || islogical(text)
                if isscalar(text) && isreal(text) && isfinite(double(text)) && type ~= "text"
                    value = double(text);
                    return
                elseif type == "text" && isscalar(text)
                    value = DatasetVariables.valueText(double(text));
                    return
                end
                value = []; ok = false;
                why = "A number value must be one finite real number.";
                return
            end
            s = string(text);
            if ~isscalar(s); value = []; ok = false; why = "A value must be one number or one piece of text."; return; end
            if ismissing(s); s = ""; end
            s = strtrim(s);
            if strlength(s) == 0; value = []; return; end
            x = str2double(s);
            isNum = ~isnan(x) && isfinite(x) && isreal(x);
            switch type
                case "text"
                    value = s;
                case "number"
                    if isNum
                        value = x;
                    else
                        value = []; ok = false;
                        why = sprintf('"%s" is not a number.', s);
                        return
                    end
                otherwise
                    if isNum; value = x; else; value = s; end
            end
            if isstring(value) && strlength(value) > DatasetVariables.MaxTextLength
                value = []; ok = false;
                why = sprintf('The text is %d characters long; at most %d.', strlength(s), DatasetVariables.MaxTextLength);
            end
        end

        function s = valueText(v)
            %valueText  A value as text: a number with up to 15 significant digits, text as it is, "" for none.
            if isempty(v)
                s = "";
            elseif isnumeric(v) || islogical(v)
                s = string(sprintf('%.15g', double(v)));
            else
                s = string(v);
            end
        end

        function t = typeOf(v)
            %typeOf  "number" or "text" ("" for no value).
            if isempty(v)
                t = "";
            elseif isnumeric(v) || islogical(v)
                t = "number";
            else
                t = "text";
            end
        end

        %% --- One set -----------------------------------------------------
        function e = entry(label, value, opts)
            %entry  One variable's entry, checked: E = entry(LABEL, VALUE, Units=, Description=, Created=, Updated=).
            %   VALUE is a number or text (a number given as text stays
            %   text: parseValue reads what a person typed). Errors
            %   DatasetVariables:BadLabel, :BadValue, :BadUnits,
            %   :BadDescription.
            arguments
                label
                value
                opts.Units = ""
                opts.Description = ""
                opts.Created = ""
                opts.Updated = ""
            end
            [ok, why] = DatasetVariables.checkLabel(label);
            if ~ok; error('DatasetVariables:BadLabel', '%s', why); end
            if isnumeric(value) || islogical(value)
                [v, ok, why] = DatasetVariables.parseValue(value, "number");
            else
                [v, ok, why] = DatasetVariables.parseValue(value, "text");
            end
            if ~ok; error('DatasetVariables:BadValue', '%s', why); end
            if isempty(v); error('DatasetVariables:BadValue', 'A variable needs a value.'); end
            u = strtrim(DatasetVariables.text1(opts.Units, 'DatasetVariables:BadUnits', "Units"));
            if strlength(u) > DatasetVariables.MaxUnitsLength || contains(u, newline)
                error('DatasetVariables:BadUnits', 'Units are one line of at most %d characters.', DatasetVariables.MaxUnitsLength);
            end
            d = strtrim(DatasetVariables.text1(opts.Description, 'DatasetVariables:BadDescription', "The description"));
            if strlength(d) > DatasetVariables.MaxDescriptionLength
                error('DatasetVariables:BadDescription', 'The description is %d characters long; at most %d.', ...
                    strlength(d), DatasetVariables.MaxDescriptionLength);
            end
            e = struct('label', strtrim(string(label)), 'value', v, 'units', u, 'description', d, ...
                'created', string(opts.Created), 'updated', string(opts.Updated));
        end

        function s = require(s)
            %require  A set checked whole: S = require(S); errors on any bad entry.
            %   S is a scalar struct of entries (or struct([]) / [] for none).
            %   Each entry is made again through entry (so text is a string
            %   scalar and a number a double) and every name is checked
            %   (checkName, also against the set's other names). Errors
            %   DatasetVariables:BadName, :Duplicate and entry's.
            if isempty(s) && ~(isstruct(s) && isscalar(s)); s = struct(); return; end
            if ~(isstruct(s) && isscalar(s))
                error('DatasetVariables:BadInput', 'A set of variables is a scalar struct, one field per name.');
            end
            names = string(fieldnames(s)).';
            out = struct();
            for k = 1:numel(names)
                n = names(k);
                [ok, why] = DatasetVariables.checkName(n, names(1:k-1));
                if ~ok
                    id = 'DatasetVariables:BadName';
                    if any(lower(n) == lower(names(1:k-1))); id = 'DatasetVariables:Duplicate'; end
                    error(id, '%s', why);
                end
                e = s.(n);
                if ~(isstruct(e) && isscalar(e) && all(isfield(e, {'label', 'value'})))
                    error('DatasetVariables:BadInput', 'Variable %s needs a label and a value.', n);
                end
                out.(n) = DatasetVariables.entry(e.label, e.value, Units=fieldOr(e, 'units', ""), ...
                    Description=fieldOr(e, 'description', ""), Created=fieldOr(e, 'created', ""), ...
                    Updated=fieldOr(e, 'updated', ""));
            end
            s = out;
        end

        function [s, bad] = parse(raw)
            %parse  A set from what jsondecode read (the manifest's "variables"); never errors.
            %   [S, BAD] = parse(RAW): the entries that are valid (a name,
            %   a label, a number or text value; checked as require does),
            %   in the file's order; BAD names those left out (a string
            %   row). RAW [] or anything not a struct gives struct().
            s = struct();
            bad = strings(1, 0);
            if ~(isstruct(raw) && isscalar(raw)); return; end
            for n = string(fieldnames(raw)).'
                try
                    e = raw.(n);
                    if ~(isstruct(e) && isscalar(e) && all(isfield(e, {'label', 'value'}))); error('x:x', 'x'); end
                    [ok, why] = DatasetVariables.checkName(n, string(fieldnames(s)).');
                    if ~ok; error('x:x', '%s', why); end
                    v = e.value;
                    if ischar(v); v = string(v); end
                    s.(n) = DatasetVariables.entry(e.label, v, Units=textOr(e, 'units'), ...
                        Description=textOr(e, 'description'), Created=textOr(e, 'created'), Updated=textOr(e, 'updated'));
                catch
                    bad(end+1) = n; %#ok<AGROW>
                end
            end
        end

        function h = parseHistory(raw)
            %parseHistory  The history from what jsondecode read (the manifest's "variable_history"); never errors.
            %   A struct array, or a cell of structs (jsondecode's reading of
            %   rows whose fields differ). Rows without a time, an action of
            %   Actions and a name are left out; the others get every field
            %   of emptyHistory. A struct column, in the file's order.
            h = DatasetVariables.emptyHistory();
            if isstruct(raw)
                raw = num2cell(raw(:));
            elseif ~iscell(raw)
                return
            end
            for k = 1:numel(raw)
                r = raw{k};
                if ~(isstruct(r) && isscalar(r) && all(isfield(r, {'time', 'action', 'name'}))); continue; end
                try
                    row = DatasetVariables.historyRow(string(r.action), string(r.name), ...
                        string(r.time), textOr(r, 'user'), textOr(r, 'previous_name'), changedOf(r));
                catch
                    continue
                end
                if ~ismember(row.action, DatasetVariables.Actions) || row.time == "" || row.name == ""; continue; end
                h(end+1, 1) = row; %#ok<AGROW>
            end
        end

        function [s, h, added] = update(old, h, new, opts)
            %update  The new set, with created/updated stamps, and its history rows: [S, H, ADDED] = update(OLD, H, NEW, ...).
            %   OLD is the set before, H its history, NEW the set wanted
            %   (entries as entry makes them; their created/updated are
            %   ignored). For each name of NEW: not in OLD -> "created";
            %   in OLD with a label, value, units or description that
            %   differs -> "updated" (created kept); the same -> kept as it
            %   was, no row. Names of OLD missing from NEW -> "removed".
            %   Renamed= ([k x 2] string, old name then new name; a pair
            %   whose old name is not in OLD or new name not in NEW is
            %   ignored) turns a removal and a creation into one
            %   "renamed" row (created kept). S is NEW in NEW's order with
            %   the stamps set; H gains a row per change (ADDED), in NEW's
            %   order with the removals last. Options Time= (default
            %   now), User= (default DatasetVariables.user()). NEW is
            %   checked first (require): an error changes nothing.
            arguments
                old
                h
                new
                opts.Renamed string = strings(0, 2)
                opts.Time (1,1) string = DatasetVariables.stamp()
                opts.User (1,1) string = DatasetVariables.user()
            end
            old = DatasetVariables.require(old);
            new = DatasetVariables.require(new);
            if isempty(h); h = DatasetVariables.emptyHistory(); end
            ren = reshape(opts.Renamed, [], 2);
            oldNames = string(fieldnames(old)).';
            newNames = string(fieldnames(new)).';
            ren = ren(ismember(ren(:, 1), oldNames) & ismember(ren(:, 2), newNames) & ~ismember(ren(:, 2), oldNames), :);
            added = DatasetVariables.emptyHistory();
            s = struct();
            for n = newNames
                e = new.(n);
                r = find(ren(:, 2) == n, 1);
                if ~isempty(r)
                    was = old.(ren(r, 1));
                    chg = ["name", DatasetVariables.changedFields(was, e)];
                    e.created = was.created;
                    e.updated = opts.Time;
                    added(end+1, 1) = DatasetVariables.historyRow("renamed", n, opts.Time, opts.User, ren(r, 1), chg); %#ok<AGROW>
                elseif isfield(old, n)
                    was = old.(n);
                    chg = DatasetVariables.changedFields(was, e);
                    e.created = was.created;
                    e.updated = was.updated;
                    if ~isempty(chg)
                        e.updated = opts.Time;
                        added(end+1, 1) = DatasetVariables.historyRow("updated", n, opts.Time, opts.User, "", chg); %#ok<AGROW>
                    end
                else
                    e.created = opts.Time;
                    e.updated = opts.Time;
                    added(end+1, 1) = DatasetVariables.historyRow("created", n, opts.Time, opts.User, "", strings(1, 0)); %#ok<AGROW>
                end
                s.(n) = e;
            end
            for n = setdiff(oldNames, [newNames, ren(:, 1).'], 'stable')
                added(end+1, 1) = DatasetVariables.historyRow("removed", n, opts.Time, opts.User, "", strings(1, 0)); %#ok<AGROW>
            end
            h = [h(:); added];
        end

        function v = values(s)
            %values  The values alone: a struct with a field per name (S.probeDepth = 1200); struct() when none.
            v = struct();
            if ~(isstruct(s) && isscalar(s)); return; end
            for n = string(fieldnames(s)).'
                v.(n) = s.(n).value;
            end
        end

        function T = info(s)
            %info  The definitions as a table: Name, Label, Value, Units, Description, Created, Updated.
            %   Value is a cell column (a number or a string each); the
            %   others are strings. A row per variable, in the set's order;
            %   no rows (but every column) when there are none.
            names = strings(0, 1);
            if isstruct(s) && isscalar(s); names = string(fieldnames(s)); end
            n = numel(names);
            [lab, uni, des, cre, upd] = deal(strings(n, 1));
            val = cell(n, 1);
            for k = 1:n
                e = s.(names(k));
                lab(k) = e.label; val{k} = e.value; uni(k) = e.units; des(k) = e.description;
                cre(k) = e.created; upd(k) = e.updated;
            end
            T = table(names, lab, val, uni, des, cre, upd, ...
                'VariableNames', {'Name', 'Label', 'Value', 'Units', 'Description', 'Created', 'Updated'});
        end

        function s = fromInfo(T)
            %fromInfo  The set back from an info table (info's columns); never errors.
            %   Rows that are not a valid variable are left out. A set
            %   (a struct) is returned as it is, so a caller can take
            %   either.
            if isstruct(T); s = T; return; end
            s = struct();
            if ~istable(T) || ~all(ismember({'Name', 'Label', 'Value'}, T.Properties.VariableNames)); return; end
            raw = struct();
            for k = 1:height(T)
                e = struct('label', T.Label(k), 'value', T.Value(k));
                if iscell(e.value); e.value = e.value{1}; end
                for f = ["Units" "Description" "Created" "Updated"]
                    if ismember(f, T.Properties.VariableNames); e.(lower(f)) = T.(f)(k); end
                end
                n = string(T.Name(k));
                if isvarname(n); raw.(n) = e; end
            end
            s = DatasetVariables.parse(raw);
        end

        function t = toText(s, delimiter)
            %toText  The set as one line for a table cell: "probeDepth = 1200 µm; cohort = 3" ("" for none).
            arguments
                s
                delimiter (1,1) string = DatasetVariables.DisplayDelimiter
            end
            t = "";
            if ~(isstruct(s) && isscalar(s)); return; end
            parts = strings(1, 0);
            for n = string(fieldnames(s)).'
                e = s.(n);
                p = n + " = " + DatasetVariables.valueText(e.value);
                if e.units ~= ""; p = p + " " + e.units; end
                parts(end+1) = p; %#ok<AGROW>
            end
            t = join(parts, delimiter);
            if isempty(t) || ismissing(t); t = ""; end
        end

        function t = displayLabel(label, units)
            %displayLabel  "Probe Depth (µm)": the label with its units, or the label alone.
            t = string(label);
            if nargin > 1 && string(units) ~= ""; t = t + " (" + string(units) + ")"; end
        end

        function n = names(s)
            %names  The names of a set, a string row (in its order).
            n = strings(1, 0);
            if isstruct(s) && isscalar(s); n = string(fieldnames(s)).'; end
        end

        %% --- Several sets ------------------------------------------------
        function T = columns(sets, opts)
            %columns  A column per variable for a table of datasets: T = columns(SETS), one row per set.
            %   SETS is a cell (one set per row; an info table is taken
            %   too, fromInfo). T has a column per name
            %   used in any set, ColumnPrefix + name (var_probeDepth), in
            %   the order they first appear. A name holding numbers in
            %   every set that has it is a double column (NaN where a set
            %   lacks it); otherwise a string column (missing where a set
            %   lacks it; numbers as valueText). VariableDescriptions holds
            %   each one's label (the first set's that has it) and
            %   VariableUnits its units. A table with no columns when no
            %   set has a variable.
            %   T = columns(SETS, Rows=IDX) gives a row per element of IDX
            %   (indices into SETS), so a table of units takes the columns
            %   of each unit's dataset: columns(SETS, Rows=datasetOfUnit).
            arguments
                sets cell
                opts.Rows = "all"
            end
            if isequal(opts.Rows, "all")
                rows = (1:numel(sets)).';
            else
                rows = reshape(double(opts.Rows), [], 1);
            end
            sets = cellfun(@DatasetVariables.fromInfo, sets, 'UniformOutput', false);
            names = strings(1, 0);
            for k = 1:numel(sets)
                names = [names, setdiff(DatasetVariables.names(sets{k}), names, 'stable')]; %#ok<AGROW>
            end
            T = table('Size', [numel(rows) 0], 'VariableTypes', {}, 'VariableNames', {});
            descr = strings(1, 0);
            units = strings(1, 0);
            for n = names
                isNum = true;
                lab = ""; uni = "";
                for k = 1:numel(sets)
                    s = sets{k};
                    if isstruct(s) && isscalar(s) && isfield(s, n)
                        isNum = isNum && isnumeric(s.(n).value);
                        if lab == ""; lab = s.(n).label; uni = s.(n).units; end
                    end
                end
                if isNum; col = NaN(numel(sets), 1); else; col = strings(numel(sets), 1); col(:) = missing; end
                for k = 1:numel(sets)
                    s = sets{k};
                    if isstruct(s) && isscalar(s) && isfield(s, n)
                        if isNum; col(k) = s.(n).value; else; col(k) = DatasetVariables.valueText(s.(n).value); end
                    end
                end
                T.(DatasetVariables.ColumnPrefix + n) = col(rows);
                descr(end+1) = lab; %#ok<AGROW>
                units(end+1) = uni; %#ok<AGROW>
            end
            if ~isempty(names)
                T.Properties.VariableDescriptions = cellstr(descr);
                T.Properties.VariableUnits = cellstr(units);
            end
        end

        function V = vocabulary(sets)
            %vocabulary  The variables in use across sets: a struct column with name, label, units, description, type and count.
            %   One row per name (the first set's definition that has it),
            %   in the order they first appear; type "number", "text" or
            %   "mixed"; count = how many sets hold it. The dialog offers
            %   them under Use existing, so a variable keeps one name,
            %   label and units across datasets.
            V = struct('name', {}, 'label', {}, 'units', {}, 'description', {}, 'type', {}, 'count', {});
            V = V(:);
            for k = 1:numel(sets)
                s = sets{k};
                for n = DatasetVariables.names(s)
                    e = s.(n);
                    t = DatasetVariables.typeOf(e.value);
                    i = find(string({V.name}) == n, 1);
                    if isempty(i)
                        V(end+1, 1) = struct('name', n, 'label', e.label, 'units', e.units, ...
                            'description', e.description, 'type', t, 'count', 1); %#ok<AGROW>
                    else
                        V(i).count = V(i).count + 1;
                        if V(i).type ~= t; V(i).type = "mixed"; end
                    end
                end
            end
        end

        %% --- History -----------------------------------------------------
        function h = emptyHistory()
            %emptyHistory  A history with no rows (0x1 struct, every field).
            h = struct('time', {}, 'action', {}, 'name', {}, 'previous_name', {}, 'changed', {}, 'user', {});
            h = h(:);
        end

        function c = historyCell(h)
            %historyCell  The history as jsonencode should see it: a cell column, so one row is still a JSON list.
            c = cell(numel(h), 1);
            for k = 1:numel(h)
                r = h(k);
                r.changed = cellstr(r.changed);   % a JSON list, also of one
                if isempty(r.changed); r.changed = {}; end
                c{k} = r;
            end
        end

        function t = stamp()
            %stamp  Now, as the manifest writes times ("yyyy-MM-dd HH:mm:ss").
            t = string(datetime('now', 'Format', DatasetVariables.TimeFormat));
        end

        function u = user()
            %user  The computer's user name ("" when unknown).
            u = string(getenv('USERNAME'));
            if u == ""; u = string(getenv('USER')); end
        end
    end

    methods (Static, Access = private)
        function chg = changedFields(was, e)
            chg = strings(1, 0);
            for f = DatasetVariables.Fields
                a = was.(f); b = e.(f);
                if ~(isequal(class(a), class(b)) && isequal(a, b)); chg(end+1) = f; end %#ok<AGROW>
            end
        end

        function r = historyRow(action, name, time, user, previousName, changed)
            r = struct('time', string(time), 'action', string(action), 'name', string(name), ...
                'previous_name', string(previousName), 'changed', reshape(string(changed), 1, []), 'user', string(user));
        end

        function s = text1(v, id, what)
            if ischar(v) || (isstring(v) && isscalar(v))
                s = string(v);
                if ismissing(s); s = ""; end
            elseif isempty(v)
                s = "";
            else
                error(id, '%s must be text.', what);
            end
        end
    end
end


function v = fieldOr(s, f, default)
v = default;
if isfield(s, f); v = s.(f); end
if isempty(v) && ~ischar(v) && ~isstring(v); v = default; end
end


function t = textOr(s, f)
t = "";
if isfield(s, f) && (ischar(s.(f)) || (isstring(s.(f)) && isscalar(s.(f))))
    t = string(s.(f));
end
end



function c = changedOf(r)
c = strings(1, 0);
if isfield(r, 'changed') && ~isempty(r.changed)
    try
        c = reshape(string(r.changed), 1, []);
    catch
    end
end
end
