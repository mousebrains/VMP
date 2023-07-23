% Split mat file into individual profiles

function pInfo = mat2profiles(filenames, info)
arguments
    filenames table
    info struct
end % arguments
%%
% Add additional profile related columns to the filenames table
sz = size(filenames.sn);
filenames.t0 = NaT(sz);
filenames.t1 = NaT(sz);
filenames.minDepth = nan(sz);
filenames.maxDepth = nan(sz);
filenames.nProfiles = nan(sz);
filenames.latMin = nan(sz);
filenames.lonMin = nan(sz);
filenames.latMax = nan(sz);
filenames.lonMax = nan(sz);

if exist(info.profileInfoFilename, "file") % Merge existing information
    a = load(info.profileInfoFilename);
    names = string(filenames.Properties.VariableNames);
    filenames = myJoiner(filenames, a.filenames, ...
        ["basename", "sn"], ...
        names(names.startsWith("fn")));
    % Replace fnBin names in a.pInfo with current binnedRoot, in case it
    % changed on us due to the signature.
    a.pInfo.fnBin = fullfile(info.binnedRoot, a.pInfo.sn, append(a.pInfo.basename, ".mat"));
    pInfo = a.pInfo;
else
    pInfo = table();
    pInfo.fnProf = strings(0);
end % exist

gps = []; % Only load gps info if needed

