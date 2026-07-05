%% 1. SYSTEM SETUP & EXACT DATA EXTRACTION
% --- RUN CONFIGURATION ---
Run_Name = 'uA_very_Light_Load'; 
Run_Title = strrep(Run_Name, '_', ' ');

f = logspace(2, 7, 2500); 
w = f * 2 * pi;
L = G * C; 

[magG, phG] = bode(G, w);
[magC, phC] = bode(C, w);
[magL, phL] = bode(L, w);

magG_dB = 20*log10(squeeze(magG));
magC_dB = 20*log10(squeeze(magC));
magL_dB = 20*log10(squeeze(magL));
phG_deg = unwrap(squeeze(phG) * pi/180) * 180/pi;
phC_deg = unwrap(squeeze(phC) * pi/180) * 180/pi;
phL_deg = unwrap(squeeze(phL) * pi/180) * 180/pi;

% --- DYNAMIC COMPENSATOR & SYSTEM DATA EXTRACTION ---
% Using the continuous transfer function L for exact root finding
[GM, PM, Wcg, Wcp] = margin(L);
fc = Wcp / (2*pi); 
Fcg = Wcg / (2*pi); 
Fcp = fc;

[Zc, Pc, ~] = zpkdata(C, 'v');
fz_c = sort(abs(Zc(Zc~=0)) / (2*pi)); 
fp_c = sort(abs(Pc(Pc~=0)) / (2*pi)); 

fz1 = fz_c(1);
fz2 = fz_c(2);
fp1 = fp_c(1);
fp2 = fp_c(2);

[Zg, Pg, ~] = zpkdata(G, 'v');
fp_g = sort(abs(Pg(Pg~=0)) / (2*pi)); 
fz_g = sort(abs(Zg(Zg~=0)) / (2*pi)); 

% --- STRICT ACADEMIC LIGHT MODE FORMATTING ---
set(groot, 'defaultAxesFontSize', 12, 'defaultAxesFontName', 'Times New Roman', ...
           'defaultLineLineWidth', 2, 'defaultAxesGridColor', 'k', ...
           'defaultAxesGridAlpha', 0.15, 'defaultFigureColor', 'w', ...      
           'defaultAxesColor', 'w', 'defaultTextColor', 'k', ...        
           'defaultAxesXColor', 'k', 'defaultAxesYColor', 'k', ...
           'defaultLegendColor', 'w', 'defaultLegendTextColor', 'k', 'defaultLegendEdgeColor', 'k');      

%% FIGURE 1: THE RAW POWER STAGE (PLANT G)
fig1 = figure('Name', sprintf('Power Stage - %s', Run_Title), 'Position', [100, 100, 900, 700]);
subplot(2,1,1);
h_magG = semilogx(f, magG_dB, 'Color', [0 0.4470 0.7410]); grid on; hold on;
title(sprintf('1. Uncompensated Power Stage Plant G(s) (%s)', Run_Title), 'FontSize', 14, 'FontWeight', 'bold', 'Color', 'k');
ylabel('Magnitude (dB)', 'Color', 'k');
leg_handles_G = h_magG;
leg_labels_G = {'Plant Magnitude'};
if ~isempty(fp_g)
    f_LC = fp_g(1);
    h_LC = plot(f_LC, interp1(f, magG_dB, f_LC), 'rx', 'MarkerSize', 10, 'LineWidth', 2.5);
    xline(f_LC, 'k:');
    leg_handles_G(end+1) = h_LC;
    leg_labels_G{end+1} = sprintf('LC Pole (%.1f kHz)', f_LC/1000);
end
if ~isempty(fz_g)
    f_ESR = fz_g(1);
    h_ESR = plot(f_ESR, interp1(f, magG_dB, f_ESR), 'mo', 'MarkerSize', 8, 'LineWidth', 2);
    xline(f_ESR, 'k:');
    leg_handles_G(end+1) = h_ESR;
    leg_labels_G{end+1} = sprintf('ESR Zero (%.1f kHz)', f_ESR/1000);
end
legend(leg_handles_G, leg_labels_G, 'Location', 'southwest', 'FontSize', 11);
ylim([-100 100]); 

