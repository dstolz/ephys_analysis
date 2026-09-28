function editorGenerate(obj)
%editorGenerate  Fill the editor's sites table from the chosen generator.
%   Linear, Multi-column and Tetrode use the Sites / Pitch / Shanks /
%   Columns / Spacing fields; Template takes a site-order template or a
%   full NeuroNexus design name, whose pitch and shank spacing win over
%   the fields (ChannelMap.sitesFromTemplate).
E = obj.Editor;
t = string(E.GenDrop.Value);
pitch = E.GenPitch.Value;
try
    switch t
        case "Linear"
            S = ChannelMap.sitesFromTemplate("linear", N=E.GenN.Value, Pitch=pitch, ...
                Shanks=E.GenShanks.Value, ShankSpacing=E.GenSpacing.Value);
            tmpl = "linear";
        case "Multi-column"
            S = ChannelMap.sitesFromTemplate("multi_column", Columns=E.GenColumns.Value, PerColumn=E.GenN.Value, ...
                Pitch=pitch, ColumnSpacing=E.GenSpacing.Value, Shanks=E.GenShanks.Value, ...
                ShankSpacing=E.GenSpacing.Value * E.GenColumns.Value + 150);
            tmpl = "multi_column";
        case "Tetrode"
            S = ChannelMap.sitesFromTemplate("tetrode", Tetrodes=E.GenN.Value, Pitch=pitch, ...
                Shanks=E.GenShanks.Value, ShankSpacing=E.GenSpacing.Value);
            tmpl = "tetrode";
        otherwise
            name = string(E.GenTemplate.Value);
            p = ChannelMap.parseDesignName(name);
            args = {};
            if isnan(p.Pitch)
                args = [args, {'Pitch', pitch}];
            else
                pitch = p.Pitch;
            end
            if isnan(p.ShankSpacing)
                args = [args, {'ShankSpacing', E.GenSpacing.Value}];
            end
            S = ChannelMap.sitesFromTemplate(name, args{:});
            tmpl = p.Template;
    end
catch ME
    E.Status.Text = char("Not generated: " + ME.message);
    return
end
E.Sites.Data = S;
E.Channels.Value = height(S);
E.Template = tmpl;
E.PitchUm = pitch;
E.GeometrySource = "template";
E.Status.Text = char(sprintf("Generated %d sites (%s).", height(S), tmpl));
obj.Editor = E;
obj.editorRefresh();
end
