function f = compute_grad_hist_feat(rgbUint8, nBins)
% Gradient magnitude histogram feature (L1-normalized).
% rgbUint8: HxWx3 uint8
% f: 1 x nBins double

    if nargin < 2, nBins = 16; end

    I = im2double(ensure_rgb_uint8(rgbUint8));
    G = rgb2gray(I);

    % Sobel gradients
    Gx = imfilter(G, fspecial('sobel')'/8, 'replicate');
    Gy = imfilter(G, fspecial('sobel')/8,  'replicate');

    mag = hypot(Gx, Gy);  % gradient magnitude

    % Histogram (fixed range; gradients typically in [0, ~1])
    edges = linspace(0, 1, nBins+1);
    h = histcounts(mag(:), edges);

    f = double(h);
    s = sum(f);
    if s > 0
        f = f / s; % L1 normalize
    end
end
