function c = project_config()
% R2024a educational study; proposed values are identified in the guide.
c.model = 'ann_transmission_line';
c.f0 = 50;
c.Ts = 50e-6;                 % electrical time step: 20 kHz
c.featureStep = 1e-3;         % ANN update: 1 kHz
c.window = round(1/c.f0/c.Ts); % one causal cycle: 400 samples
c.stopTime = 0.26;
c.VLL = 11e3;
c.Sbase = 1e6;
c.Ssc = 30e6;
c.XR = 0.01;                 % exactly as stated in supplied PDF
c.lineKm = 10;
c.r = [0.01273 0.3864];       % [positive zero] ohm/km
c.l = [0.9337e-3 4.1264e-3];  % H/km
c.cap = [12.74e-9 7.751e-9];  % F/km; assumed SPS defaults, not in PDF
c.loadP = 0.8e6;
c.loadQ = 0.3e6;
c.Vbase = c.VLL/sqrt(3);      % phase-to-neutral RMS
c.Ibase = c.Sbase/(sqrt(3)*c.VLL);
c.blankTime = 0.04;
c.detectorThreshold = 0.5;    % validate; PDF used 0.1
c.bitThreshold = 0.5;
c.confirmSamples = 3;        % 3 ANN updates, NOT 3 electrical steps
c.classConfirmSamples = 3;
c.seed = 2026;
c.classes = {'Normal','AG','BG','CG','AB','AC','BC', ...
             'ABG','ACG','BCG','ABC','ABCG'};
c.bits = [0 0 0 0; 1 0 0 1; 0 1 0 1; 0 0 1 1; ...
          1 1 0 0; 1 0 1 0; 0 1 1 0; 1 1 0 1; ...
          1 0 1 1; 0 1 1 1; 1 1 1 0; 1 1 1 1];
end
