# ANN-based transmission-line fault detection in MATLAB R2024a

## What you will build

You will build a three-phase electrical system in Simulink, generate healthy and faulted voltage/current waveforms, turn them into eight numerical features, train two artificial neural networks (ANNs), and evaluate their decisions on simulations they have not seen during training.

The supplied reference is a 16-page presentation titled **Dual Artificial-Neural-Network Protection for Transmission-Line Faults**. It describes an 11 kV, 10 km system with two networks. ANN-2 detects a fault; ANN-1 outputs four phase/ground bits and a distance. This package follows that architecture. It is a reproducible teaching implementation, not an exact reproduction of the presentation's original experiment: the original SLX model, training data, trained weights, feature-processing definition and several electrical parameters were not supplied.

The main objective of your project is detection. Classification and location are valuable extensions, and are included because the reference includes them. Build and understand detection before attempting to optimize the other outputs.

An 11 kV radial feeder is usually described as a distribution-level system. Retain the reference's title if required by your project, but accurately describe your simulated voltage level. Results on this feeder do not automatically establish performance on a long, high-voltage transmission line.

### The learning path

1. Understand balanced three-phase operation and faults.
2. Build and verify the electrical network without any ANN.
3. Generate independent scenarios and save the waveforms.
4. Extract the same causal features for training and inference.
5. Split complete scenarios into training, validation and testing groups.
6. Train the detector, then the classifier/locator.
7. Evaluate accuracy, false alarms, distance error and event delay.
8. Replay the trained networks in Simulink.
9. Extend to live features, breaker logic and difficult unseen conditions.

Do not start by pressing Train in a neural-network app. A network trained on incorrect physical data can produce a beautiful training plot and still be useless.

## 1. Basic electrical concepts

### 1.1 Voltage, current, line voltage and phase voltage

Voltage drives current through an impedance. In sinusoidal AC, impedance combines resistance and reactance: `Z = R + jX`. Resistance dissipates real power; inductance and capacitance store and return energy.

A balanced three-phase source has equal phase voltage magnitudes separated by 120 electrical degrees. For the positive A-B-C sequence, use phase angles 0, -120 and +120 degrees. In a star-connected balanced system, `Vphase,rms = VLL,rms/sqrt(3)`. Thus an 11 kV line-to-line source has approximately 6.351 kV phase-to-neutral RMS and 8.981 kV phase-voltage peak. Do not enter 11 kV as the phase-to-neutral RMS value when the block expects line-to-line RMS.

RMS is the equivalent DC value for heating in a resistor. A sinusoid's RMS value is its peak divided by sqrt(2). A sampled waveform window has `RMS(x) = sqrt(mean(x.^2))`.

### 1.2 Frequency and sampling

At 50 Hz, one cycle lasts 20 ms. With the proposed electrical step of 50 microseconds, there are 400 samples per cycle. The ANN does not need a new decision every electrical step: this implementation updates it every 1 ms. These are two separate clocks:

| Quantity | Setting | Meaning |
|---|---:|---|
| Electrical step | 50 microseconds | Time resolution for the circuit and waveform samples |
| Feature window | 20 ms | Past samples contributing to one RMS feature |
| ANN update | 1 ms | Time between consecutive feature vectors and decisions |
| Detector persistence | 3 ANN updates | Three consecutive positive decisions required |

Three positive updates span 2 ms from the first to the third update. Measured total delay also includes the time to the first update, feature response and ANN response. Do not call this a guaranteed 3 ms total detection time.

### 1.3 Real, reactive and apparent power

For a balanced load, `S = sqrt(3)*VLL*Iline`. Real power P is measured in watts; reactive power Q in var; apparent power magnitude is `sqrt(P^2+Q^2)`. Power factor is `P/|S|`.

The proposed load is P = 0.8 MW and Q = 0.3 Mvar, so |S| is approximately 0.854 MVA and power factor is approximately 0.936 lagging. This is below the 1 MVA transformer rating at nominal voltage. The Parallel RLC Load is a constant-impedance load: actual power falls when its voltage falls. Its P and Q entries describe consumption at its nominal voltage, not a controller that forces constant power.

### 1.4 What a fault does

A short-circuit fault creates an unintended current path. At the measurement point, current often increases and voltage often falls, but the amount depends on fault resistance, source strength, distance and grounding. Not every fault produces an enormous current: high-resistance earth faults can be difficult to separate from normal changes.

Fault resistance limits fault current. The SPS fault block has a resistance in each selected phase branch and a separate common grounding resistance. For AG, the path includes both branch resistance Rf and ground resistance Rg. For an AB fault, the phase-to-phase path includes two phase-branch resistances. Do not treat the entered Rf as the entire loop resistance in every fault type.

### 1.5 Fault classes and target bits

In the target vector `[A B C G]`, a one indicates that a phase or ground is involved. G is a label of the simulated topology; it is not a fourth phase measurement.

