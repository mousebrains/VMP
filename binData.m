% Bin profiles into depth bins

function pInfo = binData(pInfo, info)
arguments
    pInfo table
    info struct
end % arguments
%% Bin the data into depth bins
dz = info.bin_Width; % Bin stepsize (m)

method = info.bin_method; % Which method to aggregate the data together
if ~isa(method, "function_handle")
    if method == "median"
        method = @(x) median(x, "omitmissing");
    elseif method == "mean"
        method = @(x) mean(x, "omitmissing");
    else
        error("Unrecognized binning method %s\n", method)
    end % if
end % if ~isa

pInfo = pInfo(pInfo.qUse,:); % Only retain records we'll use

for fnProf = unique(pInfo.fnProf)'
    pRows = pInfo(pInfo.fnProf == fnProf & pInfo.qUse,:);
    fnBin = pRows.fnBin(1); % They are all the same name

    fprintf("fnBin %s\n", fnBin);
    fprintf("fnPro %s\n", fnProf);
    if isnewer(fnBin, fnProf)
        fprintf("Skipping %s %s, already exist\n", pRows.sn(1), pRows.basename(1));
        continue;
    end % if isnewer

    fprintf("Binning %d profiles for %s %s\n", size(pRows, 1), pRows.sn(1), pRows.basename(1));
    fprintf("loading %s\n", fnProf);
    profiles = load(fnProf).profiles;
    casts = cell(size(pRows,1),1);
    
    minDepth = min(pRows.minDepth, [], "omitmissing"); % Minimum depth in casts
    maxDepth = max(pRows.maxDepth, [], "omitmissing"); % Maximum depth in casts

    allBins = (floor(minDepth*dz)/dz):dz:(maxDepth + dz/2); % Bin centroids

    for index = 1:size(pRows,1)
        row = pRows(index,:);
        profile = profiles{row.index};

        fast = profile.fast;
        slow = profile.slow;

        fast.bin = interp1(allBins-dz/2, allBins, fast.P_fast, "previous"); % -dz/2 to find bin centroid
        slow.bin = interp1(allBins-dz/2, allBins, slow.P_slow, "previous");

        fast = fast(~isnan(fast.bin),:); % Take off values above the first bin
        slow = slow(~isnan(slow.bin),:);

        if isfield(profile, "diss") && isfield(profile.diss, "tbl")
            diss = profile.diss.tbl;
            diss.bin = interp1(allBins-dz/2, allBins, diss.P, "previous"); % Might be empty
            diss = diss(~isnan(diss.bin),:);
        else
            diss = table();
        end % if
        if isfield(profile, "bbl") && isfield(profile.bbl, "tbl")
            bbl = profile.bbl.tbl;
            bbl.bin = interp1(allBins-dz/2, allBins, bbl.P, "previous"); % Might be empty
            bbl = bbl(~isnan(bbl.bin),:);
        else
            bbl = table();
        end % if

        if isempty(fast) || isempty(slow)
            fprintf("No bins found for profile %d in %s %s\n", ...
                index, row.sn, row.basename);
            continue;
        end % No fast and slow data to work with

        fast.grp = findgroups(fast.bin);
        slow.grp = findgroups(slow.bin);

        fastNames = setdiff(string(fast.Properties.VariableNames), ["bin", "grp", "t_fast", "t_fast_YD"]);
        slowNames = setdiff(string(slow.Properties.VariableNames), ["bin", "grp", "t", "t_slow", "t_slow_YD"]);

        tblF = rowfun(method, fast, "InputVariables", "bin", "GroupingVariables", "grp", "OutputVariableNames", "bin");
        tblS = rowfun(method, slow, "InputVariables", "bin", "GroupingVariables", "grp", "OutputVariableNames", "bin");

        for varName = slowNames
            a = rowfun(method, slow, "InputVariables", varName, "GroupingVariables", "grp", "OutputVariableNames", varName);
            tblS.(varName) = a.(varName);
        end % for slow names

        for varName = fastNames
            a = rowfun(method, fast, "InputVariables", varName, "GroupingVariables", "grp", "OutputVariableNames", varName);
            tblF.(varName) = a.(varName);
        end % for fast names

        % Merge slow and fast tables

        tblF = removevars(tblF, "grp");
        tblS = removevars(tblS, "grp");

        tblF = renamevars(tblF, "GroupCount", "cntFast");
        tblS = renamevars(tblS, "GroupCount", "cntSlow");

        tbl = outerjoin(tblF, tblS, "Keys", "bin", "MergeKeys", true);

        %%
        %
        % Dissipation is special and we're only going to work with e
        % and FM, figure of merit = mad*sqrt(dof_spec),
        % mad = mean absolute deviation,
        % dof_spec = degrees of freedom in each dissipation estimate
        %
        % e and FM are nxp matrices where
        %   n is the number of probes and
        %   p is the number of pressure bins

        if ~isempty(diss) % Top downwards
            diss.grp = findgroups(diss.bin);
            diss.e(diss.e < info.bin_dissFloor) = nan;

            tblD = rowfun(@(bin, e, FM) myDiss(bin, e, FM, info, method), ...
                diss, ...
                "InputVariables", ["bin", "e", "FM"], ...
                "GroupingVariables", "grp", ...
                "OutputVariableNames", ["bin", "e", "FM"]);
            tblD = removevars(tblD, "grp"); % Drop grouping variable
            tblD = renamevars(tblD, "GroupCount", "cntDiss");
            tbl = outerjoin(tbl, tblD, "Keys", "bin", "MergeKeys", true);
        end % if ~isempty diss

        if ~isempty(bbl) % Bottom upwards
            bbl.grp = findgroups(bbl.bin);
            bbl.e(bbl.e < info.bin_dissFloor) = nan;

            tblB = rowfun(@(bin, e, FM) myDiss(bin, e, FM, info, method), ...
                bbl, ...
                "InputVariables", ["bin", "e", "FM"], ...
                "GroupingVariables", "grp", ...
                "OutputVariableNames", ["bin", "e", "FM"]);
            tblB = removevars(tblB, "grp"); % Drop grouping variable
            tblB = renamevars(tblB, ...
                ["GroupCount", "e", "FM"], ...
                ["cntBBL", "e_bbl", "FM_bbl"]);
            tbl = outerjoin(tbl, tblB, "Keys", "bin", "MergeKeys", true);
        end % if ~isempty bbl
        %%

        casts{index} = tbl;
    end % for index

    qDrop = cellfun(@isempty, casts);
    if any(qDrop)
        casts = casts(~qDrop);
        pRows = pRows(~qDrop,:);
    end % any qDrop

    nCasts = numel(casts);
    nBins = numel(allBins);

    names = [];
    for iCast = 1:nCasts % In case a dissipation table is empty
        rhs = casts{iCast};
        names = union(names, rhs.Properties.VariableNames);
    end % for iCast
    names = setdiff(string(names), "bin");
    [~, ix] = sort(lower(names)); % case-insensitive sort is for humans
    names = names(ix);

    tbl = table();
    tbl.bin = allBins'; % Bin centroids
    tbl.t = NaT(nBins,nCasts);

    for name = setdiff(names, "t")'
        tbl.(name) = nan(nBins, nCasts);
    end % for name

    for iCast = 1:nCasts
        rhs = casts{iCast};
        [~, iLeft, iRight] = innerjoin(tbl, rhs, "Keys", "bin");
        if isempty(iLeft)
            head(tbl)
            head(rhs)
            error("Unexpected empty innerjoin")
        end % if isempty
        for name = setdiff(string(rhs.Properties.VariableNames), "bin")
            tbl.(name)(iLeft,iCast) = rhs.(name)(iRight);
        end % for name
    end % for iCast;

    profiles = struct ( ...
        "tbl", tbl(1:end-1,:), ... % Strip off last row which will be NaN
        "info", pRows);

    myMkDir(fnBin);
    save(fnBin, "-struct", "profiles");
    fprintf("Saving %d profiles to %s\n", size(pRows,1), fnBin);
