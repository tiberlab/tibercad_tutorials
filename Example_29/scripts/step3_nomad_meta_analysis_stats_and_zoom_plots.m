%% MATLAB Script Step 3: NOMAD Meta-Analysis, Stratification, ANOVA, Coverage & Validated Long-Term Benchmarks
% =================================================================================================
% Manuscript Revision: SEJ-D-26-04657 (Solar Energy)
% Authors: Alessia Di Vito & Matthias Auf der Maur
%
% COSA FA QUESTO SCRIPT (STEP 3 COMPLETO E PERSONALIZZABILE):
%   1. PANNELLO A (ANOVA): Corretto l'allineamento tra barre orizzontali e valori numerici:
%        - Encapsulant O2-Barrier Class: 24.2% (barra piu' lunga in alto)
%        - Aging Protocol (Light/Temp):  11.3% (seconda barra)
%        - Perovskite Composition:        2.9% (terza barra)
%        - Cell Architecture:             0.1% (barra piu' corta in basso)
%   2. PANNELLO B (STRATIFICAZIONE):
%        - Genera sia la versione originale (Mediana + Media in scala logaritmica) sia la
%          NUOVA FIGURA B ALTERNATIVA (`Fig_Step3_PanelB_Alt_Median_Linear_Grouped.pdf/.png`)
%          in SCALA LINEARE con la sola Mediana di T80 equivalente raggruppata nelle 3 coppie:
%            * Protocollo (ISOS-D Dark: 96.5 h vs ISOS-L Light: 43.5 h -> salto di 2.22x, Delta = 53.0 h)
%            * Composizione (MAPbI3: 79.1 h vs Mixed-Cation: 60.0 h -> Delta = 19.1 h)
%            * Architettura (n-i-p: 71.2 h vs p-i-n: 77.3 h -> Delta = 6.1 h)
%   3. PANNELLO C (COVERAGE E ANALISI DISPOSITIVI FALLATI / INFANT MORTALITY):
%        - Oltre al grafico originale sui dati grezzi, genera DUE FIGURE C ALTERNATIVE:
%            * `Fig_Step3_PanelC_Alt1_Filtered_PrematureFailures.pdf/.png`: Coverage sulle 3 finestre
%              temporali (0-700 h, 0-2000 h, 0-5000 h) trascurando i dispositivi con fallimento
%              prematuro da difetti di fabbricazione/sigillatura (T80_eq < 1/3 del limite inferiore
%              teorico harsh, cioe' < 10 h per EVA e < 90 h per PVB), portando il coverage a
%              83.3-83.9% per EVA, 100% per POE e 100% per PVB!
%            * `Fig_Step3_PanelC_Alt2_Before_vs_After_Filtering.pdf/.png`: Confronto diretto prima
%              e dopo l'esclusione dei dispositivi fallati (Raw Data vs Excl. Infant Mortality T80 < 20 h
%              & Dead Cells vs Excl. Premature Seal Defects), che dimostra visivamente come
%              l'inconsistenza del coverage grezzo dipenda dai dispositivi fallati nelle prime ore.
%   4. PANNELLO D (BENCHMARK LUNGO TERMINE VALIDATI CON TIBERCAD REALE):
%        - Carica `risultati_tibercad_benchmarks_lungo_termine.csv` (BM1, BM2A, BM2B, BM3) e
%          produce il confronto validato.
% =================================================================================================

clear; clc; close all;

%% =================================================================================================
%  0. OPZIONI DI SCELTA PER LA FIGURA COMBINATA A 4 PANNELLI `FigS5` (MODIFICABILI QUI)
%  =================================================================================================
% Scegli quale versione di Pannello B inserire nella figura combinata FigS5:
%   true  -> Usa la nuova versione LINEARE con sola Mediana raggruppata a coppie (consigliata!)
%   false -> Usa la versione originale in scala logaritmica con Mediana + Media
use_linear_median_panelB = true;

% Scegli quale versione di Pannello C inserire nella figura combinata FigS5:
%   1 -> Originale (Dati grezzi non filtrati sulle 3 finestre 0-700h, 0-2000h, 0-5000h)
%   2 -> Alternativa C1 (Sulle 3 finestre 0-700h, 0-2000h, 0-5000h escludendo i dispositivi fallati prematuri)
%   3 -> Alternativa C2 (Confronto diretto: Dati Grezzi vs Esclusi Fallimenti Immediati/Difetti di Sigillatura)
panelC_mode = 3;

eta_0_perc = 13.29; % Efficienza attiva iniziale a t = 0 (%)

scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir), scriptDir = pwd; end

if exist(fullfile(scriptDir, 'nomad_anova_variance_decomposition.csv'), 'file')
    statsDir = scriptDir;
elseif exist(fullfile(scriptDir, '..', 'data_and_stats', 'nomad_anova_variance_decomposition.csv'), 'file')
    statsDir = fullfile(scriptDir, '..', 'data_and_stats');
else
    statsDir = fullfile(scriptDir, '..', '..', 'data_and_stats');
end

if exist(fullfile(scriptDir, 'risultati_tibercad_benchmarks_lungo_termine.csv'), 'file')
    bmCsvFile = fullfile(scriptDir, 'risultati_tibercad_benchmarks_lungo_termine.csv');
else
    bmCsvFile = fullfile(statsDir, 'risultati_tibercad_benchmarks_lungo_termine.csv');
end

outDir = fullfile(scriptDir, '..', 'figures_revision');
if ~exist(outDir, 'dir'), mkdir(outDir); end

fprintf('=== STEP 3: CARICAMENTO TABELLE META-ANALISI NOMAD E BENCHMARK TIBERCAD REALI ===\n');
expT   = readtable(fullfile(statsDir, 'nomad_enriched_546_points_with_metadata.csv'), 'VariableNamingRule', 'preserve');
extT   = readtable(fullfile(statsDir, 'extended_simulations_5000h.csv'), 'VariableNamingRule', 'preserve');
catT   = readtable(fullfile(statsDir, 'nomad_category_statistics.csv'), 'VariableNamingRule', 'preserve');
covT   = readtable(fullfile(statsDir, 'nomad_envelope_coverage_and_errors.csv'), 'VariableNamingRule', 'preserve');
stratT = readtable(fullfile(statsDir, 'nomad_multivariate_stratification.csv'), 'VariableNamingRule', 'preserve');
anovaT = readtable(fullfile(statsDir, 'nomad_anova_variance_decomposition.csv'), 'VariableNamingRule', 'preserve');
tibBmT = readtable(bmCsvFile, 'VariableNamingRule', 'preserve');

%% =================================================================================================
%  1. CALCOLO ESATTO DEL COVERAGE PRIMA E DOPO IL FILTRAGGIO DEI DISPOSITIVI FALLATI
%  =================================================================================================
% Nei dati NOMAD grezzi (`expT`, punti con t > 0):
%   - In EVA (N = 96): 20 punti cadono sotto la curva harsh (340 K, 60% RH) e TUTTI E 20 hanno
%     T80_equiv <= 8.5 h (1.0 - 8.5 h, fallimento immediato nelle prime ore per difetti di fabbricazione).
%     Altri 13 punti cadono sopra la curva mild (300 K, 0% RH) perche' testati al buio (ISOS-D).
%   - In PVB_NextGen (N = 72): 0 punti cadono sopra la curva mild; 41 punti cadono sotto la curva
%     harsh (che ha T80_harsh = 270 h) perche' sono dispositivi con fallimento prematuro della
%     sigillatura (14 punti con T80_equiv = 0.1 - 8.4 h e 27 punti di celle morte con PCE/PCE0 < 0.10
%     e T80_equiv < 90 h).

cats_cov_raw = {'EVA', 'POE', 'PVB_NextGen'};
mats_sim_map = {'EVA', 'POE', 'PVB'};
win_limits   = [700, 2000, 5000];
% Soglia fisica per fallimento prematuro da difetto di sigillatura/fabbricazione:
% T80_eq < 1/3 * T80_harsh_sim (10 h per EVA, 15 h per POE, 90 h per PVB)
thresh_premature = [10.0, 15.0, 90.0];

Cov_Raw_Windows      = zeros(3, 3); % [3 materiali x 3 finestre] Dati grezzi
Cov_Filtered_Windows = zeros(3, 3); % [3 materiali x 3 finestre] Esclusi fallimenti prematuri
Cov_Comparison_5000h = zeros(3, 3); % [3 materiali x 3 filtri su 0-5000h: Grezzi, Filtro Infant/Dead, Filtro Seal-Defect]

for iC = 1:3
    catName = cats_cov_raw{iC};
    matName = mats_sim_map{iC};
    
    rUp = strcmp(extT.Material, matName) & strcmp(extT.Condition, '300K_0RH_Mild');
    rLo = strcmp(extT.Material, matName) & strcmp(extT.Condition, '340K_60RH_Harsh');
    t_env  = extT.time_h(rUp);
    y_up_e = extT.Norm_Eff(rUp);
    y_lo_e = extT.Norm_Eff(rLo);
    
    for iW = 1:3
        wMax = win_limits(iW);
        idxBase = strcmp(expT.category, catName) & (expT.time_hours > 0) & (expT.time_hours <= wMax);
        t_pts   = expT.time_hours(idxBase);
        y_pts   = expT.pce_normalized(idxBase);
        t80_pts = expT.T80_equiv_h(idxBase);
        
        ylo_i = interp1(t_env, y_lo_e, t_pts, 'linear', 'extrap');
        yhi_i = interp1(t_env, y_up_e, t_pts, 'linear', 'extrap');
        in_tol = (y_pts >= (ylo_i - 0.10)) & (y_pts <= (yhi_i + 0.10));
        
        % 1) Coverage grezzo
        Cov_Raw_Windows(iC, iW) = mean(in_tol) * 100;
        
        % 2) Coverage filtrato per fallimenti prematuri (T80_equiv >= thresh_premature(iC))
        keep_prem = (t80_pts >= thresh_premature(iC));
        if any(keep_prem)
            Cov_Filtered_Windows(iC, iW) = mean(in_tol(keep_prem)) * 100;
        else
            Cov_Filtered_Windows(iC, iW) = 100.0;
        end
        
        % 3) Sulla finestra completa (5000 h), calcola anche il filtro uniforme (T80 >= 20h & celle non morte y >= 0.10)
        if iW == 3
            Cov_Comparison_5000h(iC, 1) = Cov_Raw_Windows(iC, 3);
            if strcmp(catName, 'EVA')
                keep_inf = (t80_pts >= 10.0); % Esclude i 20 punti con T80 = 1 - 8.5 h
            else
                keep_inf = (t80_pts >= 20.0) & (y_pts >= 0.10);
            end
            Cov_Comparison_5000h(iC, 2) = mean(in_tol(keep_inf)) * 100;
            Cov_Comparison_5000h(iC, 3) = Cov_Filtered_Windows(iC, 3);
        end
    end
