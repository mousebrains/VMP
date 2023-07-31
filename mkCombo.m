% Join binned cast tables together into a single table
%
% June-2023, Pat Welch, pat@mousebrains.com

function cInfo = mkCombo(bInfo, info)
arguments
    bInfo table
    info struct
end % arguments
%%
stime = tic();

cInfo = bInfo;
cInfo.qIncluded = false(size(cInfo,1),1);

if exist(info.comboInfoFilename, "file")
    names = string(cInfo.Properties.VariableNames);
    cInfo = myJoiner( ...
        cInfo, ...
        load(info.comboInfoFilename).cInfo, ...
        ["basename", "sn"], ...
        names(names.startsWith("fn")));
end % if exist

allNames = []; % All the column names in the combo file
bins = []; % All the depth bins
nCasts = 0;

filenames = unique(cInfo.fnBin(cInfo.qUse & ~cInfo.qIncluded));
qExist = isfile(info.comboFilename);
casts = cell(numel(filenames)+qExist,1); % +1 for combo file itself

for index = 1:numel(filenames)
    stime = tic();
    fn = filenames(index);
    rhs = load(fn);
    if isempty(rhs), continue; end % I don't expect this to ever happen, but...
    casts{index} = rhs;
    allNames = union(allNames, rhs.tbl.Properties.VariableNames);
    nCasts = nCasts + size(rhs.info,1);
    bins = union(bins, rhs.tbl.bin);
end % for index

if nCasts == 0
    fprintf("Nothing new to add to combo\n");
    return;
end % if nCasts

if exist(info.comboFilename, "file") % Previous combo file exists, so append to list
    casts{end} = rhs;
    allNames = union(allNames, rhs.tbl.Properties.VariableNames);
    nCasts = nCasts + size(rhs.info,1);
    bins = union(bins, rhs.tbl.bin);
end % if

casts = casts(~cellfun(@isempty, casts)); % Prune empty casts

nTall = numel(bins); % Total number of bins we'll have

tbl = table(); % Merged result of tbl table in profiles files
tbl.bin = bins; % By union we know it is strictly monotonic
tbl.t = NaT(nTall, nCasts);

allNames = string(allNames);
[~, ix] = sort(lower(allNames)); % dictionary sort for humans
allNames = allNames(ix);

for name = sort(setdiff(allNames, ["bin", "t"]))' % Initialize new tbl variables
    tbl.(name) = nan(nTall, nCasts);
end % for name

offset = 0; % Column offset for arrays
timeInfo = cell(numel(casts),1);

for index = 1:numel(casts)
    items = casts{index};
    rhs = items.tbl;
    timeInfo{index} = items.info;
    [~, iLeft, iRight] = innerjoin(tbl, rhs, "Keys", "bin");
    nWide = size(rhs.t,2);
    ii = (1:nWide) + offset;
    offset = offset + nWide; % Next offset
    for name = setdiff(string(rhs.Properties.VariableNames), "bin") % Fill tbl with new data
        tbl.(name)(iLeft, ii) = rhs.(name)(iRight,:);
    end % for name
end % for index

timeInfo = vertcat(timeInfo{:}); % Glue timeInfo together into a single table

[~, ix] = unique(timeInfo(:,["t0", "sn", "basename"])); % Unique and ascending in time per instrument
timeInfo = timeInfo(ix,:);

for name = setdiff(string(tbl.Properties.VariableNames), "bin")
    tbl.(name) = tbl.(name)(:,ix);
end % for name

combo = struct();
combo.info = timeInfo;
combo.tbl = tbl;
save(info.comboFilename, "-struct", "combo");

cInfo.qIncluded(:) = true;

save(info.comboInfoFilename, "cInfo");

fprintf("Took %.2f seconds to write %dx%d to %s\n", ...
    toc(stime), size(tbl.t,1), size(tbl.t, 2), info.comboFilename);
end % mkCombo