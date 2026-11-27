%% MATLAB Script Step 1: Analisi di Sensitivita' Analitica (Cira et al.) & Validazione TiberCAD Reale
% =================================================================================================
% Manuscript Revision: SEJ-D-26-04657 (Solar Energy)
% Authors: Alessia Di Vito & Matthias Auf der Maur
%
% COSA FA QUESTO SCRIPT (TUTTO LO STEP 1 COMPLETO E AUTOCONSISTENTE):
%   1. Calcola analiticamente e numericamente la rate di degradazione r_tot (DPO + WPO + idrato)
%      secondo Cira et al. (2025) e la propagazione dell'errore al primo ordine:
%        - Imposta in cima allo script la variabile `error_scale_factor` (es. 0.5 per +/- sigma/2,
%          1.0 per +/- 1 sigma, 1.96 per 95% CI) per controllare l'ampiezza della banda shaded
%          nelle Figure S1a (DPO vs P_O2) e S1b (WPO vs P_H2O).
%   2. Separa esplicitamente:
%        (A) Il contributo della SOLA DERIVATA PARZIALE normalizzata |dr/dp_i * (p_i / r)| (%),
%            che mostra analiticamente come varia r al variare percentuale di ciascun parametro;
%        (B) Il contributo di ciascun parametro all'ERRORE GLOBALE su r, [(dr/dp_i)*sigma_p_i]^2 / sigma_r^2 (%),
%            che mostra come il peso dell'incertezza sperimentale sulle energie di attivazione
%            (E_A_DPO, E_A_WPO, E_A_hyd) domini la varianza complessiva.
%   3. Legge direttamente il file CSV delle 24 simulazioni TiberCAD reali a T = 320 K, t = 1e6 s, RH = 50%
%      (`risultati_tibercad_sensitivita_320K.csv`) per EVA, POE, PVB al variare di:
%        - Modello cinetico: minus_sigma (-60% rate, flusso 2.08e20) e plus_sigma (+60% rate, flusso 1.76e22)
%        - Trasporto acqua:  minus_water (0.4 * D0_H2O) e plus_water (1.6 * D0_H2O)
%        - Trasporto O2:     minus_oxygen (0.4 * D0_O2) e plus_oxygen (1.6 * D0_O2)
%        - Accoppiamento SPICE: minus_exp (n_ph=n_Rs=0.5) e plus_exp (n_ph=n_Rs=1.5)
%      e produce il Bar Plot dell'efficienza residua normalizzata eta(1e6 s)/eta_0 (che sostituisce
%      le vecchie Figure 2a e 2b dello Step 1).
%   4. Valida e genera la Figura 2c del T80 estratto per ciascun materiale (EVA, POE, PVB) con la
%      relativa barra di errore calibrata direttamente sui risultati TiberCAD reali a 320 K, 50% RH.
% =================================================================================================

clear; clc; close all;

%% =================================================================================================
%  0. IMPOSTAZIONI UTENTE (MODIFICABILI COMODAMENTE QUI)
%  =================================================================================================
% Imposta qui l'ampiezza della barra/area shaded di errore nelle Figure S1a e S1b:
%   0.5  -> mostra +/- 0.5 * sigma (piu' e meno sigma mezzi: consigliato per ottima leggibilita')
%   1.0  -> mostra +/- 1.0 * sigma (1 deviazione standard)
%   1.96 -> mostra +/- 1.96 * sigma (Intervallo di confidenza al 95%)
error_scale_factor = 0.5;

% Efficienza attiva iniziale del modulo non degradato (t = 0) da TiberCAD:
% Pmax(0) = 0.13287 W su A_attiva = 10 cm^2 -> Eff_Attiva(0) = 13.29%
eta_0_perc = 13.29;
Pmax_0_W   = 0.1328704;

% Valori nominali da TiberCAD a T = 320 K, t = 1e6 s (277.78 h), RH = 50% (flusso 1.5e21, n_exp = 1.0):
% Estratti dalle simulazioni nominali a 320 K, RH 50% (EVA = 0.73%, POE = 10.10%, PVB = 13.26%)
eff_nom_perc = struct('EVA', 0.73, 'POE', 10.10, 'PVB', 13.26);

% Individuazione automatica delle cartelle di input e output
scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir), scriptDir = pwd; end

if exist(fullfile(scriptDir, 'risultati_tibercad_sensitivita_320K.csv'), 'file')
    csvFile = fullfile(scriptDir, 'risultati_tibercad_sensitivita_320K.csv');
elseif exist(fullfile(scriptDir, '..', 'data_and_stats', 'risultati_tibercad_sensitivita_320K.csv'), 'file')
    csvFile = fullfile(scriptDir, '..', 'data_and_stats', 'risultati_tibercad_sensitivita_320K.csv');
