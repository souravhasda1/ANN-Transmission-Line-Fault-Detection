function P=predict_dual_ann(M,X)
Z=(X-M.mu)./M.sigma;
P.score=M.det(Z); Y=M.joint(Z);
P.fault=P.score>=M.c.detectorThreshold;
P.bits=Y(1:4,:)>=M.c.bitThreshold;
P.classId=decode_fault(P.bits,M.c);
P.distanceRawKm=Y(5,:)*M.c.lineKm;
P.distanceKm=min(M.c.lineKm,max(0,P.distanceRawKm));
P.distanceKm(~P.fault)=NaN; % plot/report NaN; use separate valid flag in hardware
P.classId(~P.fault)=1;
P.classId(P.fault & P.classId==1)=0;
end
