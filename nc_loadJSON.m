%
% Load a JSON file defining attributes for a NetCDF file
%
% July-2023, Pat Welch, pat@mousebrains.com

function [attrG, attrV, nameMap, compressionLevel, dimensions, globalMap] = nc_loadJSON(fn, info, tbl)
arguments (Input)
    fn string
    info struct
    tbl table
end % arguments
arguments (Output)
    attrG struct
    attrV struct
    nameMap struct
    compressionLevel int8
    dimensions struct
    globalMap struct
end % arguments output

if exist(fn, "file")
    attr = jsondecode(fileread(fn));
else
    attr = struct();
end % if

for name = ["compressionLevel", "nameMap", "global", "vars", "dimensions", "globalMap"]
    if ~isfield(attr, name)
        attr.(name) = struct();
    end % if
end % for

attrG = nc_addGlobalAttributes(attr.global, info);
attrG = nc_addGlobalRanges(attrG, tbl, attr.globalMap);
attrV = attr.vars;
nameMap = attr.nameMap;
compressionLevel = attr.compressionLevel;
if isempty(attr.compressionLevel), compressionLevel = -1; end

dimensions = attr.dimensions;
globalMap = attr.globalMap;
end % nc_loadJSON