else
    csvFile = fullfile(scriptDir, '..', '..', 'data_and_stats', 'risultati_tibercad_sensitivita_320K.csv');
end

outDir = fullfile(scriptDir, '..', 'figures_revision');
if ~exist(outDir, 'dir'), mkdir(outDir); end

%% =================================================================================================
%  1. PARAMETRI DEL MODELLO CINETICO DI CIRA ET AL. (2025) E PROPAGAZIONE DELL'ERRORE
%  =================================================================================================
param_names = {'k_0_DPO', 'E_A_DPO', 'K_2', 'K_3', 'k_0_WPO', 'E_A_WPO', 'f_hyd', 'k_0_hyd', 'E_A_hyd'};
param_Tex   = {'k_{0,DPO}', 'E_{A,DPO}', 'K_2', 'K_3', 'k_{0,WPO}', 'E_{A,WPO}', 'f_{hyd}', 'k_{0,hyd}', 'E_{A,hyd}'};
p           = [1.5e-16, 0.56, 9.5e-4, 2.3e-14, 1.3e-27, -0.12, 0.55, 3.2e22, 1.5];
err_p_95    = [0.2e-16, 0.02, 1.2e-4, 0.4e-14, 0.2e-27,  0.12, 0,    0,      0.4];

% Conversione da intervallo 95% CI a deviazione standard (1 sigma)
sigma_p = err_p_95 / 1.96;

% Costanti e condizioni operative per le curve di Cira et al. (Fig. S1a, S1b)
T_C = [25, 45, 65, 85];         % [°C]
T   = 273.15 + T_C;             % [K]
Phi_0 = 1.5e21;                 % [photons m^-2 s^-1]
n   = (Phi_0)^0.72;             % [(ph. m^-2 s^-1)^0.72]

% Etichetta automatica per la legenda in base a error_scale_factor
if abs(error_scale_factor - 0.5) < 1e-4
    err_label_str = '\pm 0.5\sigma';
elseif abs(error_scale_factor - 1.0) < 1e-4
    err_label_str = '\pm 1\sigma';
elseif abs(error_scale_factor - 1.96) < 1e-2
    err_label_str = '\pm 95% CI';
else
    err_label_str = sprintf('\\pm %.2g\\sigma', error_scale_factor);
end

% --- Calcolo per GRAFICO S1b: r_tot vs P_H2O (a P_O2 = 21.3 kPa fissata) ---
P_O2_1     = 21.3; % [kPa]
P_H2O_pts  = [0, 0.59, 1.17, 1.76, 2.34];
P_H2O_grid = linspace(0, 2.34, 100);

[r_tot_grid, sigma_r_tot_grid, ~, ~, ~] = propagate_error( ...
    @(params) calc_r_tot(params, T, n, P_O2_1, P_H2O_grid), p, sigma_p);
[r_tot_pts, sigma_r_tot_pts, contrib_err_H2O, contrib_deriv_H2O, S_norm_H2O] = propagate_error( ...
    @(params) calc_r_tot(params, T, n, P_O2_1, P_H2O_pts), p, sigma_p);

% --- Calcolo per GRAFICO S1a: r_DPO vs P_O2 (a P_H2O = 0 kPa) ---
P_O2_pts   = linspace(0, 21.3, 5);
P_O2_grid  = linspace(0, 21.3, 100);
P_H2O_2    = 0;

[r_DPO_grid, sigma_r_DPO_grid, ~, ~, ~] = propagate_error( ...
    @(params) calc_r_tot(params, T, n, P_O2_grid, P_H2O_2), p, sigma_p);
[r_DPO_pts, sigma_r_DPO_pts, contrib_err_O2, contrib_deriv_O2, S_norm_O2] = propagate_error( ...
    @(params) calc_r_tot(params, T, n, P_O2_pts, P_H2O_2), p, sigma_p);

% --- Verifica puntuale al punto di lavoro TiberCAD (T = 320 K, P_O2 = 21.3 kPa, RH = 50%) ---
T_sim_K   = 320.0;
P_H2O_sim = 1.17; % [kPa] (~50% RH di riferimento in Cira et al.)
[r_sim_0, sig_sim_0, contrib_err_sim, contrib_deriv_sim, S_norm_sim] = propagate_error( ...
    @(params) calc_r_tot(params, T_sim_K, n, P_O2_1, P_H2O_sim), p, sigma_p);

rel_sigma_sim_pct = (sig_sim_0 / r_sim_0) * 100;
r_plus_flux  = calc_r_tot(p, T_sim_K, (1.76e22)^0.72, P_O2_1, P_H2O_sim);
r_minus_flux = calc_r_tot(p, T_sim_K, (2.08e20)^0.72, P_O2_1, P_H2O_sim);

