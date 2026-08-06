# Experiment 2: training-snapshot count

- Source dataset: 90 validated saved FVM snapshots.
- Fixed validation: cases 81--90; training subsets are nested prefixes of cases 1--80.
- Counts compared: 5, 10, 15, 20, 40, 80.
- POD RIC threshold: 0.9999; Gaussian RBF epsilon=1.0, lambda=1.0e-6.
- Crosses in the plots denote holdout points outside the per-feature training bounds.
- This is a single deterministic subset path, not a repeated-subset uncertainty study.
- A fixed-k=4 control is provided to separate snapshot-count effects from the automatic increase in retained POD modes.