| ID | Class | Physical connection | A | B | C | G |
|---:|---|---|---:|---:|---:|---:|
| 1 | Normal | No short circuit | 0 | 0 | 0 | 0 |
| 2 | AG | A to ground | 1 | 0 | 0 | 1 |
| 3 | BG | B to ground | 0 | 1 | 0 | 1 |
| 4 | CG | C to ground | 0 | 0 | 1 | 1 |
| 5 | AB | A to B | 1 | 1 | 0 | 0 |
| 6 | AC | A to C | 1 | 0 | 1 | 0 |
| 7 | BC | B to C | 0 | 1 | 1 | 0 |
| 8 | ABG | A and B to ground | 1 | 1 | 0 | 1 |
| 9 | ACG | A and C to ground | 1 | 0 | 1 | 1 |
| 10 | BCG | B and C to ground | 0 | 1 | 1 | 1 |
| 11 | ABC | Three-phase short circuit | 1 | 1 | 1 | 0 |
| 12 | ABCG | Three-phase short circuit with ground connection | 1 | 1 | 1 | 1 |

ID 0 is reserved for Unknown: an invalid or not-yet-confirmed network output. For example `[1 0 0 0]` is not one of the short-circuit classes above. Do not automatically force an invalid bit combination to the nearest named class.

### 1.6 Symmetrical components and zero sequence

An unbalanced three-phase phasor set can be decomposed into positive, negative and zero sequence. Positive sequence has normal A-B-C rotation; negative sequence has reverse rotation; zero sequence consists of three in-phase components.

With `a = exp(j*2*pi/3)`:

```
V0 = (Va + Vb + Vc)/3
V1 = (Va + a*Vb + a^2*Vc)/3
V2 = (Va + a^2*Vb + a*Vc)/3
```

The same equations apply to current phasors. For instantaneous waveforms, `v0(t) = (va(t)+vb(t)+vc(t))/3` also gives the instantaneous zero-sequence component. This package computes its windowed RMS magnitude. Compute the sum BEFORE RMS: the average of three phase RMS magnitudes is not zero-sequence voltage.

In ideal balanced operation, the instantaneous phase sum is zero. Many ground faults produce nonzero residual current `Ia+Ib+Ic = 3*I0`, provided the system has a ground-return path. An ungrounded line-to-line fault normally has negligible zero-sequence current. Grounding configuration therefore changes the features and must be part of the physical model.

**Important physical limitation:** a perfectly balanced ABCG fault can have zero ground current, because three equal phase currents sum to zero. A symmetrical ABC short circuit can then produce effectively the same one-end measurements. No ANN can reliably infer a hidden ground connection from identical inputs. The reference's ABCG-to-ABC errors may reflect this observability limitation, not merely insufficient training. Preserve the 12 labels for comparison, but also report a score merging ABC and ABCG into a single three-phase-fault class. The supplied evaluation code does both.

## 2. From the reference to an explicit model

### 2.1 Parameter provenance

| Parameter | Value used | Basis |
|---|---|---|
| Nominal voltage | 11 kV line-to-line RMS | PDF pp. 4-5 |
| Frequency | 50 Hz | PDF p. 4 |
| Source short-circuit power | 30 MVA baseline | PDF p. 4 |
| Source X/R | 0.01 baseline | PDF pp. 4-5; unusually resistive, verify if intended |
| Protected line | 10 km | PDF p. 4 |
| Positive-sequence R | 0.01273 ohm/km | PDF p. 5 |
| Zero-sequence R | 0.3864 ohm/km | PDF p. 5 |
| Positive-sequence L | 0.9337 mH/km | PDF p. 5 |
| Zero-sequence L | 4.1264 mH/km | PDF p. 5 |
| Positive/zero C | 12.74 / 7.751 nF/km | Proposed: installed R2024a PI-line defaults; absent from PDF |
| Transformer | 1 MVA, 11/0.4 kV | PDF p. 4 |
| Transformer winding connection | Yg/Yg | Proposed; not established by PDF text |
| Each winding resistance/reactance | 0.005 / 0.025 pu | Proposed teaching values |
| Magnetizing R/L | 500 / 500 pu | Proposed linear transformer values |
| Transformer saturation | Off | Proposed baseline; add for inrush challenge later |
| Load P/Q | 0.8 MW / 0.3 Mvar | Proposed |
| Load nominal voltage | 400 V line-to-line | Correct secondary-bus setting; PDF p. 13 identifies old 1 kV mismatch |
| Electrical sample time | 50 microseconds | Proposed |
| Feature definition | One-cycle causal RMS, eight inputs | Explicit implementation choice; PDF does not fully specify preprocessing |

Do not state that the proposed values came from the paper. Record changes in your report, because capacitance, grounding and transformer impedance influence faults.

### 2.2 Source impedance calculation

For a three-phase short-circuit MVA specified at the nominal voltage, the positive-sequence Thevenin impedance magnitude is `|Zs| = VLL^2/Ssc`.

For 11 kV and 30 MVA, |Zs| = 4.0333 ohm. If `k = X/R = 0.01`, then:

```
Rs = |Zs|/sqrt(1+k^2)       approximately 4.0331 ohm
Xs = k*Rs                 approximately 0.04033 ohm
Ls = Xs/(2*pi*50)          approximately 0.1284 mH
```

