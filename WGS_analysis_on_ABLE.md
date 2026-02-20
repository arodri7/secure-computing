# Genomic Tools Deployment Guide
## Polaris → ABLE (GeomicVar Project)

**Prepared for:** Alex Rodriguez, Argonne National Laboratory  
**Date:** February 2026  
**Reference Genome:** GRCh38 / HG38  
**WGS Data Source:** MVP (physical hard drive delivery to ABLE)

---

## Overview

This document covers the build, packaging, and transfer of three genomic analysis tools as Singularity/Apptainer containers for deployment in the ABLE (Advanced Bioinformatics Learning Environment) secure air-gapped environment.

### Tools Covered
| Tool | Purpose | Image Source |
|------|---------|-------------|
| **Parliament2** | Structural Variant (SV) Detection — includes Breakdancer, Breakseq2, CNVnator, SVTyper, SVViz, Delly2, Manta, Lumpy, SURVIVOR | `docker://dnanexus/parliament2:latest` |
| **NVIDIA Parabricks** | GPU-accelerated variant calling (BWA-MEM + GATK) | `docker://nvcr.io/nvidia/clara/clara-parabricks:4.6.0-1` |
| **Ensembl VEP** | Variant Effect Prediction — annotation of variant calls from Parliament2 and Parabricks against GRCh38 | `docker://ensemblorg/ensembl-vep` |

### Infrastructure
| System | Role | Notes |
|--------|------|-------|
| **Polaris (ANL)** | Build environment | Has Apptainer 1.4.1, internet access, PBS scheduler |
| **ABLE Internet Side** | Staging / transfer | Air-gapped, SFTP ingress via `ingress-abledtn.cels.anl.gov` |
| **ABLE Secure Side** | Execution environment | SLURM scheduler, Singularity on compute and GPU nodes |

### Key Paths
| Location | Path |
|----------|------|
| Polaris working directory | `/lus/grand/projects/GeomicVar/rodriguez/tools` |
| ABLE SFTP ingress | `ingress-abledtn.cels.anl.gov` |

---

## Section 1: Building Containers on Polaris

### 1.0 Load Required Modules on Polaris

Before running any `apptainer` commands on Polaris, the necessary modules must be loaded. This applies to both the login node and any interactive compute node session.

```bash
module use /soft/modulefiles/
module load spack-pe-base/0.10.1
module load apptainer/1.4.1

cd /lus/grand/projects/GeomicVar/rodriguez/tools
```

> **Note:** These module commands must be run each time you start a new session or obtain a new compute node. Consider adding them to your `~/.bashrc` or a setup script to avoid repeating them manually.

---

### Why Two-Step Build?

Polaris login nodes have memory limits that cause `mksquashfs` to be killed when building large containers directly. The workaround is:
1. Pull the Docker image layers to a **sandbox directory** on the login node (internet access, low memory usage)
2. Convert sandbox to a `.sif` file on a **compute node** (no internet needed, more RAM available)

### 1.1 Parliament2 (SV Detection)

Parliament2 is a meta-caller that runs multiple SV detection tools and merges results using SURVIVOR. The following tools are bundled in the container:

**Callers:** Breakdancer, Breakseq2, CNVnator, Delly2, Manta, Lumpy  
**Genotyping:** SVTyper  
**Visualization:** SVviz  
**Merging:** SURVIVOR

Parliament2 is a meta-caller for structural variant (SV) detection. It bundles and orchestrates the following SV tools, merging their results using SURVIVOR:

- **Breakdancer** — SV detection from read pair anomalies
- **Breakseq2** — SV detection using breakpoint sequences
- **CNVnator** — Copy number variant detection using read depth
- **SVTyper** — Genotyping of SVs
- **SVViz** — SV visualization and validation
- **Delly2** — SV discovery using paired-ends and split-reads
- **Manta** — SV and indel calling optimized for speed
- **Lumpy** — Probabilistic SV discovery
- **SURVIVOR** — Merging and benchmarking of SV calls across callers

**Step 1 — Pull to sandbox (login node):**
```bash
cd /lus/grand/projects/GeomicVar/rodriguez/tools

apptainer build --sandbox parliament2_sandbox/ docker://dnanexus/parliament2:latest
```

**Step 2 — Get an interactive compute node:**
```bash
qsub -I -l select=1 -l walltime=01:00:00 -A GeomicVar -q debug -l filesystems=home:grand
```

**Step 3 — Load modules on the compute node:**
```bash
module use /soft/modulefiles/
module load spack-pe-base/0.10.1
module load apptainer/1.4.1
```

**Step 4 — Convert sandbox to SIF:**
```bash
cd /lus/grand/projects/GeomicVar/rodriguez/tools

apptainer build parliament2.sif parliament2_sandbox/
```

**Step 4 — Clean up sandbox:**
```bash
# Verify SIF exists and looks correct first
ls -lh parliament2.sif

rm -rf parliament2_sandbox/
```

> **Note:** The xattr warning during build (`destination filesystem does not support xattrs`) is benign and can be ignored.

---

