% Create the directory that a file will live in, if needed

function myMkDir(fn)
directory = fileparts(fn);
if ~exist(directory, "dir")
    mkdir(directory)
end % ~exist directory
end % mkMyDir