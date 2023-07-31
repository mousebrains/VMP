%
% Create a variable with attributes and ranges
%
% July-2023, Pat Welch, pat@mousebrains.com

function varID = nc_createVariables(ncid, dimIDs, nameMap, tbl, attrV, compressionLevel)
arguments
    ncid double
    dimIDs double
    nameMap struct
    tbl table
    attrV struct
    compressionLevel int8 = -1
end % arguments

names = string(tbl.Properties.VariableNames);

varID = nan(size(tbl,2),1);

for index = 1:numel(names)
    name = names(index);
    val = tbl.(name);
    if isfield(nameMap, name)
        nameNC = nameMap.(name);
    else
        nameNC = name;
    end

    if isrow(val) || iscolumn(val)
        dID = dimIDs(1);
    else
        dID = dimIDs;
    end % if isrow

    varID(index) = netcdf.defVar(ncid, nameNC, nc_mkXType(val), dID);
    if compressionLevel >= 0
        netcdf.defVarDeflate(ncid, varID(index), false, true, compressionLevel);
    end % if compressioinLevel
    if ~isfield(attrV, nameNC), attrV.(nameNC) = struct(); end
    attr = attrV.(nameNC);
    switch class(val)
        case "datetime"
            attr.valid_min = posixtime(min(val(:), [], "omitmissing"));
            attr.valid_max = posixtime(max(val(:), [], "omitmissing"));
            attr.units = "seconds since 1970-01-01 00:00:00";
            attr.calendar = "proleptic_gregorian";
        case "logical"
            attr.dtype = "bool";
            attr.valid_min = min(val(:), [], "omitmissing");
            attr.valid_max = max(val(:), [], "omitmissing");
        case {"char", "string"}
            ;
        otherwise
            attr.valid_min = min(val(:), [], "omitmissing");
            attr.valid_max = max(val(:), [], "omitmissing");
    end
    nc_putAtt(ncid, varID(index), attr);
end % for
end % nc_createVariables