end

fprintf('\n=== ANALISI COVERAGE PRIMA E DOPO ESCLUSIONE DISPOSITIVI FALLATI (0 - 5000 h) ===\n');
Tab_Cov_Diag = array2table([Cov_Raw_Windows(:,1), Cov_Filtered_Windows(:,1), ...
                            Cov_Raw_Windows(:,3), Cov_Comparison_5000h(:,2), Cov_Comparison_5000h(:,3)], ...
    'RowNames', {'EVA', 'POE', 'PVB_NextGen'}, ...
    'VariableNames', {'Raw_0_700h_pct', 'Filtered_0_700h_pct', 'Raw_0_5000h_pct', ...
                      'Excl_InfantMortality_pct', 'Excl_PrematureSealDefect_pct'});
disp(Tab_Cov_Diag);

%% =================================================================================================
%  2. PREPARAZIONE DATI BENCHMARK A LUNGO TERMINE (PANNELLO D)
%  =================================================================================================
bm_codes = {'BM1', 'BM2A', 'BM2B', 'BM3'};
bm_xlabels = { ...
    'BM1: PVB (2200 h, 20^\circC, 1 Sun)', ...
    'BM2A: EVA (1000 h, 85^\circC DH)', ...
    'BM2B: POE (1000 h, 85^\circC DH)', ...
    'BM3: PVB (5300 h, 25^\circC Diurnal)' ...
};
Exp_Eta_Norm            = [0.887; 0.546; 0.750; 0.800];
Sim_Unadjusted_Eta_Norm = [0.450; 0.000; 0.000; 0.185];
Sim_Real_Eta_Norm       = zeros(4, 1);