The model enters R and L directly, avoiding ambiguity about the source block's short-circuit specification switch. A small X/R is not typical of many inductive grid equivalents; retain it for reference alignment, then test a justified alternative separately. Do not silently replace 0.01 with 10 and call it a reproduction.

### 2.3 PI line and fault location

A PI-section line has series R and L with shunt capacitance divided between its ends. The R/L/C values are specified per kilometre in the SPS block, and the block applies the Length parameter. Do not multiply them by the line length and also enter the length: that counts length twice.

Split the 10 km line into two parts around the fault node. For a fault d kilometres from the sending end, set Line1 length to d and Line2 length to 10-d. Connect the fault block as a SHUNT branch at the junction. Normal through-current must continue through Line1 and Line2; the fault block is not inserted in series.

For example, a 3 km fault uses 3 km + 7 km. The default scenario generator samples 0.5-9.5 km, avoiding zero-length sections. A true 10 km terminal fault should be implemented directly at the receiving terminal, with no artificial zero-length line. The reference's 1/5/10 km labels are not all used as the only training locations; independent continuous distances are more informative.

## 3. MATLAB setup and first model

### 3.1 Required software

Use MATLAB R2024a, Simulink, Simscape and Simscape Electrical, plus Deep Learning Toolbox. The default code does not require Statistics and Machine Learning Toolbox, DSP System Toolbox or Parallel Computing Toolbox. The rolling RMS uses base MATLAB operations. Parallel simulation is optional later.

Run:

```matlab
version
ver
which feedforwardnet -all
which spsThreePhaseSourceLib -all
```

This package intentionally uses the Specialized Power Systems (SPS) blocks available in R2024a. Do not mix their electrical ports with native Simscape conserving ports. SPS uses powergui; native Simscape networks use Solver Configuration and Electrical Reference. MathWorks removed the bundled SPS library in R2026a, so instructions for new releases differ.

### 3.2 Use the supplied files

Extract the ZIP into a folder you can write to, and set that folder as MATLAB's Current Folder. Start with:

```matlab
c = project_config;
test_feature_math
build_power_model(c)     % only if ann_transmission_line.slx is absent
smoke_test
```

The builder deliberately refuses to overwrite an existing model or close unsaved work. If the package already contains the built SLX model, open it and run smoke_test without rebuilding. To rebuild after intentional edits to configuration, save your existing model under another name first.

### 3.3 How to build the circuit manually

Even when using the builder, perform this once so you understand the model.

1. In MATLAB type `simulink`, create a blank model and save it as `ann_transmission_line.slx`.
2. Add **powergui** from Simscape > Electrical > Specialized Power Systems. Set Simulation type to Discrete and sample time to `50e-6`.
3. Add **Three-Phase Source**. Choose grounded-star Yg, 11,000 V line-to-line RMS, 50 Hz, phase angle 0, non-ideal source enabled. Specify R = 4.0331 ohm and L = 0.0001284 H directly.
4. Add **Three-Phase V-I Measurement** at the sending end, between the source and Line1. Choose phase-to-ground voltages and current measurement. Turn off per-unit output so the logging receives volts and amperes.
5. Add two **Three-Phase PI Section Line** blocks. Set both to 50 Hz and the R/L/C pairs from the parameter table. Initially use 5 km each.
6. Add **Three-Phase Fault** as a branch at the Line1-Line2 junction. Initially select A and Ground only. Initial status is 0, external control is off, switching times are `[0.1 0.3]`, branch resistance is 0.1 ohm and ground resistance is 0.1 ohm.
7. Add **Three-Phase Transformer (Two Windings)** after Line2. Use the ratings and proposed per-unit winding values in the table. Select linear, nonsaturating operation initially.
8. Add **Three-Phase Parallel RLC Load** after the transformer. Use grounded star, 400 V nominal, 50 Hz, P = 800000 W, inductive Q = 300000 var and capacitive Q = 0.
9. Wire A to A, B to B and C to C throughout. Source -> measurement -> Line1 -> Line2 -> transformer -> load. Branch the fault at the line junction.
10. Connect the measurement's voltage and current output vectors to two **To Workspace** blocks. Set Variable names to `Vabc` and `Iabc`, format to Timeseries, decimation to 1 and unlimited saved points.
11. In Model Settings > Solver choose Fixed-step and discrete, step size `50e-6`; stop time `0.26`. Enable Single simulation output / ReturnWorkspaceOutputs.
12. Run once and inspect the phase waveforms. The first test keeps the fault on after it starts; its off command at 0.3 s is beyond the 0.26 s stop time.

Keep the exact block names Source, Measure, Line1, Line2, Fault, Transformer and Load if using the automation scripts. The script changes parameters by these paths.

### 3.4 What to verify before training

In a healthy run, phase voltages should be balanced, the current should have a sensible magnitude and lag for the inductive load, and zero-sequence quantities should be nearly zero after startup. Receiving voltage can be below the nominal value due to source, line and transformer drops. Do not require every measured phase RMS to be exactly 1 pu under load.

For AG, check that phase A current and phase-to-ground voltage change as expected; residual current should respond. For AB, check A and B and comparatively small zero sequence. For ABC, expect approximately balanced phase disturbances. Look at the fault node as well as the sending-end voltage if a voltage change seems unexpectedly small.

