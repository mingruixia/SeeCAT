function P = poly_trend(T, order)
% POLY_TREND  Constant and Legendre polynomial trends up to ORDER.
%   P = seecat.denoise.poly_trend(T, order)    % T x (order+1)
%
% Legendre polynomials on [-1, 1] are close to orthogonal, so the fit is
% well conditioned for any series length.

x = linspace(-1, 1, T)';
P = ones(T, order + 1);
for k = 1:order
    L = legendre(k, x');
    P(:, k + 1) = L(1, :)';
end
end