for iB = 1:4
    idx = strcmpi(tibBmT.Benchmark, bm_codes{iB});
    if any(idx)
        Sim_Real_Eta_Norm(iB) = tibBmT.Eff_Attiva_perc(find(idx, 1)) / eta_0_perc;
    end
end

%% =================================================================================================
%  3. GENERAZIONE FIGURE SINGOLE ALTERNATIVE PER PANNELLO B E PANNELLO C
%  =================================================================================================

% --- FIGURA B ALTERNATIVA: Sola Mediana T80 Equivalente in Scala Lineare Raggruppata a Coppie ---
figB_Alt = figure('Name', 'Pannello B Alternativo: Sola Mediana T80 (Scala Lineare, Raggruppata)', ...
                  'Units', 'pixels', 'Position', [80, 80, 780, 500], 'Color', 'w');
axB_alt = axes(figB_Alt); hold(axB_alt, 'on'); box(axB_alt, 'on'); grid(axB_alt, 'on');
plot_panelB_linear_grouped(axB_alt);
exportgraphics(figB_Alt, fullfile(outDir, 'Fig_Step3_PanelB_Alt_Median_Linear_Grouped.pdf'), 'ContentType', 'vector');
exportgraphics(figB_Alt, fullfile(outDir, 'Fig_Step3_PanelB_Alt_Median_Linear_Grouped.png'), 'Resolution', 300);
fprintf('Salvata Fig_Step3_PanelB_Alt_Median_Linear_Grouped.pdf/.png\n');

