% Add in seawater properties to slow

function slow = addSeawaterProperties(profile)
arguments
    profile struct
end % arguments

slow = profile.slow;
slow.JAC_SP = gsw_SP_from_C(slow.JAC_C, slow.JAC_T, slow.P_slow); % Practical salinity
slow.JAC_SA = gsw_SA_from_SP(slow.JAC_SP, slow.P_slow, profile.lon, profile.lat); % Absolute salinity
slow.JAC_theta = gsw_CT_from_t(slow.JAC_SA, slow.JAC_T, slow.P_slow); % Conservation T
slow.JAC_sigma = gsw_sigma0(slow.JAC_SA, slow.JAC_theta);
slow.JAC_rho = gsw_rho(slow.JAC_SA, slow.JAC_theta, slow.P_slow) - 1000; % density kg/m^3 - 1000
slow.depth = gsw_depth_from_z(gsw_z_from_p(slow.P_slow, profile.lat));
end % addSeawaterProperties