function T = figureObservations(src, spec)
%figureObservations  The observations a dataset offers for a figure: its units, its channels, or itself.
%   T = figureObservations(SRC, SPEC) lists what the figure SPEC
%   (EphysAnalysisConfig.figureFor: observe.kind resolved) can be drawn
%   for on the dataset SRC (loadAnalysisSource), one row each: the preview's
%   observation picker, and what Generate repeats the figure over. By
%   SPEC.observe.kind:
%     "unit"     the units observe.units keeps:
%                selectUnits(src, observe.units, Ref=spec.ref,
%                Selection=spec.selection) (only their table is used; the
%                spike trains stay in the outputs' cache)
%     "channel"  the columns observe.channels names ([] = all) of the
%                observe.signal extract: selectChannels' table
%     "dataset"  one row, the dataset itself
%   Units and channels are in probe order (probeOrder with spec.style:
%   SortShank, SortDepth), so stepping through them walks the probe.
%
%   T columns
%     kind      "unit" | "channel" | "dataset"
%     label     the picker's text: "<unit>  <class>  ch <N>  <y> µm" for a
%               unit (the unit's short label, its class unless the label
%               starts with it, its recording channel, its probe y), "<SIG>
%               ch <N>  <y> µm" for a channel (an AUX channel: "AUX
%               <label>"), the dataset's name for the dataset
%     unitId    the unit's id (selectUnits' unitId: the sorter's id, the
%               channel of a detection); NaN for a channel or the dataset
%     channel   the 1-based recording channel (NaN: none, e.g. AUX, or the
%               dataset)
%     column    the extract's column (a channel observation; NaN otherwise)
%     shank     the probe shank (NaN for the dataset)
%     depth     the probe y, µm (NaN when unknown)
%     meta      {1 x 1} cell: the unit's selectUnits row, the channel's
%               selectChannels row, or a one-row table of the dataset's
%               name
%   A dataset that lacks the observed source (no sorted units, no
%   detections, no such extract) or keeps no unit gives an empty T with
%   these columns. EphysAnalysisRunner.computeFigure takes a row
%   (Observation=T(k,:)).
%
%   See also EphysAnalysisRunner.computeFigure, figureSkipReason, probeOrder,
%   selectUnits, selectChannels.

arguments
    src (1,1) struct
    spec (1,1) struct
end

ob = spec.observe;
T = emptyObservations();
switch ob.kind
    case "unit"
        try
            [~, meta] = selectUnits(src, ob.units, Ref=spec.ref, Selection=spec.selection);
        catch ME
            if ismember(string(ME.identifier), ["selectUnits:NoUnits" "selectUnits:NoDetected" "selectUnits:NoneLeft"])
                return
            end
            rethrow(ME);
        end
        n = height(meta);
        meta = meta(probeOrder(meta, n, spec.style), :);
        short = shortUnitLabels(meta.label);
        label = strings(n, 1);
        for k = 1:n
            parts = short(k);
            if ~startsWith(short(k), meta.class(k)); parts(end+1) = meta.class(k); end %#ok<AGROW>
            if isfinite(meta.channel(k)) && short(k) ~= "ch" + meta.channel(k)
                parts(end+1) = "ch " + meta.channel(k); %#ok<AGROW>
            end
            parts(end+1) = depthText(meta.y(k)); %#ok<AGROW>
            label(k) = strjoin(parts(parts ~= ""), "  ");
        end
        T = table(repmat("unit", n, 1), label, double(meta.unitId), double(meta.channel), NaN(n, 1), ...
            double(meta.shank), double(meta.y), rowsOf(meta), ...
            'VariableNames', {'kind', 'label', 'unitId', 'channel', 'column', 'shank', 'depth', 'meta'});
    case "channel"
        sig = upper(ob.signal);
        if ~isfield(src.signals, sig) || ~src.signals.(sig); return; end
        [~, ~, meta] = selectChannels(src, sig, Channels=[]);   % every column in order: the cached signal, not copied
        if ~isempty(ob.channels)
            meta = meta(ismember(meta.channel, ob.channels), :);
        end
        n = height(meta);
        if n == 0; return; end
        meta = meta(probeOrder(meta, n, spec.style), :);
        label = strings(n, 1);
        for k = 1:n
            rc = meta.recordingChannel(k);
            if isfinite(rc)
                parts = [sig + " ch " + rc, depthText(meta.y(k))];
            else
                parts = sig + " " + meta.label(k);
            end
            label(k) = strjoin(parts(parts ~= ""), "  ");
        end
        T = table(repmat("channel", n, 1), label, NaN(n, 1), double(meta.recordingChannel), double(meta.channel), ...
            double(meta.shank), double(meta.y), rowsOf(meta), ...
            'VariableNames', {'kind', 'label', 'unitId', 'channel', 'column', 'shank', 'depth', 'meta'});
    otherwise   % "dataset"
        T = table("dataset", string(src.name), NaN, NaN, NaN, NaN, NaN, {table(string(src.name), 'VariableNames', {'name'})}, ...
            'VariableNames', {'kind', 'label', 'unitId', 'channel', 'column', 'shank', 'depth', 'meta'});
end
end


function T = emptyObservations()
T = table(strings(0, 1), strings(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), cell(0, 1), ...
    'VariableNames', {'kind', 'label', 'unitId', 'channel', 'column', 'shank', 'depth', 'meta'});
end


function c = rowsOf(meta)
%rowsOf  One cell per row of META, each holding that row.
c = cell(height(meta), 1);
for k = 1:height(meta)
    c{k} = meta(k, :);
end
end


function s = depthText(y)
s = "";
if isfinite(y); s = compose("%g µm", round(y)); end
end
