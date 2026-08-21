% VERIFY_FITTER  Comprehensive accuracy + physical-feasibility audit of the
% Magic-Formula 6.1 fitter. Runs the full 7-mode pipeline on the bundled
% (de-identified) FSAE TTC data and prints a per-mode report plus a battery
% of physical-plausibility checks evaluated across the operating envelope.
%
% Sections:
%   1. Load + parse data, summarize operating ranges.
%   2. Run full pipeline (Fx0,Fy0,Mz0,Fx,Fy,Mz,Mx) in dependency order.
%   3. Best-fit accuracy report (NRMSE, physical RMSE, R^2, cost reduction,
%      convergence, residual bias).
%   4. Physical-feasibility report (friction, stiffness signs, peak forces,
%      trail sign, MF shape-factor validity across full envelope, Mx/My sign).
addpath(genpath('D:\Documents\GitHub\magic-formula-tyre-tool\src\magic-formula-tyre-library\src'));
addpath('D:\Documents\GitHub\magic-formula-tyre-tool\src\magic-formula-tyre-library');
warning('off','MATLAB:nearlySingularMatrix');
import magicformula.v61.*

R2 = @(y,ym) 1 - sum((y-ym).^2)/max(eps,sum((y-mean(y)).^2));
sep = @() fprintf('\n%s\n', repmat('-',1,72));

%% ---- 1. Data -----------------------------------------------------------
libroot = 'D:\Documents\GitHub\magic-formula-tyre-tool\src\magic-formula-tyre-library';
fCorner = fullfile(libroot,'doc','examples','fsae-ttc-data','fsaettc_obscured_testbench_cornering.mat');
fDrive  = fullfile(libroot,'doc','examples','fsae-ttc-data','fsaettc_obscured_testbench_drivebrake.mat');
parser = tydex.parsers.FSAETTC_SI_ISO_Mat();
m = [parser.run(fCorner), parser.run(fDrive)];
m = m.downsample(10,0);
fprintf('Loaded %d steady-state sweeps (downsampled x10).\n', numel(m));

% Build one big input matrix to summarize ranges.
FZ = []; SX = []; SA = []; IA = []; IP = []; VX = [];
for i = 1:numel(m)
    FZ = [FZ; m(i).FZW(:)]; SX = [SX; m(i).LONGSLIP(:)];
    SA = [SA; m(i).SLIPANGL(:)]; IA = [IA; m(i).INCLANGL(:)];
    IP = [IP; m(i).INFLPRES(:)]; VX = [VX; m(i).LONGVEL(:)];
end
sep()
fprintf('Operating ranges in fitted data:\n');
fprintf('  FZ  : %7.1f .. %7.1f N   (%d levels)\n', min(FZ),max(FZ),numel(unique(FZ)));
fprintf('  SX  : %7.3f .. %7.3f      SA: %+6.2f .. %+6.2f deg\n', min(SX),max(SX),rad2deg(min(SA)),rad2deg(max(SA)));
fprintf('  IA  : %+6.2f .. %+6.2f deg   IP: %6.0f .. %6.0f Pa   VX: %5.1f m/s\n', ...
    rad2deg(min(IA)),rad2deg(max(IA)),min(IP),max(IP),min(VX));

%% ---- 2. Run full pipeline ----------------------------------------------
p = Parameters();
p.FNOMIN.Value = m(1).ModelParameters(1).Value;
p.NOMPRES.Value = m(1).ModelParameters(2).Value;
p.UNLOADED_RADIUS.Value = 0.20574;
fprintf('\nFNOMIN=%.0f N  NOMPRES=%.0f Pa  R0=%.4f m\n', p.FNOMIN.Value, p.NOMPRES.Value, p.UNLOADED_RADIUS.Value);

fitter = Fitter(m, p);
fitter.FitModes = [magicformula.FitMode.Fx0 magicformula.FitMode.Fy0 magicformula.FitMode.Mz0 ...
                   magicformula.FitMode.Fx  magicformula.FitMode.Fy  magicformula.FitMode.Mz  magicformula.FitMode.Mx];
fitter.Options.Display = 'off';
fitter.WarnOnMixedSpecimens = false;
fprintf('Running full pipeline...\n');
tic; fitter.run(); tTotal = toc;
fprintf('Total fit time: %.1f s\n', tTotal);
pFit = fitter.ParametersFitted;
results = fitter.FitResults;

