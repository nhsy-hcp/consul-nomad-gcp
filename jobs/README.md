# Nomad Jobs Directory

This directory contains example Nomad job definitions for various workloads that can be deployed on the Consul/Nomad GCP infrastructure.

## Available Jobs

### 🔄 Infrastructure Services

#### `traefik.nomad`
**Reverse Proxy & Load Balancer**
- **Purpose**: HTTP/HTTPS ingress controller with automatic SSL certificates
- **Type**: Service job
- **Resources**: 500 MHz CPU, 512 MB RAM
- **Features**:
  - Automatic Let's Encrypt SSL certificates
  - Consul service discovery integration
  - Dashboard accessible at `:8443/dashboard`
  - Automatic HTTP to HTTPS redirection
- **Ports**: 80 (HTTP), 443 (HTTPS), 8443 (Dashboard)
- **Configuration**: Uses templated TOML config with Consul integration

#### `traefik-example.nomad`
**Parameterized Traefik Configuration**
- **Purpose**: Alternative Traefik setup with configurable variables
- **Variables**: `consul_token`, `domain`, `letsencrypt_email`
- **Differences**: More flexible configuration through variables

#### `traefik-volume.hcl`
**Traefik Volume Definition**
- **Purpose**: Host volume specification for Traefik ACME certificates
- **Type**: Single-node-single-writer host volume
- **Plugin**: Built-in `mkdir` plugin

### 🚀 Application Examples

#### `echoserver.nomad`
**Simple HTTP Echo Server**
- **Purpose**: Basic HTTP service for testing ingress and load balancing
- **Image**: `gcr.io/google_containers/echoserver:1.10`
- **Type**: Service job (2 instances)
- **Resources**: 50 MHz CPU, 64 MB RAM
- **Features**:
  - HTTP health checks
  - Traefik integration with SSL
  - Minimal resource footprint

#### `helloworld.nomad`
**Java Spring Boot Application**
- **Purpose**: Demonstrates Java application deployment
- **Driver**: Native Java driver (not Docker)
- **Type**: Service job
- **Resources**: 100 MHz CPU, 512 MB RAM
- **Features**:
  - Artifact download from GitHub releases
  - SHA256 checksum verification
  - JVM memory configuration
  - Traefik integration

### 🧠 AI/ML Workloads

#### `openui.nomad`
**OpenUI + Ollama Stack**
- **Purpose**: AI chat interface with local LLM backend
- **Type**: Service job with 2 tasks
- **Tasks**:
  - **ollama-server**: LLM inference engine
    - Resources: 3 CPU cores, 12 GB RAM, 1 NVIDIA GPU
    - Image: `ollama/ollama`
    - Port: 11434 (API)
  - **openui**: Web interface
    - Resources: 1 CPU core, 3 GB RAM
    - Image: `ghcr.io/open-webui/open-webui:cuda`
    - Port: 8080 (HTTP)
- **Features**:
  - GPU acceleration for LLM inference
  - Web search integration
  - Persistent data storage
  - Traefik SSL integration
- **Configuration**: Optimized for medium usage (3-5 users, 7B models)

#### `jupyter.nomad`
**Jupyter Notebook Server**
- **Purpose**: Data science and ML development environment
- **Image**: `jupyter/scipy-notebook:latest`
- **Type**: Service job
- **Resources**: 1 CPU core, 2 GB RAM
- **Features**:
  - JupyterLab interface
  - Password protection (configurable)
  - Persistent workspace storage
  - Sudo access enabled
  - Traefik SSL integration

### 🧪 Testing & Development

#### `gpu-test.nomad`
**GPU Functionality Test**
- **Purpose**: Verify NVIDIA GPU availability and functionality
- **Type**: Batch job
- **Node Pool**: GPU nodes only
- **Resources**: 1 NVIDIA GPU
- **Image**: `nvidia/cuda:12.8.1-base-ubuntu22.04`
- **Behavior**: Runs `nvidia-smi` and sleeps for 5 minutes

## Deployment Instructions

### Prerequisites
1. Deployed Consul/Nomad infrastructure (see main README.md)
2. Environment variables configured:
   ```bash
   eval $(terraform output -raw eval_vars)
   ```

### Deploy Individual Jobs
```bash
# Deploy Traefik first (required for ingress)
nomad job run jobs/traefik.nomad

# Deploy applications
nomad job run jobs/echoserver.nomad
nomad job run jobs/helloworld.nomad
nomad job run jobs/jupyter.nomad
nomad job run jobs/openui.nomad

# Test GPU functionality
nomad job run jobs/gpu-test.nomad
```

### Deploy All Example Jobs
```bash
# Use the task runner
task run-jobs

# Or manually
nomad job run jobs/traefik.nomad
nomad job run jobs/echoserver.nomad
```

### Access Applications
Applications are accessible via HTTPS with automatic SSL certificates:
- **Traefik Dashboard**: `https://ingress.<your-domain>:8443/dashboard`
- **EchoServer**: `https://echoserver.ingress.<your-domain>`
- **HelloWorld**: `https://helloworld.ingress.<your-domain>`
- **Jupyter**: `https://jupyter.ingress.<your-domain>`
- **OpenUI**: `https://open-webui.ingress.<your-domain>`

## Job Management

### Check Job Status
```bash
nomad job status <job-name>
nomad alloc logs <allocation-id>
```

### Stop Jobs
```bash
nomad job stop <job-name>

# Stop all jobs
task purge-jobs
```

### Resource Requirements

| Job | CPU | Memory | GPU | Special Requirements |
|-----|-----|--------|-----|---------------------|
| traefik | 500 MHz | 512 MB | - | Host networking |
| echoserver | 50 MHz | 64 MB | - | - |
| helloworld | 100 MHz | 512 MB | - | Java driver |
| jupyter | 1000 MHz | 2 GB | - | Host volume |
| openui | 4000 MHz | 15 GB | 1 GPU | GPU node pool |
| gpu-test | - | - | 1 GPU | GPU node pool |

## Node Pool Requirements

- **default**: Most applications (CPU-only workloads)
- **gpu**: GPU-enabled applications (openui, gpu-test)

## Volume Requirements

Some jobs require host volumes to be configured on the Nomad clients:
- `traefik`: ACME certificate storage
- `jupyter`: Persistent notebook storage
- `openui`: Model and data persistence

## Troubleshooting

### Common Issues
1. **Job pending**: Check node pool and resource availability
2. **GPU not available**: Ensure GPU node pool has available resources
3. **SSL certificate issues**: Check Traefik logs and Let's Encrypt rate limits
4. **Service discovery**: Verify Consul integration is working

### Useful Commands
```bash
# Check node resources
nomad node status -verbose

# View job logs
nomad alloc logs -f <allocation-id>

# Check service registration
consul catalog services
```