Resolve incorrect phase order, grounding, units and fault-switch settings now. Neural-network tuning cannot repair a miswired circuit.

## 4. Features: turning waveforms into useful ANN inputs

### 4.1 The eight inputs

The reference lists `Va,Vb,Vc,Ia,Ib,Ic,|V0|,|I0|` without enough detail to reproduce its exact signal conditioning. This implementation explicitly uses:

```
x = [RMS(va), RMS(vb), RMS(vc), RMS(ia), RMS(ib), RMS(ic),
     RMS((va+vb+vc)/3), RMS((ia+ib+ic)/3)]'
```

All RMS quantities use the last 400 waveform samples, including the current sample. A one-cycle window is stable and easy to understand. It smooths transients and sacrifices some temporal detail, so the presentation's reported 3-5 ms delay cannot simply be assumed for this new implementation.

The first 399 samples lack a full window. The code ignores feature decisions before a 40 ms startup blanking interval. Startup blanking is a simulation baseline, not proof of secure operation after every energization or reclose.

### 4.2 Per-unit and standardization

Use phase RMS base voltage `11000/sqrt(3) = 6350.85 V` and current base `1e6/(sqrt(3)*11000) = 52.49 A`. Divide phase and zero-sequence voltages by the voltage base, and currents by the current base. Thus a 104.98 A phase RMS current is 2 pu.

Then standardize each feature using training-set statistics only: `z = (x-mu)/sigma`. These two stages have different purposes. Per-unit expresses physical quantities relative to system ratings. Standardization helps the numerical optimizer balance feature scales. Store mu and sigma with the trained networks; never recompute them separately on test data or during live inference.

For shallow MATLAB networks, each sample is a COLUMN. Thus X is 8-by-N, detector targets are 1-by-N and joint targets are 5-by-N. This differs from some modern tabular learning interfaces that use observations as rows.

### 4.3 Causal filtering

A protective decision at time t must depend only on data available at or before t. The code uses `filter` with a trailing rectangular window. A centred moving average or `filtfilt` can accidentally use future samples and make offline detection look unrealistically fast. `test_feature_math` checks that modifying future voltage samples does not change earlier features.

The rolling RMS includes DC offset and harmonics. It is not the same as a fundamental-frequency phasor magnitude. If you change to a DFT estimator, wavelets or another filter, regenerate the training data and retrain; do not swap preprocessing only in Simulink.

## 5. Generate a trustworthy dataset

### 5.1 One row of settings is one independent scenario

Each scenario specifies fault class, distance, phase-branch resistance, ground resistance, inception time, source phase, source short-circuit level and load scale. The simulator produces thousands of waveform samples; the extractor supplies many overlapping feature windows. Those windows are highly correlated and are not independent experiments.

The presentation expands only 36 distinct patterns into 360 repeated rows and then randomly divides rows. Identical patterns can land in training and testing. This package instead splits entire scenario IDs: no window from a held-out simulation enters training.

Do not take one AG simulation, copy it ten times and describe it as ten independent AG cases. If you add noise to one waveform, keep every noisy copy in the same split as its source waveform.

### 5.2 Proposed scenario ranges

| Quantity | Default range | Why vary it? |
|---|---|---|
| Fault class | 12 classes including healthy | Learn phase patterns and normal operation |
| Distance | 0.5-9.5 km, continuous | Learn more than three memorized positions |
| Phase-branch resistance | Approximately 0.01-5 ohm, log sampled | Cover stronger and weaker faults |
| Ground resistance | 0.01-10 ohm, log sampled | Vary residual signals |
| Inception time | 0.10-0.12 s | Change the point on the waveform |
| Source phase | -180 to +180 degrees | Vary inception angle and startup phase |
| Load multiplier | 0.5-1.0 | Avoid one fixed operating point |
| Short-circuit MVA | 24-36 MVA | Change source strength |

Fault inception angle is the waveform phase at fault application, not just a time in seconds. Relative to the source sine convention it depends on both phase setting and `360*f*tOn`; changing time by a whole cycle leaves the angle unchanged.

Start with 10 scenarios per class (120 simulations) as a pipeline check. For a first study use at least 80 per class (960 simulations), then assess whether validation performance stabilizes with more data. These are suggested starting sizes, not guarantees of sufficient coverage.

### 5.3 Commands

```matlab
c = project_config;
S = make_scenarios(10,c);
D = generate_dataset(S,c,'data_pilot');
```

Each raw scenario is saved individually. If interrupted, rerun with the identical S, configuration and folder. A manifest prevents silently reusing old data under new settings. For a larger study use a new folder:

```matlab
S = make_scenarios(80,c);
D = generate_dataset(S,c,'data_study');
```

The detector receives healthy and onset/settled fault windows. The joint network trains on healthy windows and fully post-fault windows; it excludes the first full cycle after inception because class/location targets are ambiguous in a mixed healthy/fault window. This means classification has not been trained to be reliable in the earliest transient. Confirmation logic and timing tests are still required.