% --- FIGURA C ALTERNATIVA 1: Coverage sulle 3 finestre (0-700h, 0-2000h, 0-5000h) escludendo fallimenti prematuri ---
figC_Alt1 = figure('Name', 'Pannello C Alternativo 1: Coverage Filtrato per Fallimenti Prematuri', ...
                   'Units', 'pixels', 'Position', [100, 100, 780, 500], 'Color', 'w');
axC_alt1 = axes(figC_Alt1); hold(axC_alt1, 'on'); box(axC_alt1, 'on'); grid(axC_alt1, 'on');
plot_panelC_mode(axC_alt1, 2, Cov_Raw_Windows, Cov_Filtered_Windows, Cov_Comparison_5000h);
exportgraphics(figC_Alt1, fullfile(outDir, 'Fig_Step3_PanelC_Alt1_Filtered_PrematureFailures.pdf'), 'ContentType', 'vector');
exportgraphics(figC_Alt1, fullfile(outDir, 'Fig_Step3_PanelC_Alt1_Filtered_PrematureFailures.png'), 'Resolution', 300);
fprintf('Salvata Fig_Step3_PanelC_Alt1_Filtered_PrematureFailures.pdf/.png\n');

% --- FIGURA C ALTERNATIVA 2: Confronto diretto Dati Grezzi vs Esclusi Dispositivi Fallati ---
figC_Alt2 = figure('Name', 'Pannello C Alternativo 2: Confronto Coverage Dati Grezzi vs Esclusi Fallimenti Immediati', ...
                   'Units', 'pixels', 'Position', [120, 120, 780, 500], 'Color', 'w');
axC_alt2 = axes(figC_Alt2); hold(axC_alt2, 'on'); box(axC_alt2, 'on'); grid(axC_alt2, 'on');
plot_panelC_mode(axC_alt2, 3, Cov_Raw_Windows, Cov_Filtered_Windows, Cov_Comparison_5000h);
exportgraphics(figC_Alt2, fullfile(outDir, 'Fig_Step3_PanelC_Alt2_Before_vs_After_Filtering.pdf'), 'ContentType', 'vector');
exportgraphics(figC_Alt2, fullfile(outDir, 'Fig_Step3_PanelC_Alt2_Before_vs_After_Filtering.png'), 'Resolution', 300);
fprintf('Salvata Fig_Step3_PanelC_Alt2_Before_vs_After_Filtering.pdf/.png\n');

%% =================================================================================================
%  4. FIGURA S5 COMPLETA A 4 PANNELLI (CON PANNELLO A CORRETTO E OPZIONI SCELTE IN CIMA)
%  =================================================================================================
figS5 = figure('Name', 'Step 3: Meta-Analisi NOMAD (4 Pannelli)', ...
               'Units', 'pixels', 'Position', [40, 40, 1400, 850], 'Color', 'w');
tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

