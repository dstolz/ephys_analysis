classdef test_ClassdefDeclarations < matlab.unittest.TestCase
    %test_ClassdefDeclarations  Every classdef method declaration matches its method file.
    %   MATLAB takes a method's inputs and outputs from its declaration in
    %   the classdef's methods block, and compares them with the function
    %   line of the method file only when the method is called: a
    %   declaration that lists fewer inputs than its file then fails with
    %   "Too many input arguments" (the analysis app once could not open
    %   for this). This suite reads the methods blocks of every @Class
    %   folder in pipeline/ and analysis/ and compares each declaration
    %   ("out = name(obj, a)", "[a, b] = name(obj, opts)", "name(obj)") with
    %   the function line of @Class/name.m: the number of inputs and of
    %   outputs, varargin and varargout apart. An arguments block's
    %   name=value options come in as one input (opts) on both. Abstract
    %   methods and methods whose body is in the classdef are skipped; a
    %   declaration without a method file is reported too. A temporary
    %   class with planted mismatches checks that each one is reported, by
    %   class, method and both lines.
    %
    %   Usage:  runtests("test_ClassdefDeclarations")

    methods (Test)
        function everyDeclarationMatchesItsFile(tc)
            here = fileparts(mfilename('fullpath'));
            roots = [string(here), string(fullfile(fileparts(here), 'analysis'))];
            [P, n] = declarationProblems(roots);
            tc.log(1, sprintf('%d declarations compared with their method files', n));
            tc.verifyGreaterThan(n, 300, sprintf( ...
                'the methods blocks of pipeline/ and analysis/ hold %d declarations with a method file', n));
            tc.verifyEmpty(P, "declarations that do not match their method files:" + newline ...
                + strjoin(problemText(P), newline));
        end

        function plantedMismatchesAreReported(tc)
            tmp = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            writePlantedClass(tmp.Folder);
            [P, n] = declarationProblems(string(tmp.Folder));
            tc.verifyEqual(n, 9, 'the nine declarations with a method file are compared');
            tc.verifyEqual(sort([P.method]), sort(["fewerIn" "moreOut" "varIn" "afterInline" "noFile"]), ...
                ['the planted mismatches are reported and nothing else (abstract, inline, continued, ' ...
                'varargout and arguments-block methods match)']);
            tc.verifyTrue(all([P.class] == "Planted"), 'each problem names its class');
            p = P([P.method] == "fewerIn");
            tc.verifyEqual([p.declaration, p.definition], ["r = fewerIn(obj, a)", "function r = fewerIn(obj, a, b)"], ...
                'a problem carries the declaration and the function line');
            tc.verifyTrue(contains(p.what, "2 inputs") && contains(p.what, "3"), p.what);
            p = P([P.method] == "varIn");
            tc.verifyTrue(contains(p.what, "varargin"), p.what);
            p = P([P.method] == "noFile");
            tc.verifyEqual(p.definition, "", 'a declaration without a method file has no function line');
            txt = problemText(P);
            tc.verifyTrue(any(contains(txt, "Planted.moreOut") & contains(txt, "function r = moreOut(obj)")), ...
                'the report text names class.method and both lines');
        end
    end
end


function [P, n] = declarationProblems(roots)
%declarationProblems  Declarations in the @Class folders under ROOTS that do not match their method files.
%   P is a struct array (class, method, declaration, definition, what) and
%   N the number of declarations compared with a method file.
P = struct('class', {}, 'method', {}, 'declaration', {}, 'definition', {}, 'what', {});
n = 0;
for root = reshape(string(roots), 1, [])
    D = dir(fullfile(root, '@*'));
    for c = reshape(D([D.isdir]), 1, [])
        cls = string(c.name(2:end));
        classFile = fullfile(c.folder, c.name, cls + ".m");
        if ~isfile(classFile); continue; end              % an old-style class folder
        for d = methodDeclarations(classFile)
            if d.name == cls; continue; end              % a constructor lives in the classdef
            mfile = fullfile(c.folder, c.name, d.name + ".m");
            if ~isfile(mfile)
                P(end+1) = problem(cls, d, "", "declared without a method file"); %#ok<AGROW>
                continue
            end
            f = functionLine(mfile);
            n = n + 1;
            what = strings(1, 0);
            if f.nIn ~= d.nIn || f.varIn ~= d.varIn
                what(end+1) = "declared with " + countText(d.nIn, d.varIn, "varargin", "input") ...
                    + ", the file has " + countText(f.nIn, f.varIn, "varargin", "input"); %#ok<AGROW>
            end
            if f.nOut ~= d.nOut || f.varOut ~= d.varOut
                what(end+1) = "declared with " + countText(d.nOut, d.varOut, "varargout", "output") ...
                    + ", the file has " + countText(f.nOut, f.varOut, "varargout", "output"); %#ok<AGROW>
            end
            if ~isempty(what)
                P(end+1) = problem(cls, d, f.text, strjoin(what, "; ")); %#ok<AGROW>
            end
        end
    end
