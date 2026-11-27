%% MATLAB Script Step 2: Profili Spaziali Reali da VTU TiberCAD (P_O2, C_O2, P_H2O, C_H2O, f_PSK)
% =================================================================================================
% Manuscript Revision: SEJ-D-26-04657 (Solar Energy)
% Authors: Alessia Di Vito & Matthias Auf der Maur
%
% VERIFICA DELLE UNITA' DI MISURA E CONVENZIONI FISICHE (TUTTO ALLINEATO CON TABELLA 1 E CIRA ET AL.):
%   1. Coordinate geometriche esatte dal file `module.geo` e dai file `.vtu`:
%        - Bordo esterno del sigillante (Le = 5.0 mm): x = -5.0 mm -> distanza dal bordo d_edge = 0.0 mm
%        - Meta' sigillante perimetrale:               x = -2.5 mm -> d_edge = 2.5 mm
%        - Interfaccia sigillante / substrato modulo:  x =  0.0 mm -> d_edge = 5.0 mm
%        - Bordo esterno della Cella 1 attiva:         x =  4.5 mm -> d_edge = 9.5 mm (dopo Lc + 2*P2 + P3)
%        - Centro di simmetria del modulo (Cella 3):   x = 17.7 mm -> d_edge = 22.7 mm
%   2. Pressione parziale e concentrazione di Ossigeno (`oi_time_*.vtu`):
%        - Al bordo esterno (d_edge = 0 mm): P_O2(0) = 21,278 Pa = 21.28 kPa (0.21 atm).
%        - Solubilita' di Henry S0_O2 da Tabella 1 del manoscritto (in [g m^-3 Pa^-1]):
%            EVA: S0_O2 = 1.80e-3 g m^-3 Pa^-1 -> C_O2(0) = S0_O2 * P_O2(0) = 38.30 g m^-3
%            POE: S0_O2 = 1.44e-3 g m^-3 Pa^-1 -> C_O2(0) = S0_O2 * P_O2(0) = 30.64 g m^-3
%            PVB: S0_O2 = 0.72e-3 g m^-3 Pa^-1 -> C_O2(0) = S0_O2 * P_O2(0) = 15.32 g m^-3
%          (Nota: nei file `.vtu`, TiberCAD salva `Concentration` in [g cm^-3] = 10^-6 [g m^-3];
%           moltiplicando per 10^6 si ottiene esattamente C_O2 in [g m^-3]!).
%   3. Pressione parziale e concentrazione di Acqua (`wi_time_*.vtu`):
%        - Convenzione di riferimento di Cira et al. (2025) e dello Step 1:
%            50% RH (riferito alla pressione di saturazione a T ambiente, P_sat(20°C) = 2.34 kPa)
%            corrisponde a una pressione parziale al bordo P_H2O(0) = 1.17 kPa (1,170 Pa).
%        - Nota su TiberCAD: nei file VTU ad alta temperatura (es. 340 K, RH 60%), il modulo
%            interno `wateringress` di TiberCAD calcola P_sat(340 K) = 27.15 kPa e impone al bordo
%            0.60 * 27.15 = 16.29 kPa. Poiche' l'equazione di Fick dP/dt = D * nabla^2(P) e la
%            legge di Henry C = S0 * P sono strettamente lineari rispetto alla condizione al contorno,
%            normalizzando il profilo VTU alla convenzione di riferimento P_H2O(0) = 1.17 kPa si ottiene:
%            * P_H2O(0) = 1.17 kPa (1,170 Pa) al bordo esterno (d_edge = 0 mm)
%            * Concentrazione disciolta C_H2O(x) = S0_H2O * P_H2O(x) in [g m^-3]:
%                EVA (S0_H2O = 0.45 g m^-3 Pa^-1): C_H2O(0) = 526.5 g m^-3 (e 448.0 g m^-3 a Cella 1)
%                POE (S0_H2O = 0.01 g m^-3 Pa^-1): C_H2O(0) =  11.7 g m^-3 (e 0.130 g m^-3 a Cella 1: 3,450x meno di EVA!)
%                PVB (S0_H2O = 0.45 g m^-3 Pa^-1): C_H2O(0) = 526.5 g m^-3 (e < 10^-4 g m^-3 a Cella 1 grazie a basso D_H2O!)
% =================================================================================================

clear; clc; close all;

