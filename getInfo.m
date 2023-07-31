%
% Parse arguments and build structure for
% P files -> mat files
% mat files -> profiles
% profiles -> binned data
%
% July-2023, Pat Welch, pat@mousebrains.com
%
%%
function a = getInfo(varargin)
p = inputParser();
validString = @(x) isstring(x) || ischar(x) || iscellstr(x);
validPositive = @(x) inRange(x, 0);
validNotNegative = @(x) inRange(x, 0, inf, true);

%% Path related parameters
addParameter(p, "dataRoot", string(fullfile(fileparts(mfilename("fullpath")), "../Data")), @(x) isfolder(x));
addParameter(p, "vmpRoot", "VMP", validString); % Where P files are located
addParameter(p, "matRoot", "VMP/Matfiles", validString); % Where to write mat file versions of P files
addParameter(p, "profileRoot", "VMP", validString); % Where to write profiles
addParameter(p, "binnedRoot", "VMP", validString); % Where to write binned data
addParameter(p, "ctdRoot", "VMP", validString); % Where to write CTD/DO data
addParameter(p, "logRoot", "VMP", validString); % Where to store the log file
%% GPS related parameters
addParameter(p, "gpsFilename", "GPS/gps.nc", validString); % Relative to dataRoot
addParameter(p, "gpsClass", @GPSInfo, @(x) isa(x, "function_handle")); % Class to get GPS information from
addParameter(p, "gpsMethod", "linear", @(x) ismember(x, ["linear", "nearest", "next", "previous", "pchip", "cubic", "v5cubic", "makima", "spline"]));
addParameter(p, "gpsMaxTimeDiff", 60, validPositive); % maximum time difference for warning
%% Profile split parameters
addParameter(p, "profile_pressureMin", 0.5, validPositive); % Minimum pressure in dbar for a profile
addParameter(p, "profile_speedMin", 0.3, validPositive); % Minimum vertical speed in m/s for a profile
addParameter(p, "profile_minDuration", 7, validPositive); % Minimum cast length in seconds for a profile
addParameter(p, "profile_direction", "down", @(x) ismember(x, ["up", "down"])); % profile direction, up or down
%% Cast trimming for shear dissipation estimates to drop initial instabilities
addParameter(p, "trim_dz", 0.5, validPositive); % depth bin size for calculating variances (0.5 gives enough samples on the slow side at 1m/s and )
addParameter(p, "trim_minDepth", 1, validPositive); % Minimum depth to look at for variances
addParameter(p, "trim_maxDepth", 50, validPositive); % maximum depth to look down to for variances
addParameter(p, "trim_quantile", 0.6, @(x) inRange(x, 0, 1, true, true)); % Which quantile to choose as the minimum depth
addParameter(p, "trim_use", true, @(x) ismember(x, [true, false])); % Should the trim depth be used to trim the top of dives off
addParameter(p, "trim_extraDepth", 0, validNotNegative); % Extra depth to add to the trim depth value when processing dissipation
%% Cast trimming from the bottom up, think bottom crashing to go after BBL
addParameter(p, "bbl_dz", 0.5, validPositive); % depth bin size for calculating variances (0.5 gives enough samples on the slow side at 1m/s and )
addParameter(p, "bbl_minDepth", 10, validPositive); % Minimum depth to look at for variances
addParameter(p, "bbl_maxDepth", 50, validPositive); % Maximum depth to look down to for variances
addParameter(p, "bbl_quantile", 0.6, @(x) inRange(x, 0, 1, true, true)); % Which quantile to choose as the minimum depth
addParameter(p, "bbl_use", false, @(x) ismember(x, [true, false])); % Should the bbl depth be used to trim the top of dives off
addParameter(p, "bbl_extraDepth", 0, validNotNegative); % Extra depth to add to the bottom depth value when processing dissipation
%% FP07 calibration
addParameter(p, "fp07_calibration", true, @(x) ismember(x, [true, false])); % Perform an in-situ calibration of the FP07 probes agains JAC_T
addParameter(p, "fp07_order", 2, @(x) inRange(x, 1, 3)); % Steinhart-Hart equation order
addParameter(p, "fp07_reference", "JAC_T", validString); % Which sensor is the reference sensor
%% Despike parameters for shear dissipation calculation
% [thresh, smooth, and length] (in seconds) -> Rockland default value,
addParameter(p, "despike_sh_thresh", 8, validPositive); % Shear probe
addParameter(p, "despike_sh_smooth", 0.5, validPositive);
addParameter(p, "despike_sh_N_FS", 0.05, validPositive);
addParameter(p, "despike_sh_warning_fraction", 0.03, validPositive); % Warning fraction
addParameter(p, "despike_A_thresh", 8, validPositive); % Acceleration
addParameter(p, "despike_A_smooth", 0.5, validPositive);
addParameter(p, "despike_A_N_FS", 0.05, validPositive);
addParameter(p, "despike_A_warning_fraction", 0.02, validPositive); % Warning fraction
%% Dissipation parameters
addParameter(p, "diss_downwards_fft_length_sec", 0.5, validPositive); % Disspation FFT length in seconds for top -> bottom estimates
addParameter(p, "diss_upwards_fft_length_sec", 0.25, validPositive); % Disspation FFT length in seconds for bottom -> top estimates
addParameter(p, "diss_downwards_length_fac", 2, validPositive); % Multiples fft_length_sec to get dissipation length for top -> bottom estimates
addParameter(p, "diss_upwards_length_fac", 2, validPositive); % Multiples fft_length_sec to get dissipation length for bottom -> top estimates
addParameter(p, "diss_T1Norm", 1, validPositive); % Value to multiple T1_fast temperature probe by to calculate mean for dissipation estimate
addParameter(p, "diss_T2Norm", 1, validPositive); % Value to multiple T2_fast temperature probe by to calculate mean for dissipation estimate
addParameter(p, "diss_warning_ratio", 5); % if e samples are further than this apart, tag as big
addParameter(p, "diss_warning_fraction", 0.15); % When to warn about difference of e probes > diss_warning_ratio
%% Binning parameters
addParameter(p, "bin_method", "median", @(x) ismember(x, ["median", "mean"])); % Which method to use to combine bins together
addParameter(p, "bin_Width", 1, validPositive); % Bin width in (m)
addParameter(p, "bin_dissFloor", 1e-11, validPositive); % Dissipation estimates less than this are set to nan, for bad electronics
addParameter(p, "bin_dissRatio", 5, validPositive); % If different probes are within this ratio, then use mean else the smaller one
%% NetCDF global attributes
addParameter(p, "netCDF_acknoledgement", missing, validString);
addParameter(p, "netCDF_contributer_name", missing, validString);
addParameter(p, "netCDF_contributer_role", missing, validString);
addParameter(p, "netCDF_creator_email", missing, validString);
addParameter(p, "netCDF_creator_institution", missing, validString);
addParameter(p, "netCDF_creator_name", missing, validString);
addParameter(p, "netCDF_creator_type", missing, validString);
addParameter(p, "netCDF_creator_url", missing, validString);
addParameter(p, "netCDF_id", missing, validString);
addParameter(p, "netCDF_institution", missing, validString);
addParameter(p, "netCDF_instrument_vocabulary", missing, validString);
addParameter(p, "netCDF_license", missing, validString);
addParameter(p, "netCDF_metadata_link", missing, validString);
addParameter(p, "netCDF_platform", missing, validString);
addParameter(p, "netCDF_platform_vocabulary", missing, validString);
addParameter(p, "netCDF_product_version", missing, validString);
addParameter(p, "netCDF_program", missing, validString);
addParameter(p, "netCDF_project", missing, validString);
addParameter(p, "netCDF_publisher_email", missing, validString);
addParameter(p, "netCDF_publisher_institution", missing, validString);
addParameter(p, "netCDF_publisher_name", missing, validString);
addParameter(p, "netCDF_publisher_type", missing, validString);
addParameter(p, "netCDF_publisher_url", missing, validString);
%%
parse(p, varargin{:});
a = p.Results(1);

