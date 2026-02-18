% plot_results.m
% Reads results/metrics_grade4_full_with_time.csv and generates plots into results/plots/

clc; close all;

inPath = fullfile("results", "metrics_grade4_full_with_time.csv");
assert(isfile(inPath), "Could not find %s", inPath);

T = readtable(inPath);

outDir = fullfile("results","plots");
if ~exist(outDir, "dir"), mkdir(outDir); end

% Ensure types are friendly
T.Original = string(T.Original);
T.OptMode  = string(T.OptMode);
T.Method   = string(T.Method);
T.K        = double(T.K);

% Convenience: readable label per curve
T.Curve = T.OptMode + " + " + T.Method;

originals = unique(T.Original);
Ks = unique(T.K);
Ks = sort(Ks);

metricsToPlot = ["S_CIELAB","SSIM","BuildTime_s"];
yLabels = containers.Map( ...
    ["S_CIELAB","SSIM","BuildTime_s"], ...
    ["Mean S-CIELAB (lower is better)", "SSIM (higher is better)", "Build time (s)"] ...
);

% -------- Per-original plots --------
for i = 1:numel(originals)
    orig = originals(i);
    S = T(T.Original == orig, :);

    curves = unique(S.Curve);

    for mt = 1:numel(metricsToPlot)
        metric = metricsToPlot(mt);

        figure('Visible','off');
        hold on; grid on;

        for c = 1:numel(curves)
            curveName = curves(c);
            C = S(S.Curve == curveName, :);

            % Build y aligned to Ks
            y = nan(size(Ks));
            for kk = 1:numel(Ks)
                kVal = Ks(kk);
                rows = C(C.K == kVal, :);
                if ~isempty(rows)
                    y(kk) = rows.(metric)(1);
                end
            end

            plot(Ks, y, '-o', 'DisplayName', curveName);
        end

        xlabel('Database size K');
        ylabel(yLabels(metric));
        title(sprintf("%s: %s vs K", strip_file(orig), metric), 'Interpreter','none');
        legend('Location','best');
        xlim([min(Ks) max(Ks)]);

        savePath = fullfile(outDir, sprintf("%s_%s_vs_K.png", strip_file(orig), metric));
        exportgraphics(gcf, savePath, 'Resolution', 200);
        close(gcf);
    end
end

% -------- Summary plots across originals (mean ± std) --------
% Group by (OptMode, Method, K)
G = groupsummary(T, ["OptMode","Method","K"], ["mean","std"], ["S_CIELAB","BuildTime_s","SSIM"]);

% Add curve label
G.Curve = string(G.OptMode) + " + " + string(G.Method);

summaryMetrics = ["mean_S_CIELAB","mean_BuildTime_s"];
summaryStd     = ["std_S_CIELAB","std_BuildTime_s"];
summaryTitles  = ["Mean S-CIELAB across originals", "Mean BuildTime across originals"];
summaryYLabels = ["S-CIELAB (mean ± std)", "Build time (s) (mean ± std)"];

for s = 1:numel(summaryMetrics)
    mName = summaryMetrics(s);
    sdName = summaryStd(s);

    figure('Visible','off');
    hold on; grid on;

    curves = unique(G.Curve);
    for c = 1:numel(curves)
        curveName = curves(c);
        C = G(G.Curve == curveName, :);

        % Ensure sorted by K
        [~, idx] = sort(C.K);
        C = C(idx, :);

        x = C.K;
        y = C.(mName);
        e = C.(sdName);

        errorbar(x, y, e, '-o', 'DisplayName', curveName);
    end

    xlabel('Database size K');
    ylabel(summaryYLabels(s));
    title(summaryTitles(s), 'Interpreter','none');
    legend('Location','best');
    xlim([min(Ks) max(Ks)]);

    savePath = fullfile(outDir, sprintf("SUMMARY_%s_vs_K.png", mName));
    exportgraphics(gcf, savePath, 'Resolution', 200);
    close(gcf);
end

disp("Plots saved to: " + outDir);

% -------- helper --------
function name = strip_file(pathStr)
% Turn "data\originals\test1.jpg" into "test1"
    pathStr = string(pathStr);
    [~, name, ~] = fileparts(pathStr);
end
