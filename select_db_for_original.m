function dbSel = select_db_for_original(db, orig, tileSize, gridSize, M)
% Pick M database images whose mean Lab are closest to the set of tile mean Labs
% in the current original image (image-dependent optimization).

    orig = ensure_rgb_uint8(orig);

    targetH = gridSize(1) * tileSize(1);
    targetW = gridSize(2) * tileSize(2);
    orig = imresize(orig, [targetH targetW]);

    tileH = tileSize(1); tileW = tileSize(2);
    T = gridSize(1) * gridSize(2);

    tileLab = zeros(T, 3);
    t = 1;
    for r = 1:gridSize(1)
        for c = 1:gridSize(2)
            y1 = (r-1)*tileH + 1; y2 = r*tileH;
            x1 = (c-1)*tileW + 1; x2 = c*tileW;
            patch = orig(y1:y2, x1:x2, :);
            tileLab(t,:) = compute_mean_lab(patch);
            t = t + 1;
        end
    end

    dbLab = db.meanLab;          % N x 3
    N = size(dbLab,1);

    M = min(M, N);               % clamp

    % Score each DB image by its closest distance to any tileLab
    scores = zeros(N,1);
    for i = 1:N
        d = tileLab - dbLab(i,:);
        scores(i) = min(sum(d.^2, 2));
    end

    [~, order] = sort(scores, 'ascend');
    idx = order(1:M);

    % Copy fields
    dbSel.tiles   = db.tiles(:,:,:,idx);
    dbSel.meanLab = db.meanLab(idx,:);
    dbSel.files   = db.files(idx);

    if isfield(db,"structFeat"), dbSel.structFeat = db.structFeat(idx,:); end
    if isfield(db,"structBins"), dbSel.structBins = db.structBins; end
end
