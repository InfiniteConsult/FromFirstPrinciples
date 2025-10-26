# InfiniteConsulting Technical Articles & Development Environment
- email: info@infcon.co.za
- linkedin: https://www.linkedin.com/in/warren-jitsing-0ab3b21ab/

# Accelerate First. Accelerate Hard. No Latency.

![banner](banner.jpg)

---
## Overview

Welcome. This repository serves a dual purpose. It is both a collection of long-form, first-principles technical articles and the source code for the high-performance, containerized development environment in which they were written.

The primary goal is to provide a fully reproducible, professional-grade toolchain for C++, Python, and Rust development. By building this environment from the ground up using Docker, we directly solve the classic "it works on my machine" problem, ensuring that the code and the articles can be explored in a consistent and reliable setting.

## Core Philosophy

This project is guided by a few fundamental principles:

* **First-Principles Thinking**: We focus on understanding the "why" behind the technology. Instead of just using a tool, we deconstruct how it works, from the Linux kernel features that enable containers to the HTTP protocols that power web APIs.
* **Absolute Reproducibility**: The entire environment is defined as code (`Dockerfile`, shell scripts). This guarantees that any developer, on any machine that can run Docker, can spin up an identical setup, eliminating environmental drift and configuration errors.
* **High Performance as a Standard**: We reject stale, pre-packaged binaries. The environment custom-builds modern toolchains like GCC and experimental versions of Python (`nogil`), providing direct access to cutting-edge features and optimizations.

## Quick Start

These instructions will guide you through building and running the development environment. This process is designed to be straightforward, but the initial build can be time-intensive as it compiles the toolchains from source.

### 1\. Clone the Repository

First, clone this repository to your local machine and navigate into the project directory.

```shell
git clone https://github.com/InfiniteConsult/FromFirstPrinciples.git
cd LinkedInArticles
```

### 2\. Prepare the Host System

Next, run the host setup script. This will install Docker, which is the containerization engine that powers the entire environment. Note that this script requires `sudo` privileges to install system packages.

```shell
bash install-docker.sh
```

### 3\. Configure the Environment (Optional)

The environment can be customized, for example, to enable NVIDIA GPU support for machine learning tasks. To see and set these options, use the `configure.sh` script. If you skip this step, the environment will be built with default (CPU-only) settings.

```shell
# Example: To enable GPU support
bash configure.sh --enable-gpu
```

### 4\. Build the Docker Image

This script builds the container image as defined in the `Dockerfile`. The initial build is a one-time process and may take a significant amount of time. Subsequent builds will be much faster, as Docker will reuse cached layers for steps that have not changed.

```shell
bash build-dev.sh
```

### 5\. Run the Container

This command starts the container, mounting the necessary local directories and exposing the service ports. All services (SSH, JupyterLab, and the Article Viewer) will start automatically in the background.

```shell
bash dev-container.sh
```

### 6\. Access Your Services

Once the container is running, you can access its services:

  * **SSH / IDE Connection**: Connect directly to the container's shell or use a remote-capable IDE (like VS Code or a JetBrains IDE) for a full-featured development experience.
    ```shell
    ssh -p 10200 your_username@127.0.0.1
    ```
  * **JupyterLab**: Access the interactive web IDE for data science and prototyping.
    `https://127.0.0.1:10201`
  * **Article Viewer**: Read the articles in the live, self-hosted viewer.
    `https://127.0.0.1:10202`

## Repository Structure

The repository is organized into several distinct directories. This structure is deliberate, creating a clean separation between the environment's definition, the source content, and your personal workspace.

### Core Environment Files (Root `/`)
The files in the root directory are the **engine** that builds and controls the entire containerized environment. These include:
* `Dockerfile`: The blueprint for the container image.
* `build-dev.sh`: The script to build the image.
* `dev-container.sh`: The script to run the container.
* `entrypoint.sh`: The script that runs inside the container on startup.
* `configure.sh` & `dev.conf`: The system for customizing your build (e.g., enabling GPU support).

For a complete, first-principles deconstruction of how these files work, please read the article located in `articles/0002_docker_dev_environment/`. Understanding this article is key to customizing and maintaining the environment.

### `articles/`
This directory is the knowledge base of the repository. It contains the source code and text for all the technical articles, with each sub-folder representing a single article.

### `viewer/`
This directory contains the source code for the self-contained FastAPI web application that serves and renders the content from the `articles/` directory.

### `repos/`
This is your **persistent, mounted workspace**. It is the ideal location to clone your own Git repositories and do your development work. Because it is mounted directly from your host machine, any work you do here is safe and separate from the container's internal filesystem and will persist even if the container is rebuilt. This separation prevents your personal projects from being accidentally mixed with the core repository's source code.

### `data/`
This is a **persistent, mounted storage directory** for miscellaneous files that should persist between container runs. This is not for active development, but for configuration and stateful data. By default, it is used for:
* Importing your `.gitconfig` and GPG keys to maintain your identity.
* Storing the auto-generated, self-signed TLS certificates for the services.ed, self-signed TLS certificates for the JupyterLab and viewer services.
