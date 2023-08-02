%
% aggregate CTD/Chlorophyll data into time bins to reduce the size to something manageable
%
% July-2023, Pat Welch, pat@mousebrains.com

function binCTD(pInfo, info)
arguments
    pInfo table
    info struct
end % arguments

fnCombo = info.("ctdFilename");
fnInfo  = info.("ctdInfoFilename");

cInfo = table();
[cInfo.fnProf, ix] = unique(pInfo.fnProf);
cInfo.sn = pInfo.sn(ix);
cInfo.basename = pInfo.basename(ix);
cInfo.fnCTD = fullfile(info.ctdRoot, cInfo.sn, append(cInfo.basename, ".mat"));
cInfo.qIncluded = false(size(cInfo.fnProf));

if exist(fnInfo, "file")
    lhs = load(fnInfo).cInfo;
    lhs.fnCTD = fullfile(info.ctdRoot, lhs.sn, append(lhs.basename, ".mat")); % Update path if needed
    cInfo = myJoiner(cInfo, lhs, "fnProf", "fnCTD");
end % if exist

newInfo = cInfo(~cInfo.qIncluded,:);

if isempty(newInfo)
    fprintf("Nothing new to add to %s\n", fnCombo);
    return;
end % if isempty

allNames = strings(0,1);
qExist = isfile(fnCombo);
tbl = cell(size(newInfo,1) + qExist,1);

dtBin = info.bin_ctd_dt;

for index = 1:size(newInfo,1)
    stime = tic();
    row = newInfo(index,:);
    fnProf = row.fnProf;
    if isnewer(row.fnCTD, fnProf)
        fprintf("Newer %s\n", row.fnCTD);
        b = load(row.fnCTD).b;
        allNames = union(allNames, string(b.Properties.VariableNames));
        tbl{index} = b;
        fprintf("CTDbin %.2f seconds n=%d %d/%d %s Loaded\n", ...
            toc(stime), size(b,1), index, size(newInfo,1), fnProf);
        continue;
    end

    rhs = load(fnProf, "ctd", "chlorophyll");

    ctd = rhs.ctd;
    chl = rhs.chlorophyll;

    t0 = min(ctd.t);
    t1 = max(ctd.t);
    if ~isempty(chl)
        t0 = min(t0, chl.t);
        t1 = max(t1, chl.t);
    end % if ~isempty
    t0 = floor(posixtime(t0) / dtBin) * dtBin;
    t1 = ceil(posixtime(t1)  / dtBin) * dtBin;
    tBins = datetime(t0:dtBin:t1, "ConvertFrom", "posixtime");
    iBins = 1:numel(tBins);

    ctd.grp = findgroups(interp1(tBins, iBins, ctd.t, "previous"));

    myFun = @(tbl, name) rowfun(@(x) median(x, "omitmissing"), tbl, ...
        "InputVariables", name, ...
        "GroupingVariables", "grp", ...
        "OutputVariableNames", name);

    b = myFun(ctd, "t");
    b = removevars(b, "grp");
    b = renamevars(b, "GroupCount", "nSlow");
    b.tSlow = b.t;
    b.t = interp1(tBins, tBins, b.tSlow, "previous");
    for name = setdiff(string(ctd.Properties.VariableNames), ["grp", "t"])
        temp = myFun(ctd, name);
        b.(name) = temp.(name);
    end % for

    if ~isempty(chl)
        chl.grp = findgroups(interp1(tBins, iBins, chl.t, "previous"));
        bb = myFun(chl, "t");
        for name = setdiff(string(chl.Properties.VariableNames), string(ctd.Properties.VariableNames))
            temp = myFun(chl, name);
            bb.(name) = temp.(name);
        end % for
        bb = removevars(bb, "grp");
        bb = renamevars(bb, ["GroupCount", "t"], ["nFast", "tFast"]);
        bb.t = interp1(tBins, tBins, bb.tFast, "previous");
        b = outerjoin(b, bb, "Keys", "t", "MergeKeys", true);
    end % if ~isempty

    b.t = b.t + seconds(dtBin / 2); % Bin centroid

    myMkDir(row.fnCTD);
    save(row.fnCTD, "b");

    allNames = union(allNames, string(b.Properties.VariableNames));
    tbl{index} = b;
    fprintf("CTDbin %.2f seconds n=%d %d/%d %s\n", ...
        toc(stime), size(b,1), index, size(newInfo,1), fnProf);
end % for

if qExist
    tbl{end} = load(fnCombo).tbl;
    allNames = union(allNames, string(tbl{end}.Properties.VariableNames));
end % if qExist

tbl = tbl(~cellfun(@isempty, tbl)); % Prune any empty entries

% Make sure every table has the same columns
for index = 1:size(tbl,1)
    tNames = sort(string(tbl{index}.Properties.VariableNames));
    for name = setdiff(allNames, tNames)' % Add in missing columns
        if ismember(name, ["tSlow", "tFast"])
            tbl{index}.(name) = NaT(size(tbl{index},1),1);
        else
            tbl{index}.(name) = nan(size(tbl{index},1),1);
        end % if ismember
    end % for
end % for index

tbl = vertcat(tbl{:}); % This takes care of column realignment

[~, ix] = unique(tbl.t); % Unique and ascending in t
tbl = tbl(ix,:);

myMkDir(fnCombo);
myMkDir(fnInfo);

save(fnCombo, "tbl");
saveNetCDF(fnCombo, tbl, info);

cInfo.qIncluded(:) = true;
save(fnInfo, "cInfo");
fprintf("CTDbin wrote %dx%d to %s\n", size(tbl,1), size(tbl,2), fnCombo);
end % binCTD


function saveNetCDF(fnCombo, tbl, info)
arguments
    fnCombo string
    tbl table
    info struct
end % arguments

[dirname, basename] = fileparts(fnCombo);
fnNC = fullfile(dirname, append(basename, ".nc"));
myDir = fileparts(mfilename("fullpath"));
fnCDL = fullfile(myDir, "CTD.json");

mkNetCDF(fnNC, tbl, info, fnCDL);
end % saveNetCDF