a.dataRoot = abspath(a.dataRoot);
if ~isfolder(a.dataRoot)
    error("dataRoot is not a folder, %s", a.dataRoot);
end % if

names = string(p.Parameters);

for name = names(~ismember(names, p.UsingDefaults)) % Only work with non-default values
    x = str2double(a.(name));
    if ~isnan(x)
        a.(name) = x;
    end % if ~isnan
end % for name

for name = names(endsWith(names, "Root") & ~ismember(names, "dataRoot")) % Paths other than dataRoot
    dirname = a.(name);
    if isfolder(dirname)
        a.(name) = abspath(dirname);
    else % ~isfolder
        a.(name) = abspath(fullfile(a.dataRoot, dirname));
    end % if isfolder
end % for name

for name = names(endsWith(names, "Filename")) % Filenames
    fn = a.(name);
    if exist(fn, "file")
        a.(name) = abspath(fn);
    else
        a.(name) = abspath(fullfile(a.dataRoot, fn));
    end % if exist
end % for name

qPaths = endsWith(names, "Root") | endsWith(names, "Filename");
qKeep = structfun(@(x) isstring(x) || isnumeric(x), a)';
qProfile = ~startsWith(names, "bin") & ~qPaths & qKeep;
qBinned = ~qPaths & qKeep; % Includes profile parameters