end
end


function p = problem(cls, d, definition, what)
p = struct('class', cls, 'method', d.name, 'declaration', d.text, 'definition', definition, 'what', what);
end


function t = countText(n, var, varName, noun)
t = sprintf("%d %s%s", n, noun, repmat('s', 1, n ~= 1));
if var; t = t + " + " + varName; end
end


function txt = problemText(P)
%problemText  One line per problem: Class.method: what (declaration | function line).
txt = strings(0, 1);
for p = reshape(P, 1, [])
    txt(end+1, 1) = sprintf("%s.%s: %s (classdef: ""%s""; file: ""%s"")", ...
        p.class, p.method, p.what, p.declaration, p.definition); %#ok<AGROW>
end
end


function D = methodDeclarations(file)
%methodDeclarations  The method declarations of the classdef FILE outside Abstract methods blocks.
%   D is a struct array: name, nIn, varIn, nOut, varOut, text. Methods
%   defined in the classdef (function ... end) are not declarations.
D = struct('name', {}, 'nIn', {}, 'varIn', {}, 'nOut', {}, 'varOut', {}, 'text', {});
S = codeStatements(fileread(file));
stack = strings(1, 0);                                  % the blocks open
abstract = false;
for k = 1:numel(S)
    t = char(S(k));
    w = string(regexp(t, '^[A-Za-z]\w*', 'match', 'once'));
    top = "";
    if ~isempty(stack); top = stack(end); end
    if w == "end"
        if ~isempty(stack); stack(end) = []; end
        if top == "classdef"; return; end                % local functions follow
        continue
    end
    switch top
        case ""
            if w == "classdef"; stack(end+1) = w; end %#ok<AGROW>
        case "classdef"
            if any(w == ["methods" "properties" "events" "enumeration"])
                stack(end+1) = w; %#ok<AGROW>
                abstract = w == "methods" && ~isempty(regexp(t, '\<Abstract\>', 'once')) ...
                    && isempty(regexpi(t, '\<Abstract\>\s*=\s*false\>', 'once'));
            end
        case "methods"
            if w == "function"
                stack(end+1) = w; %#ok<AGROW>
            elseif ~abstract
                d = signature(t);
                if ~isempty(d); D(end+1) = d; end %#ok<AGROW>
            end
        case {"properties" "events" "enumeration"}
            % nothing in these opens a block
        otherwise                                       % in a method's body
            if any(w == ["if" "for" "parfor" "while" "switch" "try" "spmd" "function"]) ...
                    || ~isempty(regexp(t, '^arguments\s*(\(\s*\w+\s*\))?$', 'once'))
                stack(end+1) = w; %#ok<AGROW>
            end
    end
end
end


function f = functionLine(file)
%functionLine  The signature of the first function line of FILE (with its continued lines).
L = splitlines(string(fileread(file)));
k = find(~cellfun(@isempty, regexp(cellstr(L), '^\s*function\>', 'once')), 1);
txt = L(k);
while contains(regexprep(txt(end), '%.*$', ''), "...") && k < numel(L)
    k = k + 1;
    txt(end+1) = L(k); %#ok<AGROW>
end
S = codeStatements(strjoin(txt, newline));
f = signature(regexprep(S(1), '^function\s*', ''));
f.text = S(1);
end


function d = signature(t)
%signature  Inputs and outputs of "[a, b] = name(x, y)", "a = name(x)" or "name(x)" ([] if T is none).
d = [];
t = strtrim(char(t));
whole = t;
lhs = '';
k = find(t == '=', 1);
if ~isempty(k) && ~any(t(1:k-1) == '(')                  % "outputs = ..."
    lhs = t(1:k-1);
    t = strtrim(t(k+1:end));
end
name = regexp(t, '^[A-Za-z][\w.]*', 'match', 'once');
if isempty(name); return; end
rest = strtrim(t(numel(name)+1:end));
args = '';
if ~isempty(rest)
    if rest(1) ~= '(' || rest(end) ~= ')'; return; end
    args = rest(2:end-1);
end
outs = names(erase(lhs, ["[" "]"]));
ins = names(args);
d = struct('name', string(name), ...
    'nIn', numel(ins) - any(ins == "varargin"), 'varIn', any(ins == "varargin"), ...
    'nOut', numel(outs) - any(outs == "varargout"), 'varOut', any(outs == "varargout"), ...
    'text', string(whole));
end


function v = names(txt)
v = string(regexp(txt, '[^\s,]+', 'match'));
end


