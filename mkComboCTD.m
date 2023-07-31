% Combine data from whole files togeter
%
% June-2023, Pat Welch, pat@mousebrains.com

function cInfo = mkComboCTD(tblName, pInfo, info)
arguments
    tblName string
    pInfo table
    info struct
end % arguments

fnCombo = info.(append(tblName, "Filename"));
fnInfo  = info.(append(tblName, "InfoFilename"));
fnProfiles = unique(pInfo.fnProf);

cInfo = table();
cInfo.fnProf = fnProfiles;
cInfo.qIncluded = false(size(fnProfiles));

if exist(fnInfo, "file")
    lhs = load(fnInfo).cInfo;
    cInfo = myJoiner(cInfo, lhs, "fnProf");
end % if exist

newInfo = cInfo(~cInfo.qIncluded,:);

if isempty(newInfo), return; end % Nothing new to add

allNames = strings(0,1);
qExist = isfile(fnCombo);
tbl = cell(size(newInfo,1) + qExist,1);

for index = 1:size(newInfo,1)
    fnProf = newInfo.fnProf(index);
    tbl{index} = load(fnProf, tblName).(tblName);
    allNames = union(allNames, string(tbl{index}.Properties.VariableNames));
end % for

if qExist % Already exist
    tbl{end} = load(fnCombo).tbl;
end

for index = 1:size(tbl,1)
    tNames = sort(string(tbl{index}.Properties.VariableNames));
    for name = setdiff(allNames, tNames)'
        tbl{index}.(name) = nan(size(tbl{index}.t));
    end % for
end % for index

tbl = vertcat(tbl{:});

[~, ix] = unique(tbl.t);
tbl = tbl(ix,:);

myMkDir(fnCombo);
myMkDir(fnInfo);

save(fnCombo, "tbl");

saveNetCDF(fnCombo, tbl, info);

cInfo.qIncluded(:) = true;
save(fnInfo, "cInfo");
end % mkComboCTD

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