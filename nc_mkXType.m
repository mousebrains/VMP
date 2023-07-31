% return the NetCDF data type from the variables data type
%
% July-2023, Pat Welch, pat@mousebrains.com

function x = nc_mkXType(val)
switch class(val)
    case {"double", "datetime"}
        x = netcdf.getConstant("NC_DOUBLE");
    case {"string", "char"}
        x = netcdf.getConstant("NC_STRING");
    case "logical"
        x = netcdf.getConstant("NC_UBYTE");
    otherwise
        error("Unrecognized type %s", class(val));
end % switch
end % nc_mkXType