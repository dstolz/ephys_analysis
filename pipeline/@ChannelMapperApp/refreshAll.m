function refreshAll(obj)
%refreshAll  Show obj.Result: table, probe, connector faces, info, problems, selection.
%   The selected site stays selected when the new result still has it.
obj.refreshResultTable();
obj.drawProbe();
obj.drawFaces();
R = obj.Result;
b = obj.Bank;

% --- what the probe and package are ---
info = strings(0, 1);
if obj.ProbeId ~= "" && b.has(obj.ProbeId)
    pr = b.get(obj.ProbeId);
    switch pr.GeometrySource
        case "template"
            src = "from a site-order template";
        case "ks4-json"
            src = "from a Kilosort4 probe file";
        case "probeinterface"
            src = "from probeinterface";
        case "csv"
            src = "from a CSV";
        case "editor"
            src = "entered by hand";
        otherwise
            src = "of unknown origin";
    end
    info(end + 1) = sprintf("%g sites on %g shank(s), geometry %s.", pr.Channels, pr.Shanks, src);
else
    info(end + 1) = "No probe design: the table shows the wiring only (the export needs a design).";
end
if obj.PackageId ~= "" && b.has(obj.PackageId)
    pkg = b.get(obj.PackageId);
    conns = unique(strsOf(pkg.Faces, 'Connector'), 'stable');
    info(end + 1) = sprintf("%s: %d x %s.", pkg.Name, numel(pkg.Faces), strjoin(conns, " + "));
end
if ~isempty(R)
    switch R.Trust
        case "verified"
            t = "verified (checked against a recording or probeinterface)";
        case "rule-derived"
            t = "rule-derived (from the vendors' drawings, not checked against a recording)";
        otherwise
            t = "unverified (a rotated mate: check it against a recording)";
    end
    info(end + 1) = "Trust: " + t + ".";
end
obj.InfoLabel.Text = char(strjoin(info, " "));
if ~isempty(R) && R.Trust == "verified"
    obj.InfoLabel.FontColor = [0 0.45 0];
elseif ~isempty(R) && R.Trust == "unverified"
    obj.InfoLabel.FontColor = [0.65 0.35 0];
else
    obj.InfoLabel.FontColor = [0 0 0];
end

% --- problems ---
if isempty(R)
    obj.ProblemsLabel.Text = 'Choose a package and a headstage.';
    obj.ProblemsLabel.FontColor = [0.4 0.4 0.4];
elseif isempty(R.Problems)
    nRec = nnz(isfinite(R.Table.RecordingRow0));
    obj.ProblemsLabel.Text = char(sprintf("No problems: %d of %d sites reach a recording row (%d channels recorded).", ...
        nRec, height(R.Table), R.NChan));
    obj.ProblemsLabel.FontColor = [0 0.5 0];
else
    shown = R.Problems(1:min(8, end));
    more = "";
    if numel(R.Problems) > 8
        more = newline + sprintf("... and %d more.", numel(R.Problems) - 8);
    end
    obj.ProblemsLabel.Text = char(sprintf("%d problem(s):", numel(R.Problems)) + newline + ...
        strjoin("  " + shown, newline) + more);
    obj.ProblemsLabel.FontColor = [0.75 0 0];
end

% --- keep the selection ---
sel = obj.Selection;
none = struct('site', NaN, 'face', "", 'cell', [NaN NaN]);
if isempty(R)
    sel = none;
elseif isfinite(sel.site) && ~any(R.Table.Site == sel.site)
    sel = none;
elseif ~isfinite(sel.site) && sel.face ~= ""
    % a pin: keep it only while that face is drawn and still has the cell
    k = find(strsOf(obj.FaceDraw, 'Key') == sel.face, 1);
    if isempty(k) || any(sel.cell > [obj.FaceDraw(k).Rows obj.FaceDraw(k).Cols])
        sel = none;
    end
end
obj.Selection = sel;
obj.applySelection();
obj.updateTitle();
end
