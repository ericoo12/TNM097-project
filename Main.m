% Hejhopp - Main script (Color-only vs Color+Structure, multiple DB sizes, metrics)
clc; clear; close all;

% If you keep code in subfolders, uncomment:
% addpath(genpath("src"));
% addpath(genpath(fullfile("external","scielab")));

dbFolder = fullfile("data","db");
origPaths = [
    fullfile("data","originals","test1.jpg")
    fullfile("data","originals","test2.jpg")
    fullfile("data","originals","test3.jpg")
];

outFolder = fullfile("results");
if ~exist(outFolder, "dir"), mkdir(outFolder); end

% Sanity check dataset
dbCount = numel(dir(fullfile(dbFolder, "*.jpg")));
assert(dbCount >= 200, "Need >=200 JPGs in data/db. Found %d", dbCount);
fprintf("DB images found: %d\n", dbCount);

% Mosaic settings
tileSize = [32 32];
gridSize = [60 80];

% Load/build DB cache (IMPORTANT: delete cache if you changed preprocess_db)
cachePath = fullfile("data","db_cache.mat");

if ~isfile(cachePath)
    db = preprocess_db(dbFolder, tileSize); % should now also create db.structFeat/db.structBins
    save(cachePath, "db", "-v7.3");
else
    S = load(cachePath, "db");
    db = S.db;
end
disp(fieldnames(db));
% Experiment settings
Ks = [800, 200, 100, 50];
methods = ["ColorOnly", "ColorStruct"];   % compare both approaches

% Parameters for Color+Structure method
Kc = 15;        % shortlist size (top-K by Lab color distance)
wStruct = 0.5;  % structure weight

% Results table schema
allRows = table('Size',[0 8], ...
    'VariableTypes', {'string','string','double','double','double','double','double','double'}, ...
    'VariableNames', {'Original','Method','K','PSNR','SSIM','S_CIELAB','MSE','DeltaEab'});

for p = 1:numel(origPaths)
    origPath = string(origPaths(p));
    orig = imread(origPath);
    [~, baseName, ~] = fileparts(origPath);

    for K = Ks
        % Reduce DB if needed
        if K == size(db.meanLab, 1)
            dbK = db;
        else
            dbK = reduce_db_fps(db, K, 42);
        end
        if K < size(db.meanLab,1)
            assert(isfield(dbK,"structFeat"), "dbK missing structFeat after reduction");
        end

        for m = 1:numel(methods)
            method = methods(m);

            % Build mosaic
            if method == "ColorOnly"
                mosaic = build_mosaic(orig, dbK, tileSize, gridSize);
            else
                mosaic = build_mosaic_color_structure(orig, dbK, tileSize, gridSize, Kc, wStruct);
            end

            % Save mosaic
            outPath = fullfile(outFolder, sprintf("mosaic_%s_%s_K%d.png", baseName, method, K));
            imwrite(mosaic, outPath);

            % Metrics
            M = evaluate_metrics(imresize(orig, [size(mosaic,1) size(mosaic,2)]), mosaic);

            % Add row (must match allRows schema exactly)
            row = table('Size',[1 8], ...
                'VariableTypes', {'string','string','double','double','double','double','double','double'}, ...
                'VariableNames', {'Original','Method','K','PSNR','SSIM','S_CIELAB','MSE','DeltaEab'});

            row.Original  = origPath;
            row.Method    = method;
            row.K         = double(K);
            row.PSNR      = double(M.PSNR);
            row.SSIM      = double(M.SSIM);
            row.S_CIELAB  = double(M.S_CIELAB);
            row.MSE       = double(M.MSE);
            row.DeltaEab  = double(M.DeltaEab);

            allRows = [allRows; row]; %#ok<AGROW>
        end
    end
end

% Export metrics
metricsPath = fullfile(outFolder, "metrics_color_vs_structure.csv");
writetable(allRows, metricsPath);
disp(allRows);
fprintf("Wrote metrics to %s\n", metricsPath);