fprintf('=========================================================================\n');
fprintf('VERIFICA PUNTO DI SIMULAZIONE TIBERCAD (T = 320 K, P_O2 = 21.3 kPa, RH = 50%%)\n');
fprintf('  Errore relativo 1-sigma propagato sulla rate : +/- %.2f%% (~60%%)\n', rel_sigma_sim_pct);
fprintf('  Rapporto rate con flusso +1 sigma (1.76e22)  : %.4f (+%.1f%%)\n', r_plus_flux/r_sim_0, (r_plus_flux/r_sim_0 - 1)*100);
fprintf('  Rapporto rate con flusso -1 sigma (2.08e20)  : %.4f (%.1f%%)\n', r_minus_flux/r_sim_0, (r_minus_flux/r_sim_0 - 1)*100);
fprintf('=========================================================================\n\n');

%% =================================================================================================
%  2. FIGURA S1 (a, b): CURVE DPO E WPO CON BANDA SHADED SETTABILE (`error_scale_factor`)
%  =================================================================================================
figS1 = figure('Name', sprintf('Figura S1a,b: Rate DPO e WPO (%s)', err_label_str), ...
               'Units', 'pixels', 'Position', [70, 90, 1220, 510], 'Color', 'w');
tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
colors = lines(length(T));

% --- Pannello (a): r_DPO vs P_O2 (a P_H2O = 0) ---
ax1 = nexttile; hold(ax1, 'on'); box(ax1, 'on'); grid(ax1, 'on');
for t_idx = 1:length(T)
    c = colors(t_idx, :);
    y_line = r_DPO_grid(:, t_idx)';
    y_err  = sigma_r_DPO_grid(:, t_idx)' * error_scale_factor;
    y_hi   = y_line + y_err;
    y_lo   = max(0, y_line - y_err); % Evita valori negativi non fisici

    fill(ax1, [P_O2_grid, fliplr(P_O2_grid)], [y_hi, fliplr(y_lo)], ...
         c, 'FaceAlpha', 0.20, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    plot(ax1, P_O2_grid, y_line, '--', 'Color', c, 'LineWidth', 1.6, 'HandleVisibility', 'off');
    plot(ax1, P_O2_pts, r_DPO_pts(:, t_idx), 'd', 'Color', c, 'MarkerFaceColor', c, ...
         'MarkerSize', 7.5, 'DisplayName', sprintf('T = %d^\\circC (%s)', T_C(t_idx), err_label_str));
end
xlabel(ax1, 'P_{O_2} (kPa)', 'FontSize', 14, 'FontWeight', 'bold');
ylabel(ax1, 'rate (mol/(m^2s))', 'FontSize', 14, 'FontWeight', 'bold');
title(ax1, sprintf('(a) Dry Photo-Oxidation (P_{H_2O} = 0 kPa, band: %s)', err_label_str), 'FontSize', 13, 'FontWeight', 'bold');
legend(ax1, 'Location', 'northwest', 'FontSize', 11);
axis(ax1, [0, 21.3, 0, 4.5e-8]);
set(ax1, 'FontSize', 13);

% --- Pannello (b): r_tot vs P_H2O (a P_O2 = 21.3 kPa) ---
ax2 = nexttile; hold(ax2, 'on'); box(ax2, 'on'); grid(ax2, 'on');
for t_idx = 1:length(T)
    c = colors(t_idx, :);
    y_line = r_tot_grid(:, t_idx)';
    y_err  = sigma_r_tot_grid(:, t_idx)' * error_scale_factor;
    y_hi   = y_line + y_err;
    y_lo   = max(0, y_line - y_err);

    fill(ax2, [P_H2O_grid, fliplr(P_H2O_grid)], [y_hi, fliplr(y_lo)], ...
         c, 'FaceAlpha', 0.20, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    plot(ax2, P_H2O_grid, y_line, '--', 'Color', c, 'LineWidth', 1.6, 'HandleVisibility', 'off');
    plot(ax2, P_H2O_pts, r_tot_pts(:, t_idx), 'd', 'Color', c, 'MarkerFaceColor', c, ...
         'MarkerSize', 7.5, 'DisplayName', sprintf('T = %d^\\circC (%s)', T_C(t_idx), err_label_str));
end
xlabel(ax2, 'P_{H_2O} (kPa)', 'FontSize', 14, 'FontWeight', 'bold');
ylabel(ax2, 'rate (mol/(m^2s))', 'FontSize', 14, 'FontWeight', 'bold');
title(ax2, sprintf('(b) Humid Photo-Oxidation (P_{O_2} = 21.3 kPa, band: %s)', err_label_str), 'FontSize', 13, 'FontWeight', 'bold');
legend(ax2, 'Location', 'northwest', 'FontSize', 11);
axis(ax2, [0, 2.34, 0, 4.5e-8]);
set(ax2, 'FontSize', 13);

exportgraphics(figS1, fullfile(outDir, 'FigS1_revised_kinetics_with_uncertainty.pdf'), 'ContentType', 'vector');
exportgraphics(figS1, fullfile(outDir, 'FigS1_revised_kinetics_with_uncertainty.png'), 'Resolution', 300);

%% =================================================================================================
%  3. BAR PLOT CONTRIBUTO DERIVATE PARZIALI VS CONTRIBUTO ALL'ERRORE GLOBALE SULLA RATE
%  =================================================================================================
% Confrontiamo 5 condizioni chiave:
%   1) Secco (25°C, P_H2O = 0)
%   2) Secco (85°C, P_H2O = 0)
%   3) Umido (25°C, P_H2O = 2.34 kPa)
%   4) Umido (85°C, P_H2O = 2.34 kPa)
%   5) Punto Simulazione TiberCAD (320 K = 47°C, RH 50%, P_H2O = 1.17 kPa)