Healthy distance targets are stored numerically as zero only to keep arrays finite. Their location loss weights are zero. They are not presented as a true 0 km fault.

### 5.4 Dataset structure

| Field | Shape | Meaning |
|---|---|---|
| D.X | 8-by-N | Per-unit features before standardization |
| D.bits | 4-by-N | A/B/C/G labels |
| D.fault | 1-by-N | Healthy 0 or fault 1 |
| D.distance | 1-by-N | Distance in km; placeholder 0 for healthy |
| D.group | 1-by-N | Parent scenario ID |
| D.classId | 1-by-N | Class label for this window |
| D.jointValid | 1-by-N | Whether to use this window for joint-network fitting/evaluation |
| D.time | 1-by-N | Time at the end of the feature window |

## 6. Understand and train the neural networks

### 6.1 What one neuron does

A neuron multiplies its inputs by weights, adds a bias and applies a nonlinear activation: `a = f(W*x+b)`. Weights control the contribution of each input; biases shift decision boundaries. A hidden layer combines several neurons so the network can learn relationships that a single threshold cannot express.

Training changes weights to reduce a loss measured against known targets. It does not discover the correct labels for you. The simulation settings supply the ground truth.

### 6.2 The two architectures

ANN-2 is **8 -> 20 -> 10 -> 1**. Its output is a scalar fault score. ANN-1 is **8 -> 20 -> 10 -> 5**. Its outputs are `[A B C G d/L]`. For a BG fault 5 km along this 10 km line, ANN-2 target is 1 and ANN-1 target is `[0 1 0 1 0.5]`.

The hidden layers use `tansig`, which maps activations into approximately -1 to 1. Outputs are linear (`purelin`) to retain the small feedforward, MSE-based reference approach. Therefore bit and detection outputs can be slightly below 0 or above 1: they are SCORES, not calibrated probabilities. The distance output is normalized by line length so kilometre values do not dominate the binary-target loss.

Twenty and ten hidden neurons are starting architecture choices from the reference, not an optimal universal design. Larger networks can overfit a small dataset. Increase data quality before increasing layer sizes.

### 6.3 Loss and Levenberg-Marquardt

Mean squared error averages `(target-prediction)^2`. Levenberg-Marquardt (`trainlm`) uses information about the residual Jacobian to adjust weights; conceptually it moves between a cautious gradient-like step and a local least-squares step. A typical update is proportional to `-(J'*J + mu*I)\(J'*e)`. Here mu is the optimizer damping parameter, unrelated to the feature mean called mu in code.

LM is effective for small dense networks but can consume substantial memory as the number of samples grows. Use fewer representative windows per scenario, train in manageable experiments, or move to `trainscg`/modern minibatch training when needed. Do not solve memory limitations by throwing away all challenging operating conditions.

The joint loss ignores location on healthy rows. Phase/ground bit losses still apply on healthy rows, whose four bits should be zero. The detector uses class weights calculated from training data to reduce the effect of healthy/fault window imbalance.

### 6.4 Training, validation and test roles

Training updates weights. Validation chooses when to stop and selects the detector threshold. Testing is reserved for final assessment. The code creates roughly 70/15/15 splits by scenario within each class; integer rounding means the pilot split is not exactly these percentages.

`divideind` applies explicit indices. Default preprocessing is disabled because the code standardizes from the training subset itself. Validation can stop training after 12 consecutive validation failures. Test indices are not used by `train` at all.

Run:

```matlab
M = train_dual_ann(D);
R = evaluate_dual_ann(M,D);
```

The detector threshold is selected from 0.05 to 0.95 using validation balanced accuracy. The reference's 0.1 is not a universal threshold. A real protection objective may prioritize false-trip probability or missed-fault cost rather than balanced accuracy; select that operating point using validation, then freeze it before testing. The bit threshold remains 0.5 in this baseline.

### 6.5 Avoid common training misunderstandings

Low training MSE does not establish good fault protection. A high regression correlation across mixed bit/distance outputs is not a substitute for class accuracy or kilometre error. Repeatedly tuning against the final test set converts it into another validation set. Keep a separate challenge set for the final report.

The electrical ANN should also be compared with simple baselines, such as a tuned overcurrent detector using the same held-out scenarios. If the ANN cannot improve a relevant metric, explain why instead of hiding the comparison.

## 7. Testing and results you should report

### 7.1 Detection

A true positive is a fault window correctly detected; false negative is a missed fault. A false positive is a healthy window incorrectly flagged; true negative is correctly healthy.

```
Accuracy  = (TP+TN)/(TP+TN+FP+FN)
Precision = TP/(TP+FP)
Recall    = TP/(TP+FN)
F1        = 2*Precision*Recall/(Precision+Recall)
FPR       = FP/(FP+TN)
```

Always show the class counts. A detector predicting Normal on a dataset containing 99% healthy rows has 99% accuracy and detects no faults.

### 7.2 Classification

Report exact four-bit or exact class correctness, not only average bit accuracy. Three correct phase bits plus a wrong G bit still give the wrong exact class. The code includes Unknown predictions in the confusion matrix and reports a separate ABC/ABCG-merged score. Report exact fault-class accuracy on true settled fault windows, including detector misses, so detector failures cannot disappear from the classification result.

