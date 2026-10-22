function F = applyChanges(F, D, T, changes)
%applyChanges  Give the targets T (changeTargets' rows) the changed values.
%   F = EphysAnalysisConfig.applyChanges(F, D, T, CHANGES): each row's
%   figure takes the figure settings of CHANGES (figureEditChanges'
%   entries), once, and its panel (row.panel) the panel settings. A
%   field of an alignment the figure or panel uses but does not have of
%   its own makes it its own first, from the one it uses (the figure's,
%   else the Defaults D's), as the editor does when one of its rows is
%   edited. The figures are not normalized here: assigning them to a
%   config's Figures does that.
%
%   See also EphysAnalysisConfig.changeTargets, EphysAnalysisConfig.figureEditChanges.

arguments
    F struct
    D (1,1) struct
    T struct
    changes struct
end
done = false(1, numel(F));
for r = reshape(T, 1, [])
    fig = F(r.figure);
    for c = reshape(changes, 1, [])
        tok = split(c.path, ".").';
        if c.scope == "figure"
            if ~done(r.figure); fig = setAt(fig, tok, c.value, alignmentOf(fig, [], D)); end
        elseif r.panel >= 1
            p = fig.panels(r.panel);
            fig.panels(r.panel) = setAt(p, tok, c.value, alignmentOf(fig, p, D));
        end
    end
    done(r.figure) = true;
    F(r.figure) = fig;
end
end


function s = setAt(s, tok, v, A)
%setAt  Struct S with the value at the path TOK set to V; an alignment S uses but lacks starts from A's.
if numel(tok) > 1 && ismember(tok(1), ["ref" "window" "selection"]) && ~isstruct(s.(tok(1)))
    s.(tok(1)) = A.(tok(1));
end
s = setPath(s, tok, v);
end


function s = setPath(s, tok, v)
if isscalar(tok)
    s.(tok) = v;
else
    s.(tok(1)) = setPath(s.(tok(1)), tok(2:end), v);
end
end
