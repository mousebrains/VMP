%% hotelfile_seaglider_netcdf
% Generate a hotel-file from the NetCDF files generated by a Seaglider
%%
% <latex>\index{Scripts!hotelfile\_seaglider\_netcdf}</latex>
%
%%% Syntax
%   User Script:  hotelfile_seaglider_netcdf
%
% * [file_num_range] Scan input NetCDF mission-files within the specified
%      range. 
% * [file_base_name] Base name of the input NetCDF mission-files. 
% * []
% * [output_file_name] Hotel-file created with the specified name. The
%      default name is derrived from the input-file names.
%
%%% Description
% Generate a hotel-file from the NetCDF mission-files of a Sea-glider that
% were generated by Kongsberg-supplied software. 
%
% The resulting hotel-file contains the subset of data from the NetCDF
% mission-files that are useful for converting RSI binary data files into
% physical units and for other purposes. All of the vectors that are
% extracted from the mission-files are interpolated to the RSI
% $\texttt{t\_fast}$ and $\texttt{t\_slow}$ time vectors. The mission data
% vectors are renamed using the $\texttt{\_fast}$ and $\texttt{\_slow}$
% postfixes. A direct comparison of mission-file data and RSI recorded data
% is then possible.
%
%%% Examples
% The hotel-file can be generated by navigating to the directory containing
% the NetCDF files.  This script is then executed.
%
%    >> hotelfile_seaglider_netcdf
%
% The resulting hotel-file can then be used with $\texttt{odas\_p2mat}$. In
% this example, a RSI raw binary data file ending in $\texttt{16}$ is used.
%
%    >> odas_p2mat('*16', 'vehicle', 'sea_glider', ...
%                  'hotel_file', 'my_hotel_file_name.mat');
%
% If there is a time offset between the RSI data and the data supplied
% within in the mission-file, a time offset can be added to the RSI
% instrument time.
%
%    >> odas_p2mat('*16', 'vehicle', 'sea_glider', ...
%                  'hotel_file', 'my_hotel_file_name.mat', ...
%                  'time_offset', -5);
%
% This is a script that you must edit. The parameters
% $\texttt{file\_num\_range}$, $\texttt{file\_base\_name}$ and
% $\texttt{output\_file\_name}$ are near the top of the function. The names
% of the desired data in the mission-file, and the names that they will
% attain in your RSI data mat-file are tabulated just below the parameter
% names. 

%%%%%%%% Credit

% Version History:
%
% 2015-02-03 RGL, Original version
% 2015-04-22 RGL, Original version
% 2015-04-23 RGL, added ability to read CTD data.
% 2015-04-20 WID, Slightly modified + documented.
% 2015-10-26 WID, Complete rewrite - support for final hotel file format.
% 2015-10-28 RGL, Document changes.
% 2015-11-18 RGL, Update documentation.

file_num_range   = 1:28;
file_base_name   = 'p613';
output_file_name = sprintf('%s_%04d_%04d', file_base_name,    ...
                                           file_num_range(1), ...
                                           file_num_range(end));

var_data = {
%   Sea-glider variable name  ODAS_P2MAT required name
    'time'                    'time'
    'speed'                   'speed'
    'speed_qc'                'speed_qc'
    'speed_gsm'               'speed_gsm'
    'horz_speed'              'H_speed'
    'vert_speed'              'V_speed'
    'depth'                   'P'
    'glide_angle'             'glide_angle'
    'eng_pitchAng'            'pitch'
    'eng_rollAng'             'roll'
};

% Construct NetCDF input data file names
inputfiles = {};
for file_num = file_num_range
    inputfiles{end+1} = sprintf('%s%04d.nc', file_base_name, file_num);
end

for sensor = var_data'
    data = [];
    for file = inputfiles
        try
            data2 = ncread(file{1}, sensor{1});
            data = [data; data2];
        catch; end
    end
    if strcmpi(sensor{2}, 'time')
        time = data;
    elseif ~isempty(data) && ~isempty(time)
        result.(sensor{2}).data = data;
        result.(sensor{2}).time = time;
    end
end

if ~exist('result', 'var')
    error('Hotel file data not found.');
end

% Modify pressure / depth values so they are in units of dBar
%for f = {'P', 'depth', 'P_CTD'}
%    if isfield(result,f{1})
%        result.(f{1}).data = result.(f{1}).data * 10;
%    end
%end

% Fix for speed_qc. Value provided as characters - convert into doubles.
if isfield(result,'speed_qc')
    result.speed_qc.data = double(result.speed_qc.data) - double('0');
end

% Modify speed values so they are in units of m/s
for f = {'speed', 'speed_gsm', 'H_speed', 'V_speed'}
    if isfield(result,f{1})
        result.(f{1}).data = result.(f{1}).data / 100;
    end
end


% Output file declared at the begining of the file.
save(output_file_name, '-struct', 'result')
