
% Despike a profile, then calculate the dissipation from the shear probes
%
% This is a ground up rewrite of my code derived from Fucent's code
%
% June-2023, Pat Welch, pat@mousebrains.com

function profile = calcDissShear(profile, pInfo, info)
arguments
    profile struct,
    pInfo table,
    info struct,
end % arguments

label = sprintf("%s/%s cast %d", pInfo.sn, pInfo.basename, pInfo.index);

[dissInfo, SH_HP, AA] = mkDissInfo(profile, info, pInfo, ...
    "diss_downwards_fft_length_sec", "diss_downwards_length_fac", label);

if info.trim_use % Trim the top of the profile
    q = dissInfo.P >= (pInfo.trimDepth + info.trim_extraDepth);
    SH_HP = SH_HP(q,:);
    AA  = AA(q,:);
    for name = ["speed", "T", "t", "P"]
        dissInfo.(name) = dissInfo.(name)(q);
    end % for name
end % if trim_use

if size(SH_HP,1) >= dissInfo.diss_length % enough data to work with
    try
        diss = get_diss_odas(SH_HP, AA, dissInfo);
        diss = mkEpsilonMean(diss, info.diss_epsilon_minimum, dissInfo.diss_length, ...
            profile.fs_fast, info.diss_warning_fraction, label);
        diss.depth = interp1(profile.slow.t_slow, profile.slow.depth, diss.t, "linear", "extrap");
        diss.t = pInfo.t0 + seconds(diss.t - diss.t(1));
        profile.diss = mkDissStruct(diss, dissInfo);
    catch ME
        fprintf("Error %s calculating Top->Bottom dissipation, %s\n", label, ME.message);
        for i = 1:numel(ME.stack)
            stk = ME.stack(i);
            fprintf("Stack(%d) line=%d name=%s file=%s\n", i, stk.line, string(stk.name), string(stk.file));
        end % for i
        profile.diss = mkEmptyDissStruct(dissInfo);
    end % try

else % Too little data, so fudge up profile.diss
    profile.diss = mkEmptyDissStruct(dissInfo);
end % if ~isempty

%% Calculate dissipation bottom to top

[dissInfo, SH_HP, AA] = mkDissInfo(profile, info, pInfo, ...
    "diss_upwards_fft_length_sec", "diss_upwards_length_fac", label);

if info.bbl_use % Trim the bottom of the profile
    q = dissInfo.P <= (pInfo.bottomDepth + info.bbl_extraDepth);
    SH_HP = SH_HP(q,:);
    AA  = AA(q,:);
    for name = ["speed", "T", "t", "P"]
        dissInfo.(name) = dissInfo.(name)(q);
    end % for name
end % if trim_use

if size(SH_HP,1) >= dissInfo.diss_length % enough data to work with
    % flip upside down so the dissipation is calculated from the bottom upwards

    SH_HP = flipud(SH_HP);
    AA = flipud(AA);
    for name = ["speed", "T", "t", "P"]
        dissInfo.(name) = flipud(dissInfo.(name));
    end % for name

    try
        diss = get_diss_odas(SH_HP, AA, dissInfo);
        diss = mkEpsilonMean(diss, info.diss_epsilon_minimum, dissInfo.diss_length, ...
            profile.fs_fast, info.diss_warning_fraction, label);
        diss.depth = interp1(profile.slow.t_slow, profile.slow.depth, diss.t, "linear", "extrap");
        profile.bbl = mkDissStruct(diss, dissInfo);
    catch ME
        fprintf("Error %s calculating Bottom->Top dissipation, %s\n", label, ME.message);
        for i = 1:numel(ME.stack)
            stk = ME.stack(i);
            fprintf("Stack(%d) line=%d name=%s file=%s\n", i, stk.line, string(stk.name), string(stk.file));
        end % for i
        profile.diss = mkEmptyDissStruct(dissInfo);
    end % try
