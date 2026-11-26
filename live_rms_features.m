function [x,ready]=live_rms_features(v,i)
% Paste this function into a Simulink MATLAB Function block.
% Fixed R2024a baseline: Ts=50 us, f=50 Hz, VLL=11 kV, Sbase=1 MVA.
% Input v/i: three-element columns; output x: eight-element column.
% Call at EVERY 50 us electrical step. Zero-Order Hold afterward at 1 ms.
%#codegen
persistent hist total pos count
if isempty(hist)
    hist=zeros(8,400); total=zeros(8,1); pos=1; count=0;
end
v=v(:); i=i(:);
w=[v;i;sum(v)/3;sum(i)/3]; z=w.^2;
total=total-hist(:,pos)+z; hist(:,pos)=z;
pos=pos+1; if pos>400, pos=1; end
count=min(count+1,400);
base=[11000/sqrt(3)*ones(3,1);1e6/(sqrt(3)*11000)*ones(3,1); ...
      11000/sqrt(3);1e6/(sqrt(3)*11000)];
x=sqrt(max(total,0)/400)./base; ready=count>=400;
end
