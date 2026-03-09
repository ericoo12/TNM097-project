% ========================================================================
% Main.m
% Photomosaic experiment runner + evaluation
%
% What this script does:
%  1) Loads (or builds) a preprocessed image database (tiles + features)
%  2) Builds photomosaics for multiple originals
%  3) Compares methods:
%       - ColorOnly    (match tiles using only mean CIELAB color)
%       - ColorStruct  (two-stage: color shortlist -> structure tie-break)
%  4) Compares DB strategies:
%       - Global           (same DB for all originals)
%       - ImageDependent   (preselect DB subset tailored to the original)
%  5) Compares different DB sizes K = [800, 200, 100, 50]
%  6) Measures runtime + objective metrics, writes CSV, then plots results
% ========================================================================

clc; clear; close all;

% Reproducibility: ensures that any random choices (e.g. FPS start point)
% are repeatable across runs/machines.
rng(42);
addpath(genpath(fullfile(pwd,"scielab_from_lab3/")));
% ------------------------------------------------------------------------
% Paths: database + originals + output folder
% ------------------------------------------------------------------------
dbFolder = fullfile("data","db");  % where your ~800 tile images are stored

% Original images to mosaic (you can add more here)
origPaths = [
    fullfile("data","originals","test1.jpg")
    fullfile("data","originals","test2.jpg")
    fullfile("data","originals","test3.jpg")
];

% Output folder for generated mosaics + CSV + plots
outFolder = fullfile("results");
if ~exist(outFolder, "dir")
    mkdir(outFolder);
end

% ------------------------------------------------------------------------
% Sanity check: ensure there are enough DB images available
% ------------------------------------------------------------------------
dbCount = numel(dir(fullfile(dbFolder, "*.jpg")));
assert(dbCount >= 200, "Need >=200 JPGs in data/db. Found %d", dbCount);
fprintf("DB images found: %d\n", dbCount);

% ------------------------------------------------------------------------
% Mosaic settings:
% tileSize: size of each database tile image placed in the mosaic
% gridSize: number of tiles (rows x cols) in the mosaic
%
% Mosaic output size becomes:
%   (gridSize(1)*tileSize(1)) x (gridSize(2)*tileSize(2))
% ------------------------------------------------------------------------
tileSize = [32 32];
gridSize = [60 80];

% ------------------------------------------------------------------------
% Database cache:
% We preprocess the DB once (resize, compute meanLab, structFeat, store tiles)
% and store it in data/db_cache.mat.
%
% This saves a lot of time for repeated experiments.
% If the cache exists but lacks struct features, we rebuild it.
% ------------------------------------------------------------------------
cachePath = fullfile("data","db_cache.mat");

needsRebuild = true;
if isfile(cachePath)
    S = load(cachePath, "db");
    db = S.db;
    % If these fields are missing, cache was created before we added structure
    needsRebuild = ~isfield(db,"structFeat") || ~isfield(db,"structBins");
end

if needsRebuild
    fprintf("Rebuilding DB cache...\n");
    % preprocess_db creates:
    %   db.tiles      [tileH x tileW x 3 x N] uint8
    %   db.meanLab    [N x 3] double
    %   db.structFeat [N x B] double
    %   db.structBins scalar (B)
    %   db.files      [N x 1] string
    db = preprocess_db(dbFolder, tileSize);
    save(cachePath, "db", "-v7.3");
end

% ------------------------------------------------------------------------
% Experiment settings
% Ks:        DB sizes to test (full DB = 800 in your case)
% methods:   tile selection rule (color only vs color+structure)
% optModes:  how we choose the database for each original (global vs image-dependent)
% ------------------------------------------------------------------------
Ks      = [800, 200, 100, 50];
methods = ["ColorOnly", "ColorStruct"];
optModes = ["Global", "ImageDependent"];

% ------------------------------------------------------------------------
% Parameters for ColorStruct:
% Kc:      shortlist size (top-K by color distance before structure check)
% wStruct: how strongly structure affects final score
% ------------------------------------------------------------------------
Kc = 15;
wStruct = 0.5;

% ------------------------------------------------------------------------
% Parameter for ImageDependent DB:
% M0: preselection pool size from full DB before reducing to K.
%     Example: pick the 300 DB images whose colors match the original best,
%     then run FPS to reduce to K.
% ------------------------------------------------------------------------
M0 = 300;

% Debug print toggle (useful during development)
verbose = false;

% ------------------------------------------------------------------------
% Results table schema:
% We store one row per (Original, OptMode, Method, K).
% BuildTime_s measures only mosaic-building time (not metrics computation).
% ------------------------------------------------------------------------
allRows = table('Size',[0 10], ...
    'VariableTypes', {'string','string','string','double','double','double','double','double','double','double'}, ...
    'VariableNames', {'Original','OptMode','Method','K','BuildTime_s','PSNR','SSIM','S_CIELAB','MSE','DeltaEab'});

