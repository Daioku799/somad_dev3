# Experiment 4: Gaussian RBF parameter sensitivity

- This is an epsilon/lambda sweep for one Gaussian kernel, not a comparison of kernel families.
- Train/validation split: cases 1--80 / 81--90; retained POD modes: 78.
- Epsilon values: 0.5, 1.0, 1.5, 2.0, 3.0; lambda values: 1.0e-8, 1.0e-6, 0.0001, 0.01.
- Baseline: epsilon=1.0, lambda=1.0e-6.
- Best mean L2: epsilon=0.5, lambda=1e-02 (0.07367%).
- Best mean Tmax: epsilon=0.5, lambda=1e-08 (0.07095 K).
- Parameter selection must name its objective because the L2 and Tmax optima differ.
- The paired-case plot compares the baseline, L2-optimal, and Tmax-optimal settings; crosses are outside the per-feature train range.
