# Energy measurement

No file of the upstream project is modified: this directory and
`.github/workflows/energy-measurement.yml` are the only additions, and
`git diff 1.8.0 --stat` on this branch lists only these five paths.

## What is measured

Two stages from job `Linux_Runs` of `azure-pipelines.yml` at commit `646da0f072a8afef6a980aa427a710311e67eb9d`
(tag `1.8.0`), matrix entry `pylatest_conda_forge_mkl` on `ubuntu-22.04`, with the steps of
`build_tools/azure/posix.yml`. At this tag the cell runs on Azure Pipelines; it is the same cell that
the HEAD campaign measures on GitHub Actions (`unit-tests.yml`, `Linux x86-64 pylatest_conda_forge_mkl`):
the latest Python and dependencies from conda-forge with MKL, installed from an explicit lock file, with
coverage and the doctests enabled.

| stage | command | origin |
|---|---|---|
| `build` | `pip install --verbose --no-build-isolation --editable .` with the ccache setup and `LDFLAGS` of `build_tools/azure/install.sh` | step `Install` |
| `test` | `build_tools/azure/test_script.sh`, then `build_tools/azure/test_docs.sh` | steps `Test Library` and `Test Docs` |

`build` is the compilation and installation of the package into the pre-installed locked
environment. `install.sh` also creates the conda environment and downloads the Playwright browsers, which
need the network; those two parts are in the image and the compilation is transcribed command by
command. `test` is the test suite followed by the doctests; its exit is the larger of the two. There is
no `train` stage: every `fit` runs inside a pytest item.

The environment is created from `./build_tools/azure/pylatest_conda_forge_mkl_linux-64_conda.lock` (270 packages), whose sha256 is verified at
image build time and again at the start of each stage. The stages run with `--network none`,
`--memory=12g` and no swap; `run_pipeline.sh` verifies once per run, before the baseline, that the
container has no route. `memory.peak` and `memory.events` of the container cgroup are recorded per stage.

## Differences from the hosted job

- The ccache directory lives inside the container and starts empty on every run, so `build`
  measures a full compilation. The hosted job restores a warm cache through the `Cache@2` task.
- `test_script.sh` derives the number of xdist workers from `joblib.cpu_count()`: the number of cores of the host here.
- `Test Docs` runs after `Test Library` whatever its exit, as in the HEAD campaign; on Azure it runs only after a successful `Test Library`.
- Each stage starts a new container. A Docker volume created per run holds `build/`, and what
  `pip` writes at the top of `site-packages` is carried from `build` to `test` through it.

Expected exits: `build` 0 and `test` 0; a run is conform when `junit.xml` lists no failed test.

## Build

```
docker build -t scikit-learn-measurement-1.8.0 -f energy-measurement/Dockerfile energy-measurement
```

## Run

```
gh workflow run energy-measurement.yml --ref release-1.8.0 -f campaign=validation
gh workflow run energy-measurement.yml --ref release-1.8.0 -f campaign=full
```

`validation` runs run 0 only; `full` runs a warm-up, runs 1 to 10 and the median.
Results, including `junit.xml`, the exit and wall of each `test` command, the memory files per
stage, the network check per run and the host swap and package temperature sidecars read outside
the RAPL window, are uploaded as a workflow artifact.

One run locally:

```
bash energy-measurement/run_pipeline.sh 1
```
