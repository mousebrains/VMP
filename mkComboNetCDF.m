% Create a NetCDF version of the combo mat file
%
% There are two tables in the file, info and tbl
%
% We'll have two dimensions, info.t0 and tbl.bin, so special from mkNetCDF
%
% July-2023, Pat Welch, pat@mousebrains.com
%

function mkComboNetCDF(info)
arguments
    info struct
end % arguments
%%
fnCombo = info.comboFilename;
[dirname, basename] = fileparts(fnCombo);
fnNC = fullfile(dirname, append(basename, ".nc"));

if isnewer(fnNC, fnCombo)
    fprintf("No need to rebuild %s\n", fnNC);
    return;
end % if isnewer

combo = load(fnCombo); % info and tbl

myDir = fileparts(mfilename("fullpath"));
fnCDL = fullfile(myDir, "Combo.json");

myMkNetCDF(fnNC, combo, info, fnCDL);
error("GOTME");
end % mkComboNetCDF

%
% This is a bastardized version of mkNetCDF
%
% July-2023, Pat Welch, pat@mousebrains.com

function myMkNetCDF(fn, combo, info, fnJSON)
arguments
    fn string     % Output filename
    combo struct  % Input data
    info struct   % parameters from getInfo
    fnJSON string % JSON file defining variable attributes
end % arguments

cInfo = combo.info;
tbl = combo.tbl;

cInfo = removevars(cInfo, ["basename", "sn", "qUse", "fnM", "fnProf", "fnBin", "index"]);
head(cInfo)
head(tbl)


[attrG, attrV, nameMap, compressionLevel] = nc_loadJSON(fnJSON, info, cInfo);

attrG.geospatial_vertical_min = min(tbl.bin);
attrG.geospatial_vertical_max = max(tbl.bin);
attrG.geospatial_bounds_vertical = sprintf("%f,%f", ...
    attrG.geospatial_vertical_min, attrG.geospatial_vertical_max);
fmt = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'";
tMin = min(cInfo.t0);
tMax = max(cInfo.t1);
attrG.time_coverage_end = string(tMax, fmt);
attrG.time_coverage_duration = sprintf("T%fS", seconds(tMax - tMin));
attrG.time_coverage_resolution = sprintf("T%fS", seconds(mkResolution(tbl.t)));

if exist(fn, "file"), delete(fn); end

ncid = netcdf.create(fn, ... % Create a fresh copy
    bitor(netcdf.getConstant("CLOBBER"), netcdf.getConstant("NETCDF4")));

nc_putAtt(ncid, netcdf.getConstant("NC_GLOBAL"), attrG); % Add any global attributes

dimIDs = nan(2,1);
dimIDs(1) = netcdf.defDim(ncid, "bin", size(tbl,1));
dimIDs(2) = netcdf.defDim(ncid, "time", size(cInfo,1));

varID = nc_createVariables(ncid, dimIDs(2), nameMap, cInfo, attrV, compressionLevel);
tblID = nc_createVariables(ncid, dimIDs, nameMap, tbl, attrV, compressionLevel);
netcdf.endDef(ncid);

nc_putVar(ncid, varID, cInfo);
nc_putVar(ncid, tblID, tbl);

netcdf.close(ncid);
error("GotMe");
end % mkNetCDF

function resolution = mkResolution(t)
arguments
    t datetime
end % arguments

dt = diff(t);
n = sum(~isnan(dt));
mu = mean(dt, "omitmissing");
resolution = sum(mu .* n) ./ sum(n);
end % mkResolution