else % Too little data, so fudge up profile.diss
    profile.diss = mkEmptyDissStruct(dissInfo);
end % if ~isempty
end % calcDissShear

function dInfo = mkEmptyDissStruct(dissInfo)
arguments
    dissInfo struct
end % arguments
dInfo = struct();
dInfo.info = dissInfo;
tbl = table();
tbl.P = nan(0); % For binning
dInfo.tbl = tbl;
end % mkEmptyDissStruct

function dInfo = mkDissStruct(diss, dissInfo)
arguments
    diss struct
    dissInfo struct
end % arguments
%%
dInfo = struct();
dInfo.info = dissInfo;
tbl = table();

% I don't like this hardcoding, but for single dissipation estimates I have
% not found a clean dynamic method!
npNames = ["e", "K_max", "method", "dof_e", "mad", "FM"];
pNames = ["speed", "nu", "P", "T", "t", "epsilonMean", "epsilonLnSigma", "depth"];
mnpNames = "Nasymth_spec";

for name = string(fieldnames(diss))'
    if ismember(name, pNames) % Column vectors of one sample per dissipation estimate
        tbl.(name) = diss.(name);
    elseif ismember(name, npNames) % n sensors x p dissipation estimates
        tbl.(name) = permute(diss.(name), [2,1]);
    elseif ismember(name, mnpNames) % m freq x n sensors x p disspation estimates
        tbl.(name) = perument(diss.(name), [3,2,1]);
    else
        dInfo.(name) = diss.(name);
    end % if
end % for

dInfo.tbl = tbl;
end % mkDissStruct

function [dissInfo, SH_HP, AA] = mkDissInfo(profile, info, pInfo, fftSec, fftFac, label)
arguments
    profile struct
    info struct
    pInfo (1,:) table
    fftSec string
    fftFac string
    label string
end % arguments
%%
fast = profile.fast; % fast variables for despiking
fft_length_sec = info.(fftSec);
fft_length_fac = info.(fftFac);

AA = table();
for name = ["Ax", "Ay"]
    AA.(name) = myDespike(fast.(name), profile.fs_fast, info, "A", ...
        append(label, " ", name, " ", fftSec), pInfo);
end
AA = table2array(AA);

% Grab all the shear probes
names = regexp(string(fast.Properties.VariableNames), "^sh\d+$", "once", "match");
names = unique(names(~ismissing(names))); % Sorted shear probes, assumes <10 shear probes

SH = table(); % Space for all the shear probes
for name = names
    SH.(name) = myDespike(fast.(name), profile.fs_fast, info, "sh", ...
        append(label, " ", name, " ", fftSec), pInfo);
end % for
SH = table2array(SH);

HP_cut = 0.5 * 1 / fft_length_sec; % Follow Matlab manual
[bh, ah] = butter(1, HP_cut / profile.fs_fast / 2, "high");
% Do a forward filter then flip and reverse filter
SH_HP = filter(bh, ah, SH); % Filter forwards
SH_HP = flipud(SH_HP); % Flip forwards to backwards
SH_HP = filter(bh, ah, SH_HP); % Filter backwards
SH_HP = flipud(SH_HP); % Flip backwards to forward

%% Calculate dissipation top to bottom

dissInfo = struct();
dissInfo.fft_length = round(fft_length_sec * profile.fs_fast);
dissInfo.diss_length = fft_length_fac * dissInfo.fft_length;
dissInfo.overlap = ceil(dissInfo.diss_length / 2);
dissInfo.fs_fast = profile.fs_fast;
dissInfo.fs_slow = profile.fs_slow;
dissInfo.speed = fast.speed_fast;
dissInfo.T = (info.diss_T1Norm * fast.T1_fast + info.diss_T2Norm * fast.T2_fast) / (info.diss_T1Norm + info.diss_T2Norm);
dissInfo.t = fast.t_fast;
dissInfo.P = fast.P_fast;
end % mkDissInfo

