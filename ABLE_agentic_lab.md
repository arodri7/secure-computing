# Deploying Agentic Lab Academy on ABLE

This guide provides step-by-step instructions for deploying and running **[Agentic Lab Academy](https://github.com/tnnandi/agentic_lab_academy)** within the ABLE (Advanced Bioinformatics Learning Environment) secure computing environment at Argonne National Laboratory.

Agentic Lab Academy is a multi-agent research workflow system that uses LLMs to automate scientific discovery tasks: literature review, research planning, code generation, execution, and iterative refinement. **On ABLE, it supports local code execution only—job submission to other HPC systems (Polaris, Aurora, Sophia) is not possible due to ABLE's air-gapped architecture.**

## Table of Contents

- [Overview](#overview)
- [ABLE Architecture](#able-architecture)
- [Prerequisites](#prerequisites)
- [System Requirements](#system-requirements)
- [Step 1: Initial Setup](#step-1-initial-setup)
- [Step 2: Data Transfer from Polaris](#step-2-data-transfer-from-polaris)
- [Step 3: Clone Repository](#step-3-clone-repository)
- [Step 4: Configure Conda Environment](#step-4-configure-conda-environment)
- [Step 5: Configure LLM Backend](#step-5-configure-llm-backend)
  - [Step 5B: Configure Local PyPI (Optional)](#step-5b-configure-local-pypi-optional-if-available-on-able)
- [Step 6: Running the Framework](#step-6-running-the-framework)
- [Understanding the Framework](#understanding-the-framework)
- [Troubleshooting](#troubleshooting)
- [References](#references)

---

## Overview

**[Agentic Lab Academy](https://github.com/tnnandi/agentic_lab_academy)** is a composable, multi-agent research automation system that:

- Breaks research tasks into coordinated agent workflows (PI Planning, Research, Code Writing, Code Execution, Review, Critique)
- Generates Python code based on your research objectives
- Executes code locally on ABLE login nodes (the only execution mode available on ABLE)
- Automatically refines code based on execution failures
- Maintains persistent artifacts (logs, generated scripts, results) for reproducibility
- Provides human-in-the-loop checkpoints for plan approval and iteration control

**Common use cases on ABLE:**
- Single-cell RNA-seq analysis and QC (like the example: radiation exposure Geneformer QC)
- Genomics data processing pipelines
- Bioinformatics feature engineering
- Multi-step computational biology workflows

**Key advantage over manual scripting**: You describe *what* you want to analyze (topic, data, requirements), and the agents collectively generate, test, and refine the *how*.

---

## ⚠️ CRITICAL: Ollama is the ONLY LLM Backend on ABLE

**This is not a choice—it is a hard constraint due to ABLE's architecture.**

ABLE is an **air-gapped, isolated environment with NO internet access** from login or compute nodes. This means:

- ❌ **Cloud-based LLM backends WILL NOT WORK**: OpenRouter, ALCF Sophia vLLM endpoints, any API-based service requiring internet calls
- ✅ **ONLY [Ollama](https://ollama.com) works**: Local LLM inference deployed on ABLE infrastructure
- 🔒 The security design is intentional—air gaps protect sensitive research data

The original agentic_lab_academy framework supports multiple backends (ollama, openrouter, alcf_sophia), but on ABLE, attempting to use anything other than Ollama will fail with:

```
ConnectionError: Failed to connect to [REMOTE_API_ENDPOINT]
TimeoutError: [Errno 110] Connection timed out
```

**Configuration for ABLE must be:**

```python
LLM_CONFIG = {
    "source": "ollama",                          # ALWAYS "ollama" on ABLE
    "model": "[YOUR_LOCAL_MODEL_NAME]",         # e.g., "mistral", "neural-chat"
    "api_endpoint": "http://localhost:11434",   # ALWAYS local Ollama endpoint
    "temperature": 0.7,
    "max_tokens": 2048,
}
```

Do not attempt to override this with cloud backends. If you need higher-capability models, coordinate with ABLE/ALCF support about deploying additional Ollama models locally.

---

## ⚠️ IMPORTANT: ABLE is Isolated—No External HPC Job Submission

**ABLE is an air-gapped sandbox environment that is isolated from other ALCF systems.**

This means:

- ❌ **Cannot submit jobs to Polaris** (access blocked; Polaris is external to ABLE)
- ❌ **Cannot submit jobs to Aurora** (access blocked; Aurora is external to ABLE)
- ❌ **Cannot submit jobs to Sophia** (access blocked; Sophia is external to ABLE)
- ✅ **Can ONLY execute jobs locally on ABLE login/compute nodes**
- ✅ **Can potentially use ABLE's scheduler if available** (contact ABLE support for details)

The `--use_hpc` flag in agentic_lab_academy is designed for ALCF Sophia/Polaris job submission via PBS `qsub`. **This will NOT work on ABLE.** Do not attempt it.

**All computations must run locally within ABLE's isolated environment.**

If your research requires computational resources beyond what ABLE provides:
1. Complete initial development and testing on ABLE using local execution
2. Export your refined scripts and data
3. Run larger workloads on Polaris or other systems outside of ABLE

---

## ABLE Architecture

ABLE is a secure, air-gapped computing environment with distinct node types and intentional connectivity barriers:

| Node Type | Internet Access | Purpose | Example Hostname |
|-----------|-----------------|---------|------------------|
| **Runtime Nodes (Sandbox)** | ✅ Yes | Package installation, downloads, pip/conda operations | `svr-rk1-ableruntime` |
| **Login Nodes (Air-gapped ABLE)** | ❌ No | Job submission, interactive development, script execution | `svr-rk1-ablelogin` |
| **Compute Nodes (Air-gapped ABLE)** | ❌ No | Execution of submitted jobs | Various (managed by scheduler) |

### Why Two-Node Setup Matters

ABLE intentionally separates internet-connected and air-gapped environments for security:

```
Internet-Connected (Runtime):
  └─ Download packages, access pip/conda repositories
     └─ Create conda environments with all dependencies

Air-Gapped (Login/Compute):
  └─ Access environments created on runtime node
  └─ Submit jobs, run frameworks, generate results
  └─ NO internet access (security by design)
```

**Critical principle**: You must install packages on the **runtime node**, then configure the login node to access them via a `.condarc` file pointing to `/ableruntime/[USERNAME]/.conda/envs/`.

### Data Flow in ABLE

```
External System (Polaris, Local Computer)
    │
    ├─→ SFTP Ingress DTN
    │   (ingress-abledtn.cels.anl.gov)
    │   └─→ /ableinbox/[USERNAME]/
    │
    └─→ ABLE Secure Environment
        │
        ├─ Login Node (Non-Internet)
        │  ├─ Clone agentic_lab_academy
        │  ├─ Activate conda environment
        │  ├─ Configure LLM backend (Ollama)
        │  └─ Execute: python -m agentic_lab_academy.main ...
        │
        ├─ Runtime Node (Internet)
        │  └─ pip install -r requirements.txt
        │     (during initial conda environment setup)
        │
        └─ Results → SFTP Egress DTN
            (egress-abledtn.cels.anl.gov)
            └─→ /ableoutbox/[USERNAME]/
                (download to local machine)
```

---

## Prerequisites

### ⚠️ CRITICAL: No Internet Access on ABLE Login/Compute Nodes

Before proceeding, understand these **hard architectural constraints**:

- **ABLE login nodes and compute nodes have NO internet access** (by design, for security)
- **ABLE is isolated from other ALCF systems** – cannot submit to Polaris, Sophia, Aurora, etc.
- This means:
  - ✅ All LLM inference must be local (Ollama only)
  - ✅ Code execution must be local (CodeExecutorAgent only)
  - ❌ Cloud-based services (OpenRouter, OpenAI, etc.) are unreachable
  - ❌ External HPC job submission (Polaris, Sophia) is not possible
  - ❌ Web scraping or URL fetching will fail
  - ❌ PyPI dependencies cannot be downloaded during job execution (only during setup)

**If you need cloud-based services or external HPC access, this is not the right environment.** ABLE is intentionally isolated for security.

### Required Access & Credentials

- **ABLE Account**: Active user credentials on ABLE sandbox
- **HSPD-12 Smart Card**: Configured for SFTP authentication to DTN nodes
- **Polaris Access** (optional): If transferring data from Polaris system
- **GitHub Access**: Ability to clone repositories (try runtime node if login node blocks it)
- **Ollama Access**: Ollama LLM service must be [pre-deployed and running on ABLE](https://github.com/arodri7/secure-computing/blob/main/README.md)

### Local Machine Setup

#### Mac Users

Configure SSH to support HSPD-12 smart card authentication:

```bash
# Edit ~/.ssh/config and add:
PKCS11Provider=/usr/lib/ssh-keychain.dylib
```

Test connectivity to ABLE's DTN:

```bash
# Test ingress (upload) connection - you should be prompted for PIN
sftp ingress-abledtn.cels.anl.gov

# Type 'quit' to exit
quit
```

#### Linux/Windows Users

[**Provide platform-specific HSPD-12 setup for your environment - typically involves OpenSC or similar**]

---

## System Requirements

### ABLE Environment

- **Login Node**: `svr-rk1-ablelogin` (non-internet, used for job submission)
- **Runtime Node**: `svr-rk1-ableruntime` (internet-connected, used for package installation)
- **Conda**: Miniforge is available system-wide at `/ableruntime/software/miniforge`
- **Storage**: [**Specify your storage allocation and home directory path**]

### Framework Requirements

Based on agentic_lab_academy dependencies:

- **Python**: 3.9+ (recommend 3.11 or 3.12)
- **Key Dependencies**:
  - `academy` (ProxyStore agent middleware)
  - `pydantic` (configuration management)
  - `requests` (HTTP client for Ollama/API calls)
  - `aiohttp` (async HTTP for agent communication)
  - `pdfplumber` or `pypdf` (PDF parsing for research papers)
  - `arxiv` (arXiv paper API client)
  - Additional bioinformatics libraries as needed for your use case (scanpy, anndata, etc.)

- **Ollama**: Local LLM inference service ([pre-deployed on ABLE](https://github.com/arodri7/secure-computing/blob/main/README.md) or accessed via API)
- **Disk Space**: [**Specify minimum disk space needed for conda environment + workspace outputs**]
- **Memory**: [**Specify minimum RAM for agents + code execution**]

### Optional: ABLE-Hosted PyPI Repository

One of the key limitations of ABLE's air-gapped architecture is that **the Code Executor Agent cannot dynamically install packages from the internet** during code execution. However, this can be mitigated with an **ABLE-hosted PyPI repository**.

**Current Behavior (without local PyPI)**:
- Pre-install all dependencies in your conda environment before running the framework
- If generated code tries to `pip install [PACKAGE]` at runtime, it will fail with `Could not find a version that satisfies the requirement`

**Potential Solution (with ABLE-hosted PyPI)**:
- Deploy a local PyPI mirror or private package repository on ABLE infrastructure
- Point pip to this local repository instead of the public PyPI
- Allow agents' generated code to install packages dynamically during execution

**If your ABLE deployment includes a local PyPI repository**:

The repository should be accessible from login nodes. Configure it by:

```bash
# Create or edit ~/.pip/pip.conf
cat > ~/.pip/pip.conf << 'EOF'
[global]
index-url = http://[ABLE_PYPI_HOST]:[PORT]/simple/
# Example: http://localhost:8080/simple/
EOF

# Test the connection
pip index versions numpy  # Should work if repo is reachable
```

When the Code Executor Agent runs generated code, it will use this local PyPI mirror instead of trying to reach the public PyPI.

**Contact ABLE support to inquire about**:
1. Whether a local PyPI mirror is available on ABLE
2. The hostname and port of the local PyPI repository
3. Which packages are available in the mirror
4. Procedures for adding new packages to the mirror

When the Code Executor Agent runs generated code, it will use this local PyPI mirror instead of trying to reach the public PyPI.

**Contact ABLE support to inquire about**:
1. Whether a local PyPI mirror is available on ABLE
2. The hostname and port of the local PyPI repository
3. Which packages are available in the mirror
4. Procedures for adding new packages to the mirror

For now, **plan for pre-installing all required packages in your conda environment during the setup phase**.

---

## Step 5B: Configure Local PyPI (Optional, if available on ABLE)

If your ABLE deployment includes an ABLE-hosted PyPI repository, configure pip to use it on the **login node**:

```bash
# Create pip configuration to use local PyPI
mkdir -p ~/.pip
cat > ~/.pip/pip.conf << 'EOF'
[global]
index-url = http://[**ABLE_PYPI_HOSTNAME**]:[**PORT**]/simple/
# Example: http://pypi-mirror.able.anl.gov:8080/simple/
EOF

# Verify the configuration
cat ~/.pip/pip.conf

# Test that the local PyPI is reachable
pip index versions numpy

# If successful, you should see versions of numpy available from the local mirror
```

**Advantages of configuring local PyPI**:
- Code Executor Agent can dynamically install packages during execution
- Less need to pre-install every dependency up front
- More flexible for exploratory research workflows

**Contact ABLE support for**:
- Availability and hostname/port of local PyPI
- How to request additional packages be added to the mirror
- Authentication credentials (if required)

If no local PyPI is available, proceed to Step 6 and pre-install all packages in your conda environment.

---

## Step 1: Initial Setup

### 1A: Connect to ABLE Login Node

```bash
ssh username@svr-rk1-ablelogin
```

### 1B: Create Working Directory

```bash
# Create a directory for agentic_lab_academy
mkdir -p ~/agentic_lab
cd ~/agentic_lab

# Verify you're on the login node (non-internet)
hostname
# Output should show: svr-rk1-ablelogin or similar
```

### 1C: Verify Ollama is Running

```bash
# Check if Ollama service is accessible
curl http://localhost:11434/api/tags

# Expected output: list of available models
# If connection fails, Ollama may not be running or API endpoint differs
# Contact ABLE support or check with your team on Ollama deployment
```

---

## Step 2: Data Transfer from Polaris

If your research uses data from Polaris, transfer it to ABLE before running the framework.

### 2A: Prepare Data on Polaris

```bash
# On Polaris login node
ssh username@polaris.alcf.anl.gov

# Navigate to your project data
cd /grand/[PROJECT]/[YOUR_DATA_DIRECTORY]/

# List files you need
ls -la *.h5ad
# or .mtx, .tsv, .csv, etc.

# [**Add your specific data preparation commands**]
# Example: If using Geneformer-style single-cell data:
# - GSM8080315_sample1_R0_barcodes.tsv.gz
# - GSM8080315_sample1_R0_features.tsv.gz
# - GSM8080315_sample1_R0_matrix.mtx.gz
# [Create staging directory if needed]
```

### 2B: Transfer to ABLE via SFTP

From your **local machine**, use SFTP to upload data:

```bash
# Start SFTP ingress connection (upload-only)
sftp ingress-abledtn.cels.anl.gov

# When prompted, enter your PIN (from your HSPD-12 smart card)

# You'll be placed in /ableinbox/[your_username]
pwd

# Upload your data files
cd [LOCAL_DIRECTORY_WITH_YOUR_DATA]
put [**FILENAME**]

# For multiple files
mput *.gz
mput *.mtx

# Verify upload
ls -la

# Exit
quit
```

### 2C: Retrieve Data on ABLE

On the **ABLE login node**:

```bash
# List files in your inbox
ls -la /ableinbox/[YOUR_USERNAME]/

# Create data directory in your working directory
mkdir -p ~/agentic_lab/data

# Copy data from inbox to your workspace
cp /ableinbox/[YOUR_USERNAME]/GSM* ~/agentic_lab/data/

# Verify transfer
ls -la ~/agentic_lab/data/
```

---

## Step 3: Clone Repository

### 3A: Clone agentic_lab_academy

On the **ABLE login node**:

```bash
cd ~/agentic_lab

# Clone the repository
git clone https://github.com/tnnandi/agentic_lab_academy.git
cd agentic_lab_academy

# List the framework structure
ls -la
```

### 3B: Understand Directory Structure

```
agentic_lab_academy/
├── README.md                    # Original framework documentation
├── requirements.txt             # Python dependencies
├── pyproject.toml               # Project configuration
├── main.py                      # CLI entry point
├── academy_agents.py            # Agent implementations
├── config.py                    # LLM configuration defaults
├── llm.py                       # Backend-agnostic LLM interface
├── prompts.py                   # Prompt templates for agents
├── models.py                    # Data models (Pydantic)
├── utils.py                     # PDF/link parsing, file utilities
├── workflows/
│   └── orchestrator.py          # Async agent orchestration
└── workspace_runs/              # Timestamped outputs (created at runtime)
```

---

## Step 4: Configure Conda Environment

ABLE's internet separation requires a **two-phase conda setup**: install packages on the runtime node (internet), then access them from the login node (no internet).

### Phase 1: Create Environment on Runtime Node (Internet-Connected)

```bash
# SSH into the runtime node
ssh username@svr-rk1-ableruntime

# Source conda initialization
. /ableruntime/software/miniforge/etc/profile.d/conda.sh

# Create a new environment for agentic_lab
conda create -n agentic_lab python=3.11

# Activate it
conda activate agentic_lab

# Install dependencies from requirements.txt
# (First, you need to get the requirements.txt file there)
cd ~/agentic_lab/agentic_lab_academy
pip install -r requirements.txt

# IMPORTANT: Install additional packages that your research code will need
# The Code Executor Agent will try to auto-install missing packages during execution,
# but it's better to pre-install everything here to avoid runtime delays.
# Examples:
pip install scanpy anndata numpy scipy pandas scikit-learn matplotlib seaborn
# Add any domain-specific packages your analysis requires

# Verify critical packages are installed
pip list | grep -E "academy|pydantic|requests"

# You should see output like:
# academy          0.X.X
# pydantic         2.X.X
# requests         2.X.X

# Exit the runtime node when done
exit
```

**Note on Package Installation**: Since the Code Executor Agent runs on non-internet login nodes, it cannot dynamically install packages from public PyPI. However, if your ABLE deployment includes an ABLE-hosted PyPI repository, the agent can use it to install additional packages at runtime. Coordinate with ABLE support to set this up.

### Phase 2: Configure Login Node to Access Environment (Non-Internet)

Back on the **login node**:

```bash
# Create .condarc file pointing to your conda environments on the runtime node
cat > ~/.condarc << 'EOF'
envs_dirs:
  - /ableruntime/[YOUR_USERNAME]/.conda/envs
EOF

# Verify the configuration
cat ~/.condarc

# Source conda initialization
. /ableruntime/software/miniforge/etc/profile.d/conda.sh

# List available environments (should include agentic_lab)
conda env list

# You should see:
# base                     /ableruntime/software/miniforge
# agentic_lab              /ableruntime/[YOUR_USERNAME]/.conda/envs/agentic_lab

# Activate the environment
conda activate agentic_lab

# Verify critical packages can be imported
python -c "import academy; import pydantic; print('Packages loaded successfully')"

# Deactivate for now (you'll reactivate when running the framework)
conda deactivate
```

### Important Notes on Conda

- **Every login**: You must source the conda script and reactivate your environment
- **Environment persistence**: Your environment is stored on the runtime node's filesystem and accessible from any login node via `.condarc`
- **Package updates**: If you need to add packages later, SSH back to the runtime node, activate `agentic_lab`, and `pip install [PACKAGE]`

---

## Step 5: Configure LLM Backend

**IMPORTANT**: On ABLE, you have only ONE LLM backend option: **Ollama**. Cloud-based backends will not work due to internet restrictions.

### 5A: Understand Why Ollama is Required

| Backend | Status on ABLE | Reason |
|---------|----------------|--------|
| **Ollama (local)** | ✅ **WORKS** | Runs locally on ABLE; no internet required |
| OpenRouter | ❌ Fails | Requires internet to reach openrouter.ai API |
| ALCF Sophia vLLM | ❌ Fails | Requires internet to reach ALCF endpoints |
| Any cloud API | ❌ Fails | ABLE login nodes cannot access external internet |

**This is not configurable.** The air gap between ABLE and the internet is intentional and cannot be bypassed.

### 5B: Verify Ollama is Deployed and Running

On the **login node**, check that Ollama is accessible:

```bash
# Test Ollama API endpoint
curl http://localhost:11434/api/tags

# Expected successful output (JSON):
# {"models": [{"name": "mistral:latest", ...}, {"name": "neural-chat:latest", ...}]}

# If connection fails with "Connection refused":
ps aux | grep ollama
# If no ollama process is running, contact ABLE support to start the Ollama service

# If you see a different port, update your code to use that port instead
```

### 5C: Review Default Configuration

On the **login node**, examine the framework's config:

```bash
cd ~/agentic_lab/agentic_lab_academy

# View the configuration file
cat config.py | grep -A 20 "LLM_CONFIG"
```

You should see:

```python
LLM_CONFIG = {
    "source": "ollama",                        # This MUST be "ollama"
    "model": "[MODEL_NAME]",                   # e.g., "mistral", "neural-chat"
    "api_endpoint": "http://localhost:11434",  # This MUST be localhost
    "temperature": 0.7,
    "max_tokens": 2048,
}
```

### 5D: Verify Your Model is Available

List the models deployed on ABLE's Ollama instance:

```bash
curl http://localhost:11434/api/tags | python -m json.tool

# You'll see output like:
# {
#   "models": [
#     {
#       "name": "mistral:latest",
#       "modified_at": "2026-01-20T10:30:00...",
#       ...
#     },
#     {
#       "name": "neural-chat:latest",
#       ...
#     }
#   ]
# }
```

Choose a model from this list. If you need a model that's not available, contact ABLE support.

### 5E: Customize LLM Parameters (Optional)

To adjust temperature or max tokens, you can:

**Option 1**: Edit `config.py` directly

```bash
# Open config.py and modify LLM_CONFIG
vim config.py

# Change temperature (0.0 = deterministic, 1.0 = creative):
LLM_CONFIG["temperature"] = 0.5  # More focused responses
```

**Option 2**: Pass parameters on the command line when running

```bash
python -m agentic_lab_academy.main \
  --mode code_only \
  --model mistral \
  --temperature 0.6 \
  --topic "..."
```

### 5F: Test Ollama Inference

Quick sanity check that the LLM is working:

```bash
# Ask Ollama a simple question
curl http://localhost:11434/api/generate -d '{
  "model": "mistral",
  "prompt": "What is Python?",
  "stream": false
}' | python -m json.tool

# You should see a response with generated text
```

If this fails, Ollama is not properly deployed. Contact ABLE support before proceeding.

---

## Step 6: Running the Framework

### 6A: Prepare Your Research Topic

Before running, write out your research objective clearly. Example (from the framework README):

```
"I want to perform quality control on single-cell datasets exposed to low-dose radiation. 
Load the two samples in the directory [PATH] (GSM8080315 as 'control' and GSM8080317 as 'r100') 
and concatenate them. Map genes to Ensembl IDs using GENCODE v47. Apply Geneformer-style QC 
filtering. Generate QC plots and save results to results/qc_filtered_radiation.h5ad"
```

### 6B: Set Up Environment on Login Node

Every time you log in, prepare your environment:

```bash
# SSH to login node if needed
ssh username@svr-rk1-ablelogin

# Navigate to the framework
cd ~/agentic_lab/agentic_lab_academy

# Source conda and activate environment
. /ableruntime/software/miniforge/etc/profile.d/conda.sh
conda activate agentic_lab

# Verify environment is active (prompt should show (agentic_lab))
echo $CONDA_DEFAULT_ENV
```

### 6C: Run a Basic Framework Invocation

Start with a **code_only** mode (generate code without auto-execution) to review the agents' output:

```bash
# Basic invocation - code generation only
python -m agentic_lab_academy.main \
  --mode code_only \
  --conda_env /ableruntime/[YOUR_USERNAME]/.conda/envs/agentic_lab \
  --files_dir ~/agentic_lab/data \
  --topic "Analyze the GSM samples in my data directory and perform basic quality control checks, generating summary statistics."
```

**Important Note on Package Dependencies**: 

The agents' generated code may try to `pip install` packages during execution. To avoid failures:

1. **Pre-install all expected packages** in your conda environment before running (recommended)
2. **Enable local PyPI** if available on ABLE (check with support)
3. **Review generated code** during human-in-the-loop checkpoints to catch install statements you can handle proactively

For example, if your research uses `scanpy` and `anndata`, pre-install them:
```bash
# On runtime node during conda setup
pip install scanpy anndata
```

### 6D: Monitor Execution and Human-in-the-Loop Approvals

The framework will pause at key checkpoints:

1. **PI Planning** – Agent proposes a multi-step research plan
   - Review the plan in your terminal
   - Type `approve` to proceed or `revise [feedback]` to request changes

2. **Code Generation** – Agent proposes Python code
   - Review the generated code (also saved in `workspace_runs/run_<timestamp>/generated_code/`)
   - Type `approve` to execute or `revise` to request changes

3. **Execution** – Code runs and feedback loops
   - Monitor stdout/stderr
   - Agent auto-retries on failure (up to configured attempt limits)

### 6E: Retrieve Results

After successful execution:

```bash
# List output artifacts
ls -la workspace_runs/

# Find your most recent run
ls -la workspace_runs/run_*/

# Common output directories:
# - workspace_runs/run_<ts>/generated_code/       (generated Python scripts)
# - workspace_runs/run_<ts>/conversation_log.jsonl (agent dialog log)
# - output_agent/                                  (final reports and summaries)

# View a generated script
cat workspace_runs/run_<ts>/generated_code/script_0.py

# Check the conversation log (JSON lines format)
head -20 workspace_runs/run_<ts>/conversation_log_<ts>.jsonl
```

### 6F: Download Results to Local Machine

Once analysis is complete, transfer results back:

```bash
# On the ABLE login node, copy results to your inbox
mkdir -p ~/upload_results
cp -r ~/agentic_lab/agentic_lab_academy/workspace_runs/run_* ~/upload_results/
cp -r ~/agentic_lab/agentic_lab_academy/output_agent/ ~/upload_results/

# On your local machine, SFTP to egress node to download
sftp egress-abledtn.cels.anl.gov

# When prompted, enter PIN

# Download all results
cd ~/download_results  # or wherever you want results locally
get -r output_agent/
get -r run_*

# Exit
quit
```

---

## Understanding the Framework

### Agent Roles

Each role is implemented as an async `academy.Agent`:

| Agent | Role | Responsibility |
|-------|------|-----------------|
| **User/Human** | Operator | Provides topic, data, approvals at checkpoints |
| **PI Agent** | Plan Creator | Converts research topic into multi-step execution plan |
| **Browsing Agent** | Context Aggregator | Ingests PDFs, file directories, web searches into unified digest |
| **Research Agent** | Report Writer | Drafts narrative research report grounded in sources |
| **Code Writer Agent** | Developer | Proposes and refines Python scripts based on feedback |
| **Code Executor Agent** | Runner | Executes scripts locally, captures output, auto-installs packages |
| **HPCAgent** | HPC Submitter | ❌ **NOT AVAILABLE ON ABLE** – ABLE is isolated from external HPC systems; use CodeExecutorAgent only |
| **Code Reviewer Agent** | QA | Inspects failed executions and proposes automated patches |
| **Critic Agent** | Feedback Loop | Consolidates quality/health feedback for next iteration |

### Command-Line Flags

Key flags for `python -m agentic_lab_academy.main`:

```bash
--mode {code_only, interactive}
  # code_only: Generate code, show it, wait for approval (no auto-run)
  # interactive: Full agent loop with human checkpoints

--topic "YOUR RESEARCH QUESTION"
  # The research objective; can be very detailed

--files_dir /path/to/data
  # Directory of input files (CSVs, H5AD, etc.) for browsing agent

--pdfs_dir /path/to/papers
  # Directory of PDFs for literature context

--links "url1 url2 ..."
  # URLs for web scraping (with caution; may not work on air-gapped ABLE)

--conda_env /path/to/conda/env
  # Conda environment for code execution
  # Use: /ableruntime/[USERNAME]/.conda/envs/agentic_lab

--use_hpc
  # ❌ DO NOT USE ON ABLE – ABLE is isolated from external HPC systems
  # This flag enables HPCAgent for Polaris/Sophia job submission
  # Since ABLE cannot reach external clusters, this will fail
  # Always omit this flag when running on ABLE

--model mistral  # or neural-chat, openchat, etc.
  # Override default LLM model

--temperature 0.7
  # LLM temperature (0.0=deterministic, 1.0=creative)
```

### Output Artifacts

After each run, find outputs in:

```
workspace_runs/
└── run_2026-01-23_15-30-45/
    ├── conversation_log_2026-01-23_15-30-45.jsonl
    │   └── Full agent dialog (question/response pairs)
    │
    ├── generated_code/
    │   ├── script_0.py
    │   ├── script_1.py
    │   └── ...iteration N...
    │
    ├── execution_logs/
    │   ├── script_0_stdout.txt
    │   ├── script_0_stderr.txt
    │   └── script_0_reasoning.txt (LLM analysis of failures)
    │
    └── hpc_outputs/  (if --use_hpc)
        ├── job_iter0_00.pbs  (PBS script submitted)
        ├── job_iter0_00.out  (Sophia stdout)
        └── job_iter0_00.err  (Sophia stderr)

output_agent/
├── iteration_0.md       (Research report, iteration 0)
├── iteration_0.py       (Code summary, iteration 0)
├── final_report.md      (Consolidated final report)
└── ...
```

---

## Troubleshooting

### Problem: `conda: command not found`

**Solution**:
```bash
# You need to source the conda initialization script on each login
. /ableruntime/software/miniforge/etc/profile.d/conda.sh

# Then verify conda is available
conda --version
```

**Add to ~/.bashrc** to automate this:
```bash
cat >> ~/.bashrc << 'EOF'
. /ableruntime/software/miniforge/etc/profile.d/conda.sh
EOF

# Restart your shell or source ~/.bashrc
source ~/.bashrc
```

### Problem: `ModuleNotFoundError: No module named 'academy'`

**Solution**:
```bash
# Verify your environment is activated
echo $CONDA_DEFAULT_ENV
# Should show: agentic_lab

# If not activated, activate it
conda activate agentic_lab

# If still not found, reinstall on runtime node
ssh username@svr-rk1-ableruntime
. /ableruntime/software/miniforge/etc/profile.d/conda.sh
conda activate agentic_lab
pip install academy
```

### Problem: `curl: (7) Failed to connect to localhost port 11434`

**Solution**:
```bash
# Ollama service is not running
# Check if it's running
ps aux | grep ollama

# If not, start it (ask your ABLE support contact for startup procedure)
# Alternatively, check if Ollama is available on a different endpoint:
curl http://[DIFFERENT_OLLAMA_HOST]:11434/api/tags

# Update config.py with correct endpoint if needed
```

### Problem: `ConnectionError: Failed to connect to api.openrouter.com` or Similar Cloud API Error

**This is expected on ABLE.** You cannot use cloud-based LLM backends because:

- ABLE has **NO internet access** from login/compute nodes (by design)
- Your code is trying to reach an external API that is unreachable
- **Solution**: You MUST use Ollama (local inference)

**If you see this error, it means someone (or your code) tried to configure:**
```python
LLM_CONFIG = {
    "source": "openrouter",  # ❌ Won't work on ABLE
    "api_endpoint": "https://openrouter.ai/api/v1",  # ❌ No internet access
}
```

**Fix it by using Ollama instead:**
```python
LLM_CONFIG = {
    "source": "ollama",  # ✅ Local inference
    "api_endpoint": "http://localhost:11434",  # ✅ No internet required
    "model": "mistral",  # Use available model
}
```

This is not a bug or configuration issue—it's the air-gap security design of ABLE. You cannot change it.

### Problem: `TimeoutError: [Errno 110] Connection timed out`

**Symptom**: Your script waits for a long time then fails with a timeout error.

**Cause**: Your LLM backend is trying to reach an external API through the internet (which doesn't exist on ABLE).

**Solution**: Ensure you are using Ollama (local) backend exclusively. Check your `config.py` or command-line arguments to ensure `"source": "ollama"` is set.

### Problem: Ollama model not found

### Problem: `Permission denied` when cloning repository

**Solution**:
```bash
# GitHub may be blocked on ABLE login nodes (air gap)
# Clone on runtime node instead:
ssh username@svr-rk1-ableruntime
cd ~
git clone https://github.com/tnnandi/agentic_lab_academy.git

# Then copy to your working directory
```

### Problem: Out of disk space during `pip install` or code execution

**Solution**:
```bash
# Check disk usage
du -sh ~/*
df -h ~

# Clean conda cache
conda clean --all

# Remove old workspace_runs
rm -rf ~/agentic_lab/agentic_lab_academy/workspace_runs/old_runs

# Check available space
df -h
```

### Problem: Code execution fails with `subprocess.CalledProcessError`

**Solution**:
1. Check the execution log:
   ```bash
   cat workspace_runs/run_<timestamp>/execution_logs/script_X_stderr.txt
   ```

2. Review LLM-generated reasoning:
   ```bash
   cat workspace_runs/run_<timestamp>/execution_logs/script_X_reasoning.txt
   ```

3. The Code Reviewer Agent will typically auto-retry; monitor the conversation log
4. If manual fixes are needed, edit the generated script and rerun

### Problem: `qsub: command not found` or PBS submission fails

**Cause**: You used the `--use_hpc` flag on ABLE, attempting to submit to external HPC systems.

**Why it fails**: ABLE is **isolated and cannot reach Polaris, Sophia, Aurora, or any external HPC system**. The `qsub` command may not even be available on ABLE.

**Solution**: 
```bash
# ❌ NEVER use this on ABLE:
python -m agentic_lab_academy.main --use_hpc ...

# ✅ ALWAYS use local execution instead:
python -m agentic_lab_academy.main \
  --mode code_only \
  --conda_env /ableruntime/[USERNAME]/.conda/envs/agentic_lab \
  --topic "..."
```

This is not a bug—it's the expected behavior of ABLE's isolated architecture. All computations must run locally within ABLE.

### Problem: Code execution fails with `pip install [PACKAGE]` – "Could not find a version that satisfies the requirement"

**Symptom**: Generated code tries to install a package and fails with:
```
ERROR: Could not find a version that satisfies the requirement [PACKAGE]
ERROR: No matching distribution found for [PACKAGE]
```

**Why it happens**: The Code Executor Agent tries to dynamically install missing packages using `pip install [PACKAGE]`, but:
1. Login nodes have **NO internet access** to public PyPI
2. The package is not pre-installed in your conda environment

**Solutions**:

**Option 1: Pre-install all packages on runtime node (Recommended)**

During the conda environment setup phase (Step 4 Phase 1), install all packages your analysis needs:

```bash
# On runtime node, in your activated agentic_lab environment
pip install [MISSING_PACKAGE]

# For common bioinformatics workflows:
pip install scanpy anndata polars dask-dataframe seaborn plotly pandas scipy
```

Then the agents' generated code will find these packages already available.

**Option 2: Use ABLE-hosted PyPI repository (If Available)**

If your ABLE deployment includes a local PyPI mirror:

```bash
# Configure pip to use local PyPI
cat > ~/.pip/pip.conf << 'EOF'
[global]
index-url = http://[ABLE_PYPI_HOST]:[PORT]/simple/
EOF

# Test it works
pip index versions numpy
```

Then the Code Executor Agent can install packages from the local repository.

**Check with ABLE support**:
- Is a local PyPI repository available on ABLE?
- What hostname/port should I use?
- Which packages are available in the mirror?
- How do I request new packages be added?

**Option 3: Modify generated code to avoid `pip install`**

During human-in-the-loop review, if the agent generates code with `pip install` statements, you can:
1. Edit the generated script to remove the install statements
2. Pre-install those packages on the runtime node
3. Re-approve and re-run the code

---

## References

- **Agentic Lab Academy Repository**: https://github.com/tnnandi/agentic_lab_academy
- **Academy Middleware (ProxyStore)**: https://docs.proxystore.dev/
- **ABLE Documentation**: https://www.alcf.anl.gov/able
- **ALCF Polaris User Guide**: https://www.alcf.anl.gov/support/polaris-user-guide
- **ALCF Sophia System**: [Contact ALCF support for Sophia documentation]
- **Ollama Documentation**: https://github.com/ollama/ollama

---

## Support & Contributing

For issues or improvements:

1. Review this guide's [Troubleshooting](#troubleshooting) section
2. Check the [agentic_lab_academy issues](https://github.com/tnnandi/agentic_lab_academy/issues)
3. Contact your ABLE/ALCF support team: [**ADD YOUR SUPPORT EMAIL**]

---

**Last Updated**: January 23, 2026  
**Framework Version**: agentic_lab_academy (master branch)  
**Tested On**: ABLE (svr-rk1-ablelogin/runtime), Ollama [**SPECIFY VERSION**]  
**Python Version**: 3.11  
**Conda Environment**: /ableruntime/[USERNAME]/.conda/envs/agentic_lab
