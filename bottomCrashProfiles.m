% Trim the bottom part of profiles before the VMP crashes into the bottom

function pInfo = bottomCrashProfiles(profiles, pInfo, info)
arguments
    profiles cell
    pInfo table
    info struct
end % arguments
%%

if info.bbl_use
    warning("Bottom Crash Detection not implemented!");
end % if info.bbl_use

nProfiles = numel(profiles);
pInfo.bottomDepth = pInfo.maxDepth + 1; % Past the deepest part of each profile
end % trimProfiles