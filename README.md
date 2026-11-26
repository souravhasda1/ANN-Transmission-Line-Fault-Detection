# ANN-Based Transmission Line Fault Detection and Location

MATLAB/Simulink project for detecting, classifying, and locating transmission-line faults with two feedforward artificial neural networks (ANNs). This example uses a **10 km line split into 8 km and 2 km sections**, so the fault block is connected at the **8 km point**.

## Requirements

- MATLAB **R2024a** and Simulink
- Simscape Electrical **Specialized Power Systems** (for the three-phase electrical blocks and `powergui`)
- Deep Learning Toolbox (for `feedforwardnet` and `trainlm`)
- The project files listed below

The code was prepared for R2024a; results can vary slightly with solver settings, model parameters, and ANN training data.

## Project files

Keep these files together in the project folder. Replace the example model name below if your `.slx` file has another name.

| File | Purpose |
| --- | --- |
| `ann_fresh_fault_scopes.slx` | Simulink electrical network, scopes, and Live ANN block |
| `train_dual_ann.m` | Trains and saves the two ANN networks |
| `split_scenarios.m` | Splits scenarios for training and validation; required by `train_dual_ann` |
| Data-generation scripts and their dependencies | Needed if retraining from simulated cases |
| `training_data.mat` containing `D` | Needed only for the retraining commands below; use your actual data filename if different |
| `trained_dual_ann.mat` | Trained model loaded by the Live ANN implementation; needed to run inference without retraining |
| Other `.m` files called by the Live ANN block | Required for live inference; keep their function names and file names consistent |

`training_data.mat` is an **example filename**, not a file created by `train_dual_ann.m`. To reproduce training, provide your own dataset-generating script or a MAT-file containing `D`. Do not claim a fresh training run is reproducible until those files are included. The Live ANN code must load the same `trained_dual_ann.mat` file produced by training.

## Model setup: 8 km + 2 km example

1. Connect an **11 kV, 50 Hz**, three-phase source to a three-phase V-I measurement block.
2. Connect **Line 1 (8 km)**, then **Line 2 (2 km)**, then the transformer and load. Keep the line electrical parameters appropriate for each section.
3. Connect the three-phase fault block at the junction of Line 1 and Line 2. Its distance from the measurement end is therefore **8 km**, and total line length is **10 km**.
4. For an AG example, enable **phase A and ground** in the fault block. Set fault initiation to **0.10 s** and clearing to **0.30 s**, if those are the test conditions you intend to show.
5. Set `powergui` to **Discrete** with sample time **`5e-5` s**. Use a stop time of **`0.35` s** to see both fault initiation and clearing; a stop time of `0.26` s shows the fault but not clearing.
6. Set the training configuration's `lineKm` to **10** for this example. Ensure training scenarios use the same total length and feature definitions as the model used for inference. The true fault distance is **8 km**, or **0.8 per unit** of the line length.

Changing a line's displayed label is insufficient: open each line block and verify its actual length parameter. Verify the fault block is connected at the 8 km junction.

## Run an existing trained model

Place the `.slx`, the Live ANN dependencies, and `trained_dual_ann.mat` in the project folder. In the MATLAB Command Window, run:

```matlab
cd('C:\path\to\ANN-Transmission-Line-Fault-Detection')  % edit this path
addpath(genpath(pwd))
assert(isfile('trained_dual_ann.mat'), 'Missing trained_dual_ann.mat')
open_system('ann_fresh_fault_scopes')                 % edit if your model has another name
set_param('ann_fresh_fault_scopes', 'StopTime', '0.35')
simOut = sim('ann_fresh_fault_scopes');
```

Open the scopes or displays in the model to examine `Vabc`, `Iabc`, RMS values, `V0`, `I0`, trip, class ID, fault score, and estimated distance. `simOut` is the simulation result object; signal data are available inside it only when the model is configured to log those signals.

**Before running:** confirm the source, line lengths, fault type and switching times in the block dialogs. The commands above set the stop time; they do **not** change the fault block's settings or the line lengths.

