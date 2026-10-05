function applySynthDesign(obj, D)
%applySynthDesign  Show SyntheticDesign D in the Synthetic tab's tables and background fields.
%   An empty Event or Parameter shows as "(none)". See gatherSynthDesign.
arguments
    obj (1,1) EphysPreprocessingApp
    D (1,1) SyntheticDesign
end
obj.SynthUnitsTable.Data = toCells(D.Units, obj.synthColumns("unit"));
obj.SynthLFPTable.Data = toCells(D.LFP, obj.synthColumns("lfp"));
B = D.Background;
obj.SynthRhythmField.Value = B.RhythmScale;
obj.SynthPinkField.Value = B.PinkUV;
obj.SynthNoiseField.Value = B.NoiseUV;
obj.SynthLineNoiseField.Value = B.LineNoiseUV;
if ismember(B.LineFreqHz, [50 60]); obj.SynthLineFreqDropDown.Value = B.LineFreqHz; end
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
        elseif islogical(x)
            C{i, j} = x(i);
        else
            C{i, j} = double(x(i));
        end
    end
end
end
