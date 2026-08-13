function [beta,iterations,converged] = fit_poisson_irls(X,y,dt,lambda,maxIter,tolerance,etaClip)
beta = zeros(size(X,2),1);
beta(1) = log(max(mean(y)/dt,1e-9));
penalty = eye(size(X,2)); penalty(1,1) = 0;
converged = false;
for iterations = 1:maxIter
    eta = min(max(X*beta + log(dt),etaClip(1)),etaClip(2));
    mu = exp(eta);
    weight = max(mu,1e-10);
    working = eta + (y-mu)./weight - log(dt);
    updated = (X'*(weight.*X) + lambda*penalty) \ (X'*(weight.*working));
    if max(abs(updated-beta)) < tolerance
        beta = updated; converged = true; return
    end
    beta = updated;
end
end
