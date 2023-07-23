% Make paths for binning the data

function bInfo = mkBinInfo(paths, bParams, pInfo, info)
arguments
    paths struct
    bParams struct
    pInfo table
    info struct
end % arguments
%%

if isfield(bParams, "EOL"), bParams = rmfield(bParams, "EOL"); end

bInfo = bParams;
bInfo.profileHash = info.hash; % Include in hash signature

hash = string(dec2hex(keyHash(jsonencode(bInfo)))); % A hash for this set of parameters
bInfo.binRoot = fullfile(paths.dataRoot, sprintf("Binned_%s", hash));
bInfo.castInfoFilename = fullfile(bInfo.binRoot, "cast.info.mat");
bInfo.comboInfoFilename = fullfile(bInfo.binRoot, "combo.info.mat");
bInfo.comboFilename = fullfile(bInfo.binRoot, "combo.mat");

bInfo.pInfo = pInfo;

[~, ix] = unique(pInfo.fnProf);
filenames = table();
filenames.basename = pInfo.basename(ix);
filenames.sn = pInfo.sn(ix);
filenames.qUse = true(size(filenames.sn));
filenames.nProfiles = zeros(size(filenames.sn));
filenames.fnProf = pInfo.fnProf(ix);
filenames.fnCast = fullfile(bInfo.binRoot, "profiles", filenames.sn, append(filenames.basename, ".mat"));
bInfo.filenames = filenames;

if exist(bInfo.castInfoFilename, "file")
    lhs = load(bInfo.castInfoFilename).bInfo.filenames;
    rhs = bInfo.filenames;
    [~, iLeft, iRight] = outerjoin(lhs, rhs, "Keys", ["basename", "sn"]);
    qJoint = iLeft ~= 0 & iRight ~= 0; % Rows in both lhs and rhs
    qLeft = iLeft ~= 0 & iRight == 0; % Rows only in lhs
    if any(qJoint)
        rhs.fnProf(iRight(qJoint)) = lhs.fnProf(iLeft(qJoint));
    end % if any qJoint
    if any(qLeft) % Only in lhs
        rhs = [rhs; lhs(iLeft(qLeft),:)]; % Append
    end % if any qLeft
    bInfo.filenames = rhs;
end % if

end % mkBinInfo