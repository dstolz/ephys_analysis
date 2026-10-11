function D = gatherSynthDesign(obj)
%gatherSynthDesign  The SyntheticDesign the Synthetic tab's tables and noise fields describe.
%   "(none)" (or blank) in Event / Parameter is no line / no parameter; a
%   number typed as text is read as one ("NaN" = every channel for an
%   evoked potential's Channel).
D = SyntheticDesign();
D.Units = fromCells(obj.SynthUnitsTable.Data, obj.synthColumns("unit"), SyntheticDesign.unitTable(0));
D.LFP = fromCells(obj.SynthLFPTable.Data, obj.synthColumns("lfp"), SyntheticDesign.lfpTable(0));
D.NoiseUV = obj.SynthNoiseField.Value;
D.SineUV = obj.SynthSineField.Value;
end


function T = fromCells(C, vars, ref)
n = size(C, 1);
if n == 0; T = ref; return; end
cols = cell(1, numel(vars));
for j = 1:numel(vars)
    r = ref.(vars(j));
    col = C(:, j);
    if isstring(r)
        x = strings(n, 1);
        for i = 1:n
            if ~isempty(col{i}); x(i) = strtrim(string(col{i})); end
        end
        x(x == "(none)") = "";
    else
        x = NaN(n, 1);
        for i = 1:n
            v = col{i};
            if ischar(v) || isstring(v); v = str2double(v); end
            if isnumeric(v) && isscalar(v); x(i) = double(v); end
        end
    end
    cols{j} = x;
end
T = table(cols{:}, 'VariableNames', cellstr(vars));
end
