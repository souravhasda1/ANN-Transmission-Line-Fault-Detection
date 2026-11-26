function smoke_test()
% First gate: electrical sanity, feature dimension and no-fault zero sequence.
c=project_config(); S=make_scenarios(1,c);
normal=simulate_case(S(1,:),c);
fault=simulate_case(S(2,:),c);
[X,~,v]=extract_features(normal,c);
assert(size(X,1)==8 && all(isfinite(X(:))));
fprintf('Healthy median phase voltage pu: %s\n',mat2str(median(X(1:3,v),2),4));
fprintf('Healthy median zero sequence pu: %s\n',mat2str(median(X(7:8,v),2),4));
figure('Name','Electrical smoke test');
subplot(2,1,1); plot(normal.t,normal.V); grid on; ylabel('Healthy Vabc (V)');
subplot(2,1,2); plot(fault.t,fault.I); grid on; ylabel('AG Iabc (A)'); xlabel('Time (s)');
save('smoke_waveforms.mat','normal','fault');
disp('Inspect the waveforms before generating training data.');
end
