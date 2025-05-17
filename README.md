# ScalaDev

A Docker image providing a ready-to-use Scala 3 development environment. Ideal as a base for VS Code DevContainers or standalone use.

## Features

* **Non-root user** `scaladev` with sudo privileges
* **Locale** configured to `en_US.UTF-8`
* **Core tools**: `curl`, `wget`, `git` (with LFS), `make`, `gcc`/`g++`, `nano` (with syntax highlighting), `postgresql-client`, Python 3, etc.
* **Docker CLI & Compose** (via host socket)
* **kubectl** (latest stable) + bash completion + `k` alias
* **Java 21 JDK**
* **Scala 3.7.0** (`scala` on `$PATH`)
* **sbt 1.10.11** (`sbt` on `$PATH`)

## Quick Usage

1. **Clone** repo

   ```bash
   git clone https://github.com/brakmic/ScalaDev.git
   cd ScalaDev
   ```

2. **Build** image

   ```bash
   docker build \
     --build-arg NONROOT_USER=scaladev \
     --tag scala-dev:3.7.0 .
   ```

3. **Run** interactive shell (with Docker access)

   ```bash
   docker run --rm -it \
     -v "$PWD":/workspace \
     -v /var/run/docker.sock:/var/run/docker.sock \
     -w /workspace \
     scala-dev:3.7.0
   ```

   Now you can run `docker ps` or `docker compose` directly inside the container.

## Accessing Kubernetes

1. Copy your `~/.kube/config` into the container:

   ```bash
   docker run --rm -it \
     -v "$HOME/.kube/config":/home/scaladev/.kube/config:ro \
     -w /workspace \
     scala-dev:3.7.0
   ```

2. If you’re using Docker-Desktop’s Kubernetes, edit the `server:` entries in that config:

   ```yaml
   clusters:
   - name: docker-desktop
     cluster:
       server: https://docker-for-desktop:6443
   ```

   or for KinD:

   ```yaml
       server: https://desktop-control-plane:6443
   ```

   Then you can `kubectl get pods` from inside.

## VS Code DevContainer

Place this in `.devcontainer/devcontainer.json`:

```json
{
  "name": "My Scala DevContainer",
  "image": "brakmic/scaladev:latest",
  "workspaceFolder": "/workspace",
  "workspaceMount": "source=${localWorkspaceFolder},target=/host_workspace,type=bind,consistency=cached",
  "customizations": {
    "vscode": {
      "settings": {
        "files.exclude": {
          "**/.git": true,
          "**/.DS_Store": true
        }
      }
    }
  },
  "mounts": [
    "source=${localWorkspaceFolder}/.devcontainer/setup-workspace.mjs,target=/workspace/.devcontainer/setup-workspace.mjs,type=bind",
    "source=/var/run/docker.sock,target=/var/run/docker.sock,type=bind"
  ],
  "forwardPorts": [
    8080,
    9990,
    8081,
    8443,
    9993,
    9994,
    5432
  ],
  "initializeCommand": "docker network inspect devnetwork >/dev/null 2>&1 || docker network create devnetwork",
  "runArgs": [
    "--network=devnetwork",
    "--add-host=host.docker.internal:host-gateway",
    "--add-host=desktop-control-plane:host-gateway",
    "--add-host=docker-for-desktop:host-gateway"
  ],
  "postCreateCommand": "node /workspace/.devcontainer/setup-workspace.mjs && ln -sf /workspace/dev.code-workspace /home/scaladev/.vscode-server/dev.code-workspace",
  "remoteUser": "scaladev",
  "containerEnv": {
    "HOST_WORKSPACE": "${localWorkspaceFolder}"
  }
}
```

### What you get

* **Docker inside**: mount `/var/run/docker.sock` and use all Docker-CLI & Compose commands
* **Kubernetes inside**: mount your `~/.kube/config` and hit any cluster (adjust `server:` to `docker-for-desktop` or `desktop-control-plane`)
* **Port forwarding**: map your common dev ports (Scala apps, Keycloak, Postgres, WildFly…)
* **Custom init**: create networks, run setup scripts, link workspaces

## Customization

* Override **SCALA_VERSION**, **SBT_VERSION**, **NONROOT_USER** with `--build-arg`
* Extend this image in your own `Dockerfile` (`FROM scala-dev:3.7.0`) to add tools or services

## License

[MIT](./LICENSE)