### 7.3 Location

For true faults, `error = predicted distance - true distance`:

```
MAE  = mean(abs(error))
RMSE = sqrt(mean(error.^2))
Normalized RMSE (%) = 100*RMSE/line length
```

For example 0.2 km RMSE on a 10 km line is 2% of line length. Report the raw network RMSE, bounded-output RMSE, maximum error and the percentage of true fault windows for which a location was actually issued. Clipping a wildly wrong prediction to 0-10 km can make the operational display sensible while concealing a weak regressor; show both raw and clipped error.

Do not assign healthy samples a 1/5/10 km truth. A healthy line has no fault distance. The code evaluates location only on true settled faults and does not exclude misses just because the detector failed to issue a location.

### 7.4 Timing is an event-level measure

Replay full held-out waveforms with `replay_case`. Detection delay is the first valid trip time minus fault inception time. A trip that was already latched before the fault is a false trip, not a zero-delay success. The code marks that event's detection delay NaN.

Also measure classification settling time, location settling time, false-trip events per healthy simulation and missed-fault events. Set a location tolerance, for example 0.5 km, before measuring settling. A useful settling definition is first time the output stays within tolerance for the next full cycle. State that this is an offline evaluation criterion, not a filter used to make the online decision. Run `E = evaluate_events(M,'data_pilot',0.5)` to save heldout_event_results.csv with these event measures. NaN means that a valid result was not established in the observed interval; report the coverage/missing count, not just the mean of successful cases.

Window accuracy does not equal event accuracy because many neighbouring windows belong to the same event. Give both, and estimate confidence intervals by resampling whole scenarios, not individual overlapping windows.

### 7.5 Do not copy the presentation's results as your results

The reference reports 100% internal detector accuracy, 91.67% overall exact classification and 0.123 km fault-only RMSE. It explicitly cautions that repeated patterns undermine generalization claims. Those numbers describe its supplied dataset, not this implementation. Your measured results may be lower and more defensible because the testing is harder and preprocessing differs.

## 8. Put the trained ANN into Simulink

### 8.1 First: causal feature replay

Use one held-out raw case:

```matlab
id = M.split.testGroups(end);
tmp = load(fullfile('data_pilot',sprintf('case_%05d.mat',id)),'raw');
replay_case(M,tmp.raw);
build_relay_demo(M,tmp.raw); % once; refuses to overwrite an existing demo
out = sim('ann_relay_replay');
```

`build_relay_demo` creates a From Workspace feature source, a 1 ms digital clock, an Interpreted MATLAB Fcn block and a logged result vector. Features were computed causally from a complete recorded waveform: every row still uses only its own past samples. This is an offline playback demonstration, not a closed-loop electrical protection model.

The five outputs are `[trip, classID, distanceKm, locationValid, detectorScore]`. If locationValid is zero, the distance value is a placeholder and must not be displayed as an actual fault at 0 km.

`relayFeatures` must exist in the base workspace when opening the replay model. Regenerate it with:

```matlab
[X,t] = extract_features(tmp.raw,M.c);
relayFeatures = timeseries(X',t');
clear relay_block
out = sim('ann_relay_replay');
```

The trained MAT file must be in the current folder/on the path. Clear `relay_block` after retraining so its persistent copy reloads the new weights. Use Normal simulation mode; the interpreted block is for learning and is not a generated-code deployment solution.

### 8.2 Next: live feature extraction from the electrical model

1. Add a MATLAB Function block to a COPY of the electrical model. Paste `live_rms_features.m` into it. Connect Vabc and Iabc as three-element column inputs.
2. Run this block at the 50 microsecond electrical rate; it maintains 400 past samples internally and outputs the same eight per-unit RMS values used offline.
3. Add a Zero-Order Hold at 1 ms after the feature output. Combine its eight values with a Digital Clock at 1 ms using a Mux, clock first.
4. Add an Interpreted MATLAB Fcn block calling `relay_block(u)` with output dimension 5. The path to the trained MAT file must resolve. The blanking rule suppresses initial decisions.
5. Log the five outputs and compare them against offline `replay_case` for the SAME electrical case. They should agree within numerical roundoff and sample alignment.
6. If you change Ts, frequency or bases, update both live and offline functions and retrain. The provided live block deliberately fixes the baseline values for straightforward Simulink code generation of the feature calculation.

For exported/real-time inference, replace the interpreted wrapper with a supported generated network function/subsystem or explicit weight-matrix operations. The equivalent hidden equations are `a1=tansig(W1*z+b1)`, `a2=tansig(W2*a1+b2)`, `y=W3*a2+b3`. Export BOTH networks plus mu/sigma and retain the exact preprocessing and sample rates. Validate numerical agreement before connecting trip logic.

### 8.3 Relay logic

The detector can issue a trip flag without waiting for the classification or distance estimate. The supplied logic does this:

1. Ignore startup before 40 ms.
2. Require three consecutive positive detector updates.
3. Latch the trip flag until reset/new simulation.
4. Confirm the same valid class for three active updates.
5. Only then issue a bounded distance, smoothed by a short median history.