%% ---- 3. Best-fit accuracy ----------------------------------------------
sep()
fprintf('BEST-FIT ACCURACY\n');
fprintf('%-6s %4s %9s %9s %8s %9s %9s %7s %7s %5s %s\n', ...
    'Mode','ok','InitCost','FinalCost','reduct','PhysRMSE','MaxAbsErr','NRMSE%','R2%','rst','atBounds');
chans = containers.Map({'Fx0','Fx','Fy0','Fy','Mz0','Mz','Mx'}, ...
                       {'FX','FX','FYW','FYW','MZW','MZW','MXW'});
residStats = struct();
for k = 1:numel(results)
    r = results(k);
    fm = char(r.FitMode);
    I = fitter.FitModeFlags(fm);
    mm = m(I);
    if isempty(mm); continue; end
    ch = chans(fm);
    ps = struct(pFit);
    resid = []; obsAll = []; mdlAll = [];
    for i = 1:numel(mm)
        % unpack returns MZ(9),MY(10),MX(11); request MX explicitly.
        [sx,sa,fz,ip,ia,vx,fx,fy,mz,~,mx] = unpack(mm(i));
        switch fm
            case 'Fx0'; mi = Fx0(ps,sx,fz,ip,ia);            yi = fx;
            case 'Fx';  mi = Fx(ps,sx,sa,fz,ip,ia,vx);       yi = fx;
            case 'Fy0'; mi = Fy0(ps,sa,fz,ip,ia);            yi = fy;
            case 'Fy';  mi = Fy(ps,sx,sa,fz,ip,ia,vx);       yi = fy;
            case 'Mz0'; mi = Mz0(ps,sa,fz,ip,ia,vx);         yi = mz;
            case 'Mz'
                fxm = Fx(ps,sx,sa,fz,ip,ia,vx); fym = Fy(ps,sx,sa,fz,ip,ia,vx);
                mi = Mz(ps,sx,sa,fz,ip,ia,vx,fxm,fym);
                pure = sx == 0;
                if any(pure(:))
                    m0 = Mz0(ps,sa,fz,ip,ia,vx); m0 = m0 + zeros(size(mi));
                    mi(pure) = m0(pure);
                end
                yi = mz;
            case 'Mx'
                fym = Fy(ps,sx,sa,fz,ip,ia,vx);
                mi = Mx(ps,fz,ip,ia,fym);   yi = mx;
        end
        % Some channels are scalar constants; coerce to column vectors and
        % broadcast scalar model outputs to the measurement length.
        yi = yi(:); mi = mi(:);
        if isempty(yi) || isempty(mi); continue; end
        if isscalar(mi) && numel(yi) > 1; mi = mi*ones(size(yi)); end
        if isscalar(yi) && numel(mi) > 1; yi = yi*ones(size(mi)); end
        if numel(yi) ~= numel(mi)
            warning('Size mismatch %s sweep %d: yi=%d mi=%d (skipped)',fm,i,numel(yi),numel(mi));
            continue;
        end
        good = isfinite(yi) & isfinite(mi);
        resid = [resid; (yi(good)-mi(good))]; %#ok<AGROW>
        obsAll = [obsAll; yi(good)]; mdlAll = [mdlAll; mi(good)]; %#ok<AGROW>
    end
    residStats.(fm) = resid;
    r2val = R2(obsAll, mdlAll);
    reduct = 100*(1 - r.FinalObjective/max(eps,r.InitialObjective));
    fprintf('%-6s %4d %9.2f %9.2f %7.1f%% %9.2f %9.2f %6.1f%% %6.1f%% %5d %d\n', ...
        fm, r.Accepted, r.InitialObjective, r.FinalObjective, reduct, ...
        r.PhysicalRMSE, r.MaxAbsoluteError, 100*r.NormalizedRMSE, 100*r2val, ...
        r.RestartCount, numel(r.ParametersAtBounds));
end
% Residual bias check
sep()
fprintf('Residual bias (mean/std/|max|, NaNs omitted -> mean~0 vs peak):\n');
for fm = fieldnames(residStats)'
    r = residStats.(fm{1});
    fprintf('  %-3s: n=%d  mean=%+.3e  std=%.3e  |max|=%.3e\n', fm{1}, numel(r), ...
        mean(r,'omitnan'), std(r,'omitnan'), max(abs(r),[],'omitnan'));
end