function S = codeStatements(txt)
%codeStatements  The statements of MATLAB code TXT, as trimmed strings.
%   Comments (% and %{ %} blocks) and continuations (...) are taken out,
%   and the code is split at ; , and line ends outside brackets (a line
%   end inside [ ] or { } separates rows, not statements). Strings and
%   char vectors are kept whole: a ' after a name, a number, a closing
%   bracket, a dot or another ' is a transpose, else it opens a char vector.
lines = splitlines(string(txt));
S = strings(1, 0);
cur = '';
depth = 0;
inBlock = false;
for ln = 1:numel(lines)
    L = char(lines(ln));
    t = strtrim(L);
    if inBlock
        inBlock = ~strcmp(t, '%}');
        continue
    end
    if strcmp(t, '%{')
        inBlock = true;
        continue
    end
    cont = false;
    i = 1;
    while i <= numel(L)
        ch = L(i);
        if ch == '%'
            break
        elseif ch == '.' && i + 2 <= numel(L) && strcmp(L(i:i+2), '...')
            cont = true;
            break
        elseif ch == '"' || (ch == '''' && ~(i > 1 && any(L(i-1) == ['A':'Z' 'a':'z' '0':'9' '_)]}.'''])))
            j = i + 1;                                  % to the closing quote ('' and "" escape one)
            while j <= numel(L) && ~(L(j) == ch && (j == numel(L) || L(j+1) ~= ch))
                j = j + 1 + (L(j) == ch);
            end
            cur = [cur L(i:min(j, numel(L)))]; %#ok<AGROW>
            i = j + 1;
            continue
        elseif any(ch == '([{')
            depth = depth + 1;
        elseif any(ch == ')]}')
            depth = max(0, depth - 1);
        elseif (ch == ';' || ch == ',') && depth == 0
            push();
            i = i + 1;
            continue
        end
        cur = [cur ch]; %#ok<AGROW>
        i = i + 1;
    end
    if cont || depth > 0
        cur = [cur ' ']; %#ok<AGROW>
    else
        push();
    end
end
push();

    function push()
        s = strtrim(string(cur));
        if s ~= ""; S(end+1) = s; end
        cur = '';
    end
end


function writePlantedClass(root)
%writePlantedClass  @Planted under ROOT: a classdef with planted mismatches and its method files.
cdir = fullfile(root, '@Planted');
mkdir(cdir);
writeLines(fullfile(cdir, 'Planted.m'), [
    "classdef Planted < handle"
    "    % Planted  Declarations that match their files and some that do not (methods(obj) here is text)."
    "    properties"
    "        Names = [""a"" ""b"""
    "                 ""c"" ""d""]                 % a row break inside brackets"
    "        Text = 'it''s 50% done; end'        % a quote, a percent sign and end in a char vector"
    "        Scale = [1 2]';                     % a transpose"
    "    end"
    "    methods"
    "        r = good(obj, a, b)"
    "        r = fewerIn(obj, a)                 % the file takes (obj, a, b)"
    "        [r, s] = moreOut(obj)               % the file returns one"
    "        varIn(obj, varargin)                % the file takes (obj, a)"
    "        r = ..."
    "            continued(obj, a, ...           % one declaration on three lines"
    "            b)"
    "        varargout = varOut(obj, opts)"
    "        noFile(obj)"
    "        function r = inline(obj, x)"
    "            if x > 0, r = x'; else; r = -x; end"
    "            for k = 1:2"
    "                r = r + obj.Scale(end) * k;"
    "            end"
    "            %{"
    "            end"
    "            %}"
    "        end"
    "        r = afterInline(obj, a, b)          % the file takes (obj, a)"
    "    end"
    "    methods (Abstract)"
    "        r = abstractOne(obj, a)"
    "    end"
    "    methods (Static, Access = private)"
    "        r = staticGood(a)"
    "        [a, b] = twoOut(x)"
    "    end"
    "end"
    ""
    "function localHelper()"
    "end"]);
writeLines(fullfile(cdir, 'good.m'), ["function r = good(obj, a, b)" "r = [obj a b];" "end"]);
writeLines(fullfile(cdir, 'fewerIn.m'), ["function r = fewerIn(obj, a, b)" "r = [obj a b];" "end"]);
writeLines(fullfile(cdir, 'moreOut.m'), ["function r = moreOut(obj)" "r = obj;" "end"]);
writeLines(fullfile(cdir, 'varIn.m'), ["function varIn(obj, a) %#ok<INUSD>" "end"]);
writeLines(fullfile(cdir, 'continued.m'), ["function r = continued(obj, ...  first" "    a, b)" "r = [obj a b];" "end"]);
writeLines(fullfile(cdir, 'varOut.m'), ["function varargout = varOut(obj, opts)" "arguments" "    obj" ...
    "    opts.Name (1,1) string = """"" "end" "varargout = {obj, opts};" "end"]);
writeLines(fullfile(cdir, 'afterInline.m'), ["function r = afterInline(obj, a)" "r = [obj a];" "end"]);
writeLines(fullfile(cdir, 'staticGood.m'), ["% help before the function line" "function r = staticGood(a)" ...
    "arguments" "    a (1,1) double = 1" "end" "r = a;" "end"]);
writeLines(fullfile(cdir, 'twoOut.m'), ["function [a, b] = twoOut(x)" "a = x; b = x;" "end"]);
end


function writeLines(file, lines)
fid = fopen(file, 'w');
fprintf(fid, '%s\n', lines);
fclose(fid);
end