Class confirmation and location filtering do not delay the independent detector trip. Unknown/invalid classes do not become forced ground-fault labels. The distance gate is explicit.

### 8.4 Breaker extension

Add a **Three-Phase Breaker** between the source and protected line in a separate demonstration model. Confirm its external-control convention in R2024a; generally a closed command is positive and open is zero. For that convention, a latched trip maps to `breakerCommand = ~trip`. Include a specified operating delay to represent the mechanism. Test normal operation first, because an inverted command opens the line at startup.

The supplied training model intentionally leaves the breaker closed while collecting faults, so current waveforms are not immediately truncated. Closed-loop validation must separately test how opening changes measurements, class/location availability and reset behaviour. Do not use `~trip` with an unlatched noisy detector, or the breaker can chatter/reclose automatically.

This baseline detector has NOT been trained to distinguish an internal line fault from a fault downstream of the transformer or behind the source. A current/voltage disturbance alone does not establish protection-zone selectivity. Add external-fault scenarios and directional/differential/distance supervision before describing it as a selective line protection relay.

## 9. Advanced concepts and a sensible improvement order

### 9.1 Source/load variations and external faults

Generate completely new test scenarios with a different random seed, untrained distances and resistances, and eventually outside-range conditions. Add load steps, capacitor switching, transformer energization, external faults, voltage sags, unbalanced loads, line-parameter errors and frequency deviations. A fixed healthy load sweep does not substitute for these non-fault transients.

For noise experiments add noise to raw voltage/current waveforms before feature extraction, with a stated RMS-relative noise level or SNR. Preserve the parent scenario group for every noisy derivative. Test CT saturation and VT errors using appropriate sensor models; additive Gaussian noise does not represent CT saturation.

### 9.2 Better inputs for location

RMS magnitudes are easy to teach but discard relative phase and much transient information. At one terminal, fault distance, fault resistance, load and source conditions can produce similar magnitudes. A low training loss does not remove that ambiguity.

Next add positive/negative/zero sequence phasors, voltage-current phase relationships, incremental current/voltage relative to prefault conditions, or real/imaginary components. These add physical information; they also change input dimension, so 8-20-10 becomes a different model and requires retraining. Phase-derived features should avoid angle wrap issues; real/imaginary or sine/cosine encodings can help.

### 9.3 DFT, wavelets, CNNs and LSTMs

A one-cycle DFT isolates the fundamental component more directly than total RMS. It still has a window response, and off-nominal frequency causes leakage unless compensated. Wavelet coefficients summarize transients at multiple scales but require careful causal implementation and exact same preprocessing during inference.

A 1-D CNN can learn local waveform patterns from short sampled windows. An LSTM can model temporal evolution. Both need much more diverse data and disciplined sequence grouping. Do not choose a more complex architecture just because its name sounds advanced; compare on the same scenario split, latency, memory and false-trip tests.

### 9.4 Separate loss heads

The reference combines four bits and one distance with MSE. A modern improvement uses sigmoid outputs and binary cross-entropy for bits, plus a separate regression head for distance, with the distance loss masked on healthy cases. Alternatively use a softmax class head with 11 operational classes after merging ABC/ABCG and a distance regressor. Keep a separate detector if independent fast trip logic is your design goal.

Loss weighting controls how much classification competes with location. Tune it on validation data and report each task independently. A custom `dlnetwork` loop offers flexibility but is a second-stage project, not required to understand this baseline.

### 9.5 Zone security, timing and real-time claims

Real-time protection requires more than simulation sample time. Include measurement/filter delay, ADC sampling, algorithm execution, communication if used, trip logic and breaker opening. Wall-clock MATLAB runtime is not relay operating delay. Hardware-in-the-loop testing evaluates interaction with real timing and interfaces, but is outside this package.

Threshold hysteresis, reset logic, directional checks and independent backup elements can improve security when designed and tested. They cannot fix an unobservable label or a dataset that omits important disturbances.

## 10. Troubleshooting

| Symptom | Likely cause | What to check |
|---|---|---|
| SPS blocks missing | Wrong release/toolbox installation | Confirm R2024a and Simscape Electrical in `ver` |
| Cannot connect electrical ports | Mixed SPS/native Simscape families | Use SPS throughout this model |
| powergui required | Missing environment block | Add one configured for this electrical network |
| No fault effect | Switch after stop time, wrong selections or wiring | Verify tOn, selected phases and shunt junction |
| Currents unrealistically high/low | kV/V or mH/H errors | Source VLL, line per-km values, load 400 V |
| Wrong zero sequence | Added positive RMS values | Sum instantaneous phase signals before RMS |
| False fault at startup | Incomplete RMS window/initial transient | Full-window ready flag and startup blanking |
| Perfect training, weak testing | Overfit or inadequate coverage | Scenario splits, more varied cases, smaller model |
| Perfect testing with repeated rows | Data leakage | Group parent scenarios and all derivatives |
| ABCG predicted ABC | Balanced fault may be unobservable | Report merged metric and explain physical limit |
| Location on healthy line | Ungated output | Use locationValid and ignore healthy regression loss |
| Negative or >10 km raw location | Unconstrained regression/extrapolation | Report raw errors; bound only operational output |
| ANN input size mismatch | Rows/columns or feature order | X is 8-by-N in the exact listed order |
| Different offline/Simulink predictions | Changed scaling/filter/sample alignment | Compare feature vectors before comparing networks |
| Training exhausts RAM | LM Jacobian on too many samples | Fewer windows per case, more efficient optimizer |
| Replayed model cannot find data | Missing `relayFeatures` or MAT file | Recreate timeseries and set Current Folder |
| New training seems ignored | Persistent wrapper still has old weights | `clear relay_block` before simulation |

