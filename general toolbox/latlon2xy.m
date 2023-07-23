% Calculate a north/south east/west signed distances and Euclidean distance
% on a sphere between consecutive points
%
% April-2023, Pat Welch, pat@mousebrains
%             Change from vecnorm to sqrt(sum(diff)) since it is faster
%             I don't understand where radius came from

function [pos,dist] = latlon2xy(lat,lon,lat_c,lon_c)
radius=6373.19*1e3; % spherical radius of earth in m
dy = radius * pi / 180; % length of 1 degree of circumferance in latitude
dx = radius * cosd(lat_c) * pi / 180; % Length of 1 degree of circumferance in longitude at latitude
pos = [(lon - lon_c) * dx, (lat - lat_c) * dy]'; % signed distances in x and y relative to lat/lon_c, an nx2 matrix
dist = sqrt(sum(diff(pos, 1, 2).^2))'; % Euclidean distance between points
end % latlon2xy