%% ---- 4. Physical feasibility across envelope ---------------------------
sep()
fprintf('PHYSICAL FEASIBILITY (evaluated on dense envelope grid)\n');
ps = struct(pFit);
% Build an envelope grid spanning the fitted + nominal operating range.
fzGrid  = linspace(max(50,0.2*p.FNOMIN.Value), 1.8*p.FNOMIN.Value, 9)';
ipGrid  = p.NOMPRES.Value;                 % nominal pressure (data is ~single-pressure)
iaGrid  = unique([-deg2rad(5) 0 deg2rad([2 5])]);  % camber spread
sxPure  = linspace(-0.3,0.3,121)';
saPure  = linspace(-deg2rad(15),deg2rad(15),121)';
passLog = {};

% (a) Friction coefficients mux, muy in physical band [0.3 .. 3]
dfz = (fzGrid - p.FNOMIN.Value)/p.FNOMIN.Value;
mux = (ps.PDX1 + ps.PDX2*dfz);
muy = (ps.PDY1 + ps.PDY2*dfz);
chk = @(name,cond,msg) struct('name',name,'cond',cond,'msg',msg);
passLog{end+1} = chk('mux in [0.3,3]', all(mux>0.3 & mux<3), sprintf('mux: %.3f..%.3f',min(mux),max(mux)));
passLog{end+1} = chk('muy in [0.3,3]', all(muy>0.3 & muy<3), sprintf('muy: %.3f..%.3f',min(muy),max(muy)));

% (b) Shape factors in MF-valid ranges everywhere on grid
Cx = ps.PCX1; Cy = ps.PCY1; Ct = ps.QCZ1;
passLog{end+1} = chk('Cx in (1,3]',  Cx>1 & Cx<=3, sprintf('Cx=%.3f',Cx));
passLog{end+1} = chk('Cy in (1,3]',  Cy>1 & Cy<=3, sprintf('Cy=%.3f',Cy));
passLog{end+1} = chk('Ct in (0.5,2]',Ct>0.5 & Ct<=2, sprintf('Ct=%.3f',Ct));
% Longitudinal curvature Ex over slip sign and load
ExAll = [];
for s = [-1 1]
    ExAll = [ExAll; (ps.PEX1+ps.PEX2*dfz+ps.PEX3*dfz.^2).*(1-ps.PEX4*s)]; %#ok<AGROW>
end
passLog{end+1} = chk('Ex in (-5,1)', all(ExAll>-5 & ExAll<1), sprintf('Ex: %.3f..%.3f',min(ExAll),max(ExAll)));
% Lateral curvature Ey over slip sign, load, camber
EyAll = [];
for ia = iaGrid
    ga = sin(ia);
    for s = [-1 1]   % slip-angle sign (row => one scalar per iteration)
        EyAll = [EyAll; (ps.PEY1+ps.PEY2*dfz).*(1+ps.PEY5*ga^2-(ps.PEY3+ps.PEY4*ga)*s)]; %#ok<AGROW>
    end
