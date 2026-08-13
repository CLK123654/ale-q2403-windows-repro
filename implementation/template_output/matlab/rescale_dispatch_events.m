function R = rescale_dispatch_events(dispatchEvent,mu)
eventBins = find(dispatchEvent>0);
previous = 0;
R = table('Size',[numel(eventBins),5], ...
    'VariableTypes',["double","double","double","double","double"], ...
    'VariableNames',["event_sequence","interval_start_bin","dispatch_bin","integrated_hazard","z_uniform"]);
for k = 1:numel(eventBins)
    current = eventBins(k);
    integrated = sum(mu(previous+1:current));
    R{k,:} = [k,previous+1,current,integrated,1-exp(-integrated)];
    previous = current;
end
end
