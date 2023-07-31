% Set a variable's attributes from a structure
%
% July-2023, Pat Welch, pat@mousebrains.com

function nc_putAtt(ncid, varID, attr)
arguments
    ncid double
    varID double
    attr struct
end % arguments

for key = string(fieldnames(attr))'
    val = attr.(key);
    if ischar(val), val = string(val); end
    netcdf.putAtt(ncid, varID, key, val, nc_mkXType(val));
end % for
end % nc_putAtt