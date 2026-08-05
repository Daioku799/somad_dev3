# Paper 240 FVM run handoff

## Purpose

This document lets another Codex session or a human safely inspect, resume, or
stop the FVM calculations used by ROM experiments 1A, 2, 3, and 4. Runtime
state is intentionally stored in files; chat history is not authoritative.

The approved run keeps all earlier results unchanged. In particular,
`data/work/experiment_1b` is the existing exploratory experiment 1B with
`p_min = 50 um`; do not overwrite it or silently combine it with this run.

## Authoritative paths

- Runner: `run_paper_dataset_240.jl`
- Status display: `status_paper_dataset_240.jl`
- Contract test: `test_paper_dataset_240.jl`
- New results: `data/paper_240_v1/`
- Atomic state: `data/paper_240_v1/manifest.json`
- Combined driver log: `data/paper_240_v1/driver.log`
- Detached tmux socket: `/tmp/somad_dev3_paper240.sock`
- Detached tmux session: `paper240`

Never infer progress from file count alone. A case is valid only when its
manifest run record is `success` or `cached` and snapshot validation passed.

## Inspect current state

Run from `/home/foo/somad_dev3`:

```bash
julia --project=H2-rom status_paper_dataset_240.jl
tail -n 80 data/paper_240_v1/driver.log
tmux -S /tmp/somad_dev3_paper240.sock list-sessions
pgrep -af 'run_paper_dataset_240|H2-main-ext/run.jl'
```

For a live log:

```bash
tail -f data/paper_240_v1/driver.log
```

For the live terminal:

```bash
tmux -S /tmp/somad_dev3_paper240.sock attach -t paper240
```

Detach without stopping it by pressing `Ctrl-b`, then `d`.

Closing SSH or a terminal does not stop tmux. Host sleep, reboot, WSL shutdown,
power loss, or manually killing the process does stop it. Completed cases remain
recoverable because the manifest is atomically updated after every validation.

## Determine whether it is really running

Use all three signals:

1. `status_paper_dataset_240.jl` shows a current case and recent manifest time.
2. `pgrep` shows either the dataset driver or an FVM `run.jl` child.
3. `driver.log` or the current case `output.log` is changing.

A `current` manifest entry without a matching process is stale after an
interruption, not proof that a solver is still running. Starting the same
runner again is safe: valid snapshots are reported as `cached`; invalid partial
snapshots and logs are moved under that case's `quarantine/` directory.

## Approved physical and numerical conditions

- New common dataset: 100 cases, split into train 80 / validation 10 / test 10.
- Split seeds: 20260806 / 20260807 / 20260808.
- Density representation used to generate layouts: 4 x 4.
- TSV radius/diameter: 20/40 um.
- Minimum center pitch: 80 um. Keep it unchanged for this run.
- Per-cell capacity: 9; global limit: 120 TSVs.
- Domain: 1.2 x 1.2 x 0.6 mm.
- Production FVM grid: 240 x 240 x 30 physical cells.
- Saved arrays: 242 x 242 x 32 including ghost cells.
- XY pitch at production resolution: 5 um.
- Z faces must exactly match the 30-cell H2-main `Zcase2` grid.
- Solver: PBiCGSTAB + GS, tolerance 1e-4, maximum 8000 iterations,
  sequential, steady state.
- Boundary conditions and materials are inherited from H2-main defaults.
- The missing GDS behavior remains the existing rectangular-silicon fallback
  for comparability; do not change it during this run.

The generated discrete layout, not only the requested density values, is checked
for count agreement, uniqueness, 80 um pitch, and silicon boundary compliance.
The plan should have 100 unique signatures and these count summaries:

| Split | n | min | mean | max |
|---|---:|---:|---:|---:|
| train | 80 | 40 | 72.725 | 112 |
| validation | 10 | 55 | 71.5 | 87 |
| test | 10 | 63 | 72.1 | 89 |

The three training anchors contain 112, 40, and 104 TSVs.

## Execution order and stop gates

The `all` phase first runs three representative layouts at XY grids 60, 120,
240, and 480. It compares 240 against 480. The 100-case run starts only if all
three layouts satisfy all of:

- temperature-rise relative L2 <= 0.5%
- absolute maximum-temperature difference <= 0.1 K
- relative copper-volume discretization difference <= 5%

The 240-grid snapshots from the pilot are stored directly in their final case
directories and reused by the dataset phase.

The runner stops instead of continuing when:

- the grid-convergence pilot fails;
- a pilot solver fails or times out;
- three consecutive dataset cases fail;
- free disk space falls below 20 GiB;
- a saved field, grid shape, Z grid, convergence marker, or finite-value check
  fails.

Do not weaken these gates or begin the dataset after a failed pilot without new
human approval.

## Start or resume

First validate the implementation:

```bash
julia --project=H2-rom test_paper_dataset_240.jl
```

If no session exists, start the approved pipeline in tmux:

```bash
mkdir -p data/paper_240_v1
tmux -S /tmp/somad_dev3_paper240.sock new-session -d -s paper240 \
  "cd /home/foo/somad_dev3 && exec julia --project=H2-rom run_paper_dataset_240.jl --phase all >> data/paper_240_v1/driver.log 2>&1"
```

Do not start a second session if `pgrep` already shows the driver or solver.
After an interruption, the identical command is the supported resume path.

## Safe intervention rules

- Read-only inspection needs no approval.
- Do not delete or rewrite an existing snapshot, manifest, old experiment, or
  quarantine entry.
- Do not change pitch, sampling, split membership, solver settings, Z grid, or
  convergence gates while a run is in progress.
- Do not launch experiments 1A/2/3/4 analysis until the common dataset is
  complete, except for code-only preparation that does not reinterpret partial
  data.
- If the pilot fails, report its `grid_convergence.json` values and stop.
- If failures occur, report the case ID, grid, manifest reason, and tail of its
  `output.log`; preserve the failed artifacts.

## After completion

Confirm `overall: complete`, `240 dataset: 100/100`, and zero unresolved failures
with the status script. Then preserve the manifest, case plan, driver log, per-case
configs, layout metadata, snapshots, output logs, and hashes together. The test
split must remain untouched until the validation-based ROM choices for experiments
1A/2/3/4 are frozen.
