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

[dissInfo, SH_HP, A_HP] = mkDissInfo(profile, info, pInfo, ...
    "diss_downwards_fft_length_sec", "diss_downwards_length_fac");

if info.trim_use % Trim the top of the profile
    q = dissInfo.P >= (pInfo.trimDepth + info.trim_extraDepth);
    SH_HP = SH_HP(q,:);
    A_HP  = A_HP(q,:);
    for name = ["speed", "T", "t", "P"]
        dissInfo.(name) = dissInfo.(name)(q);
    end % for name
end % if trim_use


if size(SH_HP,1) >= dissInfo.diss_length % enough data to work with
    try
        diss = get_diss_odas(SH_HP, A_HP, dissInfo);

        ratioWarn(diss, pInfo, info, "Top->Bot");
        profile.diss = mkDissStruct(diss, dissInfo);
    catch ME
        ME
        profile.diss = mkEmptyDissStruct(dissInfo);
    end % try

else % Too little data, so fudge up profile.diss
    profile.diss = mkEmptyDissStruct(dissInfo);
end % if ~isempty

%% Calculate dissipation bottom to top

[dissInfo, SH_HP, A_HP] = mkDissInfo(profile, info, pInfo, ...
    "diss_upwards_fft_length_sec", "diss_upwards_length_fac");

if info.bbl_use % Trim the bottom of the profile
    q = dissInfo.P <= (pInfo.bottomDepth + info.bbl_extraDepth);
    SH_HP = SH_HP(q,:);
    A_HP  = A_HP(q,:);
    for name = ["speed", "T", "t", "P"]
        dissInfo.(name) = dissInfo.(name)(q);
    end % for name
end % if trim_use

if size(SH_HP,1) >= dissInfo.diss_length % enough data to work with
    % flip upside down so the dissipation is calculated from the bottom upwards

    SH_HP = flipud(SH_HP);
    A_HP = flipud(A_HP);
    for name = ["speed", "T", "t", "P"]
        dissInfo.(name) = flipud(dissInfo.(name));
    end % for name

    try
        diss = get_diss_odas(SH_HP, A_HP, dissInfo);

        ratioWarn(diss, pInfo, info, "Bot->Top");
        profile.bbl = mkDissStruct(diss, dissInfo);
    catch ME
        ME
        profile.diss = mkEmptyDissStruct(dissInfo);
    end % try
else % Too little data, so fudge up profile.diss
    profile.diss = mkEmptyDissStruct(dissInfo);
end % if ~isempty
end % despikeProfile

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
pNames = ["speed", "nu", "P", "T", "t"];
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

function ratioWarn(diss, pInfo, info, tit)
arguments
    diss struct
    pInfo table
    info struct
    tit string
end % arguments
%%
maxRatio = log10(info.diss_warning_ratio) / 2; % /2 due to mean
eLog = log10(diss.e);
mu = repmat(mean(eLog, "omitmissing"), size(diss.e,1), 1);
qFrac = sum(any(abs(mu - eLog) > maxRatio)) / size(diss.e,2);
if qFrac > info.diss_warning_fraction
    fprintf("Bad %s dissipation ratio, %.0f%% %d/%d for profile %d in %s %s\n", ...
        tit, qFrac * 100, ...
        round(qFrac*size(diss.e,2)), size(diss.e,2), ...
        pInfo.index, pInfo.sn, pInfo.basename);
end % if qFrac
end % ratioWarn

function [dissInfo, SH_HP, A_HP] = mkDissInfo(profile, info, pInfo, fftSec, fftFac)
arguments
    profile struct
    info struct
    pInfo (1,:) table
    fftSec string
    fftFac string
end % arguments
%%
fast = profile.fast; % fast variables for despiking
fft_length_sec = info.(fftSec);
fft_length_fac = info.(fftFac);

Ax = myDespike(fast.Ax, profile.fs_fast, info, "A", append("Ax ", fftSec), pInfo);
Ay = myDespike(fast.Ay, profile.fs_fast, info, "A", append("Ay ", fftSec), pInfo);
SH1 = myDespike(fast.sh1, profile.fs_fast, info, "sh", append("sh1 ", fftSec), pInfo);
SH2 = myDespike(fast.sh2, profile.fs_fast, info, "sh", append("sh2 ", fftSec), pInfo);

%% High pass signal for dissipation

HP_cut = 0.5 * 1 / fft_length_sec; % Follow Matlab manual
[bh, ah] = butter(1, HP_cut / profile.fs_fast / 2, "high");

SH1_HP = myHighPassFilter(SH1, ah, bh); % Filter SH1
SH2_HP = myHighPassFilter(SH2, ah, bh); % Filter SH2

%% Calculate dissipation top to bottom

dissInfo = struct();
dissInfo.fft_length = round(fft_length_sec * profile.fs_fast);
dissInfo.diss_length = fft_length_fac * dissInfo.fft_length;
dissInfo.overlap = ceil(dissInfo.diss_length / 2);
dissInfo.fs_fast = profile.fs_fast;
dissInfo.fs_slow = profile.fs_slow;
dissInfo.speed = fast.speed_fast;
dissInfo.T = (info.diss_T1Norm * fast.T1_fast*2 + info.diss_T2Norm * fast.T2_fast) / (info.diss_T1Norm + info.diss_T2Norm); 
dissInfo.t = fast.t_fast;
dissInfo.P = fast.P_fast;

SH_HP = [SH1_HP, SH2_HP];
A_HP = [Ax, Ay];
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

function hp = myHighPassFilter(sh, ah, bh)
arguments
    sh (:,1) {mustBeNumeric}
    ah (1,:) {mustBeNumeric}
    bh (1,:) {mustBeNumeric}
end % arguments
%%
% Do a forward filter then flip and reverse filter
hp = filter(bh, ah, sh); % Filter forwards
hp = flipud(hp); % Flip forwards to backwards
hp = filter(bh, ah, hp); % Filter backwards
hp = flipud(hp); % Flip backwards to forward
end % myHighPassFilter
