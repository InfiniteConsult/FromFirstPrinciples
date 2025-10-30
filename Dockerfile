# Article is the docs :)
FROM debian:12
LABEL authors="Infinite Consulting"

ARG py311="3.11.13"
ARG py312="3.12.11"
ARG py313="3.13.7"
ARG gcc15="15.2.0"
ARG USERNAME
ARG USER_UID
ARG USER_GID
ARG SSH_DIR
ARG INSTALL_CUDA_IN_CONTAINER="false"

RUN apt update \
    && apt install -y \
        build-essential ca-certificates cmake curl flex fontconfig \
        fonts-liberation git git-lfs gnupg2 iproute2 \
        less libappindicator3-1 libasound2 libatk-bridge2.0-0 libatk1.0-0 \
        libatspi2.0-0 libbz2-dev libcairo2 libcups2 libdbus-1-3 \
        libffi-dev libfl-dev libfl2 libgbm1 libgdbm-compat-dev \
        libgdbm-dev libglib2.0-0 libgtk-3-0 liblzma-dev libncurses5-dev \
        libnss3 libnss3-dev libpango-1.0-0 libreadline-dev libsqlite3-dev \
        libssl-dev libu2f-udev libx11-xcb1 libxcb-dri3-0 libxcomposite1 \
        libxdamage1 libxfixes3 libxkbcommon0 libxrandr2 libxshmfence1 \
        libxss1 libzstd-dev libzstd1 lzma m4 \
        nano netbase openssh-client openssh-server openssl \
        patch pkg-config procps python3-dev python3-full \
        python3-pip python3-tk sudo tmux tzdata \
        uuid-dev wget xvfb zlib1g-dev \
        linux-perf bpftrace bpfcc-tools tcpdump ethtool linuxptp hwloc numactl strace \
        ltrace \
    && apt upgrade -y \
    && install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt update \
    && apt install -y docker-ce-cli \
    && apt install -y \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false

# Conditionally install CUDA toolkit inside the container
RUN if [ "$INSTALL_CUDA_IN_CONTAINER" = "true" ]; then \
        echo "--- Installing CUDA Toolkit ---"; \
        wget https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/cuda-keyring_1.1-1_all.deb; \
        dpkg -i cuda-keyring_1.1-1_all.deb; \
        sudo apt update && sudo apt-get install -y cuda-tools-13-0 cuda-toolkit && \
        rm -rf /var/lib/apt/lists/* && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
        echo 'export PATH="/usr/local/cuda/bin:${PATH}"' > /etc/profile.d/cuda.sh; \
    fi

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && sed -i "s/#PubkeyAuthentication yes/PubkeyAuthentication yes/g" /etc/ssh/sshd_config \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME \
    && echo 'export GPG_TTY=$(tty)' >> /home/$USERNAME/.bashrc

RUN mkdir ~/deps && \
    cd ~/deps && \
    git clone --depth=1 -b releases/gcc-$gcc15 https://github.com/gcc-mirror/gcc.git && \
    cd gcc && \
    ./contrib/download_prerequisites && \
    mkdir build && cd build && \
    ../configure --disable-multilib --enable-languages=c,c++ && make -j 12 && make install  && \
    cd && rm -rf deps/gcc && \
    echo "export CC=/usr/local/bin/gcc" >> ~/.bashrc  && \
    echo "export CXX=/usr/local/bin/g++" >> ~/.bashrc  && \
    echo "export CC=/usr/local/bin/gcc" >> /home/$USERNAME/.bashrc  && \
    echo "export CXX=/usr/local/bin/g++" >> /home/$USERNAME/.bashrc


RUN for version in $py311 $py312 $py313; do \
        echo "--- Building Python version ${version} ---"; \
        wget https://github.com/python/cpython/archive/refs/tags/v${version}.tar.gz; \
        tar -xzf v${version}.tar.gz; \
        cd cpython-${version}; \
        \
        CONFIGURE_FLAGS="--enable-optimizations --enable-loadable-sqlite-extensions --with-lto=full"; \
        if [ "$version" = "$py313" ]; then \
            echo "--- Adding --disable-gil flag for nogil build ---"; \
            CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-gil"; \
        fi; \
        \
        ./configure $CONFIGURE_FLAGS; \
        make -j 12; \
        sudo make altinstall; \
        cd ..; \
    done && \
    rm -rf v*.tar.gz && \
    rm -rf cpython-*

USER $USERNAME
WORKDIR /home/$USERNAME

RUN curl https://sh.rustup.rs -sSf | sh -s -- -y


RUN python3.12 -m venv /home/$USERNAME/.venv_jupyter && \
    . /home/$USERNAME/.venv_jupyter/bin/activate && \
    python3 -m pip install --no-cache-dir jupyterlab

RUN curl -fsSL https://install.julialang.org | sh -s -- -y && \
    echo 'export PATH="/home/'$USERNAME'/.cargo/bin:/home/'$USERNAME'/.juliaup/bin:$PATH"' >> /home/$USERNAME/.bashrc && \
    . /home/$USERNAME/.venv_jupyter/bin/activate && \
    /home/$USERNAME/.juliaup/bin/julia -e 'using Pkg; Pkg.add("IJulia"); println("IJulia installation complete.");'

COPY --chown=$USERNAME:$USERNAME --chmod=700 $SSH_DIR /home/$USERNAME/.ssh

RUN cat /home/$USERNAME/.ssh/id_rsa.pub > /home/$USERNAME/.ssh/authorized_keys

RUN printf "Host github\n\
    HostName github.com\n\
    IdentityFile ~/.ssh/id_rsa\n\
    StrictHostKeyChecking no\n\
\n\
Host your-private-gitlab\n\
    HostName git.example.com\n\
    Port 2222\n\
    IdentityFile ~/.ssh/id_rsa\n\
    StrictHostKeyChecking no\n\
" > /home/$USERNAME/.ssh/config

COPY --chown=$USERNAME:$USERNAME --chmod=755 ./entrypoint.sh /entrypoint.sh

EXPOSE 22 8888 8889
ENTRYPOINT ["/entrypoint.sh"]