cond_labels = {'Secco (25^\circC)', 'Secco (85^\circC)', 'Umido (25^\circC)', 'Umido (85^\circC)', 'Sim. 320 K (RH 50%)'};

% Matrice A: Peso percentuale della SOLA DERIVATA PARZIALE normalizzata |dr/dp_i * (p_i/r)| (%)
deriv_matrix = [
    squeeze(contrib_deriv_H2O(1, 1, :))';   % P_H2O = 0, T = 25°C
    squeeze(contrib_deriv_H2O(1, 4, :))';   % P_H2O = 0, T = 85°C
    squeeze(contrib_deriv_H2O(end, 1, :))'; % P_H2O = 2.34, T = 25°C
    squeeze(contrib_deriv_H2O(end, 4, :))'; % P_H2O = 2.34, T = 85°C
    squeeze(contrib_deriv_sim(1, 1, :))'    % P_H2O = 1.17, T = 320 K
];

% Matrice B: Peso percentuale di ciascun parametro sulla VARIANZA DELL'ERRORE GLOBALE [(dr/dp_i)*sigma_i]^2 / sigma_r^2 (%)
err_matrix = [
    squeeze(contrib_err_H2O(1, 1, :))';     % P_H2O = 0, T = 25°C
    squeeze(contrib_err_H2O(1, 4, :))';     % P_H2O = 0, T = 85°C
    squeeze(contrib_err_H2O(end, 1, :))';   % P_H2O = 2.34, T = 25°C
    squeeze(contrib_err_H2O(end, 4, :))';   % P_H2O = 2.34, T = 85°C
    squeeze(contrib_err_sim(1, 1, :))'      % P_H2O = 1.17, T = 320 K
];

figDerivErr = figure('Name', 'Contributo Derivate Parziali vs Contributo Errore su r', ...
                     'Units', 'pixels', 'Position', [80, 70, 1320, 540], 'Color', 'w');
tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
param_colors = turbo(length(p));

% --- Pannello (a): Contributo della sola derivata parziale normalizzata ---
axD = nexttile;
bD = bar(axD, deriv_matrix, 'stacked');
box(axD, 'on'); grid(axD, 'on');
for k = 1:length(p)
    bD(k).FaceColor = param_colors(k, :);
end
xticks(axD, 1:length(cond_labels));
xticklabels(axD, cond_labels);
xtickangle(axD, 15);
ylabel(axD, 'Peso della sola derivata parziale |(p_i/r)\partialr/\partialp_i| (%)', 'FontWeight', 'bold', 'FontSize', 12);
title(axD, '(a) Sensitivita'' Analitica Intrinseca (Sola Derivata Parziale)', 'FontWeight', 'bold', 'FontSize', 12.5);
ylim(axD, [0 100]);
set(axD, 'FontSize', 12);

% --- Pannello (b): Contributo di ciascun parametro all'errore globale sulla rate ---
axE = nexttile;
bE = bar(axE, err_matrix, 'stacked');
box(axE, 'on'); grid(axE, 'on');
for k = 1:length(p)
    bE(k).FaceColor = param_colors(k, :);
end
xticks(axE, 1:length(cond_labels));
xticklabels(axE, cond_labels);
xtickangle(axE, 15);
ylabel(axE, 'Contributo alla varianza totale dell''errore \sigma_r^2 (%)', 'FontWeight', 'bold', 'FontSize', 12);
title(axE, '(b) Contributo all''Errore Globale su r (Pesato con \sigma_{p_i})', 'FontWeight', 'bold', 'FontSize', 12.5);
legend(axE, param_Tex, 'Location', 'eastoutside', 'FontSize', 11);
ylim(axE, [0 100]);
set(axE, 'FontSize', 12);

exportgraphics(figDerivErr, fullfile(outDir, 'FigS1_c_d_analytical_sensitivity_vs_error_variance.pdf'), 'ContentType', 'vector');
exportgraphics(figDerivErr, fullfile(outDir, 'FigS1_c_d_analytical_sensitivity_vs_error_variance.png'), 'Resolution', 300);

