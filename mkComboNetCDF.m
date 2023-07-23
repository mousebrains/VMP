% Create a NetCDF version of the combo mat file
%
% July-2023, Pat Welch, pat@mousebrains.com
%
%%

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

a = load(fnCombo);

if exist(fnNC, "file"), delete(fnNC); end

ncid = netcdf.create(fnNC, bitor(netcdf.getConstant("CLOBBER"), netcdf.getConstant("NETCDF4")));
dimIDs = nan(2,1);
dimIDs(1) = netcdf.defDim(ncid, "time", size(a.info,1));
dimIDs(2) = netcdf.defDim(ncid, "bin", size(a.tbl,1));
infoIDs = createVars(ncid, a.info, struct("t0", "time"), dimIDs);
tblIDs = createVars(ncid, a.tbl, struct("bin", "depth"), flipud(dimIDs));
netcdf.endDef(ncid);
putVars(ncid, a.info, infoIDs);
putVars(ncid, a.tbl, tblIDs);
netcdf.close(ncid);
end % mkComboNetCDF

%%

function putVars(ncid, tbl, varIDs)
arguments
    ncid double
    tbl table
    varIDs struct
end % arguments

for name = string(tbl.Properties.VariableNames)
    val = tbl.(name);
    switch class(val)
        case "datetime"
            val = posixtime(val);
        case "logical"
            val = uint8(val);
    end % switch

    netcdf.putVar(ncid, varIDs.(name), val);
end % for name
end % putVars

function ids = createVars(ncid, tbl, toRename, dimids)
arguments
    ncid double
    tbl table
    toRename struct
    dimids double
end % arguments

names = string(tbl.Properties.VariableNames);
[~, ix] = sort(lower(names)); % Dictionary sort
names = names(ix);
ids = struct();
for index = 1:numel(names)
    name = names(index);
    tgt = name;
    if isfield(toRename, name), tgt = toRename.(name); end
    val = tbl.(name);
    if iscolumn(val)
        dID = dimids(1);
    else
        dID = dimids;
    end % if
    varID = netcdf.defVar(ncid, tgt, mkXType(val), dID);
    ids.(name) = varID;
    netcdf.defVarDeflate(ncid, varID, false, true, 5);
    if isa(val, "datetime")
        netcdf.putAtt(ncid, varID, "units", "seconds since 1970-01-01");
        netcdf.putAtt(ncid, varID, "calendar", "proleptic_gregorian");
    end % if isa
end % for
end % createVars

function x = mkXType(val)
switch class(val)
    case {"double", "datetime"}
        x = netcdf.getConstant("NC_DOUBLE");
    case "string"
        x = netcdf.getConstant("NC_STRING");
    case "logical"
        x = netcdf.getConstant("NC_UBYTE");
    otherwise
        error("Unrecognized type %s", class(val));
end % switch
end % mkXType