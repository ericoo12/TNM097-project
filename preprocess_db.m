function db = preprocess_db(dbFolder, tileSize)
    files = dir(fullfile(dbFolder, "*.jpg"));
    N = numel(files);
    tileH = tileSize(1); tileW = tileSize(2);

    tiles = zeros(tileH, tileW, 3, N, "uint8");
    meanLab = zeros(N, 3);
    nBins = 16;
    structFeat = zeros(N, nBins);


    for i = 1:N
        I = imread(fullfile(files(i).folder, files(i).name));
        I = ensure_rgb_uint8(I);
        I = imresize(I, [tileH tileW]);

        tiles(:,:,:,i) = I;
        meanLab(i,:) = compute_mean_lab(I);
        structFeat(i,:) = compute_grad_hist_feat(I, nBins);

    end
    db.structFeat = structFeat;
    db.structBins = nBins;
    db.tiles = tiles;
    db.meanLab = meanLab;
    db.files = string({files.name}).';
end