%% =================================================================================================
%  4. LETTURA CSV SIMULAZIONI TIBERCAD REALI E BAR PLOT EFFICIENZA RESIDUA + T80 (FIGURA 2 / S7)
%  =================================================================================================
fprintf('Caricamento risultati simulazioni TiberCAD reali da: %s\n', csvFile);
T_tib = readtable(csvFile, 'VariableNamingRule', 'preserve');

% Ordine logico dei parametri variati per il Bar Plot:
%   1) Nominal (riferimento)
%   2) minus_sigma  (-60% rate cinetica)
%   3) plus_sigma   (+60% rate cinetica)
%   4) minus_water  (-60% permeabilita' H2O)
%   5) plus_water   (+60% permeabilita' H2O)
%   6) minus_oxygen (-60% permeabilita' O2)
%   7) plus_oxygen  (+60% permeabilita' O2)
%   8) minus_exp    (-50% esponenti SPICE, n = 0.5)
%   9) plus_exp     (+50% esponenti SPICE, n = 1.5)

materials = {'EVA', 'POE', 'PVB'};
var_list  = {'nominal', 'minus', 'plus', 'minus', 'plus', 'minus', 'plus', 'minus', 'plus'};
par_list  = {'nominal', 'sigma', 'sigma', 'water', 'water', 'oxygen', 'oxygen', 'exp', 'exp'};
cat_labels = { ...
    'Nominal', ...
    '-\sigma (Rate -60%)', '+\sigma (Rate +60%)', ...
    '-water (D_{H_2O} -60%)', '+water (D_{H_2O} +60%)', ...
    '-oxygen (D_{O_2} -60%)', '+oxygen (D_{O_2} +60%)', ...
    '-exp (SPICE n=0.5)', '+exp (SPICE n=1.5)' ...
};

% Costruzione matrice Efficienza Residua Normalizzata eta(1e6 s) / eta_0
% Dim: [9 variazioni x 3 materiali]
Eta_norm_mat = zeros(length(par_list), 3);
Eta_abs_mat  = zeros(length(par_list), 3);
Pmax_mat     = zeros(length(par_list), 3);

for jM = 1:3
    matName = materials{jM};
    % Riga 1: Nominale
    Eta_abs_mat(1, jM)  = eff_nom_perc.(matName);
    Eta_norm_mat(1, jM) = eff_nom_perc.(matName) / eta_0_perc;
    Pmax_mat(1, jM)     = (eff_nom_perc.(matName) / eta_0_perc) * Pmax_0_W;
    
    % Righe 2..9: lette direttamente dal CSV TiberCAD
    for iV = 2:length(par_list)
        idxRow = strcmpi(T_tib.Materiale, matName) & ...
                 strcmpi(T_tib.Variazione, var_list{iV}) & ...
                 strcmpi(T_tib.Parametro, par_list{iV});
        if any(idxRow)
            eff_val = T_tib.Eff_Attiva_perc(find(idxRow, 1));
            pmax_val = T_tib.Pmax_W(find(idxRow, 1));
            Eta_abs_mat(iV, jM)  = eff_val;
            Eta_norm_mat(iV, jM) = eff_val / eta_0_perc;
            Pmax_mat(iV, jM)     = pmax_val;
        end
    end
end

% Stampa a video della tabella riassuntiva normalizzata
Tab_BarPlot = array2table([Eta_abs_mat, Eta_norm_mat], ...
    'RowNames', cat_labels, ...
    'VariableNames', {'EVA_Eff_perc', 'POE_Eff_perc', 'PVB_Eff_perc', 'EVA_EtaNorm', 'POE_EtaNorm', 'PVB_EtaNorm'});
disp('=== RISULTATI TIBERCAD A T = 320 K, t = 1e6 s, RH = 50% (EFFICIENZA ATTIVA % E NORMALIZZATA) ===');
disp(Tab_BarPlot);

% --- Estrazione e validazione del T80 reale a 320 K, 50% RH dai dati TiberCAD ---
% Dalle serie temporali reali TiberCAD a 320 K, 50% RH (t1 = 27.78 h, t2 = 277.78 h, t3 = 694.44 h):
%   eta_norm(t) = exp(-(t / tau)^beta)
%   EVA: beta = 1.535, T80_nom = 52.2 h
%   POE: beta = 1.990, T80_nom = 250.3 h
%   PVB: beta = 3.735, T80_nom = 949.7 h
t2_h  = 1e6 / 3600; % 277.78 h
betas = [1.535, 1.990, 3.735];
T80_nom_vec = [52.2, 250.3, 949.7];

