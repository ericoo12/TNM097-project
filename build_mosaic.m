function mosaic = build_mosaic(orig, db, tileSize, gridSize)
    orig = ensure_rgb_uint8(orig);

    targetH = gridSize(1) * tileSize(1);
    targetW = gridSize(2) * tileSize(2);
    orig = imresize(orig, [targetH targetW]);

    tileH = tileSize(1); tileW = tileSize(2);
    mosaic = zeros(targetH, targetW, 3, "uint8");

    for r = 1:gridSize(1)
        for c = 1:gridSize(2)
            y1 = (r-1)*tileH + 1; y2 = r*tileH;
            x1 = (c-1)*tileW + 1; x2 = c*tileW;

            patch = orig(y1:y2, x1:x2, :);
            patchLab = compute_mean_lab(patch);

            d = db.meanLab - patchLab;
            [~, idx] = min(sum(d.^2,2));

            mosaic(y1:y2, x1:x2, :) = db.tiles(:,:,:,idx);
        end
    end
end
