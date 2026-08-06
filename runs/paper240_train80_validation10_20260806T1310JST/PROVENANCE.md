# Paper 240 ROM experiments 2--4

- Dataset manifest: `data/paper_240_v1/manifest.json`
- Dataset state at evaluation: `complete`, 100/100 valid cases, zero failures/timeouts
- Physical grid: 240 x 240 x 30
- Saved array shape: 242 x 242 x 32 including ghost cells
- ROM train split: cases 1--80
- ROM validation split: cases 81--90
- Test split: cases 91--100; not loaded or evaluated
- Experiment 2 train counts: 5, 10, 15, 20, 40, 80
- Experiment 3 maximum nonzero centered POD rank: 78
- Experiment 4 sweep: Gaussian epsilon 0.5, 1.0, 1.5, 2.0, 3.0 and lambda 1e-8, 1e-6, 1e-4, 1e-2
- Source slide: `/home/foo/slide/20260806進捗報告.md`
- Source slide SHA-256: `9a64b7321ac82d4801fcb4a00e5d6a4400f93bbe3236b06a8816b10188badc49`
- Derived slide: `20260806進捗報告_240正式差替版.md`
- Existing slide and image files were not overwritten.