subplot(2,1,2);
semilogx(f, phG_deg, 'Color', [0 0.4470 0.7410]); grid on; hold on;
ylabel('Phase (deg)', 'Color', 'k'); xlabel('Frequency (Hz)', 'Color', 'k');
ylim([-200 10]);

%% FIGURE 2: THE COMPENSATOR (C)
fig2 = figure('Name', sprintf('Compensator - %s', Run_Title), 'Position', [150, 150, 950, 700]);
subplot(2,1,1);
h_magC = semilogx(f, magC_dB, 'Color', [0.8500 0.3250 0.0980]); grid on; hold on;
title(sprintf('2. Type III Compensator Architecture C(s) (%s)', Run_Title), 'FontSize', 14, 'FontWeight', 'bold', 'Color', 'k');
ylabel('Magnitude (dB)', 'Color', 'k');

% Logic to combine duplicate zeros in legend
if abs(fz1 - fz2) < 1 
    h_z = plot(fz1, interp1(f, magC_dB, fz1), 'bo', 'MarkerSize', 8, 'LineWidth', 2.5);
    h_p1 = plot(fp1, interp1(f, magC_dB, fp1), 'rx', 'MarkerSize', 10, 'LineWidth', 2.5);
    h_p2 = plot(fp2, interp1(f, magC_dB, fp2), 'mx', 'MarkerSize', 10, 'LineWidth', 2.5);
    xline(fz1, 'k:'); xline(fp1, 'k:'); xline(fp2, 'k:');
    legend_handles = [h_magC, h_z, h_p1, h_p2];
    legend_labels = {'Compensator Mag', sprintf('Double Zero (%.2f kHz)', fz1/1000), ...
                     sprintf('Pole 1 (%.1f kHz)', fp1/1000), sprintf('Pole 2 (%.1f kHz)', fp2/1000)};
else
    h_z1 = plot(fz1, interp1(f, magC_dB, fz1), 'bo', 'MarkerSize', 8, 'LineWidth', 2.5);
    h_z2 = plot(fz2, interp1(f, magC_dB, fz2), 'co', 'MarkerSize', 8, 'LineWidth', 2.5);
    h_p1 = plot(fp1, interp1(f, magC_dB, fp1), 'rx', 'MarkerSize', 10, 'LineWidth', 2.5);
    h_p2 = plot(fp2, interp1(f, magC_dB, fp2), 'mx', 'MarkerSize', 10, 'LineWidth', 2.5);
    xline(fz1, 'k:'); xline(fz2, 'k:'); xline(fp1, 'k:'); xline(fp2, 'k:');
    legend_handles = [h_magC, h_z1, h_z2, h_p1, h_p2];
    legend_labels = {'Compensator Mag', sprintf('Zero 1 (%.2f kHz)', fz1/1000), ...
                     sprintf('Zero 2 (%.2f kHz)', fz2/1000), sprintf('Pole 1 (%.1f kHz)', fp1/1000), ...
                     sprintf('Pole 2 (%.1f kHz)', fp2/1000)};
end
xline(fc, 'b-.');
legend(legend_handles, legend_labels, 'Location', 'northwest', 'FontSize', 11);
ylim([-60 60]);

subplot(2,1,2);
semilogx(f, phC_deg, 'Color', [0.8500 0.3250 0.0980]); grid on; hold on;
ylabel('Phase (deg)', 'Color', 'k'); xlabel('Frequency (Hz)', 'Color', 'k');
baseline = -90;
phase_at_fc = interp1(f, phC_deg, fc);
yline(baseline, 'k--');
xline(fc, 'b-.', 'f_c', 'LabelVerticalAlignment', 'bottom');

plot([fc fc], [baseline phase_at_fc], 'b-', 'LineWidth', 2.5); 
plot([fc*0.8 fc*1.2], [baseline baseline], 'b-', 'LineWidth', 2); 
plot([fc*0.8 fc*1.2], [phase_at_fc phase_at_fc], 'b-', 'LineWidth', 2); 
text(fc*1.3, (baseline + phase_at_fc)/2, ...
    sprintf('Phase Boost\n= +%.1f^\\circ\n@ %.2f kHz', phase_at_fc - baseline, fc/1000), ...
    'Color', 'b', 'FontSize', 12, 'FontWeight', 'bold');