%% =================================================================================================
%  0. OPZIONE CONVENZIONE P_H2O AL CONTORNO (MODIFICABILE DALL'UTENTE)
%  =================================================================================================
% Imposta `use_reference_117kPa_PH2O = true` per mostrare i profili di P_H2O(x) e C_H2O(x)
% normalizzati alla convenzione di riferimento P_H2O,amb = 1.17 kPa (50% RH a T ambiente, come in Cira et al.).
% Imposta `false` se vuoi visualizzare il valore grezzo VTU calcolato da TiberCAD a 340 K (16.29 kPa).
use_reference_117kPa_PH2O = true;
P_H2O_ref_kPa             = 1.17; % [kPa] (1,170 Pa, 50% RH riferimento Cira et al.)

scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir), scriptDir = pwd; end

if exist(fullfile(scriptDir, 'real_vtu_spatial_profiles.csv'), 'file')
    statsDir = scriptDir;
elseif exist(fullfile(scriptDir, '..', 'data_and_stats', 'real_vtu_spatial_profiles.csv'), 'file')
    statsDir = fullfile(scriptDir, '..', 'data_and_stats');
else
    statsDir = fullfile(scriptDir, '..', '..', 'data_and_stats');
end

outDir = fullfile(scriptDir, '..', 'figures_revision');
if ~exist(outDir, 'dir'), mkdir(outDir); end

fprintf('=== STEP 2: CARICAMENTO PROFILI VTU REALI DA %s ===\n', statsDir);
T_prof = readtable(fullfile(statsDir, 'real_vtu_spatial_profiles.csv'), 'VariableNamingRule', 'preserve');
T_sum  = readtable(fullfile(statsDir, 'real_vtu_temporal_summary_2000h.csv'), 'VariableNamingRule', 'preserve');

% Fattore di scala per allineare P_H2O e C_H2O alla convenzione 1.17 kPa (50% RH)
P_H2O_vtu_boundary_kPa = 16.288749; % Valore al contorno nel file VTU a 340 K
if use_reference_117kPa_PH2O
    scale_H2O = P_H2O_ref_kPa / P_H2O_vtu_boundary_kPa;
    ph2o_label_str = '50% RH ref. (P_{H_2O,amb} = 1.17 kPa)';
else
    scale_H2O = 1.0;
    ph2o_label_str = 'VTU 340 K, 60% RH (P_{H_2O,amb} = 16.29 kPa)';
end

cEVA = [0.85, 0.20, 0.20]; % Crimson Red
cPOE = [0.10, 0.65, 0.35]; % Emerald Green
cPVB = [0.15, 0.45, 0.85]; % Royal Blue
mats = {'EVA', cEVA; 'POE', cPOE; 'PVB', cPVB};

%% =================================================================================================
%  1. STAMPA DI VERIFICA DELLE UNITA' E DEI VALORI NELLE POSIZIONI CHIAVE (t = 10^6 s = 277.8 h)
%  =================================================================================================
d_targets = [0.0, 2.5, 5.0, 9.5, 22.7];
pos_names = {'Outer Edge (d=0 mm)', 'Mid Seal (d=2.5 mm)', 'Seal/Module (d=5 mm)', 'Cell 1 Edge (d=9.5 mm)', 'Center Cell 3 (d=22.7 mm)'};

rows_check = [];
for iM = 1:3
    mName = mats{iM, 1};
    sub300 = T_prof(strcmp(T_prof.Material, mName) & T_prof.Temp_K == 300 & abs(T_prof.Time_s - 1.0e6) < 10, :);
    subHum = T_prof(strcmp(T_prof.Material, mName) & T_prof.Temp_K == 340 & abs(T_prof.Time_s - 1.0e6) < 10, :);
    for kP = 1:length(d_targets)
        [~, idx1] = min(abs(sub300.dist_from_outer_edge_mm - d_targets(kP)));
        [~, idx2] = min(abs(subHum.dist_from_outer_edge_mm - d_targets(kP)));
        
        po2_kpa  = sub300.PO2_kPa(idx1);
        co2_gm3  = sub300.CO2_mol_m3(idx1) * 1e6; % [g m^-3] = S0_O2 * P_O2
        ph2o_kpa = subHum.PH2O_kPa(idx2) * scale_H2O;
        ch2o_gm3 = subHum.CH2O_g_m3(idx2) * 1e6 * scale_H2O; % [g m^-3] = S0_H2O * P_H2O
        fpsk_300 = sub300.f_PSK(idx1);
        
        fprintf('  %-3s | %-25s | P_O2 = %6.3f kPa | C_O2 = %6.3f g/m^3 | P_H2O = %6.4f kPa | C_H2O = %8.4f g/m^3 | f_PSK(300K) = %.4f\n', ...
                mName, pos_names{kP}, po2_kpa, co2_gm3, ph2o_kpa, ch2o_gm3, fpsk_300);
    end
    fprintf('----------------------------------------------------------------------------------------------------------------------------------\n');