### 1.2 NVIDIA Parabricks (GPU-Accelerated Variant Calling)

**Step 1 — Pull to sandbox (login node):**
```bash
cd /lus/grand/projects/GeomicVar/rodriguez/tools

apptainer build --sandbox parabricks_sandbox/ docker://nvcr.io/nvidia/clara/clara-parabricks:4.6.0-1
```

> **Important:** The correct image name is `clara-parabricks`, not `parabricks`. The NGC registry path is `nvcr.io/nvidia/clara/clara-parabricks`.

**Step 2 — Get an interactive compute node:**
```bash
qsub -I -l select=1 -l walltime=01:00:00 -A GeomicVar -q debug -l filesystems=home:grand
```

**Step 3 — Load modules on the compute node:**
```bash
module use /soft/modulefiles/
module load spack-pe-base/0.10.1
module load apptainer/1.4.1
```

**Step 4 — Convert sandbox to SIF:**
```bash
cd /lus/grand/projects/GeomicVar/rodriguez/tools

apptainer build clara-parabricks.sif parabricks_sandbox/
```

> **Note:** If you hit `disk quota exceeded` on your home directory, redirect to the project scratch path:
> ```bash
> cd /lus/grand/projects/GeomicVar/rodriguez/tools
> apptainer build clara-parabricks.sif parabricks_sandbox/
> ```
> Always build within the project directory, not `$HOME`.

**Step 4 — Clean up sandbox:**
```bash
ls -lh clara-parabricks.sif
rm -rf parabricks_sandbox/
```

---

### 1.3 Ensembl VEP (Variant Annotation)

Ensembl VEP (Variant Effect Predictor) is used for annotation of variant calls produced by Parliament2 (SVs) and Parabricks (SNPs/indels). It annotates variants against GRCh38 providing consequence predictions, gene context, allele frequencies, and other functional information. Running in `--offline` mode is required in ABLE due to the air-gapped environment.

**Step 1 — Pull to sandbox (login node):**
```bash
cd /lus/grand/projects/GeomicVar/rodriguez/tools

apptainer build --sandbox vep_sandbox/ docker://ensemblorg/ensembl-vep
```

**Step 2 — Get an interactive compute node:**
```bash
qsub -I -l select=1 -l walltime=01:00:00 -A GeomicVar -q debug -l filesystems=home:grand
```

**Step 3 — Load modules on the compute node:**
```bash
module use /soft/modulefiles/
module load spack-pe-base/0.10.1
module load apptainer/1.4.1
```

**Step 4 — Convert sandbox to SIF:**
```bash
cd /lus/grand/projects/GeomicVar/rodriguez/tools

apptainer build vep.sif vep_sandbox/
```

**Step 4 — Download VEP cache and FASTA for GRCh38 (login node, needs internet):**
```bash
mkdir -p /lus/grand/projects/GeomicVar/rodriguez/tools/vep_data

singularity exec /lus/grand/projects/GeomicVar/rodriguez/tools/vep.sif \
  INSTALL.pl \
  -c /lus/grand/projects/GeomicVar/rodriguez/tools/vep_data \
  -a cf \
  -s homo_sapiens \
  -y GRCh38
```

> **Note:** This downloads ~15-20GB of cache and FASTA data. It may take significant time. Run in a `screen` or `tmux` session to avoid interruption.

**Step 5 — Clean up sandbox:**
```bash
ls -lh vep.sif
rm -rf vep_sandbox/
```

---

## Section 2: Transfer to ABLE

### 2.1 What to Transfer

After builds are complete, the following files need to be transferred to ABLE:

```
/lus/grand/projects/GeomicVar/rodriguez/tools/
├── parliament2.sif
├── clara-parabricks.sif
├── vep.sif
└── vep_data/                  # VEP cache + GRCh38 FASTA (~15-20GB)
    └── homo_sapiens/
        └── [version]/
            └── GRCh38/
```

### 2.2 Transfer via SFTP to ABLE Internet Side

```bash
sftp -i <your_hspd12_key> username@ingress-abledtn.cels.anl.gov
```

Once connected:
```bash
# Create destination directory structure
mkdir -p /path/on/able/tools

# Transfer SIF files
put /lus/grand/projects/GeomicVar/rodriguez/tools/parliament2.sif /path/on/able/tools/
put /lus/grand/projects/GeomicVar/rodriguez/tools/clara-parabricks.sif /path/on/able/tools/
put /lus/grand/projects/GeomicVar/rodriguez/tools/vep.sif /path/on/able/tools/

# Transfer VEP data directory (recursive)
put -r /lus/grand/projects/GeomicVar/rodriguez/tools/vep_data /path/on/able/tools/
```

> **Authentication:** ABLE uses HSPD12 authentication via PKCS11Provider. Ensure your credentials are active before initiating transfer.

---

## Section 3: WGS Data from MVP

The WGS data will be delivered by MVP on a **physical hard drive** to be installed within ABLE. Once the drive is mounted:

