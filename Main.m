% Hejhopp - Main script
% Compares:
%   Optimization: Global vs ImageDependent (per-original DB preselection)
%   Method:       ColorOnly vs ColorStruct
%   DB sizes:     800, 200, 100, 50
% Outputs mosaics + a single CSV with metrics for all combinations.

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

% Load/build DB cache (rebuild if struct fields missing)
cachePath = fullfile("data","db_cache.mat");
needsRebuild = true;
if isfile(cachePath)
    S = load(cachePath, "db");
    db = S.db;
    needsRebuild = ~isfield(db,"structFeat") || ~isfield(db,"structBins");
end
if needsRebuild
    fprintf("Rebuilding DB cache...\n");
    db = preprocess_db(dbFolder, tileSize);
    save(cachePath, "db", "-v7.3");
end

% Experiment settings
Ks = [800, 200, 100, 50];
methods  = ["ColorOnly", "ColorStruct"];   % selection rule
optModes = ["Global", "ImageDependent"];   % DB optimization mode

% Parameters for Color+Structure method
Kc = 15;        % shortlist size (top-K by Lab color distance)
wStruct = 0.5;  % structure weight

% Parameter for ImageDependent preselection pool
M0 = 300;       % choose 200-400; 300 is a good default

% Results table schema
allRows = table('Size',[0 9], ...
    'VariableTypes', {'string','string','string','double','double','double','double','double','double'}, ...
    'VariableNames', {'Original','OptMode','Method','K','PSNR','SSIM','S_CIELAB','MSE','DeltaEab'});

for p = 1:numel(origPaths)
    origPath = string(origPaths(p));
    orig = imread(origPath);
    [~, baseName, ~] = fileparts(origPath);

    for o = 1:numel(optModes)
        optMode = optModes(o);

        % Build the DB base depending on original image (image-dependent optimization)
        if optMode == "Global"
            dbBase = db;
        else
            % Requires: select_db_for_original.m
            dbBase = select_db_for_original(db, orig, tileSize, gridSize, M0);
        end

        for kIdx = 1:numel(Ks)
            K = Ks(kIdx);

            % Robust reduction logic:
            % If requested K is >= available images, just use all images in dbBase.
            Nbase = size(dbBase.meanLab, 1);
            fprintf("OptMode=%s baseName=%s Nbase=%d K=%d\n", optMode, baseName, Nbase, K);

            if K >= Nbase
                dbK = dbBase;
            else
                dbK = reduce_db_fps(dbBase, K, 42); % must copy structFeat/structBins too
            end

            % If we will run structure method, ensure struct features exist
            if any(methods == "ColorStruct")
                assert(isfield(dbK,"structFeat") && isfield(dbK,"structBins"), ...
                    "dbK missing structFeat/structBins. Fix reduce_db_fps to copy them.");
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
                outPath = fullfile(outFolder, sprintf("mosaic_%s_%s_%s_K%d.png", baseName, optMode, method, K));
                imwrite(mosaic, outPath);

                % Metrics
                M = evaluate_metrics(imresize(orig, [size(mosaic,1) size(mosaic,2)]), mosaic);

                % Add row
                row = table('Size',[1 9], ...
                    'VariableTypes', {'string','string','string','double','double','double','double','double','double'}, ...
                    'VariableNames', {'Original','OptMode','Method','K','PSNR','SSIM','S_CIELAB','MSE','DeltaEab'});

                row.Original  = origPath;
                row.OptMode   = optMode;
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
end

% Export metrics
metricsPath = fullfile(outFolder, "metrics_grade4_full.csv");
writetable(allRows, metricsPath);
disp(allRows);
fprintf("Wrote metrics to %s\n", metricsPath);

% Helpful debugging (uncomment if you suspect path collisions)
% disp("reduce_db_fps resolution:");
% which reduce_db_fps -all