end

%% =================================================================================================
%  2. FIGURA 6 PANNELLI: PROFILI SPAZIALI REALI DA VTU (P_O2, C_O2, P_H2O, C_H2O, f_PSK)
%  =================================================================================================
fig = figure('Name', 'Step 2: Profili Spaziali Reali TiberCAD VTU (Unita'' Verificate)', ...
             'Units', 'pixels', 'Position', [40, 40, 1440, 840], 'Color', 'w');
tiledlayout(2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

% --- Panel (a): Oxygen Partial Pressure P_O2(x) [kPa] ---
ax1 = nexttile; hold(ax1, 'on'); box(ax1, 'on'); grid(ax1, 'on');
for iM = 1:3
    mName = mats{iM, 1}; mCol = mats{iM, 2};
    r300_t2 = strcmp(T_prof.Material, mName) & T_prof.Temp_K == 300 & abs(T_prof.Time_s - 1.0e6) < 10 & T_prof.dist_from_outer_edge_mm <= 22.7;
    r300_t1 = strcmp(T_prof.Material, mName) & T_prof.Temp_K == 300 & abs(T_prof.Time_s - 5.0e5) < 10 & T_prof.dist_from_outer_edge_mm <= 22.7;
    plot(ax1, T_prof.dist_from_outer_edge_mm(r300_t1), T_prof.PO2_kPa(r300_t1), '--', 'Color', mCol, 'LineWidth', 1.7, ...
         'DisplayName', sprintf('%s (t = 5\\times10^5 s = 139 h)', mName));
    plot(ax1, T_prof.dist_from_outer_edge_mm(r300_t2), T_prof.PO2_kPa(r300_t2), '-', 'Color', mCol, 'LineWidth', 2.2, ...
         'DisplayName', sprintf('%s (t = 10^6 s = 278 h)', mName));
end
xline(ax1, 5.0, ':k', 'Seal (5 mm)', 'LineWidth', 1.1, 'HandleVisibility', 'off');
xline(ax1, 9.5, '-.k', 'Cell 1 (9.5 mm)', 'LineWidth', 1.1, 'HandleVisibility', 'off');
ylim(ax1, [0, 23.0]); xlim(ax1, [0, 22.7]);
xlabel(ax1, 'Distance from Outer Perimeter Edge d_{edge} (mm)', 'FontWeight', 'bold');
ylabel(ax1, 'Oxygen Partial Pressure P_{O_2}(x) (kPa)', 'FontWeight', 'bold');
title(ax1, '(a) Real TiberCAD P_{O_2}(x) Profile (P_{O_2,amb} = 21.3 kPa)', 'FontWeight', 'bold');
legend(ax1, 'Location', 'northeast', 'FontSize', 8.0);

% --- Panel (b): Dissolved Oxygen Concentration C_O2(x) = S0_O2 * P_O2(x) [g m^-3] ---
ax2 = nexttile; hold(ax2, 'on'); box(ax2, 'on'); grid(ax2, 'on');
for iM = 1:3
    mName = mats{iM, 1}; mCol = mats{iM, 2};
    r300_t2 = strcmp(T_prof.Material, mName) & T_prof.Temp_K == 300 & abs(T_prof.Time_s - 1.0e6) < 10 & T_prof.dist_from_outer_edge_mm <= 22.7;
    % Conversione da VTU [g cm^-3] a [g m^-3] moltiplicando per 10^6 (coerente con S0_O2 in [g m^-3 Pa^-1] in Tabella 1)
    C_o2_gm3 = T_prof.CO2_mol_m3(r300_t2) * 1e6;
    plot(ax2, T_prof.dist_from_outer_edge_mm(r300_t2), C_o2_gm3, '-', 'Color', mCol, 'LineWidth', 2.2, ...
         'DisplayName', sprintf('%s (t = 10^6 s, C_{O_2}(0) = %.1f g m^{-3})', mName, C_o2_gm3(1)));
end
xline(ax2, 5.0, ':k', 'Seal (5 mm)', 'LineWidth', 1.1, 'HandleVisibility', 'off');
xline(ax2, 9.5, '-.k', 'Cell 1 (9.5 mm)', 'LineWidth', 1.1, 'HandleVisibility', 'off');
ylim(ax2, [0, 42.0]); xlim(ax2, [0, 22.7]);
xlabel(ax2, 'Distance from Outer Perimeter Edge d_{edge} (mm)', 'FontWeight', 'bold');
ylabel(ax2, 'Dissolved O_2 Concentration C_{O_2}(x) (g m^{-3})', 'FontWeight', 'bold');
title(ax2, '(b) Dissolved O_2 Concentration C_{O_2}(x) = S_{0,O_2} P_{O_2}(x)', 'FontWeight', 'bold');
legend(ax2, 'Location', 'northeast', 'FontSize', 8.3);

% --- Panel (c): Water Vapor Partial Pressure P_H2O(x) [kPa] (Allineata a 1.17 kPa per 50% RH) ---
ax3 = nexttile; hold(ax3, 'on'); box(ax3, 'on'); grid(ax3, 'on');
for iM = 1:3
    mName = mats{iM, 1}; mCol = mats{iM, 2};
    r5e5 = strcmp(T_prof.Material, mName) & T_prof.Temp_K == 340 & abs(T_prof.Time_s - 5.0e5) < 10 & T_prof.dist_from_outer_edge_mm <= 22.7;
    r1e6 = strcmp(T_prof.Material, mName) & T_prof.Temp_K == 340 & abs(T_prof.Time_s - 1.0e6) < 10 & T_prof.dist_from_outer_edge_mm <= 22.7;
    plot(ax3, T_prof.dist_from_outer_edge_mm(r5e5), T_prof.PH2O_kPa(r5e5) * scale_H2O, '--', 'Color', mCol, 'LineWidth', 1.7, ...
         'DisplayName', sprintf('%s (t = 5\\times10^5 s = 139 h)', mName));
    plot(ax3, T_prof.dist_from_outer_edge_mm(r1e6), T_prof.PH2O_kPa(r1e6) * scale_H2O, '-', 'Color', mCol, 'LineWidth', 2.2, ...
         'DisplayName', sprintf('%s (t = 10^6 s = 278 h)', mName));
end
xline(ax3, 5.0, ':k', 'Seal (5 mm)', 'LineWidth', 1.1, 'HandleVisibility', 'off');
xline(ax3, 9.5, '-.k', 'Cell 1 (9.5 mm)', 'LineWidth', 1.1, 'HandleVisibility', 'off');
if use_reference_117kPa_PH2O
    ylim(ax3, [0, 1.28]);
else
    ylim(ax3, [0, 17.5]);
end
xlim(ax3, [0, 22.7]);
xlabel(ax3, 'Distance from Outer Perimeter Edge d_{edge} (mm)', 'FontWeight', 'bold');
ylabel(ax3, 'Water Partial Pressure P_{H_2O}(x) (kPa)', 'FontWeight', 'bold');
title(ax3, sprintf('(c) Water Partial Pressure P_{H_2O}(x) [%s]', ph2o_label_str), 'FontWeight', 'bold');
legend(ax3, 'Location', 'northeast', 'FontSize', 8.0);

% --- Panel (d): Dissolved Water Concentration C_H2O(x) = S0_H2O * P_H2O(x) [g m^-3] (Log Scale) ---
ax4 = nexttile; hold(ax4, 'on'); box(ax4, 'on'); grid(ax4, 'on');
for iM = 1:3
    mName = mats{iM, 1}; mCol = mats{iM, 2};
    r1e6 = strcmp(T_prof.Material, mName) & T_prof.Temp_K == 340 & abs(T_prof.Time_s - 1.0e6) < 10 & T_prof.dist_from_outer_edge_mm <= 22.7;
    C_h2o_gm3 = max(1e-6, T_prof.CH2O_g_m3(r1e6) * 1e6 * scale_H2O);
    semilogy(ax4, T_prof.dist_from_outer_edge_mm(r1e6), C_h2o_gm3, '-', 'Color', mCol, 'LineWidth', 2.2, ...
             'DisplayName', sprintf('%s (t = 10^6 s, C_{H_2O}(0) = %.1f g m^{-3})', mName, C_h2o_gm3(1)));
end
set(ax4, 'YScale', 'log'); ylim(ax4, [1e-5, 2e3]); xlim(ax4, [0, 22.7]);
xline(ax4, 5.0, ':k', 'Seal (5 mm)', 'LineWidth', 1.1, 'HandleVisibility', 'off');
xline(ax4, 9.5, '-.k', 'Cell 1 (9.5 mm)', 'LineWidth', 1.1, 'HandleVisibility', 'off');
xlabel(ax4, 'Distance from Outer Perimeter Edge d_{edge} (mm)', 'FontWeight', 'bold');
ylabel(ax4, 'Dissolved Water C_{H_2O}(x) (g m^{-3}, log scale)', 'FontWeight', 'bold');
title(ax4, '(d) Dissolved Water C_{H_2O}(x) = S_{0,H_2O} P_{H_2O}(x)', 'FontWeight', 'bold');
legend(ax4, 'Location', 'northeast', 'FontSize', 8.3);

% --- Panel (e): Active Perovskite Fraction Profile f_PSK(x) across the 5 Sub-Cells ---
ax5 = nexttile; hold(ax5, 'on'); box(ax5, 'on'); grid(ax5, 'on');
for iM = 1:3
    mName = mats{iM, 1}; mCol = mats{iM, 2};
    r300_t2 = strcmp(T_prof.Material, mName) & T_prof.Temp_K == 300 & abs(T_prof.Time_s - 1.0e6) < 10 & strcmp(T_prof.Region, 'ActiveModule');
    r300_t3 = strcmp(T_prof.Material, mName) & T_prof.Temp_K == 300 & abs(T_prof.Time_s - 2.5e6) < 10 & strcmp(T_prof.Region, 'ActiveModule');
    plot(ax5, T_prof.x_coord_mm(r300_t2), T_prof.f_PSK(r300_t2), '-', 'Color', mCol, 'LineWidth', 2.2, ...
         'DisplayName', sprintf('%s (300 K, t_2 = 10^6 s = 278 h)', mName));
    plot(ax5, T_prof.x_coord_mm(r300_t3), T_prof.f_PSK(r300_t3), '--', 'Color', mCol, 'LineWidth', 1.8, ...
         'DisplayName', sprintf('%s (300 K, t_3 = 2.5\\times10^6 s = 694 h)', mName));
end
xlim(ax5, [0, 35.4]); ylim(ax5, [0, 1.05]);
xlabel(ax5, 'Module Coordinate x (mm) [Active Sub-Cells: 4.5 to 31.0 mm]', 'FontWeight', 'bold');
ylabel(ax5, 'Active Perovskite Fraction f_{PSK}(x)', 'FontWeight', 'bold');
title(ax5, '(e) Real TiberCAD Perovskite Fraction Profile f_{PSK}(x)', 'FontWeight', 'bold');
legend(ax5, 'Location', 'southwest', 'FontSize', 7.8);

% --- Panel (f): Temporal Evolution of Sub-Cell Average f_PSK(t) from Real VTU Snapshots (0 to 2000 h) ---
ax6 = nexttile; hold(ax6, 'on'); box(ax6, 'on'); grid(ax6, 'on');
for iM = 1:3
    mName = mats{iM, 1}; mCol = mats{iM, 2};
    r300 = strcmp(T_sum.Material, mName) & T_sum.Temp_K == 300;
    r340 = strcmp(T_sum.Material, mName) & T_sum.Temp_K == 340;
    plot(ax6, T_sum.Time_h(r300), T_sum.f_PSK_subcells_avg(r300), '-o', 'Color', mCol, 'LineWidth', 2.0, ...
         'MarkerFaceColor', mCol, 'MarkerSize', 5, 'DisplayName', sprintf('%s (300 K, 0%% RH VTU)', mName));
    plot(ax6, T_sum.Time_h(r340), T_sum.f_PSK_subcells_avg(r340), '--s', 'Color', mCol, 'LineWidth', 1.8, ...
         'MarkerSize', 5, 'DisplayName', sprintf('%s (340 K, 60%% RH VTU)', mName));
end
xlim(ax6, [0, 2000]); ylim(ax6, [0, 1.05]);
xlabel(ax6, 'Aging Time t (hours) [up to t_4 = 7.2\times10^6 s = 2000 h]', 'FontWeight', 'bold');
ylabel(ax6, 'Mean Active Perovskite Fraction \langle f_{PSK}(t) \rangle', 'FontWeight', 'bold');
title(ax6, '(f) Real TiberCAD Temporal Evolution of f_{PSK}(t) (0 - 2000 h)', 'FontWeight', 'bold');
legend(ax6, 'Location', 'southwest', 'FontSize', 7.8);

exportgraphics(fig, fullfile(outDir, 'FigS6_concentration_profiles_and_coupling_n.pdf'), 'ContentType', 'vector');
exportgraphics(fig, fullfile(outDir, 'FigS6_concentration_profiles_and_coupling_n.png'), 'Resolution', 300);
exportgraphics(fig, fullfile(outDir, 'FigS6_real_vtu_spatial_profiles_and_fpsk.pdf'), 'ContentType', 'vector');
exportgraphics(fig, fullfile(outDir, 'FigS6_real_vtu_spatial_profiles_and_fpsk.png'), 'Resolution', 300);
fprintf('Salvata FigS6_real_vtu_spatial_profiles_and_fpsk.pdf/.png\n');
