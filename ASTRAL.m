%
% Convert P files to binned data for the ASTRAL-2023 data
%
% July-2023, Pat Welch, pat@mousebrains.com
%

dataRoot = "~/Desktop/ASTRAL/Data";
gpsFilename = fullfile(dataRoot, "GPS/gps.mat");

processVMPfiles( ...
	"dataRoot", dataRoot, ...
	"gpsClass", @GPSfromMat, ...
    "gpsFilename", gpsFilename ...
	);
