# syntax=docker/dockerfile:1

# Environment and browsers are installed at image build time so every measured stage runs offline.
FROM ubuntu:22.04@sha256:b8b6ee6aa931ecd9d0d952abc34dc0e5f7c6a30c6bb71b079fe399fde0329c02

ARG SKLEARN_SHA=646da0f072a8afef6a980aa427a710311e67eb9d
ARG LOCK_FILE=./build_tools/azure/pylatest_conda_forge_mkl_linux-64_conda.lock
ARG LOCK_SHA256=cb46a250215de687e672410e76de046ac362cd9275bb26c7800315229c78ad50
# build_tools/azure/install_setup_conda.sh asks for `latest`; the reference run logs expired, so this is the latest release
# published before the tag date.
ARG MINIFORGE_VERSION=25.11.0-1
ARG MINIFORGE_SHA256=be1bad9d4e67a8753eb76fb4940e9a08036786675c7adf060627e55791bf110d

ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-c"]

# The lock carries no compiler; build-essential gives the gcc 11.4.0 of the hosted ubuntu-22.04 agent image.
RUN set -eux; \
    apt-get update -qq; \
    apt-get install -qq -y --no-install-recommends \
        build-essential ca-certificates curl git sudo; \
    rm -rf /var/lib/apt/lists/*

# The hosted runner user has passwordless sudo, which `playwright install --with-deps` relies on.
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

# build_tools/azure/install.sh:61 and build_tools/shared.sh:65; the environment must equal the lock URL by URL.
RUN set -ex; \
    source build_tools/shared.sh; \
    CONDA_ALWAYS_YES=true create_conda_environment_from_lock_file testvenv "$LOCK_FILE"; \
    diff <(grep '^https://' "$LOCK_FILE" | sed 's/#.*//' | sort) \
         <(conda list --name testvenv --explicit | grep '^https://' | sed 's/#.*//' | sort); \
    conda clean --tarballs --yes

# build_tools/azure/install.sh:132-136
RUN set -ex; \
    source activate testvenv; \
    python -m playwright install --with-deps; \
    sudo rm -rf /var/lib/apt/lists/*

# Mount point of the per-run build volume; created here so the volume inherits the owner.
RUN set -eux; \
    mkdir /src/build; \
    dpkg -l > /image-provenance/dpkg.txt; \
    conda list --name testvenv --explicit > /image-provenance/conda-explicit.txt; \
    sha256sum "$LOCK_FILE" > /image-provenance/lock.sha256
