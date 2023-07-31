%
% Convert P files to binned data
%
% This is ground up rewrite of Fucent's code with a lot of enhancements
%
% July-2023, Pat Welch, pat@mousebrains.com
%
%%

function cInfo = processVMPfiles(varargin)

%% Default for saves will now be v7.3 during this session
rootSettings = settings();
rootSettings.matlab.general.matfile.SaveFormat.TemporaryValue = "v7.3";

%% Process input arguments and build a structure with parameters
info = getInfo(varargin{:}); % Parse arguments and supply defaults

diary(info.logFilename);
diary on;
fprintf("\n\n********* Started at %s **********\n\n", datetime());
fprintf("%s\n\n", jsonencode(rmfield(info, "gpsClass"), "PrettyPrint", true));

try
    filenames = mkFilenames(info); % Build a list of filenames to be processed from .P files on disk
    filenames = convert2mat(filenames); % Convert .P to .mat files
    save(info.p2matFilename, "filenames"); % Save the list of filenames for future processing

    % filenames = filenames(union(18,200:202),:);

    pInfo = mat2profiles(filenames, info); % Split into profiles

    bInfo = binData(pInfo, info); % Bin profiles into depth bins
    cInfo = mkCombo(bInfo, info); % Combine profiles together
    mkComboNetCDF(info); % Create a NetCDF version of combo.mat, if needed

    binCTD(pInfo, info); % Bin CTD and CTD data by time bins
catch ME
    fprintf("\n\nEXCEPTION\n%s\n\n", getReport(ME));
end % try

fprintf("\n\n********* Finished at %s **********\n", datetime());
diary off;

end % processVMPfiles