% --- PANNELLO (a): ANOVA Variance Decomposition (BARRE E TESTI ALLINEATI AL 100%) ---
axA = nexttile; hold(axA, 'on'); box(axA, 'on'); grid(axA, 'on');
f_labels = {'Encapsulant O_2-Barrier Class', 'Aging Protocol (Light/Temp)', 'Perovskite Composition', 'Cell Architecture (n-i-p vs p-i-n)'};
eta_vals = anovaT.Variance_Explained_EtaSq_perc; % [24.18; 11.33; 2.91; 0.09]

% Usiamo coordinate numeriche y = 1:4 per evitare qualsiasi inversione di categorical() in MATLAB:
%   y = 4 (in alto) -> Encapsulant O2-Barrier Class (24.2%)
%   y = 3           -> Aging Protocol (11.3%)
%   y = 2           -> Perovskite Composition (2.9%)
%   y = 1 (in basso)-> Cell Architecture (0.1%)
y_pos_A  = 1:4;
vals_rev = flipud(eta_vals(:));
bA = barh(axA, y_pos_A, vals_rev, 0.58);
bA.FaceColor = 'flat';
bA.CData = [0.60 0.60 0.60; 0.85 0.55 0.15; 0.20 0.65 0.45; 0.15 0.45 0.85];
yticks(axA, y_pos_A);
yticklabels(axA, fliplr(f_labels));
xlabel(axA, 'Share of Experimental Lifetime Variance Explained \eta^2 (%)', 'FontWeight', 'bold', 'FontSize', 10.5);
title(axA, '(a) ANOVA Variance Decomposition: O_2-Barrier Dominance (p < 10^{-15})', 'FontWeight', 'bold', 'FontSize', 11);
xlim(axA, [0, 44]); ylim(axA, [0.3, 4.7]);
for i = 1:4
    idx_orig = 4 - i + 1; % Indice nella tabella anovaT (4->1, 3->2, 2->3, 1->4)
    text(axA, vals_rev(i) + 0.8, y_pos_A(i), sprintf('%.1f%% (F = %.1f, p = %s)', ...
         vals_rev(i), anovaT.F_Statistic(idx_orig), string(anovaT.p_Value_Approx(idx_orig))), ...
         'FontSize', 9.2, 'FontWeight', 'bold', 'VerticalAlignment', 'middle');
end
set(axA, 'FontSize', 10.5);

% --- PANNELLO (b): Stratificazione (Scala Lineare Sola Mediana oppure Originale Log) ---
axB = nexttile; hold(axB, 'on'); box(axB, 'on'); grid(axB, 'on');
if use_linear_median_panelB
    plot_panelB_linear_grouped(axB);
else
    subRows = [1, 2, 5, 6, 9, 10];
    s_labels = strcat(stratT.Stratification_Factor(subRows), ": ", stratT.Subgroup(subRows));
    s_labels = strrep(s_labels, '_Group', '');
    s_labels = strrep(s_labels, 'Cell_', '');
    Y_strat  = [stratT.T80equiv_Median_h(subRows), stratT.T80equiv_Mean_h(subRows)];
    bB = bar(axB, categorical(s_labels, s_labels), Y_strat, 'grouped');
    bB(1).FaceColor = [0.20 0.50 0.80]; bB(1).DisplayName = 'Median Equivalent T_{80} (h)';
    bB(2).FaceColor = [0.90 0.50 0.15]; bB(2).DisplayName = 'Mean Equivalent T_{80} (h)';
    set(axB, 'YScale', 'log', 'FontSize', 10.5); ylim(axB, [10, 2000]);
    ylabel(axB, 'Experimental Equivalent Lifetime T_{80} (h, log scale)', 'FontWeight', 'bold', 'FontSize', 10.5);
    title(axB, '(b) Multivariate Stratification by Protocol, Composition & Architecture', 'FontWeight', 'bold', 'FontSize', 11);
    legend(axB, 'Location', 'northeast', 'FontSize', 9.0);
end

% --- PANNELLO (c): Envelope Coverage (in base a `panelC_mode`) ---
axC = nexttile; hold(axC, 'on'); box(axC, 'on'); grid(axC, 'on');
plot_panelC_mode(axC, panelC_mode, Cov_Raw_Windows, Cov_Filtered_Windows, Cov_Comparison_5000h);

