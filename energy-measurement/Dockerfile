# syntax=docker/dockerfile:1

# Environment is installed at image build time so every measured stage runs offline.
FROM ubuntu:22.04@sha256:b8b6ee6aa931ecd9d0d952abc34dc0e5f7c6a30c6bb71b079fe399fde0329c02

ARG SKLEARN_SHA=b51d0c9648241d1fd53dc9151689f62a61633a3d
ARG LOCK_FILE=./build_tools/azure/pylatest_conda_forge_mkl_linux-64_conda.lock
ARG LOCK_SHA256=5ef475faf01380e915a04d4a5b3b89746dc1cf366fe69b7706b05816f097b12e
# build_tools/azure/posix.yml:39-44 takes the conda of the hosted agent (or Miniforge `latest`); the agent image is not
# retained, so this is the latest Miniforge release published before the tag date.
ARG MINIFORGE_VERSION=24.3.0-0
ARG MINIFORGE_SHA256=23367676b610de826f50f7ddc91139a816d4b59bd4c69cc9b6082d9b2e7fe8a3

ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-c"]

# The lock carries no compiler; build-essential gives gcc 11.4.0, the toolchain of the other points of this series
# (the hosted agent of this tag is ubuntu-20.04).
RUN set -eux; \
    apt-get update -qq; \
    apt-get install -qq -y --no-install-recommends \
        build-essential ca-certificates curl git sudo; \
    rm -rf /var/lib/apt/lists/*

# The hosted agent user has passwordless sudo.
RUN set -eux; \
    useradd --create-home --uid 1001 --shell /bin/bash runner; \
    echo 'runner ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/runner; \
    chmod 0440 /etc/sudoers.d/runner; \
    install -d -o runner -g runner /src /image-provenance; \
    echo 'export PATH="/home/runner/miniconda3/bin:$PATH"' > /etc/profile.d/conda-path.sh

USER runner
ENV PATH="/home/runner/miniconda3/bin:${PATH}"

RUN set -eux; \
    curl -fsSL -o /tmp/miniforge.sh \
        "https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE_VERSION}/Miniforge3-${MINIFORGE_VERSION}-Linux-x86_64.sh"; \
    echo "${MINIFORGE_SHA256}  /tmp/miniforge.sh" | sha256sum -c -; \
    bash /tmp/miniforge.sh -b -p /home/runner/miniconda3; \
    rm -f /tmp/miniforge.sh; \
    conda --version

WORKDIR /src

# A git checkout, not `git archive`: build_tools/ is export-ignored.
RUN set -eux; \
    git init -q .; \
    git remote add origin https://github.com/scikit-learn/scikit-learn.git; \
    git fetch --depth 1 -q origin "$SKLEARN_SHA"; \
    git checkout -q --detach FETCH_HEAD; \
    test "$(git rev-parse HEAD)" = "$SKLEARN_SHA"; \
    test -f build_tools/azure/install.sh; \
    echo "${LOCK_SHA256}  ${LOCK_FILE}" | sha256sum -c -

# build_tools/azure/install.sh:64-67 resolves the lock with conda-lock over the network; the explicit lock installs
# directly and the environment must equal it URL by URL.
RUN set -ex; \
    CONDA_ALWAYS_YES=true conda create --name testvenv --file "$LOCK_FILE"; \
    diff <(grep '^https://' "$LOCK_FILE" | sed 's/#.*//' | sort) \
         <(conda list --name testvenv --explicit | grep '^https://' | sed 's/#.*//' | sort); \
    conda clean --tarballs --yes

# Two doctests of this tag (getting_started.rst, modules/compose.rst) call fetch_california_housing, which the hosted
# job downloads on every run; the cache it writes (sklearn/datasets/_california_housing.py) is created here instead.
RUN set -ex; \
    source activate testvenv; \
    mkdir -p /home/runner/scikit_learn_data; \
    curl -fsSL -o /tmp/cal_housing.tgz https://ndownloader.figshare.com/files/5976036; \
    echo "aaa5c9a6afe2225cc2aed2723682ae403280c4a3695a2ddda4ffb5d8215ea681  /tmp/cal_housing.tgz" | sha256sum -c -; \
    python -c "import tarfile, numpy as np, joblib; f = tarfile.open('/tmp/cal_housing.tgz', 'r:gz'); a = np.loadtxt(f.extractfile('CaliforniaHousing/cal_housing.data'), delimiter=','); joblib.dump(a[:, [8, 7, 2, 3, 4, 5, 6, 1, 0]], '/home/runner/scikit_learn_data/cal_housing_py3.pkz', compress=6)"; \
    rm -f /tmp/cal_housing.tgz; \
    sha256sum /home/runner/scikit_learn_data/cal_housing_py3.pkz

# Mount point of the per-run build volume; created here so the volume inherits the owner.
RUN set -eux; \
    mkdir /src/build; \
    dpkg -l > /image-provenance/dpkg.txt; \
    conda list --name testvenv --explicit > /image-provenance/conda-explicit.txt; \
    sha256sum "$LOCK_FILE" > /image-provenance/lock.sha256