hash_profile = string(dec2hex(keyHash(jsonencode(rmfield(a, names(~qProfile))))));
hash_bin = string(dec2hex(keyHash(jsonencode(rmfield(a, names(~qBinned))))));
a.profileRoot = fullfile(a.profileRoot, append("profiles.", hash_profile)); % Where to save profiles
a.binnedRoot = fullfile(a.binnedRoot, append("binned.", hash_bin)); % Where to save binned data
a.ctdRoot = fullfile(a.ctdRoot, append("CTD.", hash_profile));

a.logFilename = fullfile(a.logRoot, "log.txt"); % output of dairy
a.p2matFilename = fullfile(a.matRoot, "filenames.mat"); % filenames information table
a.profileInfoFilename = fullfile(a.profileRoot, "profileInfo.mat"); % Profile information table
a.castInfoFilename = fullfile(a.binnedRoot, "cast.info.mat");
a.comboInfoFilename = fullfile(a.binnedRoot, "combo.info.mat");
a.comboFilename = fullfile(a.binnedRoot, "combo.mat");
a.ctdFilename = fullfile(a.ctdRoot, "CTD.mat");
a.ctdInfoFilename = fullfile(a.ctdRoot, "CTD.info.mat");
a.chlorophyllFilename = fullfile(a.ctdRoot, "chlorophyll.mat");
a.chlorophyllInfoFilename = fullfile(a.ctdRoot, "chlorophyll.info.mat");
end % getInfo

%% Function to check if a value, string or numeric, is in a range, open/closed
function q = inRange(x, lhs, rhs, clhs, crhs)
arguments
    x
    lhs double = nan
    rhs double = nan
    clhs double = false
    crhs double = false
end; % arguments

q = false;

if isstring(x) || ischar(x)
    x = str2double(x);
    if isnan(x)
        return; % Not a numeric string
    end % if isnan
end % if

if ~isnan(lhs)
    if (lhs > x) || (~clhs && lhs >= x)
        return;
    end
end % isnan lhs

if ~isnan(rhs)
    if (rhs < x) || (~crhs && rhs <= x)
        return;
    end
end % isnan lhs
q = true;
end % inRange

function name = abspath(name)
arguments
    name string
end % arguments
try
    items = dir(name);
    item = items(1);
    if isfolder(name)
        name = item.folder;
    else % File
        name = fullfile(item.folder, item.name);
    end % if isfolder
catch
end % try
end % abspath
