# Validation status

Prepared for MATLAB R2024a on 22 November 2026.

## Checks completed

- Inspected the supplied 16-page reference presentation and its parameter, architecture and limitation statements.
- Inspected the installed R2024a SPS library block names and mask parameters used by the builder.
- Started MATLAB R2024a with a temporary preferences directory.
- Ran `test_feature_math` successfully in MATLAB. Balanced sinusoidal phase RMS values, zero-sequence cancellation, all 12 target decodings and causal feature invariance passed.
- Ran `build_power_model` successfully and saved `ann_transmission_line.slx`.
- The initial electrical test exposed incorrect grouping of `SimulationInput.setBlockParameter` arguments. Corrected `simulate_case.m` to use one block/parameter/value triplet per call.

## Not completed here

Subsequent MATLAB launches stalled before completing the corrected electrical smoke test. They were interrupted. Consequently the complete model simulation, scenario sweep, training, held-out metrics, relay replay and live/closed-loop validation have NOT been successfully executed here.

The included SLX file was constructed and saved, but that is not the same as a successful compiled simulation. The MATLAB files are a reviewed starting implementation with reproducible checks for the user, not a fully validated protection system. No trained weights, synthetic accuracy claims or claimed reproduction of the PDF's results are included.

## What to run on your MATLAB installation

```matlab
test_feature_math
open_system('ann_transmission_line.slx')
smoke_test
S = make_scenarios(10);
D = generate_dataset(S,project_config,'data_pilot');
M = train_dual_ann(D);
R = evaluate_dual_ann(M,D);
E = evaluate_events(M,'data_pilot',0.5);
```

Run these one stage at a time and inspect the electrical waveforms before starting the sweep. The builder has already supplied the model; rebuild only if you deliberately want to regenerate it after configuration changes.

For version-related API/block errors, compare the dialog with the explicit manual settings in GUIDE.html and preserve the exact error message and failing file/line. Do not change labels, preprocessing or test splits simply to make accuracy look better.

## Material limitations

- Several physical parameters and the RMS feature definition are explicit assumptions because the PDF does not supply them completely.
- Default scenarios cover a bounded radial-feeder operating range, not a full transmission-protection validation envelope.
- The default data does not include external faults or non-fault switching events, so zone selectivity and disturbance immunity are unproven.
- Perfectly balanced ABC/ABCG faults may be unidentifiable as separate classes from these inputs.
- One-end RMS magnitude features can be inadequate for accurate location across varying fault resistance/source/load conditions.
- Full-cycle RMS and persistence affect latency; the reference's 3-5 ms delay is not an established result for this code.
- The interpreted Simulink inference adapter is a Normal-mode teaching demo, not a real-time code-generation implementation.