ylim([-130 110]); 

%% FIGURE 3: TOTAL OPEN LOOP (STABILITY MARGINS)
fig3 = figure('Name', sprintf('Loop Gain T(s) - %s', Run_Title), 'Position', [200, 200, 900, 700]);
subplot(2,1,1);
h_magL = semilogx(f, magL_dB, 'r-', 'LineWidth', 2.5); grid on; hold on;
title(sprintf('3. Loop Gain T(s) = G(s)C(s) (%s)', Run_Title), 'FontSize', 14, 'FontWeight', 'bold', 'Color', 'k');
ylabel('Magnitude (dB)', 'Color', 'k');
yline(0, 'k--', 'LineWidth', 1.5);
xline(fc, 'b:', 'f_c', 'LabelVerticalAlignment', 'bottom');
h_GM = plot([Fcg, Fcg], [0, -20*log10(GM)], 'b-o', 'LineWidth', 2);
text(Fcg*0.4, 15, sprintf('G.M. = %.1f dB', 20*log10(GM)), 'Color', 'b', 'FontWeight', 'bold');
h_p_loop = plot(fp2, interp1(f, magL_dB, fp2), 'rx', 'MarkerSize', 10, 'LineWidth', 2.5);
xline(fp2, 'k:');
legend([h_magL, h_GM(1), h_p_loop], ...
    {'Loop Gain T(s)', 'Gain Margin', sprintf('HF Pole (%.1f kHz)', fp2/1000)}, ...
    'Location', 'southwest', 'FontSize', 11);
ylim([-100 80]);

subplot(2,1,2);
semilogx(f, phL_deg, 'r-', 'LineWidth', 2.5); grid on; hold on;
ylabel('Phase (deg)', 'Color', 'k'); xlabel('Frequency (Hz)', 'Color', 'k');
yline(-180, 'k--', 'LineWidth', 1.5);
xline(Fcp, 'm-.', 'LineWidth', 1.5); 
xline(fc, 'b:', 'f_c', 'LabelVerticalAlignment', 'bottom');
plot([Fcp, Fcp], [-180, -180+PM], 'b-o', 'LineWidth', 2);
text(Fcp*1.2, -130, sprintf('P.M. = %.1f^\\circ\n@ %.2f kHz', PM, Fcp/1000), 'Color', 'b', 'FontWeight', 'bold');
ylim([-225 90]); 

%% FIGURE 4: THE ACADEMIC OVERLAY
fig4 = figure('Name', sprintf('System Overlay - %s', Run_Title), 'Position', [250, 250, 1000, 750]);
subplot(2,1,1);
semilogx(f, magG_dB, ':', 'Color', [0.4 0.6 0.9], 'LineWidth', 2); hold on; grid on;
semilogx(f, magC_dB, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 2); 
semilogx(f, magL_dB, 'r-', 'LineWidth', 3);
title(sprintf('4. Control Architecture Synthesis Overlay (%s)', Run_Title), 'FontSize', 14, 'FontWeight', 'bold', 'Color', 'k');
ylabel('Magnitude (dB)', 'Color', 'k');
xline(fc, 'b:', 'f_c', 'LabelVerticalAlignment', 'bottom', 'LabelHorizontalAlignment', 'left');
legend('Plant G(s)', 'Compensator C(s)', 'Loop Gain T(s)', 'Location', 'southwest', 'FontSize', 11);
ylim([-100 80]);

subplot(2,1,2);
semilogx(f, phG_deg, ':', 'Color', [0.4 0.6 0.9], 'LineWidth', 2); hold on; grid on;
semilogx(f, phC_deg, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 2); 
semilogx(f, phL_deg, 'r-', 'LineWidth', 3);
xline(fc, 'b:', 'f_c', 'LabelVerticalAlignment', 'bottom', 'LabelHorizontalAlignment', 'left');
ylabel('Phase (deg)', 'Color', 'k'); xlabel('Frequency (Hz)', 'Color', 'k');
ylim([-225 100]);

%% FIGURE 5: CLOSED-LOOP TRANSIENT RESPONSES
fig5 = figure('Name', sprintf('System Transients - %s', Run_Title), 'Position', [300, 300, 1200, 800]);
sgtitle(sprintf('System Transients (%s)', Run_Title), 'FontSize', 16, 'FontWeight', 'bold', 'Color', 'k');

