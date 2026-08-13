function value = poisson_deviance(y,mu)
term = zeros(size(y));
mask = y > 0;
term(mask) = y(mask).*log(y(mask)./mu(mask));
value = 2*sum(term-(y-mu));
end