function b = myDespike(a, fs, info, codigo, tit, pInfo)
arguments
    a (:,1) {mustBeNumeric}
    fs (1,1) double {mustBePositive}
    info struct
    codigo string
    tit string
    pInfo (1,:) table
end % arguments
%%
p = struct();
for name = ["thresh", "smooth", "N_FS", "warning_fraction"]
    p.(name) = info.(sprintf("despike_%s_%s", codigo, name));
end % for name

[b, ~, ~, raction] = despike(a, p.thresh, p.smooth, fs, round(p.N_FS * fs));

if raction > p.warning_fraction
    fprintf("WARNING: %s spike ratio %.1f%% for profile %d in %s %s\n", ...
        tit, raction * 100, ...
        pInfo.index, pInfo.sn, pInfo.basename);
end % raction >
end % myDespike

%% Get the mean epsilon, subject to expected variance

function diss = mkEpsilonMean(diss, epsilonMinimumValue, diss_length, fs, warningFraction, label)
arguments
    diss struct % From get_diss_odas
    epsilonMinimumValue double {mustBePositive}
    diss_length double {mustBePositive}
    fs double {mustBePositive}
    warningFraction double
    label string
end

nu = diss.nu; % Dynamic viscosity
epsilon = diss.e'; % Transposed dissipation estimates
q = epsilon <= epsilonMinimumValue; % Values which should not exist, probably bad electronics
if any(q(:))
    epsilon(q) = nan;
    for index = 1:size(q,2)
        n = sum(q(:,index));
        if n > 0
            frac = n / size(q,1);
            if frac > warningFraction
                fprintf("WARNING: %s %.2f%% of the values for epsilon %d <= %g\n", ...
                    label, frac*100, index, epsilonMinimumValue);
            end % if
        end % if
    end % for
end % if any

L_K = (nu.^3 ./ epsilon).^(1/4); % Kolmogorov length (kg/m/s)
L = diss.speed * diss_length / fs; % Physical length of the data
L_hat = L ./ L_K;

Vf = 1; % Fraction of shear variance resolved by terminating the spectral integration at an upper wavenumber

L_f_hat = L_hat .* Vf.^(3/4);

var_ln_epsilon = 5.5 ./ (1 + (L_f_hat ./ 4).^(7/9)); % Variance of epsilon in log space
sigma_ln_epsilon = sqrt(var_ln_epsilon); % Standard deviation of epsilon in log space
mu_sigma_ln_epsilon = mean(sigma_ln_epsilon, 2, "omitmissing"); % Mean across shear probes at each time
CF95_range = 1.96 * sqrt(2) * mu_sigma_ln_epsilon; % 95% confidence interval in log space

for iter = 1:(size(epsilon,2)-1) % To avoid an infinite loop, this is the an at most amount
    minE = min(epsilon, [], 2, "omitmissing");
    [maxE, ix] = max(epsilon, [], 2, "omitmissing"); % get indices in case we want to drop them
    ratio = abs(diff(log([minE, maxE]), 1, 2));
    q = ratio > CF95_range; % If minE and maxE ratio -> 95% confidence interval
    if ~any(q), break; end % We're done, we can use all the values
    epsilon(sub2ind(size(epsilon), find(q), ix(q))) = nan; % Set the maximums that are outside the 95% interval to nan
    frac = sum(q) / size(epsilon,1);
    if frac > warningFraction
        fprintf("WARNING: %s dropping %.2f%% epsilons outside of 95%% confidence interval, iter=%d\n", ...
            label, sum(q) / size(epsilon,1) * 100, iter);
    end % if
end % for iter

mu = exp(mean(log(epsilon), 2, "omitmissing")); % Take the mean of the remaining values in log space
diss.epsilonMean = mu;
diss.epsilonLnSigma = mu_sigma_ln_epsilon;
end % mkEpsilonMean