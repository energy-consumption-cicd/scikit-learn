# Energy measurement

No file of the upstream project is modified: this directory and
`.github/workflows/energy-measurement.yml` are the only additions, and
`git diff 9bafc1c9 --stat` on this branch lists only these five paths.

## What is measured

Two stages from job `unit-tests` of `.github/workflows/unit-tests.yml` at commit
`9bafc1c9cab99aa036aba8207125637c39fd22db`, matrix entry
`Linux x86-64 pylatest_conda_forge_mkl` on `ubuntu-22.04`. It is the upstream reference cell:
the latest Python and dependencies from conda-forge with MKL, installed from an explicit lock
file, with coverage and the doctests enabled.

| stage | command | origin |
|---|---|---|
| `build` | `pip install --verbose --no-build-isolation --editable .` with the ccache setup and `LDFLAGS` of `build_tools/github/install.sh` | step `Build scikit-learn` |
| `test` | `bash -l build_tools/github/test_script.sh`, then `bash -l build_tools/github/test_docs.sh` | steps `Run tests` and `Run doctests in .py and .rst files` |

`build` is the compilation and installation of the package into the pre-installed locked
environment. `install.sh` also creates the conda environment and downloads the Playwright
browsers, which need the network; those two parts are in the image and the compilation is
transcribed command by command. `test` is the test suite followed by the doctests, as in the
upstream job; its exit is the larger of the two. There is no `train` stage: every `fit` runs
inside a pytest item.

The environment is created from
`build_tools/github/pylatest_conda_forge_mkl_linux-64_conda.lock` (282 packages), whose sha256 is
verified at image build time and again at the start of each stage. The stages run with
`--network none`, `--memory=12g` and no swap; `run_pipeline.sh` verifies once per run, before the
baseline, that the container has no route. `memory.peak` and `memory.events` of the container
cgroup are recorded per stage.

## Differences from the hosted job

- The ccache directory lives inside the container and starts empty on every run, so `build`
  measures a full compilation. The hosted job restores a warm cache through `actions/cache`.
- `test_script.sh` derives the number of xdist workers from `joblib.cpu_count()`: `-n4` on the
  hosted runner, the number of cores of the host here.
- Each stage starts a new container. A Docker volume created per run holds `build/`, and what
  `pip` writes at the top of `site-packages` is carried from `build` to `test` through it.

Two tests fail by design on the measurement machine (Intel i7-9700) and pass on the hosted
runner, with an identical environment:

```
linear_model/tests/test_logistic.py::test_logistic_regression_array_api_compliance[array_api_strict-device1-float32-balanced-True-False-False-lbfgs]
linear_model/tests/test_logistic.py::test_logistic_regression_array_api_compliance[array_api_strict-device1-float32-balanced-True-True-False-lbfgs]
```

Both compare a float32 `lbfgs` fit across array namespaces and miss `rtol=0.001` by a relative
difference of 0.45 %. Nothing is deselected and no tolerance is changed: the expected exit of
`test` is 1, and a run is conform when `junit.xml` lists exactly those two as failed.

## Build

```
docker build -t scikit-learn-medicao -f energy-measurement/Dockerfile energy-measurement
```

## Run

```
gh workflow run energy-measurement.yml -f campaign=validation
gh workflow run energy-measurement.yml -f campaign=full
```

`validation` runs run 0 only; `full` runs a warm-up, runs 1 to 10 and the median.
Results, including `junit.xml`, the exit and wall of each `test` command, the memory files per
stage and the network check per run, are uploaded as a workflow artifact.

One run locally:

```
bash energy-measurement/run_pipeline.sh 1
```
