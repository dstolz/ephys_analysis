function name = figureFileName(pattern, tokens, opts)
%figureFileName  Fill the {Token} placeholders of a file-name or folder pattern.
%   NAME = figureFileName(PATTERN, TOKENS) replaces each {Token} of PATTERN
%   by TOKENS.(Token) (text or a number) for a figure's file name (no
%   extension): tokens Name (dataset), Plot (figure id), Kind, Group, Unit,
%   Index (page) and Date (default: today, yyyyMMdd). Each value has every
%   character outside [A-Za-z0-9_-.] replaced by "_", e.g.
%     figureFileName("{Name}_{Plot}_{Index}", struct('Name', "SYNTH-01_260918_101500", ...
%         'Plot', "psth_stim", 'Index', 2))   % "SYNTH-01_260918_101500_psth_stim_2"
%
%   NAME = figureFileName(PATTERN, TOKENS, Kind="folder") fills a folder
%   pattern instead: tokens OutputFolder (the dataset's output folder),
%   OutputRoot, Root, Name and Date; path values are used as they are.
%
%   TEXT = figureFileName(TEXT, VALUES, Kind="label") fills a figure's
%   label text (a title, an axis label, a layer's name, a note) with the
%   label variables (figureLabelVariables' V): each {Name} that is a field
%   of VALUES becomes its value as it is; any other brace (a name not on
%   the list, TeX's x^{2}) is left as typed, and nothing is an error.
%
%   Errors: figureFileName:UnknownToken (a token this kind does not have),
%   figureFileName:MissingToken (no value given), figureFileName:BadPattern
%   (an unmatched brace, or a file name holding \ / : * ? " < > |).
%
%   See also exportFigure, EphysAnalysisConfig.validate, figureLabelVariables.

arguments
    pattern (1,1) string
    tokens (1,1) struct = struct()
    opts.Kind (1,1) string {mustBeMember(opts.Kind, ["file" "folder" "label"])} = "file"
end

if opts.Kind == "label"
    name = pattern;
    if ~contains(name, "{"); return; end
    found = regexp(pattern, '\{(\w+)\}', 'tokens');
    for tok = reshape(unique(string(cellfun(@(c) c{1}, found, 'UniformOutput', false))), 1, [])
        if ~isfield(tokens, tok); continue; end
        v = string(tokens.(tok));
        name = replace(name, "{" + tok + "}", strjoin(reshape(v(~ismissing(v)), 1, []), ", "));
    end
    return
end
if opts.Kind == "file"
    allowed = ["Name" "Plot" "Kind" "Group" "Unit" "Index" "Date"];
    pathTokens = string.empty(1, 0);
else
    allowed = ["OutputFolder" "OutputRoot" "Root" "Name" "Date"];
    pathTokens = ["OutputFolder" "OutputRoot" "Root"];
end
if ~isfield(tokens, 'Date')
    tokens.Date = string(datetime('now', 'Format', 'yyyyMMdd'));
end
if contains(regexprep(pattern, '\{\w*\}', ''), ["{" "}"])
    error('figureFileName:BadPattern', 'Unmatched brace in "%s".', pattern);
end
name = pattern;
found = regexp(pattern, '\{(\w*)\}', 'tokens');
for k = 1:numel(found)
    tok = string(found{k}{1});
    if ~ismember(tok, allowed)
        error('figureFileName:UnknownToken', 'Unknown token {%s} in "%s" (%s patterns take %s).', ...
            tok, pattern, opts.Kind, strjoin("{" + allowed + "}", " "));
    end
    if ~isfield(tokens, tok)
        error('figureFileName:MissingToken', 'No value for {%s} in "%s".', tok, pattern);
    end
    v = strjoin(reshape(string(tokens.(tok)), 1, []), "_");
    if ~ismember(tok, pathTokens)
        v = regexprep(v, '[^\w\-\.]', '_');
    end
    name = replace(name, "{" + tok + "}", v);
end
if opts.Kind == "file" && ~isempty(regexp(name, '[\\/:*?"<>|]', 'once'))
    error('figureFileName:BadPattern', 'The file name "%s" holds a character not allowed in file names (\\ / : * ? " < > |).', name);
end
end