% ========================================================================
% Main experiment loop
% ========================================================================
for p = 1:numel(origPaths)

    % Read one original image
    origPath = string(origPaths(p));
    orig = imread(origPath);

    % Base name used for output filenames (test1/test2/test3)
    [~, baseName, ~] = fileparts(origPath);

    % Loop over DB selection strategies (Global vs ImageDependent)
    for o = 1:numel(optModes)
        optMode = optModes(o);

        % ---------------------------------------------------------------
        % Choose the base DB to work from:
        % - Global: use full cached DB (or reduced later)
        % - ImageDependent: preselect a subset of size M0 tailored to orig
        % ---------------------------------------------------------------
        if optMode == "Global"
            dbBase = db;
        else
            % select_db_for_original:
            %   - computes meanLab for each tile region in the original
            %   - scores each DB image by min distance to any original tile color
            %   - keeps the best M0 images
            dbBase = select_db_for_original(db, orig, tileSize, gridSize, M0);
        end

        % Loop over DB sizes
        for kIdx = 1:numel(Ks)
            K = Ks(kIdx);

            % -----------------------------------------------------------
            % Reduce dbBase to dbK of size K (if needed).
            % If K >= available images in dbBase, just use all.
            % -----------------------------------------------------------
            Nbase = size(dbBase.meanLab, 1);

            if verbose
                fprintf("OptMode=%s baseName=%s Nbase=%d K=%d\n", optMode, baseName, Nbase, K);
            end

            if K >= Nbase
                dbK = dbBase;
            else
                % reduce_db_fps keeps a diverse subset in Lab color space.
                % IMPORTANT: it must copy structFeat/structBins too.
                %fps = farthest point sampling
                dbK = reduce_db_fps(dbBase, K, 42);
            end

            % If we might run ColorStruct, ensure reduced DB has structure features
            if any(methods == "ColorStruct")
                assert(isfield(dbK,"structFeat") && isfield(dbK,"structBins"), ...
                    "dbK missing structFeat/structBins. Fix reduce_db_fps to copy them.");
            end

            % Loop over tile selection methods
            for m = 1:numel(methods)
                method = methods(m);

                % -------------------------------------------------------
                % Build mosaic + time it
                % -------------------------------------------------------
                t0 = tic;

                if method == "ColorOnly"
                    % build_mosaic:
                    % For each tile in orig -> choose DB image minimizing Lab distance
                    mosaic = build_mosaic(orig, dbK, tileSize, gridSize);
                else
                    % build_mosaic_color_structure:
                    % Two-stage: shortlist by color (Kc) -> choose by structure distance
                    mosaic = build_mosaic_color_structure(orig, dbK, tileSize, gridSize, Kc, wStruct);
                end

                buildTime = toc(t0);

                % -------------------------------------------------------
                % Save mosaic image
                % Filename encodes original + DB strategy + method + K
                % -------------------------------------------------------
                outPath = fullfile(outFolder, sprintf("mosaic_%s_%s_%s_K%d.png", baseName, optMode, method, K));
                imwrite(mosaic, outPath);

                % -------------------------------------------------------
                % Compute evaluation metrics
                % evaluate_metrics returns:
                %   PSNR, SSIM, S_CIELAB, MSE, DeltaEab
                % Note: orig is resized to mosaic size for fair comparison
                % -------------------------------------------------------
                origResized = imresize(orig, [size(mosaic,1) size(mosaic,2)]);
                M = evaluate_metrics(origResized, mosaic);

                % -------------------------------------------------------
                % Append one row to results table
                % -------------------------------------------------------
                row = table('Size',[1 10], ...
                    'VariableTypes', {'string','string','string','double','double','double','double','double','double','double'}, ...
                    'VariableNames', {'Original','OptMode','Method','K','BuildTime_s','PSNR','SSIM','S_CIELAB','MSE','DeltaEab'});

                row.Original    = origPath;
                row.OptMode     = optMode;
                row.Method      = method;
                row.K           = double(K);
                row.BuildTime_s = double(buildTime);

                row.PSNR     = double(M.PSNR);
                row.SSIM     = double(M.SSIM);
                row.S_CIELAB = double(M.S_CIELAB);
                row.MSE      = double(M.MSE);
                row.DeltaEab = double(M.DeltaEab);

                allRows = [allRows; row]; %#ok<AGROW>
            end
        end
    end
end

% ========================================================================
% Export metrics to CSV
% ========================================================================
metricsPath = fullfile(outFolder, "metrics_grade4_full_with_time.csv");
writetable(allRows, metricsPath);

disp(allRows);
fprintf("Wrote metrics to %s\n", metricsPath);

% ========================================================================
% Plot results (reads the CSV and saves plots into results/plots/)
% ========================================================================
plot_results;