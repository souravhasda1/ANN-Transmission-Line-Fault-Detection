function y = electrical_relay_live(u)
% Interpreted MATLAB Fcn adapter. u = [time; Vabc; Iabc].
% Called at 50 us; RMS updated each sample and ANN evaluated at 1 ms.
% Educational Normal-mode simulation only, not generated relay code.
persistent lastTick lastY
if isempty(lastTick)
    lastTick=-1; lastY=zeros(5,1);
end
u=u(:);
if numel(u)~=7
    error('Electrical relay expects [time; Va; Vb; Vc; Ia; Ib; Ic].');
end
t=u(1); tick=round(t/50e-6);
if tick==lastTick
    y=lastY; return
end
[x,ready]=live_rms_features(u(2:4),u(5:7));
if ready && mod(tick,20)==0
    lastY=relay_block([t;x]);
end
lastTick=tick;
y=lastY;
end