## 11. Project milestones and report structure

### Work in gates

Gate 1: healthy and AG waveforms are electrically plausible. Gate 2: every listed class can be generated at a chosen location. Gate 3: causal feature checks pass. Gate 4: pilot training/evaluation completes without data overlap. Gate 5: unseen event replay reports delay and false trips honestly. Gate 6: live Simulink features reproduce offline predictions. Gate 7: challenge tests reveal and document limitations.

Save these figures for your report: network schematic; healthy and representative AG/AB/ABG/ABC waveforms; feature traces; training and validation loss; detection confusion matrix; class confusion matrix including Unknown; true versus estimated distance; error versus distance/resistance; and event traces showing inception, detector threshold crossing, trip, class confirmation and location validity.

Suggested chapters: problem/objectives; power-system and fault theory; ANN theory; reference method and changes; model parameters; dataset and leakage prevention; training; held-out results; dynamic relay implementation; limitations; conclusion and future work. Include a parameter provenance table and software release so another student can reproduce the experiment.

### Short viva answers

- **Why an ANN?** It can learn nonlinear relationships between measured electrical quantities and fault labels; it must still be trained and tested across relevant conditions.
- **Why two networks?** Detection can make an independent fast decision while classification/location provide additional information.
- **Why zero sequence?** It adds useful information about many ground faults and system imbalance, subject to grounding and balanced-fault limitations.
- **Why normalize?** To express consistent scales and improve numerical training without letting large voltage units dominate.
- **Why two line sections?** Their junction gives a fault point at a known distance while preserving the total line length.
- **Why scenario splits?** Nearby windows from one fault are correlated; separating windows at random can leak the same event into testing.
- **Why not always 100% accuracy?** Noise, unseen conditions, modelling errors and non-unique measurements limit performance; honest testing exposes them.
- **Can this directly protect a real grid?** No. This is an educational simulation that needs zone-selectivity, sensor, timing and hardware validation before practical protection use.

## 12. File map

| File | Purpose |
|---|---|
| project_config.m | Parameters, feature timing and class labels |
| build_power_model.m | Builds the R2024a SPS electrical model |
| simulate_case.m | Applies one scenario and returns SI waveforms |
| make_scenarios.m | Generates independent operating/fault settings |
| extract_features.m | Causal offline RMS and per-unit features |
| generate_dataset.m | Simulates, checkpoints and assembles labelled data |
| split_scenarios.m | Stratified complete-scenario train/validation/test split |
| train_dual_ann.m | Trains and saves both networks and scaling |
| predict_dual_ann.m | Predicts detection, bits and distance |
| decode_fault.m | Exact bit-pattern decoder including Unknown |
| evaluate_dual_ann.m | Held-out window metrics and plots |
| evaluate_events.m | Held-out event delays, false trips and settling times |
| replay_case.m | Causal event replay and detector delay |
| relay_logic.m | Persistence, trip latch, class confirmation and location gate |
| relay_block.m | Simulink interpreted-function adapter |
| build_relay_demo.m | Creates the Simulink feature-playback model |
| live_rms_features.m | MATLAB Function block code for live features |
| smoke_test.m | Electrical sanity check before large data generation |
| test_feature_math.m | RMS, sequence, decoder and causality checks |
| run_project.m | Runs the pilot workflow in order |
| VALIDATION.md | What was actually checked in this delivery |

## References and further reading

1. User-supplied presentation, *Dual Artificial-Neural-Network Protection for Transmission-Line Faults*, 16 pages. Architecture pp. 3, 6-7; electrical values pp. 4-5; internal results pp. 8-12; validation limitations and relay extensions pp. 13-15.
2. MathWorks, R2024a Three-Phase Fault: https://www.mathworks.com/help/releases/R2024a/sps/powersys/ref/threephasefault.html
3. MathWorks, feedforwardnet: https://www.mathworks.com/help/deeplearning/ref/feedforwardnet.html
4. MathWorks, shallow-network train and error weights: https://www.mathworks.com/help/deeplearning/ref/network.train.html
5. MathWorks, divideind: https://www.mathworks.com/help/deeplearning/ref/divideind.html
6. MathWorks, migration from SPS and the R2026a removal: https://www.mathworks.com/help/simscape-electrical/ug/upgrade-sps-models-to-use-simscape-blocks.html

Use your installed R2024a documentation for block dialogs. Current online documentation marks several legacy ANN functions for future removal; this does not mean they are unavailable in R2024a.
