# ScalaDev

A Docker image providing a ready-to-use Scala 3 development environment. Ideal as a base for VS Code DevContainers or standalone use.

## Features

* **Non-root user** `scaladev` with sudo privileges
* **Locale** configured to `en_US.UTF-8`
* **Core tools**: `curl`, `wget`, `git` (with LFS), `make`, `gcc`/`g++`, `nano` (with syntax highlighting), `postgresql-client`, Python 3, etc.
* **Docker CLI & Compose** (via host socket)
* **kubectl** (latest stable) + bash completion + `k` alias
* **Node.js v22** (with npm)
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

2. If you're using Docker-Desktop's Kubernetes, edit the `server:` entries in that config:

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
  "initializeCommand": "docker network inspect devnetwork >/dev/null 2>&1 || docker network create devnetwork 2>/dev/null || true",
  "runArgs": [
    "--network=devnetwork",
    "--add-host=host.docker.internal:host-gateway",
    "--add-host=desktop-control-plane:host-gateway",
    "--add-host=docker-for-desktop:host-gateway"
  ],
  "postCreateCommand": "node /workspace/.devcontainer/setup-workspace.mjs && ln -sf /workspace/dev.code-workspace /home/scaladev/.vscode-server/dev.code-workspace",
  "remoteUser": "scaladev",
  "containerEnv": {
    "NODE_OPTIONS": "",
    "HOST_WORKSPACE": "${localWorkspaceFolder}"
  }
}
```

### What you get

* **Docker inside**: mount docker.sock and use all Docker-CLI & Compose commands
* **Kubernetes inside**: mount your `~/.kube/config` and hit any cluster (adjust `server:` to `docker-for-desktop` or `desktop-control-plane`)
* **Port forwarding**: map your common dev ports (Scala apps, Keycloak, Postgres, WildFly…)
* **Custom init**: create networks, run setup scripts, link workspaces

### Setup Workspace Script

The DevContainer configuration references a setup script (setup-workspace.mjs) that automatically configures a VS Code multi-root workspace. Place this file in your .devcontainer directory:

```javascript
import fs from "fs";
import path from "path";

// Workspace file path
const workspaceFilePath = "/workspace/dev.code-workspace";

// Ensure the directory for the workspace file exists
const dirPath = path.dirname(workspaceFilePath);
if (!fs.existsSync(dirPath)) {
  fs.mkdirSync(dirPath, { recursive: true });
}

// Define the workspace configuration
const workspaceConfig = {
  folders: [
    {
      name: "DevContainer Workspace",
      path: "/workspace"
    },
    {
      name: "Host Workspace",
      path: "/host_workspace"
    },
    {
      name: "Demos",
      path: "/host_workspace/demos"
    },
    {
      name: "Scratchpad",
      path: "/host_workspace/scratchpad"
    },
  ],
  settings: {}
};

// Write the workspace file
fs.writeFileSync(workspaceFilePath, JSON.stringify(workspaceConfig, null, 2));
console.log(`Workspace file created: ${workspaceFilePath}`);
```

This script:

* Creates a VS Code workspace file that organizes your development environment
* Defines multiple workspace folders for different aspects of your project
* Links both container paths (workspace) and host-mounted paths (host_workspace)
* Simplifies navigation between different parts of your codebase
* Can be customized to add more folders, VS Code settings, or extensions

The workspace configuration is activated automatically when the container starts through the `postCreateCommand` in devcontainer.json.

## Customization

* Override **SCALA_VERSION**, **SBT_VERSION**, **NONROOT_USER** with `--build-arg`
* Extend this image in your own `Dockerfile` (`FROM scala-dev:3.7.0`) to add tools or services

## License

[MIT](./LICENSE)
