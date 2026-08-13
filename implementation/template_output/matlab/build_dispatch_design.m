function [X,names] = build_dispatch_design(cachePressure,dispatchEvent)
n = numel(dispatchEvent);
h1 = zeros(n,1); h2 = zeros(n,1); h3 = zeros(n,1);
for i = 1:n
    if i >= 2, h1(i) = dispatchEvent(i-1); end
    if i >= 3, h2(i) = sum(dispatchEvent(max(1,i-6):i-2)); end
    if i >= 8, h3(i) = sum(dispatchEvent(max(1,i-16):i-7)); end
end
X = [ones(n,1), cachePressure, h1, h2, h3];
names = ["intercept","cache_pressure","dispatch_5ms","dispatch_10_30ms","dispatch_35_80ms"];
end
