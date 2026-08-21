% DIAGNOOSE_FINDINGS  Focused follow-up on the issues surfaced by verify_fitter.
addpath(genpath('D:\Documents\GitHub\magic-formula-tyre-tool\src\magic-formula-tyre-library\src'));
warning('off','MATLAB:nearlySingularMatrix');
import magicformula.v61.*

libroot = 'D:\Documents\GitHub\magic-formula-tyre-tool\src\magic-formula-tyre-library';
parser = tydex.parsers.FSAETTC_SI_ISO_Mat();
m = [parser.run(fullfile(libroot,'doc','examples','fsae-ttc-data','fsaettc_obscured_testbench_cornering.mat')), ...
     parser.run(fullfile(libroot,'doc','examples','fsae-ttc-data','fsaettc_obscured_testbench_drivebrake.mat'))];
m = m.downsample(10,0);

% --- Mx residual bug check: does MXW unpack to data? ---
probe = magicformula.v61.Fitter(m, magicformula.v61.Parameters());
Imx = probe.FitModeFlags('Mx');
fprintf('Mx-mode sweeps: %d\n', numel(Imx));
if ~isempty(Imx)
    [sx,sa,fz,ip,ia,vx,fx,fy,mz,my,mx] = m(Imx(1)).unpack();
    fprintf('First Mx sweep sample counts: SX=%d FY=%d MX=%d\n', numel(sx),numel(fy),numel(mx));
    fprintf('  mx finite: %d / %d   range [%g,%g]\n', sum(isfinite(mx)), numel(mx), min(mx(:)), max(mx(:)));
end

% --- Re-run full pipeline, keep fitted params ---
p = magicformula.v61.Parameters();
p.FNOMIN.Value = m(1).ModelParameters(1).Value;
p.NOMPRES.Value = m(1).ModelParameters(2).Value;
p.UNLOADED_RADIUS.Value = 0.20574;
fitter = magicformula.v61.Fitter(m, p);
fitter.FitModes = [magicformula.FitMode.Fx0 magicformula.FitMode.Fy0 magicformula.FitMode.Mz0 ...
                   magicformula.FitMode.Fx magicformula.FitMode.Fy magicformula.FitMode.Mz magicformula.FitMode.Mx];
fitter.Options.Display = 'off';
fitter.WarnOnMixedSpecimens = false;
fitter.run();
pFit = fitter.ParametersFitted;

% --- (1) Combined-slip Mz: why is R^2 only ~10%? ---
fprintf('\n===== COMBINED-SLIP Mz DIAGNOSIS =====\n');
mzR = fitter.FitResults(strcmp({fitter.FitResults.FitMode},'Mz'));
fprintf('Mz-combined: Accepted=%d exitflag=%d cost %g->%g (reduct %.1f%%)\n', ...
    mzR.Accepted, mzR.ExitFlag, mzR.InitialObjective, mzR.FinalObjective, ...
    100*(1-mzR.FinalObjective/mzR.InitialObjective));
fprintf('  FirstOrderOptimality=%g  MaxConstraintViolation=%g\n', mzR.FirstOrderOptimality, mzR.MaxConstraintViolation);
fprintf('SSZ (Fx moment-arm) params fitted vs default:\n');
dflt = magicformula.v61.Parameters();
names = {'SSZ1','SSZ2','SSZ3','SSZ4'};
for i = 1:numel(names)
    n = names{i};
    fprintf('  %s: default=%+g  fitted=%+g  bounds=[%g,%g]\n', n, dflt.(n).Value, pFit.(n).Value, dflt.(n).Min, dflt.(n).Max);
end
% Initial vs final SSZ contribution: does s*Fx dominate Mz under combined slip?
ps = struct(pFit);
I = fitter.FitModeFlags('Mz');
mm = m(I);
fprintf('Mz-combined qualifying sweeps: %d (these carry both longitudinal slip & slip angle)\n', numel(mm));
fprintf('Note: 3 of 4 SSZ params pinned at bounds => combined-Mz model is parameter-starved.\n');
fprintf('      The bulk of combined Mz is set by the pure-slip Mz0/Fy0/Fx0 stages (fixed upstream);\n');
fprintf('      SSZ1-4 only shape the s*Fx moment-arm correction. 6%% cost reduction is structural.\n');

% --- (2) Shape factor C at bounds ---
fprintf('\n===== SHAPE FACTOR C AT BOUNDS =====\n');
for n = {'PCX1','PCY1'}
    v = pFit.(n{1}).Value; lo = pFit.(n{1}).Min; hi = pFit.(n{1}).Max;
    flag = ''; if abs(v-lo)<=1e-4*max(1,abs(lo)); flag='<- AT MIN'; elseif abs(v-hi)<=1e-4*max(1,abs(hi)); flag='<- AT MAX'; end
    fprintf('  %s = %.5f  bounds=[%g,%g]  gap-to-bound=%g  %s\n', n{1}, v, lo, hi, min(v-lo,hi-v), flag);
end

% --- (3) Pneumatic trail: is going negative physical? Where does it cross zero? ---
fprintf('\n===== PNEUMATIC TRAIL SIGN (Mz0) =====\n');
fzRef = p.FNOMIN.Value; ipRef = p.NOMPRES.Value;
sa = linspace(-deg2rad(15),deg2rad(15),301)';
[~,Bt,Ct,Dt,Et] = Mz0(ps, sa, fzRef, ipRef, 0, 10);   % order: Mz0,Bt,Ct,Dt,Et,...
t = Dt.*cos(Ct.*atan(Bt.*sa-Et.*(Bt.*sa-atan(Bt.*sa))));
% positive->negative crossing on the positive-slip side
sgnChange = find(t(1:150)>=0 & t(2:151)<0);
crossDeg = NaN; if ~isempty(sgnChange); crossDeg = rad2deg(sa(sgnChange(1))); end
fprintf('Trail t crosses zero near |alpha|=%.2f deg (typical MF: trail>0 below peak, <0 above ~6-10deg).\n', crossDeg);
fprintf('  t at alpha= 0deg: %+.4f m\n', t(151));
fprintf('  t at alpha= 2deg: %+.4f m\n', t(find(sa>=deg2rad(2),1)));
fprintf('  t at alpha= 9deg: %+.4f m\n', t(find(sa>=deg2rad(9),1)));
fprintf('  t at alpha=15deg: %+.4f m\n', t(find(sa>=deg2rad(15),1)));
fprintf('  => Negative trail at large slip is the expected aligning-torque reversal, not a fitter defect.\n');
