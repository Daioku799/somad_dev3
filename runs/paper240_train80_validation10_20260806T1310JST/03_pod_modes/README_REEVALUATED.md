# Experiment 3: retained POD modes

- Train/validation split: cases 1--80 / 81--90.
- Evaluated mode counts: 1, 2, 3, 5, 8, 10, 15, 20, 25, 30, 35, 40, 50, 60, 78.
- Gaussian RBF epsilon=1.0, lambda=1.0e-6.
- The POD projection curve uses each holdout truth field's exact projection and is a lower bound for this basis.
- The gap between POD+RBF and projection curves indicates coefficient-interpolation error.
