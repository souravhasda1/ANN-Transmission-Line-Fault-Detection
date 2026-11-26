function R=evaluate_dual_ann(M,D)
% Honest held-out WINDOW metrics; event timing is evaluated with replay_case.
ix=M.split.test; P=predict_dual_ann(M,D.X(:,ix));
y=logical(D.fault(ix)); yp=P.fault;
tp=sum(y & yp); tn=sum(~y & ~yp); fp=sum(~y & yp); fn=sum(y & ~yp);
R.detectionConfusion=[tn fp;fn tp];
R.accuracy=mean(y==yp); R.precision=tp/max(tp+fp,1);
R.recall=tp/max(tp+fn,1); R.falsePositiveRate=fp/max(fp+tn,1);
R.F1=2*R.precision*R.recall/max(R.precision+R.recall,eps);
stable=logical(D.jointValid(ix)); faultStable=stable & y;
R.exactFaultClassAccuracy=mean(P.classId(faultStable)==D.classId(ix(faultStable)));
R.bitAccuracy=mean(P.bits(:,faultStable)==D.bits(:,ix(faultStable)),2);
% All TRUE settled fault windows, including detector misses: do not cherry-pick.
e=P.distanceRawKm(faultStable)-D.distance(ix(faultStable));
ec=min(M.c.lineKm,max(0,P.distanceRawKm(faultStable)))-D.distance(ix(faultStable));
R.rawLocationRMSE=sqrt(mean(e.^2)); R.clippedLocationRMSE=sqrt(mean(ec.^2));
R.rawLocationMAE=mean(abs(e)); R.maxRawLocationError=max(abs(e));
R.locationCoverage=mean(P.fault(faultStable));
R.rawRMSEpercent=100*R.rawLocationRMSE/M.c.lineKm;
% Also report physically useful ABC/ABCG-merged score.
a=D.classId(ix(faultStable)); b=P.classId(faultStable);
a(a==12)=11; b(b==12)=11; R.mergedThreePhaseAccuracy=mean(a==b);
cm=zeros(12,13); % truth rows 1:12; predicted columns Unknown, Normal,...ABCG
for k=find(stable), cm(D.classId(ix(k)),P.classId(k)+1)=cm(D.classId(ix(k)),P.classId(k)+1)+1; end
R.classConfusion=cm; disp(R);
figure('Name','Held-out detection'); imagesc(R.detectionConfusion); colorbar;
xticks(1:2); yticks(1:2); xticklabels({'Normal','Fault'}); yticklabels({'Normal','Fault'});
xlabel('Predicted'); ylabel('True'); title('Test windows: detection counts');
figure('Name','Fault-only location'); scatter(D.distance(ix(faultStable)),P.distanceRawKm(faultStable),8,'.');
hold on; plot([0 M.c.lineKm],[0 M.c.lineKm],'k--'); grid on;
xlabel('True distance (km)'); ylabel('Raw predicted distance (km)');
title(sprintf('Held-out settled faults: RMSE %.3f km',R.rawLocationRMSE));
save('test_results.mat','R');
end