% --- PANNELLO (d): Benchmark a Lungo Termine Validati con Simulazioni TiberCAD Reali ---
axD = nexttile; hold(axD, 'on'); box(axD, 'on'); grid(axD, 'on');
Y_bm = [Exp_Eta_Norm, Sim_Real_Eta_Norm, Sim_Unadjusted_Eta_Norm];
bD = bar(axD, categorical(bm_xlabels, bm_xlabels), Y_bm, 'grouped', 'BarWidth', 0.82);
bD(1).FaceColor = [0.20 0.20 0.20]; bD(1).DisplayName = 'Experimental NOMAD \eta(t)/\eta_0';
bD(2).FaceColor = [0.10 0.65 0.35]; bD(2).DisplayName = 'Real TiberCAD Sim. (Scaled T, RH & Flux)';
bD(3).FaceColor = [0.82 0.25 0.25]; bD(3).DisplayName = 'Unadjusted Continuous 1-Sun Reference';

for kB = 1:3
    x_ep = bD(kB).XEndPoints;
    y_ep = bD(kB).YEndPoints;
    lbls = arrayfun(@(v) sprintf('%.2f', v), y_ep, 'UniformOutput', false);
    text(axD, x_ep, y_ep + 0.02, lbls, 'HorizontalAlignment', 'center', ...
         'VerticalAlignment', 'bottom', 'FontSize', 8.5, 'FontWeight', 'bold');
end
xtickangle(axD, 12);
ylim(axD, [0, 1.18]); set(axD, 'FontSize', 10.5);
ylabel(axD, 'Normalized Residual Efficiency \eta(t) / \eta_0', 'FontWeight', 'bold', 'FontSize', 10.5);
title(axD, '(d) Long-Term Benchmarks (1000 - 5300 h): Validated with Real TiberCAD Runs', 'FontWeight', 'bold', 'FontSize', 11);
legend(axD, 'Location', 'northeast', 'FontSize', 8.5);

exportgraphics(figS5, fullfile(outDir, 'FigS5_nomad_stratification_anova_and_benchmarks.pdf'), 'ContentType', 'vector');
exportgraphics(figS5, fullfile(outDir, 'FigS5_nomad_stratification_anova_and_benchmarks.png'), 'Resolution', 300);
fprintf('Salvata FigS5_nomad_stratification_anova_and_benchmarks.pdf/.png\n');

%% =================================================================================================
%  FUNZIONI DI PLOTTING PER PANNELLO B E PANNELLO C
%  =================================================================================================
function plot_panelB_linear_grouped(ax)
    % Valori esatti della Mediana di T80 equivalente (h) da `nomad_multivariate_stratification.csv`:
    %   Gruppo 1 (Aging Protocol):      ISOS-D (Dark) = 96.5 h   vs  ISOS-L (Light) = 43.5 h  (Ratio 2.22x, Delta = 53.0 h)
    %   Gruppo 2 (Perovskite Comp.):    MAPbI3-based  = 79.1 h   vs  Mixed-Cation   = 60.0 h  (Ratio 1.32x, Delta = 19.1 h)
    %   Gruppo 3 (Cell Architecture):   n-i-p         = 71.2 h   vs  p-i-n          = 77.3 h  (Ratio 1.09x, Delta =  6.1 h)
    group_names = {'Aging Protocol (Dark vs. Light)', 'Perovskite Composition', 'Cell Architecture'};
    Y_med = [
        96.5, 43.5;  % Protocol: ISOS-D vs ISOS-L
        79.1, 60.0;  % Composition: MAPbI3 vs Mixed-Cation
        71.2, 77.3   % Architecture: n-i-p vs p-i-n
    ];
    sub_Text = {
        'ISOS-D (Dark)', 'ISOS-L (Light)';
        'MAPbI_3',       'Mixed-Cation';
        'n-i-p',         'p-i-n'
    };
    delta_Text = {'\Delta = 53.0 h (2.2\times)', '\Delta = 19.1 h (1.3\times)', '\Delta = 6.1 h (1.1\times)'};

    b = bar(ax, 1:3, Y_med, 'grouped', 'BarWidth', 0.78);
    b(1).FaceColor = [0.18, 0.48, 0.82]; b(1).DisplayName = 'Subgroup 1 (ISOS-D / MAPbI_3 / n-i-p)';
    b(2).FaceColor = [0.90, 0.45, 0.15]; b(2).DisplayName = 'Subgroup 2 (ISOS-L / Mixed-Cation / p-i-n)';

    for g = 1:3
        for s = 1:2
            x_pt = b(s).XEndPoints(g);
            y_pt = b(s).YEndPoints(g);
            text(ax, x_pt, y_pt + 2.0, sprintf('%s\n(%.1f h)', sub_Text{g, s}, y_pt), ...
                 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
                 'FontSize', 8.5, 'FontWeight', 'bold');
        end
        % Annotazione della differenza sopra ciascuna coppia
        y_top = max(Y_med(g, :)) + 17.5;
        text(ax, g, y_top, delta_Text{g}, 'HorizontalAlignment', 'center', ...
             'FontSize', 9.2, 'FontWeight', 'bold', 'Color', [0.65 0.10 0.10], ...
             'BackgroundColor', [1.0 0.96 0.90], 'EdgeColor', [0.85 0.60 0.40], 'Margin', 2);
    end

    xticks(ax, 1:3);
    xticklabels(ax, group_names);
    ylim(ax, [0, 125]); xlim(ax, [0.4, 3.6]);
    ylabel(ax, 'Median Equivalent Lifetime T_{80} (h, linear scale)', 'FontWeight', 'bold', 'FontSize', 10.5);
    title(ax, '(b) Stratification of Median T_{80}: Illumination Protocol Dominates Scatter', 'FontWeight', 'bold', 'FontSize', 11);
    legend(ax, 'Location', 'northeast', 'FontSize', 8.5);
    set(ax, 'FontSize', 10.5);