T80_extracted_mat = zeros(length(par_list), 3);
T80_extracted_mat(1, :) = T80_nom_vec;
for jM = 1:3
    for iV = 2:length(par_list)
        % Usa Pmax_W / Pmax_0_W per massima precisione numerica su PVB
        eta_ratio = min(0.9992, max(1e-4, Pmax_mat(iV, jM) / Pmax_0_W));
        T80_extracted_mat(iV, jM) = t2_h * ( -log(0.80) / (-log(eta_ratio)) )^(1 / betas(jM));
    end
end

% --- Creazione Figura Combinata Step 1 (Sostituisce Fig 2a, 2b con il Bar Plot + mantiene e valida Fig 2c) ---
cEVA = [0.85, 0.20, 0.20];
cPOE = [0.10, 0.65, 0.35];
cPVB = [0.15, 0.45, 0.85];
cols_mat = [cEVA; cPOE; cPVB];

figStep1_Main = figure('Name', 'Step 1: Bar Plot Efficienza Residua TiberCAD & T80 Validato', ...
                       'Units', 'pixels', 'Position', [50, 60, 1420, 540], 'Color', 'w');
tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

% --- PANNELLO (a) [2 colonne]: Bar Plot Efficienza Residua Normalizzata per Materiale e Parametro ---
axBar = nexttile([1, 2]); hold(axBar, 'on'); box(axBar, 'on'); grid(axBar, 'on');

x_cats = categorical(cat_labels, cat_labels);
b_eff = bar(axBar, x_cats, Eta_norm_mat, 'grouped', 'BarWidth', 0.82);
b_eff(1).FaceColor = cEVA; b_eff(1).DisplayName = sprintf('EVA (Nominal \\eta/\\eta_0 = %.2f)', Eta_norm_mat(1,1));
b_eff(2).FaceColor = cPOE; b_eff(2).DisplayName = sprintf('POE (Nominal \\eta/\\eta_0 = %.2f)', Eta_norm_mat(1,2));
b_eff(3).FaceColor = cPVB; b_eff(3).DisplayName = sprintf('PVB (Nominal \\eta/\\eta_0 = %.2f)', Eta_norm_mat(1,3));

% Linee orizzontali tratteggiate di riferimento per i valori nominali dei 3 materiali
yline(axBar, Eta_norm_mat(1,1), '--', 'Color', cEVA*0.85, 'LineWidth', 1.3, 'HandleVisibility', 'off');
yline(axBar, Eta_norm_mat(1,2), '--', 'Color', cPOE*0.85, 'LineWidth', 1.3, 'HandleVisibility', 'off');
yline(axBar, Eta_norm_mat(1,3), '--', 'Color', cPVB*0.85, 'LineWidth', 1.3, 'HandleVisibility', 'off');

xtickangle(axBar, 20);
ylim(axBar, [0, 1.12]);
ylabel(axBar, 'Normalized Residual Efficiency \eta(t = 10^6 s) / \eta_0', 'FontWeight', 'bold', 'FontSize', 12);
title(axBar, '(a) Real TiberCAD Sensitivity at T = 320 K, RH = 50%, t = 10^6 s (\pm\sigma, \pmwater, \pmoxygen, \pmexp)', ...
      'FontWeight', 'bold', 'FontSize', 12);
legend(axBar, 'Location', 'northwest', 'FontSize', 10.5, 'NumColumns', 3);
set(axBar, 'FontSize', 11.5);

% Etichette numeriche sopra le barre
for jM = 1:3
    x_endpoints = b_eff(jM).XEndPoints;
    y_endpoints = b_eff(jM).YEndPoints;
    labels_bar  = arrayfun(@(v) sprintf('%.2f', v), y_endpoints, 'UniformOutput', false);
    text(axBar, x_endpoints, y_endpoints + 0.018, labels_bar, ...
         'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
         'FontSize', 8.2, 'FontWeight', 'bold', 'Color', cols_mat(jM,:)*0.75);
end

% --- PANNELLO (b) [vecchia Fig 2c validata]: T80 con barra d'errore validata sui dati TiberCAD reali ---
axT80 = nexttile; hold(axT80, 'on'); box(axT80, 'on'); grid(axT80, 'on');

