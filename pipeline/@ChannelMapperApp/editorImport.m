function editorImport(obj, source, file)
%editorImport  Fill the editor's sites from probeinterface, a Kilosort4 probe .json or a CSV.
%   editorImport("ks4", FILE)  sites numbered by their order in the file
%                              (kcoords 0.. become shanks 1..)
%   editorImport("csv", FILE)  columns site, x, y and (optional) shank
%   editorImport("probeinterface", "manufacturer/probe")  fetched with
%       probe_tool.py get-contacts; its contact ids are the site numbers
%       when they are all whole numbers, else the contacts are numbered in
%       order (and the notes say so)
%   Without FILE a dialog asks. The notes record where the geometry came from.
arguments
    obj
    source (1,1) string {mustBeMember(source, ["ks4" "csv" "probeinterface"])}
    file (1,1) string = ""
end
E = obj.Editor;
note = "";
try
    switch source
        case "ks4"
            if file == ""
                [f, p] = uigetfile({'*.json', 'Kilosort4 probe (*.json)'}, 'Import a probe''s geometry');
                figure(E.Fig);
                if isequal(f, 0); return; end
                file = fullfile(p, f);
            end
            d = readJsonFile(file);
            x = double(d.xc(:)); y = double(d.yc(:));
            k = ones(size(x));
            if isfield(d, 'kcoords') && numel(d.kcoords) == numel(x)
                k = double(d.kcoords(:));
                if min(k) == 0; k = k + 1; end
            end
            S = table((1:numel(x))', x, y, k, 'VariableNames', {'Site', 'X', 'Y', 'Shank'});
            [~, nm, ext] = fileparts(file);
            note = "Geometry imported from " + nm + ext + "; sites are numbered by their order in that file, not by the vendor: check them against the map.";
            geo = "ks4-json";
        case "csv"
            if file == ""
                [f, p] = uigetfile({'*.csv', 'CSV (*.csv)'}, 'Import sites from a CSV (site, x, y, shank)');
                figure(E.Fig);
                if isequal(f, 0); return; end
                file = fullfile(p, f);
            end
            T = readtable(file);
            T.Properties.VariableNames = lower(T.Properties.VariableNames);
            if ~all(ismember(["site" "x" "y"], string(T.Properties.VariableNames)))
                error('ChannelMapperApp:BadCSV', 'The CSV needs columns site, x and y (shank optional).');
            end
            k = ones(height(T), 1);
            if ismember("shank", string(T.Properties.VariableNames))
                k = double(T.shank);
            end
            S = table(double(T.site), double(T.x), double(T.y), k, 'VariableNames', {'Site', 'X', 'Y', 'Shank'});
            [~, nm, ext] = fileparts(file);
            note = "Geometry imported from " + nm + ext + ".";
            geo = "csv";
        case "probeinterface"
            spec = file;
            if spec == ""
                [spec, ok] = ChannelMapperApp.promptText(E.Fig, 'Import from probeinterface', ...
                    'The probe, as manufacturer/name (e.g. neuronexus/A1x32-Poly3-10mm-50-177):', ...
                    string(E.Manufacturer.Value) + "/" + string(E.Name.Value));
                if ~ok; return; end
            end
            parts = split(strtrim(spec), "/");
            if numel(parts) ~= 2
                error('ChannelMapperApp:BadProbeName', 'Write the probe as manufacturer/name.');
            end
            out = string(tempname) + ".json";
            c = onCleanup(@() deleteQuiet(out));
            E.Status.Text = 'Fetching from probeinterface (the first time may download the library) ...';
            drawnow;
            obj.runProbeTool("get-contacts", parts(1), parts(2), out);
            d = readJsonFile(out);
            ids = string(d.contact_ids);
            x = double(d.x(:)); y = double(d.y(:));
            k = str2double(string(d.shank_ids(:))) + 1;
            k(isnan(k)) = 1;
            nums = str2double(ids(:));
            if all(isfinite(nums)) && all(nums == round(nums)) && numel(unique(nums)) == numel(nums) && all(nums >= 1)
                site = nums;
                note = "Geometry from probeinterface " + spec + "; its contact ids are the site numbers.";
            else
                site = (1:numel(x))';
                note = "Geometry from probeinterface " + spec + "; it has no numeric contact ids, so the sites are numbered in contact order: check them against the map.";
            end
            S = table(site, x, y, k, 'VariableNames', {'Site', 'X', 'Y', 'Shank'});
            if strtrim(string(E.Name.Value)) == ""
                E.Name.Value = char(parts(2));
            end
            E.Manufacturer.Value = char(parts(1));
            geo = "probeinterface";
    end
catch ME
    E.Status.Text = char("Not imported: " + ME.message);
    obj.Editor = E;
    return
end
E.Sites.Data = sortrows(S, 'Site');
E.Channels.Value = height(S);
E.GeometrySource = geo;
E.Template = "";
notes = strtrim(string(E.Notes.Value));
if notes == ""
    E.Notes.Value = char(note);
else
    E.Notes.Value = char(notes + " " + note);
end
E.Status.Text = char(sprintf("Imported %d sites.", height(S)));
obj.Editor = E;
obj.editorRefresh();
end


function deleteQuiet(f)
if isfile(f)
    delete(f);
end
end
