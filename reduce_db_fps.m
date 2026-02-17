function dbSmall = reduce_db_fps(db, K, seed)
% Reduce DB to K representative images via farthest-point sampling (FPS)
% on mean Lab colors. Toolbox-free.
% IMPORTANT: also carries over structure features for betyg 4.

    if nargin < 3, seed = 42; end
    rng(seed);

    X = db.meanLab;            % [N x 3]
    N = size(X,1);
    assert(K <= N, "K must be <= number of DB images.");

    % Start from a random point
    first = randi(N);
    chosenIdx = zeros(K,1);
    chosenIdx(1) = first;

    % Track min distance to chosen set
    dmin = sum((X - X(first,:)).^2, 2);

    for t = 2:K
        [~, next] = max(dmin);
        chosenIdx(t) = next;

        dnew = sum((X - X(next,:)).^2, 2);
        dmin = min(dmin, dnew);
    end

    % Copy fields
    dbSmall.tiles   = db.tiles(:,:,:,chosenIdx);
    dbSmall.meanLab = db.meanLab(chosenIdx,:);
    dbSmall.files   = db.files(chosenIdx);

    % Carry structure features if present
    if isfield(db, "structFeat")
        dbSmall.structFeat = db.structFeat(chosenIdx, :);
    end
    if isfield(db, "structBins")
        dbSmall.structBins = db.structBins;
    end
end