## Retrain the ANNs (if the dataset is provided)

The training entry point is `train_dual_ann(D)`. If the repository contains `training_data.mat` with a structure named `D`, run:

```matlab
cd('C:\path\to\ANN-Transmission-Line-Fault-Detection')  % edit this path
addpath(genpath(pwd))
assert(isfile('training_data.mat'), 'Provide a MAT-file containing D first')
assert(isfile('split_scenarios.m'), 'Missing split_scenarios.m')
S = load('training_data.mat', 'D');
assert(isfield(S, 'D'), 'The MAT-file must contain a variable named D')
D = S.D;
assert(isfield(D, 'c') && isfield(D.c, 'lineKm'), 'D.c.lineKm is required')
assert(D.c.lineKm == 10, 'This 8 km + 2 km example uses c.lineKm = 10')
M = train_dual_ann(D);
```

This saves `trained_dual_ann.mat` in the current folder. It contains the detector network, joint network, input normalization (`mu`, `sigma`), configuration and validation-selected detector threshold. If your data generator builds `D` in memory instead, run that script first and then call `M = train_dual_ann(D);`. Training needs the fields used by the function, including `D.X`, `D.fault`, `D.bits`, `D.distance`, `D.jointValid`, and `D.c`.

**ANN architecture:** both networks have hidden layers of 20 and 10 neurons. The detector has one output for a fault-indication score; the joint network has four fault-label outputs and one distance output. Its distance target is `D.distance/D.c.lineKm`, so the example 8 km target is `0.8` when `lineKm=10`. The detector threshold is selected from validation cases. The score is not automatically a calibrated probability.

After retraining, rerun the model. If the Live ANN block caches the loaded MAT-file using persistent variables, clear its function or restart MATLAB before rerunning so it reads the new weights.

## Interpreting the outputs

| Output | Interpretation |
| --- | --- |
| Trip | Binary trip decision, 0 or 1 |
| Class ID | Fault category according to the Live ANN code's class mapping |
| Estimated distance | ANN estimate in km; compare only when the location-valid output is 1 |
| Location valid | Whether the location output should be used |
| Fault score | Numerical detector output; compare against the saved threshold |

For a healthy balanced system, the phase voltages/currents are roughly symmetric and zero-sequence values `V0=(Va+Vb+Vc)/3` and `I0=(Ia+Ib+Ic)/3` are approximately zero. For an AG fault, phase A current rises, its voltage falls, and `V0`/`I0` can become substantial. In a balanced ABC fault, all three phase currents rise and voltages fall together; `V0` and `I0` can still be approximately zero. RMS traces take time to settle because they use a measurement window.

Do not interpret a pre-fault distance display as a physical location. Use the **settled** estimate after fault inception and the location-valid output. A true-distance reference of 8 km is a comparison value, not the ANN's prediction.

## Troubleshooting

- **`Undefined function 'feedforwardnet'`**: install/enable Deep Learning Toolbox.
- **Missing electrical blocks or `powergui` error**: install/enable Simscape Electrical Specialized Power Systems.
- **`split_scenarios` or another function not found**: add its `.m` file to this folder and run `addpath(genpath(pwd))`.
- **Missing `D` or `training_data.mat`**: include the training-data generator or the MAT-file. The trained `.mat` is enough for inference only if the Live ANN block loads it successfully.
- **Wrong estimated distance**: confirm the line blocks are actually set to 8 km and 2 km, the fault is connected between them, `c.lineKm` is 10, and the live feature order matches the training feature order.
- **No visible clearing**: increase stop time beyond the fault clearing time (for example, to `0.35` s for clearing at `0.30` s).

## Repository notes

Track the model, source scripts, necessary trained weights/data, this README, and selected result figures. Exclude generated `slprj/` and `*.slxc` cache files. Treat `.slx` and `.mat` as binary files in Git; use Git LFS if trained models or datasets are large. Check that no private credentials or personal data are in the files before publishing.