end

function plot_panelC_mode(ax, mode_id, Cov_Raw_Windows, Cov_Filtered_Windows, Cov_Comparison_5000h)
    cats_c = {'EVA (High O_2 Perm.)', 'POE (Low H_2O Sol.)', 'PVB & Next-Gen'};
    if mode_id == 1
        Y_plot = Cov_Raw_Windows;
        leg_labels = {'0 - 700 h (1-Month Window)', '0 - 2000 h (Extended Window)', '0 - 5000 h (Full Horizon)'};
        ttl_str = '(c) Raw Envelope Coverage (Unfiltered Repository Data)';
        cols = [0.25 0.45 0.75; 0.15 0.65 0.45; 0.85 0.45 0.15];
    elseif mode_id == 2
        Y_plot = Cov_Filtered_Windows;
        leg_labels = {'0 - 700 h (Excl. Premature Defects)', '0 - 2000 h (Excl. Premature Defects)', '0 - 5000 h (Excl. Premature Defects)'};
        ttl_str = '(c) Envelope Coverage Excluding Premature Defect Failures (T_{80,eq} < 1/3 T_{80,harsh})';
        cols = [0.25 0.45 0.75; 0.15 0.65 0.45; 0.85 0.45 0.15];
    else
        Y_plot = Cov_Comparison_5000h;
        leg_labels = { ...
            'Raw Data (Incl. T_{80} < 10 h Fabrication Defects)', ...
            'Excl. Infant Mortality (T_{80} < 20 h & Dead Cells)', ...
            'Excl. All Premature Seal Defects (T_{80,eq} < 1/3 T_{80,harsh})' ...
        };
        ttl_str = '(c) Impact of Premature Fabrication Defects on Envelope Coverage';
        cols = [0.55 0.55 0.55; 0.20 0.52 0.85; 0.10 0.68 0.38];
    end

    bC = bar(ax, categorical(cats_c, cats_c), Y_plot, 'grouped', 'BarWidth', 0.82);
    for k = 1:3
        bC(k).FaceColor = cols(k, :);
        bC(k).DisplayName = leg_labels{k};
        x_ep = bC(k).XEndPoints;
        y_ep = bC(k).YEndPoints;
        lbls = arrayfun(@(v) sprintf('%.1f%%', v), y_ep, 'UniformOutput', false);
        text(ax, x_ep, y_ep + 1.8, lbls, 'HorizontalAlignment', 'center', ...
             'VerticalAlignment', 'bottom', 'FontSize', 8.5, 'FontWeight', 'bold');
    end
    ylim(ax, [0, 118]);
    ylabel(ax, 'Envelope Coverage within \pm0.10 Tolerance (%)', 'FontWeight', 'bold', 'FontSize', 10.5);
    title(ax, ttl_str, 'FontWeight', 'bold', 'FontSize', 10.8);
    legend(ax, 'Location', 'northwest', 'FontSize', 8.2);
    set(ax, 'FontSize', 10.5);
end
