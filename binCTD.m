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
cInfo.fnProf = unique(pInfo.fnProf);
cInfo.qIncluded = false(size(cInfo.fnProf));

if exist(fnInfo, "file")
    lhs = load(fnInfo).cInfo;
    cInfo = myJoiner(cInfo, lhs, "fnProf");
end % if exist

newInfo = cInfo(~cInfo.qIncluded,:);

if isempty(newInfo)
    fprintf("Nothing new to add to %s\n", fnCombo);
    return;
end % if isempty

allNames = strings(0,1);
qExist = isfile(fnCombo);
tbl = cell(size(newInfo,1) + qExist,1);

dtBin = 0.5;

for index = 1:size(newInfo,1)
    stime = tic();
    fnProf = newInfo.fnProf(index);
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

    oNames = setdiff(string(ctd.Properties.VariableNames), ["grp", "t"]);

    b = rowfun(@(x) median(x, 1, "omitmissing"), ctd, ...
        "SeparateInputs", false, ...
        "InputVariables", oNames, ...
        "GroupingVariables", "grp", ...
        "OutputVariableNames", "val");
    aa = array2table(b.val, "VariableNames", oNames);
    aa.grp = b.grp;
    aa.nSlow = b.GroupCount;
    b = rowfun(@(x) median(x, "omitmissing"), ctd, ...
        "InputVariables", "t", ...
        "GroupingVariables", "grp", ...
        "OutputVariableNames", "t");
    aa.tCTD = b.t;
    aa.t = interp1(tBins, tBins, aa.tCTD, "previous") + seconds(dtBin / 2);

    if ~isempty(chl)
        names = string(chl.Properties.VariableNames);
        xNames = ["grp", "t", "depth", "lat", "lon"];
        chl.grp = findgroups(interp1(tBins, iBins, chl.t, "previous"));
        b = rowfun(@(x) median(x, "omitmissing"), chl, ...
            "SeparateInputs", false, ...
            "InputVariables", setdiff(names, xNames), ...
            "GroupingVariables", "grp", ...
            "OutputVariableNames", "val");
        ab = array2table(b.val, "VariableNames", setdiff(names, union("GroupCount", xNames)));
        ab.grp = b.grp;
        ab.nFast = b.GroupCount;
        aa = innerjoin(aa, ab, "Keys", "grp");
    end % if ~isempty

    aa = removevars(aa, "grp");

    allNames = union(allNames, string(aa.Properties.VariableNames));
    tbl{index} = aa;
    fprintf("Took %.2f seconds to load %s\n", toc(stime), fnProf);
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
        fprintf("Adding %s for %s\n", name, newInfo.fnProf(index));
        tbl{index}.(name) = nan(size(tbl{index},1),1);
    end % for
end % for index

tbl = vertcat(tbl{:});

[~, ix] = unique(tbl.t); % Unique and ascending in t
tbl = tbl(ix,:);

myMkDir(fnCombo);
myMkDir(fnInfo);

save(fnCombo, "tbl");
saveNetCDF(fnCombo, tbl, info);

cInfo.qIncluded(:) = true;
save(fnInfo, "cInfo");
fprintf("Wrote %dx%d to %s\n", size(tbl,1), size(tbl,2), fnCombo);
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