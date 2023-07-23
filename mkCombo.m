% Join binned cast tables together into a single table
%
% June-2023, Pat Welch, pat@mousebrains.com

function cInfo = mkCombo(bInfo, info)
arguments
    bInfo table
    info struct
end % arguments
%%
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
casts = cell(size(cInfo,1)+1,1); % +1 for combo file itself

for index = 1:size(cInfo,1)
    row = cInfo(index,:);

    if ~row.qUse
        % fprintf("Skiping %s %s due to qUse\n", row.sn, row.basename);
        continue;
    end % if ~qUse
    
    if row.qIncluded
        % fprintf("Skipping %s %s due to qIncluded\n", row.sn, row.basename);
        continue;
    end % qIncluded

    a = load(row.fnBin);
    casts{index} = a;
    allNames = union(allNames, a.tbl.Properties.VariableNames);
    nCasts = nCasts + size(a.info,1);
    bins = union(bins, a.tbl.bin);
end % for index

if nCasts == 0
    fprintf("Nothing to add to combo\n");
    return;
end % if nCasts

if exist(info.comboFilename, "file") % Previous combo file exists, so append to list
    casts{end} = a;
    allNames = union(allNames, a.tbl.Properties.VariableNames);
    nCasts = nCasts + size(a.info,1);
    bins = union(bins, a.tbl.bin);
end % if

q = cellfun(@isempty, casts);
casts = casts(~q); % Something is here since nCasts > 0

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

timeInfo = vertcat(timeInfo{:});

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

fprintf("Wrote %dx%d to %s\n", size(tbl.t,1), size(tbl.t, 2), info.comboFilename);
end % mkCombo