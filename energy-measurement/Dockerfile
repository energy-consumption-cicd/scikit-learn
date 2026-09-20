# syntax=docker/dockerfile:1

# Environment and browsers are installed at image build time so every measured stage runs offline.
FROM ubuntu:22.04@sha256:b8b6ee6aa931ecd9d0d952abc34dc0e5f7c6a30c6bb71b079fe399fde0329c02

ARG SKLEARN_SHA=9bafc1c9cab99aa036aba8207125637c39fd22db
ARG LOCK_FILE=build_tools/github/pylatest_conda_forge_mkl_linux-64_conda.lock
ARG LOCK_SHA256=83164622aff987a8a9a4625ccb216683e09ede0f9873ebd7dcf684c5c8d3cb82
# The job asks for `latest`; this is the release the reference run resolved.
ARG MINIFORGE_VERSION=26.5.3-0
ARG MINIFORGE_SHA256=14db468222ad564658656f769506056209b6dc375f5e7dfd31eb5ebbf08fa529

ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-c"]

# The lock carries no compiler; build-essential gives the gcc 11.4.0 of the hosted ubuntu-22.04 image.
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
    test -f build_tools/github/install.sh; \
    echo "${LOCK_SHA256}  ${LOCK_FILE}" | sha256sum -c -

# build_tools/github/install.sh:61 and build_tools/shared.sh:65; the environment must equal the lock URL by URL.
RUN set -ex; \
    source build_tools/shared.sh; \
    CONDA_ALWAYS_YES=true create_conda_environment_from_lock_file testvenv "$LOCK_FILE"; \
    diff <(grep '^https://' "$LOCK_FILE" | sed 's/#.*//' | sort) \
         <(conda list --name testvenv --explicit | grep '^https://' | sed 's/#.*//' | sort); \
    conda clean --tarballs --yes

# build_tools/github/install.sh:136-140
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