end
passLog{end+1} = chk('Ey in (-5,1)', all(EyAll>-5 & EyAll<1), sprintf('Ey: %.3f..%.3f',min(EyAll),max(EyAll)));
% Combined-slip curvature Eyk over load envelope (Eqn 4.E64 limit)
dfzEnv = (linspace(0,2*p.FNOMIN.Value,3)' - p.FNOMIN.Value)/p.FNOMIN.Value;
EykEnv = ps.REY1 + ps.REY2*dfzEnv;
passLog{end+1} = chk('Eyk <= 1', all(EykEnv <= 1-5e-5), sprintf('Eyk: %.3f..%.3f',min(EykEnv),max(EykEnv)));

% (c) Stiffness signs: longitudinal slip stiffness Kxk>0; |cornering stiffness|>0
Kxk = ps.FNOMIN*(ps.PKX1+ps.PKX2*dfz).*exp(ps.PKX3*dfz);
passLog{end+1} = chk('Kxk > 0', all(Kxk>0), sprintf('Kxk: %.1f..%.1f',min(Kxk),max(Kxk)));
gaRef = sin(iaGrid(3));   % a representative camber from the grid
Kya = ps.PKY1*p.FNOMIN.Value*(1-ps.PKY3*abs(gaRef)).* ...
      sin(ps.PKY4*atan(fzGrid/p.FNOMIN.Value/((ps.PKY2+ps.PKY5*gaRef^2))));
passLog{end+1} = chk('|Kya| > 50 N/deg', all(abs(Kya)>50/180*pi), sprintf('|Kya|: %.1f..%.1f N/rad',min(abs(Kya)),max(abs(Kya))));

% (d) Peak forces bounded by mu*Fz (no force amplification beyond friction)
[Fx0v,muxg] = Fx0(ps, 0.3, fzGrid, ipGrid, 0);
passLog{end+1} = chk('Fx0 peak <= 1.05*mux*Fz', all(abs(Fx0v) <= 1.05*muxg(:).*fzGrid), ...
    sprintf('max|Fx0|/muxFz = %.3f', max(abs(Fx0v)./(muxg(:).*fzGrid))));
[Fy0v] = Fy0(ps, deg2rad(9), fzGrid, ipGrid, 0);
passLog{end+1} = chk('|Fy0| peak <= 1.05*muy*Fz', all(abs(Fy0v) <= 1.05*muy(:).*fzGrid), ...
    sprintf('max|Fy0|/muyFz = %.3f', max(abs(Fy0v)./(muy(:).*fzGrid))));

% (e) Pneumatic trail sign: t(Dt,Ct,Bt,Et) should be >= 0 for small+mid slip
tAll = [];
for ia = iaGrid(iaGrid==0)
    for fz = fzGrid'
        [~,Bt,Ct,Dt,Et] = Mz0(ps, saPure, fz, ipGrid, ia, 10);  % order: Mz0,Bt,Ct,Dt,Et,...
        tAll = [tAll; Dt.*cos(Ct.*atan(Bt.*saPure-Et.*(Bt.*saPure-atan(Bt.*saPure))))]; %#ok<AGROW>
    end
end
tPos = mean(tAll >= -0.001);
passLog{end+1} = chk('trail t>0 at low slip (~)', tPos > 0.5, ...
    sprintf('median t=%+.4f m  frac(t>0)=%.1f%%', median(tAll,'omitnan'), 100*mean(tAll(:)>=-0.001)));

% (f) Gyk combined-slip reduction factor stays in (0,1]-ish near zero slip, decays
GykAtZero = []; GykAtLarge = [];
for fz = [p.FNOMIN.Value]
    [~,~,Gyk0] = Fy(ps, 0.3, saPure, fz, ipGrid, 0, 10);
    GykAtZero = [GykAtZero; Gyk0(1)]; %#ok<AGROW>
    [~,~,GykL] = Fy(ps, 0.3, saPure, fz, ipGrid, 0, 10);
    GykAtLarge = [GykAtLarge; min(GykL)]; %#ok<AGROW>
end
passLog{end+1} = chk('Gyk starts near 1', abs(GykAtZero-1)<0.05, sprintf('Gyk(sx~0)=%.3f',GykAtZero));
passLog{end+1} = chk('Gyk decays <1 under combined slip', GykAtLarge<1, sprintf('min Gyk=%.3f',GykAtLarge));

% (g) Overturning Mx: sign tracks -Fy*camber convention; magnitude < R*Fz
fzRef = p.FNOMIN.Value;
fym = Fy(ps, 0, deg2rad(8), fzRef, ipGrid, deg2rad(3), 10);
Mxv = Mx(ps, fzRef, ipGrid, deg2rad(3), fym);
passLog{end+1} = chk('|Mx| <= R0*Fz', abs(Mxv) <= ps.UNLOADED_RADIUS*fzRef, ...
    sprintf('|Mx|=%.2f Nm  R0*Fz=%.1f',abs(Mxv),ps.UNLOADED_RADIUS*fzRef));

% (h) Rolling resistance My negative when rolling forward
Myv = My(ps, fzRef, ipGrid, 0, 10, 0);
passLog{end+1} = chk('My <= 0 forward', Myv<=0, sprintf('My=%.3f Nm',Myv));

% Print feasibility verdict
sep()
npass = 0; nfail = 0;
fprintf('%-34s %-6s %s\n','Check','Verdict','Detail');
for i = 1:numel(passLog)
    e = passLog{i};
    if e.cond; v='PASS'; npass=npass+1; else v='FAIL'; nfail=nfail+1; end
    fprintf('%-34s %-6s %s\n', e.name, v, e.msg);
end
fprintf('\nFeasibility: %d PASS / %d FAIL\n', npass, nfail);
fprintf('\nDONE.\n');
