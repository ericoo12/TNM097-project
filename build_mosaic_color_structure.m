function mosaic = build_mosaic_color_structure(orig, db, tileSize, gridSize, Kc, wStruct)
% Two-stage selection:
% 1) shortlist Kc candidates by Lab mean distance
% 2) choose best by structure distance (gradient hist)
%
% Kc: shortlist size (e.g., 10 or 20)
% wStruct: weight for structure term (e.g., 0.5). Color term is always included.

    if nargin < 5, Kc = 15; end
    if nargin < 6, wStruct = 0.5; end

    orig = ensure_rgb_uint8(orig);

    targetH = gridSize(1) * tileSize(1);
    targetW = gridSize(2) * tileSize(2);
    orig = imresize(orig, [targetH targetW]);

    tileH = tileSize(1); tileW = tileSize(2);
    mosaic = zeros(targetH, targetW, 3, "uint8");

    dbLab = db.meanLab;                 % [N x 3]
    dbFeat = db.structFeat;             % [N x B]
    nBins = db.structBins;

    for r = 1:gridSize(1)
        for c = 1:gridSize(2)
            y1 = (r-1)*tileH + 1; y2 = r*tileH;
            x1 = (c-1)*tileW + 1; x2 = c*tileW;

            patch = orig(y1:y2, x1:x2, :);

            % --- Color distance (Lab mean) ---
            patchLab = compute_mean_lab(patch);     % 1x3
            dC = dbLab - patchLab;                  % Nx3
            distColor = sum(dC.^2, 2);              % Nx1

            % shortlist Kc best by color
            [~, order] = sort(distColor, 'ascend');
            cand = order(1:min(Kc, numel(order)));

            % --- Structure feature distance ---
            patchFeat = compute_grad_hist_feat(patch, nBins); % 1xB
            dS = dbFeat(cand,:) - patchFeat;                 % Kc x B
            distStruct = sum(dS.^2, 2);                      % Kc x 1

            % Combine (normalize color within candidates to comparable scale)
            cNorm = distColor(cand);
            cNorm = (cNorm - min(cNorm)) / (max(cNorm) - min(cNorm) + eps);

            score = cNorm + wStruct * distStruct;
            [~, j] = min(score);

            idx = cand(j);
            mosaic(y1:y2, x1:x2, :) = db.tiles(:,:,:,idx);
        end
    end
end