end % for filenames
end % binData

function [bin, dissipation, FM] = myDiss(bins, e, FMs, info, method)
bin = bins(1); % We grouped by this variable, so all the same

FMs(isnan(e)) = nan; % FMs we won't use are set to NaN
logDiss = log10(e); % dissipation is log normal, so work in log space
threshold = log10(info.bin_dissRatio)/2; % /2 is for distance from mean
mu = mean(logDiss, 2, "omitmissing"); % Mean of each row
q = abs(logDiss - mu) < threshold; % Identify values close to the mean
b = logDiss; % Copy for calculating mean on values near mean
b(~q) = nan; % NaN outliers
mu = mean(b, 2, "omitmissing"); % Mean of non-outliers
b = FMs;
b(~q) = nan; % NaN outliers
muFM = mean(b, 2, "omitmissing"); % Mean of non-outlier figure of merit

qMin = isnan(mu); % Use min if everybody is an outlier
if any(qMin) % There are rows with only outliers
    [bMin, ix] = min(logDiss(qMin,:), [], 2, "omitmissing"); % Rowwise min
    ii = sub2ind(size(logDiss), find(qMin), ix); % Index into FMs
    mu(qMin) = bMin; % Rows with only outliers now are the min
    muFM(qMin) = FMs(ii); % Minimum's FM
end % if any qMin

dissipation = 10.^(method(mu));
FM = method(muFM);
end % myDiss
