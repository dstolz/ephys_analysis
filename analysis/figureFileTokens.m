function T = figureFileTokens(kind)
%figureFileTokens  The tokens an export pattern may name, such as {Name} or {Plot}: what each means.
%   T = figureFileTokens(KIND) lists the tokens of one kind of pattern: a
%   table with a row per token, Name ("Plot"), Meaning, Example and Path
%   (true for a token whose value is a whole folder, used as it is).
%     "file"    a figure's file name (Export.FilenamePattern,
%               Export.Data.FilenamePattern): Name, Plot, Kind, Group,
%               Unit, Index, Date (figureOutputName fills them)
%     "folder"  a folder (Export.Folder, Export.SessionsFolder,
%               Export.Data.Folder, Report.Folder): OutputFolder,
%               OutputRoot, Root, Name, Date
%     "title"   the report's title (Report.Title): Name (the config's
%               name), Date
%   figureFileName fills the file and folder patterns and takes no other
%   token. The analysis app's "{x}" buttons on the Export tab list them.
%     T = figureFileTokens("folder");
%     "{" + T.Name(T.Path) + "}"   % "{OutputFolder}" "{OutputRoot}" "{Root}"
%
%   See also figureFileName, figureOutputName, figureLabelVariables.

arguments
    kind (1,1) string {mustBeMember(kind, ["file" "folder" "title"])}
end

switch kind
    case "file"
        rows = {
            "Name",  "The dataset's name", "RAT1_260918_101500", false
            "Plot",  "The figure's id", "psth_stim", false
            "Kind",  "What is drawn: always figure", "figure", false
            "Group", "The trial group of a figure drawn once per group (all: otherwise)", "Freq_8000", false
            "Unit",  "The unit's or channel's short label (dataset: the dataset's figure)", "su12", false
            "Index", "The observation's number", "3", false
            "Date",  "Today's date, yyyyMMdd", "20261111", false
            };
    case "folder"
        rows = {
            "OutputFolder", "Each dataset's output folder", "D:\out\RAT1_260918_101500", true
            "OutputRoot",   "The output root: Source.OutputRoot, else Source.Root", "D:\out", true
            "Root",         "The data root: Source.Root", "D:\data", true
            "Name",         "The dataset's name", "RAT1_260918_101500", false
            "Date",         "Today's date, yyyyMMdd", "20261111", false
            };
    otherwise   % "title"
        rows = {
            "Name", "The config's name", "auditory_units", false
            "Date", "Today's date, yyyy-MM-dd", "2026-11-11", false
            };
end
T = cell2table(rows, 'VariableNames', {'Name', 'Meaning', 'Example', 'Path'});
for v = ["Name" "Meaning" "Example"]
    T.(v) = string(T.(v));
end
end
