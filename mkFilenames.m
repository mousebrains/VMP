% Filenames and parameters object

function tbl = mkFilenames(info)
arguments
    info struct
end % arguments
%%

items = dir(fullfile(info.vmpRoot, "SN*/*")); % List all files in case filesystem is case sensitive
filenames = cell(numel(items), 3); % Pre-allocate space
for index = 1:numel(items)
    item = items(index);
    if contains(lower(item.name),"_original.p"), continue; end % Skip files ending in _original.p
    [~,basename,suffix] = fileparts(item.name);
    if lower(suffix) ~= ".p", continue; end
    filenames{index,1} = basename; % fn.p
    [~, filenames{index,2}] = fileparts(item.folder); % SN
    filenames{index,3} = fullfile(item.folder, item.name); % P filename
end % for index
q = cellfun(@isempty, filenames);
tbl = array2table(string(filenames(~q(:,1),:)), "VariableNames", ["basename", "sn", "fnP"]);
tbl.qUse = true(size(tbl.fnP));
tbl.fnM = fullfile(info.matRoot, tbl.sn, append(tbl.basename, ".mat"));
tbl.fnProf = fullfile(info.profileRoot, tbl.sn, append(tbl.basename, ".mat"));
tbl.fnBin = fullfile(info.binnedRoot, tbl.sn, append(tbl.basename, ".mat"));

if exist(info.p2matFilename, "file") % Join to existing information
    try
        names = string(tbl.Properties.VariableNames);
        rhs = load(info.p2matFilename).filenames;
        tbl = myJoiner(tbl, rhs, ...
            ["basename", "sn"], ...
            names(names.startsWith("fn")));
    catch ME
        fprintf("\n\nEXCEPTION joining to %s\n%s\n\n", info.p2matFilename, getReport(ME));
    end % try
end % if exist
end % mkFilenames