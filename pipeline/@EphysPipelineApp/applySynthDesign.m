function applySynthDesign(obj, D)
%applySynthDesign  Show SyntheticDesign D in the Synthetic tab's tables and noise fields.
%   An empty Event or Parameter shows as "(none)". See gatherSynthDesign.
arguments
    obj (1,1) EphysPipelineApp
    D (1,1) SyntheticDesign
end
obj.SynthUnitsTable.Data = toCells(D.Units, obj.synthColumns("unit"));
obj.SynthLFPTable.Data = toCells(D.LFP, obj.synthColumns("lfp"));
obj.SynthNoiseField.Value = D.NoiseUV;
obj.SynthSineField.Value = D.SineUV;
end


function C = toCells(T, vars)
C = cell(height(T), numel(vars));
for j = 1:numel(vars)
    x = T.(vars(j));
    for i = 1:height(T)
        if isstring(x)
            s = x(i);
            if s == "" && ismember(vars(j), ["Event" "Parameter"]); s = "(none)"; end
            C{i, j} = char(s);
        else
            C{i, j} = double(x(i));
        end
    end
end
end