subplot(2,3,1);
[y, t] = step(IOTransfer_r2y);
plot(t*1e6, y, 'b-', 'LineWidth', 2.5); grid on;
title('Ref to Output (r \rightarrow y)', 'FontSize', 13, 'FontWeight', 'bold', 'Color', 'k');
xlabel('Time (\mus)', 'Color', 'k'); ylabel('Amplitude (V/V)', 'Color', 'k');

subplot(2,3,2);
[y, t] = step(IOTransfer_r2u);
plot(t*1e6, y, 'Color', [0.85 0.33 0.10], 'LineWidth', 2.5); grid on;
title('Control Effort (r \rightarrow u)', 'FontSize', 13, 'FontWeight', 'bold', 'Color', 'k');
xlabel('Time (\mus)', 'Color', 'k'); ylabel('Amplitude', 'Color', 'k');

subplot(2,3,4);
[y, t] = step(IOTransfer_du2y);
plot(t*1e6, y, 'r-', 'LineWidth', 2.5); grid on;
title('Line Transient (du \rightarrow y)', 'FontSize', 13, 'FontWeight', 'bold', 'Color', 'k');
xlabel('Time (\mus)', 'Color', 'k'); ylabel('Amplitude Deviation', 'Color', 'k');

subplot(2,3,5);
[y, t] = step(IOTransfer_dy2y);
plot(t*1e6, y, 'm-', 'LineWidth', 2.5); grid on;
title('Load Transient (dy \rightarrow y)', 'FontSize', 13, 'FontWeight', 'bold', 'Color', 'k');
xlabel('Time (\mus)', 'Color', 'k'); ylabel('Amplitude Deviation', 'Color', 'k');

subplot(2,3,6);
[y, t] = step(IOTransfer_n2y);
plot(t*1e6, y, 'k-', 'LineWidth', 2.5); grid on;
title('Noise Susceptibility (n \rightarrow y)', 'FontSize', 13, 'FontWeight', 'bold', 'Color', 'k');
xlabel('Time (\mus)', 'Color', 'k'); ylabel('Amplitude Deviation', 'Color', 'k');

%% --- EXPORT ALL FIGURES FOR LATEX PUBLICATION ---
fprintf('Exporting publication graphics for %s...\n', Run_Name);

exportgraphics(fig1, sprintf('Figure1_Power_Stage_Plant_%s.pdf', Run_Name), 'ContentType', 'vector', 'BackgroundColor', 'white');
exportgraphics(fig1, sprintf('Figure1_Power_Stage_Plant_%s.png', Run_Name), 'Resolution', 300, 'BackgroundColor', 'white');

exportgraphics(fig2, sprintf('Figure2_Type_III_Compensator_%s.pdf', Run_Name), 'ContentType', 'vector', 'BackgroundColor', 'white');
exportgraphics(fig2, sprintf('Figure2_Type_III_Compensator_%s.png', Run_Name), 'Resolution', 300, 'BackgroundColor', 'white');

exportgraphics(fig3, sprintf('Figure3_Loop_Gain_Margins_%s.pdf', Run_Name), 'ContentType', 'vector', 'BackgroundColor', 'white');
exportgraphics(fig3, sprintf('Figure3_Loop_Gain_Margins_%s.png', Run_Name), 'Resolution', 300, 'BackgroundColor', 'white');

exportgraphics(fig4, sprintf('Figure4_System_Overlay_%s.pdf', Run_Name), 'ContentType', 'vector', 'BackgroundColor', 'white');
exportgraphics(fig4, sprintf('Figure4_System_Overlay_%s.png', Run_Name), 'Resolution', 300, 'BackgroundColor', 'white');

exportgraphics(fig5, sprintf('Figure5_System_Transients_%s.pdf', Run_Name), 'ContentType', 'vector', 'BackgroundColor', 'white');
exportgraphics(fig5, sprintf('Figure5_System_Transients_%s.png', Run_Name), 'Resolution', 300, 'BackgroundColor', 'white');

disp('Export complete. Vector PDFs are ready for LaTeX.');