%
% Put table variables to a file
%
% July-2023, Pat Welch, pat@mousebrains.com

function nc_putVar(ncid, varID, tbl)
arguments
    ncid double
    varID (:,1) double
    tbl table
end % arguments
names = string(tbl.Properties.VariableNames);

for index = 1:numel(names)
    name = names(index);
    ident = varID(index);
    val = tbl.(name);
    switch class(val)
        case "datetime"
            val = posixtime(val);
        case "logical"
            val = uint8(val);
        case "char"
            val = string(val);
    end % switch
    netcdf.putVar(ncid, ident, val);
end % for index
end % nc_putVar