for jM = 1:3
    t80_vals = T80_extracted_mat(:, jM);
    med_v = T80_nom_vec(jM);
    mean_v = mean(t80_vals);
    lo_min = min(t80_vals);
    hi_max = max(t80_vals);
    q25 = prctile(t80_vals, 25);
    q75 = prctile(t80_vals, 75);

    % Baffi min-max (range completo delle variazioni TiberCAD reali)
    plot(axT80, [jM, jM], [lo_min, hi_max], '-k', 'LineWidth', 1.8, 'HandleVisibility', 'off');
    plot(axT80, [jM-0.14, jM+0.14], [lo_min, lo_min], '-k', 'LineWidth', 1.8, 'HandleVisibility', 'off');
    plot(axT80, [jM-0.14, jM+0.14], [hi_max, hi_max], '-k', 'LineWidth', 1.8, 'HandleVisibility', 'off');

    % Box interquartile (25%-75%)
    fill(axT80, [jM-0.24, jM+0.24, jM+0.24, jM-0.24], [q25, q25, q75, q75], cols_mat(jM,:), ...
         'FaceAlpha', 0.78, 'EdgeColor', 'k', 'LineWidth', 1.2, ...
         'DisplayName', sprintf('%s: %.0f h [%.0f - %.0f h]', materials{jM}, med_v, lo_min, hi_max));

    % Linea nominale / mediana e marker media
    plot(axT80, [jM-0.24, jM+0.24], [med_v, med_v], '-w', 'LineWidth', 2.5, 'HandleVisibility', 'off');
    plot(axT80, jM, mean_v, 'ko', 'MarkerFaceColor', 'w', 'MarkerSize', 6.5, 'HandleVisibility', 'off');
end

set(axT80, 'YScale', 'log', 'XTick', 1:3, 'XTickLabel', {'EVA', 'POE', 'PVB'});
ylim(axT80, [20, 4000]);
xlim(axT80, [0.4, 3.6]);
ylabel(axT80, 'Extracted Lifetime T_{80} at 320 K, 50% RH (h, log scale)', 'FontWeight', 'bold', 'FontSize', 12);
title(axT80, '(b) Validated T_{80} & Uncertainty Range', 'FontWeight', 'bold', 'FontSize', 12);
legend(axT80, 'Location', 'northwest', 'FontSize', 9.5);
set(axT80, 'FontSize', 11.5);

exportgraphics(figStep1_Main, fullfile(outDir, 'FigS7_sensitivity_tornado_and_monte_carlo.pdf'), 'ContentType', 'vector');
exportgraphics(figStep1_Main, fullfile(outDir, 'FigS7_sensitivity_tornado_and_monte_carlo.png'), 'Resolution', 300);

%% =================================================================================================
%  5. ESPORTAZIONE TABELLE NUMERICHE IN EXCEL E CSV (COME IN `sensit_analysis.m`)
%  =================================================================================================
% --- Tabella 1: Sweep su P_H2O (P_O2 = 21.3 kPa) con sia Errore % sia Derivate Parziali % ---
rows_H2O = [];
for t_idx = 1:length(T_C)
    for h_idx = 1:length(P_H2O_pts)
        val     = r_tot_pts(h_idx, t_idx);
        sig1    = sigma_r_tot_pts(h_idx, t_idx);
        err_scaled = sig1 * error_scale_factor;
        err_rel_1sig = (sig1 / val) * 100;
        pcts_err   = squeeze(contrib_err_H2O(h_idx, t_idx, :))';
        pcts_deriv = squeeze(contrib_deriv_H2O(h_idx, t_idx, :))';
        rows_H2O = [rows_H2O; T_C(t_idx), P_O2_1, P_H2O_pts(h_idx), val, sig1, err_scaled, err_rel_1sig, pcts_err, pcts_deriv];
    end
end

col_names = [{'T_C', 'P_O2_kPa', 'P_H2O_kPa', 'Rate_Nominale', 'Errore_1Sigma', 'Errore_Scalato_Plot', 'Errore_Rel_1Sigma_Pct'}, ...
             strcat('ErrVarPct_', param_names), strcat('DerivPct_', param_names)];
Tabella_H2O = array2table(rows_H2O, 'VariableNames', col_names);

% --- Tabella 2: Sweep su P_O2 (P_H2O = 0 kPa) ---
rows_O2 = [];
for t_idx = 1:length(T_C)
    for o_idx = 1:length(P_O2_pts)
        val     = r_DPO_pts(o_idx, t_idx);
        sig1    = sigma_r_DPO_pts(o_idx, t_idx);
        err_scaled = sig1 * error_scale_factor;
        if val > 0
            err_rel_1sig = (sig1 / val) * 100;
        else
            err_rel_1sig = 0;
        end
        pcts_err   = squeeze(contrib_err_O2(o_idx, t_idx, :))';
        pcts_deriv = squeeze(contrib_deriv_O2(o_idx, t_idx, :))';
        rows_O2 = [rows_O2; T_C(t_idx), P_O2_pts(o_idx), P_H2O_2, val, sig1, err_scaled, err_rel_1sig, pcts_err, pcts_deriv];
    end
end
Tabella_O2 = array2table(rows_O2, 'VariableNames', col_names);

filename_xlsx = fullfile(scriptDir, 'risultati_propagazione_errore.xlsx');
writetable(Tabella_H2O, filename_xlsx, 'Sheet', 'Sweep_H2O');
writetable(Tabella_O2,  filename_xlsx, 'Sheet', 'Sweep_O2');
writetable(Tab_BarPlot, filename_xlsx, 'Sheet', 'TiberCAD_320K_BarPlot', 'WriteRowNames', true);
fprintf('Tabelle salvate con successo nel file: %s\n', filename_xlsx);
fprintf('Figure salvate in: %s\n', outDir);

