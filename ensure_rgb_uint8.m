function I = ensure_rgb_uint8(I)
    if ndims(I) == 2, I = repmat(I,1,1,3); end
    if size(I,3) > 3, I = I(:,:,1:3); end
    if ~isa(I,"uint8"), I = im2uint8(I); end
end