- Confirm the data is in FASTQ or BAM format
- Confirm paired-end reads are present (`_R1` and `_R2` for FASTQ)
- If BAM files are provided, confirm `.bai` index files are present (required by Parliament2)
- Note the mount path for use in SLURM job scripts

---

## Section 4: Running Tools on ABLE (SLURM Job Scripts)

> All job scripts assume Singularity is available on ABLE compute and GPU nodes.

### 4.1 Parliament2 — SV Detection

```bash
#!/bin/bash
#SBATCH --job-name=parliament2
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=128G
#SBATCH --time=04:00:00
#SBATCH --output=parliament2_%j.log
#SBATCH --error=parliament2_%j.err
#SBATCH --partition=<your_partition>

SIF=/path/on/able/tools/parliament2.sif
DATA_DIR=/path/to/mvp/data
OUT_DIR=/path/to/output
BAM=sample.bam
REF=Homo_sapiens_assembly38.fasta

singularity run \
  --bind ${DATA_DIR}:/data \
  --bind ${OUT_DIR}:/output \
  ${SIF} \
  --bam /data/${BAM} \
  --ref /data/${REF} \
  --prefix /output/sample_output \
  --filter_short_contigs
```

> **Prerequisite:** BAM file must have a corresponding `.bai` index in the same directory.

---

### 4.2 Parabricks — GPU-Accelerated Alignment + Variant Calling

```bash
#!/bin/bash
#SBATCH --job-name=parabricks
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=128G
#SBATCH --gres=gpu:1
#SBATCH --time=04:00:00
#SBATCH --output=parabricks_%j.log
#SBATCH --error=parabricks_%j.err
#SBATCH --partition=<gpu_partition>

SIF=/path/on/able/tools/clara-parabricks.sif
DATA_DIR=/path/to/mvp/data
OUT_DIR=/path/to/output
REF=Homo_sapiens_assembly38.fasta

# FASTQ to BAM (alignment)
singularity run --nv \
  --bind ${DATA_DIR}:/data \
  --bind ${OUT_DIR}:/output \
  ${SIF} \
  pbrun fq2bam \
  --ref /data/${REF} \
  --in-fq /data/sample_R1.fastq.gz /data/sample_R2.fastq.gz \
  --out-bam /output/sample.bam
```

> **Notes:**
> - `--nv` is required to pass GPU access through to the container
> - Parabricks requires at least 1 GPU with 16GB+ VRAM
> - Use `pbrun germline` for a full alignment + variant calling pipeline in one step
> - Use `--gres=gpu:2` or more for better performance on large WGS datasets

---

### 4.3 VEP — Variant Effect Prediction

```bash
#!/bin/bash
#SBATCH --job-name=vep
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --time=06:00:00
#SBATCH --output=vep_%j.log
#SBATCH --error=vep_%j.err
#SBATCH --partition=<your_partition>

SIF=/path/on/able/tools/vep.sif
VEP_DATA=/path/on/able/tools/vep_data
INPUT_DIR=/path/to/input/vcf
OUT_DIR=/path/to/output

singularity exec \
  --bind ${VEP_DATA}:/vep_data \
  --bind ${INPUT_DIR}:/input \
  --bind ${OUT_DIR}:/output \
  ${SIF} \
  vep \
  --dir /vep_data \
  --cache --offline \
  --format vcf --vcf \
  --force_overwrite \
  --input_file /input/variants.vcf \
  --output_file /output/variants_annotated.vcf \
  --assembly GRCh38 \
  --fork 16
```

> **Notes:**
> - `--offline` is required since ABLE is air-gapped (no internet access for VEP to query Ensembl)
> - `--fork 16` enables parallel processing; match to `--cpus-per-task`
> - The VEP data directory bind mount is mandatory — VEP cannot run without the cache

---

## Section 5: Troubleshooting Reference

### Build Issues on Polaris

| Error | Cause | Fix |
|-------|-------|-----|
| `FATAL ERROR: Failed to create thread` | Too many mksquashfs threads on login node | Use `--mksquashfs-args "-processors 1"` or build on compute node |
| `signal: killed` | OOM on login node during squashfs compression | Use two-step sandbox approach; build SIF on compute node |
| `disk quota exceeded` | Home directory full | Build in `/lus/grand/projects/GeomicVar/rodriguez/tools` not `$HOME` |

### Docker → Singularity Flag Translation

| Docker | Singularity/Apptainer |
|--------|----------------------|
| `--gpus all` | `--nv` |
| `-v /host:/container` | `--bind /host:/container` |
| `--rm` | Not needed (Singularity is stateless by default) |
| `--workdir /path` | `--pwd /path` |

---

## Appendix: Verified Container Checksums

After building, record checksums for integrity verification before and after transfer:

```bash
sha256sum parliament2.sif > parliament2.sif.sha256
sha256sum clara-parabricks.sif > clara-parabricks.sif.sha256
sha256sum vep.sif > vep.sif.sha256
```

Verify on ABLE after transfer:
```bash
sha256sum -c parliament2.sif.sha256
sha256sum -c clara-parabricks.sif.sha256
sha256sum -c vep.sif.sha256
```