%% =================================================================================================
%  FUNZIONI LOCALI (ESATTE COME IN `sensit_analysis.m` + CONTRIBUTO DERIVATE PARZIALI)
%  =================================================================================================
function [y_nom, sigma_y, pct_err_contrib, pct_deriv_contrib, S_norm] = propagate_error(model_func, p, sigma_p)
    y_nom = model_func(p);
    var_y = zeros(size(y_nom));
    sum_abs_S = zeros(size(y_nom));
    indiv_var = zeros([size(y_nom), length(p)]);
    indiv_abs_S = zeros([size(y_nom), length(p)]);
    S_norm = zeros([size(y_nom), length(p)]);
    rel_step = 1e-6;

    for i = 1:length(p)
        p_plus = p;
        delta = max(abs(p(i)) * rel_step, 1e-35);
        p_plus(i) = p(i) + delta;

        % Derivata parziale dr / dp_i
        df_dp = (model_func(p_plus) - y_nom) / delta;

        % Derivata parziale normalizzata (elasticita' analitica): S_i = (p_i / r) * (dr / dp_i)
        s_i = zeros(size(y_nom));
        valid_y = abs(y_nom) > 0;
        s_i(valid_y) = df_dp(valid_y) .* (p(i) ./ y_nom(valid_y));
        S_norm(:, :, i) = s_i;
        indiv_abs_S(:, :, i) = abs(s_i);
        sum_abs_S = sum_abs_S + abs(s_i);

        % Termine di varianza propagata: [(dr / dp_i) * sigma_p_i]^2
        if sigma_p(i) > 0
            term_var = (df_dp .* sigma_p(i)).^2;
            var_y = var_y + term_var;
            indiv_var(:, :, i) = term_var;
        end
    end

    sigma_y = sqrt(var_y);

    % 1) Contributo % di ciascun parametro alla varianza dell'errore globale sigma_r^2
    pct_err_contrib = zeros(size(indiv_var));
    valid_var = var_y > 0;
    for i = 1:length(p)
        slice = indiv_var(:, :, i);
        pct_slice = zeros(size(y_nom));
        pct_slice(valid_var) = (slice(valid_var) ./ var_y(valid_var)) * 100;
        pct_err_contrib(:, :, i) = pct_slice;
    end

    % 2) Contributo % della sola derivata parziale normalizzata |S_i| / sum(|S_j|)
    pct_deriv_contrib = zeros(size(indiv_abs_S));
    valid_S = sum_abs_S > 0;
    for i = 1:length(p)
        slice_S = indiv_abs_S(:, :, i);
        pct_slice_S = zeros(size(y_nom));
        pct_slice_S(valid_S) = (slice_S(valid_S) ./ sum_abs_S(valid_S)) * 100;
        pct_deriv_contrib(:, :, i) = pct_slice_S;
    end
end

function r_tot = calc_r_tot(p, T, n, P_O2, P_H2O)
    k_b = 8.61733e-5; % [eV/K]

    k_0_DPO = p(1); E_A_DPO = p(2); K_2 = p(3); K_3 = p(4);
    k_0_WPO = p(5); E_A_WPO = p(6);
    f_hyd   = p(7); k_0_hyd = p(8); E_A_hyd = p(9);

    K_DPO = k_0_DPO * exp(-E_A_DPO ./ (k_b * T));
    K_WPO = k_0_WPO * exp(-E_A_WPO ./ (k_b * T));
    K_hyd = k_0_hyd * exp(-E_A_hyd ./ (k_b * T));

    if length(P_H2O) > 1
        den = 1 + K_2 * P_O2 * (1 + K_3 * n);
        r_DPO = K_DPO * P_O2 * n / den;
        r_tot = zeros(length(P_H2O), length(T));
        for i = 1:length(P_H2O)
            r_WPO = K_WPO * P_O2 * n * P_H2O(i) / den^2;
            hydrat_fac = 1 - f_hyd * K_hyd * P_H2O(i) ./ (den + K_hyd * P_H2O(i));
            r_tot(i, :) = (r_DPO + r_WPO) .* hydrat_fac;
        end
    else
        den = 1 + K_2 * P_O2 * (1 + K_3 * n);
        r_tot = zeros(length(P_O2), length(T));
        for i = 1:length(P_O2)
            r_DPO = K_DPO * P_O2(i) * n / den(i);
            r_WPO = K_WPO * P_O2(i) * n * P_H2O / den(i)^2;
            hydrat_fac = 1 - f_hyd * K_hyd * P_H2O ./ (den(i) + K_hyd * P_H2O);
            r_tot(i, :) = (r_DPO + r_WPO) .* hydrat_fac;
        end
    end
end