for index = 1:size(filenames, 1) % Walk through filenames
    fRow = filenames(index,:);

    if ~fRow.qUse
        % fprintf("Skipping %s %s\n", fRow.sn, fRow.basename);
        continue;
    end

    fnM = fRow.fnM;
    fnProf = fRow.fnProf;

    if isnewer(fnProf, fnM) % fnProf is newer than fnM
        % fprintf("Newer %s\n", fnProf);
        continue;
    end

    pRows = pInfo(pInfo.fnProf == fnProf,:);
    if ~isempty(pRows) && all(~pRows.qUse)
        fprintf("No useable rows for %s %s\n", fRow.sn, fRow.basename);
        disp(pRows);
        continue;
    end % if ~isempty rows

    stime = tic();
    myMkDir(fnProf);
    a = load(fnM); % Load the matfile for this set of casts
    a.label = append(fRow.sn, "/", fRow.basename);

    indicesSlow = get_profile(a.P_slow, a.W_slow, ...
        info.profile_pressureMin, ...
        info.profile_speedMin, ...
        char(info.profile_direction), ...
        info.profile_minDuration, ...
        a.fs_slow);

    if isempty(indicesSlow) % No profiles found, so change qUse to false
        filenames.qUse(index) = false;
        fprintf("No profiles found in %s %s\n", fRow.sn, fRow.basename);
        continue;
    end % if isempty indices


    nProfiles = size(indicesSlow, 2);
    fprintf("%s spliting into %d profiles\n", a.label, nProfiles);

    indicesFast = interp1(a.t_fast, 1:numel(a.t_fast), a.t_slow(indicesSlow), ...
        "nearest", "extrap"); % Fast indices for each profile

    % First change values in a for calibration and time shifts
    a = fp07Calibration(a, indicesSlow, indicesFast, info); % Adjust T?_(slow|fast) and shift JAC_[TC]
    a = CTalign(a, indicesSlow, info); % Shift JAC_C

    if isempty(gps) % Only initialize GPS if needed
        gps = info.gpsClass(info.gpsFilename, info.gpsMethod);
    end % if isempty gps

    profiles = cell(nProfiles, 1);
    profileInfo = mkProfileInfo(fRow, nProfiles);

    % Pre-build list of variables that are fast, slow, and other
    szSlow = size(a.t_slow);
    szFast = size(a.t_fast);
    names = string(fieldnames(a));
    namesFast = strings(size(names));
    namesSlow = strings(size(names));
    namesOtro = strings(size(names));
    for i = 1:numel(names)
        name = names(i);
        sz = size(a.(name));
        if sz == szFast
            namesFast(i) = name;
        elseif sz == szSlow
            namesSlow(i) = name;
        else
            namesOtro(i) = name;
        end % if sz
    end % for name
    namesFast = namesFast(namesFast ~= "")';
    namesSlow = namesSlow(namesSlow ~= "")';
    namesOtro = namesOtro(namesOtro ~= "")';

    t0 = datetime(sprintf("%s %s", a.date, a.time)); % Start time for this .P file

    for j = 1:nProfiles
        ii = indicesSlow(1,j):indicesSlow(2,j); % Indices for slow variables
        jj = indicesFast(1,j):indicesFast(2,j); % Indices for fast variables
        profile = struct("slow", table(), "fast", table());
        profile.slow.t = t0 + seconds(a.t_slow(ii)); % Times of slow samples
        profile.fast.t = t0 + seconds(a.t_fast(jj)); % Times of fast samples
        for name = namesFast
            profile.fast.(name) = a.(name)(jj);
        end % for namesFast
        for name = namesSlow
            profile.slow.(name) = a.(name)(ii);
        end % for namesSlow
        for name = namesOtro
            profile.(name) = a.(name);
        end % for namesOtro
        profile.lat = gps.lat(profile.slow.t(1)); % Latitude at start of profile
        profile.lon = gps.lon(profile.slow.t(1)); % Longitude at start of profile
        profile.dtGPS = gps.dt(profile.slow.t(1)); % Nearest GPS timestamp
        profile.slow = addSeawaterProperties(profile); % SP/SA/theta/rho/...
        profileInfo.lat(j) = profile.lat;
        profileInfo.lon(j) = profile.lon;
        profileInfo.dtGPS(j) = profile.dtGPS;
        profileInfo.minDepth(j) = min(profile.slow.P_slow);
        profileInfo.maxDepth(j) = max(profile.slow.P_slow);
        profileInfo.t0(j) = profile.slow.t(1);
        profileInfo.t1(j) = profile.slow.t(end);
        profileInfo.nSlow(j) = numel(ii);
        profileInfo.nFast(j) = numel(jj);
        profiles{j} = profile;

        if profile.dtGPS > info.gpsMaxTimeDiff
            fprintf("WARNING: %s profile %d GPS fix %s from t0 %s\n", ...
                a.label, j, string(seconds(profileInfo.dtGPS(j)), "hh:mm:ss"), ...
                profileInfo.t0(j));
        end % if profile
    end % for j

    profileInfo = trimProfiles(profiles, profileInfo, info);
    profileInfo = bottomCrashProfiles(profiles, profileInfo, info);

    for j = 1:nProfiles
        profiles{j} = calcDissShear(profiles{j}, profileInfo(j,:), info);
    end % for j

    fRow.t0 = min(profileInfo.t0);
    fRow.t1 = max(profileInfo.t1);
    fRow.minDepth = min(profileInfo.minDepth);
    fRow.maxDepth = max(profileInfo.maxDepth);
    fRow.nProfiles = nProfiles;
    fRow.latMin = min(profileInfo.lat);
    fRow.lonMin = min(profileInfo.lon);
    fRow.latMax = max(profileInfo.lat);
    fRow.lonMax = max(profileInfo.lon);
    filenames(index,:) = fRow;

    if isempty(pInfo)
        pInfo = profileInfo;
    else
        names = string(pInfo.Properties.VariableNames);
        pInfo = myJoiner(pInfo, profileInfo, ...
            ["basename", "sn", "index"], ...
            names(names.startsWith("fn")));
    end % if isempty

    profilesInfo = struct();
    szSlow = size(a.t_slow);
    szFast = size(a.t_fast);
    for name = sort(string(fieldnames(a)))'
        sz = size(a.(name));
        if (name == "Gnd") || isequal(sz, szSlow) || isequal(sz, szFast), continue; end
        profilesInfo.(name) = a.(name);
    end % for name
    profilesInfo.profiles = profiles;
    profilesInfo.fRow = fRow;
    profilesInfo.pInfo = profileInfo;
    save(fnProf, "-struct", "profilesInfo");

    fprintf("%s took %.2f seconds to extract %d profiles\n", ...
        a.label, toc(stime), numel(profiles));
end % for index

a = struct("filenames", filenames, "pInfo", pInfo);
save(info.profileInfoFilename, "-struct", "a");
end % mat2profiles

function tbl = mkProfileInfo(row, nProfiles)
tbl = table();
for name = ["basename", "sn", "qUse", "fnM", "fnProf", "fnBin"]
    tbl.(name) = repmat(row.(name), nProfiles, 1);
end % for
tbl.index = (1:nProfiles)';
tbl.t0 = NaT(nProfiles,1);
tbl.t1 = NaT(nProfiles,1);
tbl.nSlow = nan(nProfiles,1);
tbl.nFast = nan(nProfiles,1);
tbl.minDepth = nan(nProfiles,1);
tbl.maxDepth = nan(nProfiles,1);
tbl.trimDepth = nan(nProfiles,1);
tbl.lat = nan(nProfiles,1);
tbl.lon = nan(nProfiles,1);
tbl.dtGPS = nan(nProfiles,1);
end % mkProfileInfo