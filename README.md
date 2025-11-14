# Ollama Setup for Air-Gapped Environments

This guide explains how to set up and use Ollama for local LLM inference in secure, air-gapped environments (like ANL's ABLE secure environment) that have no internet access.

## Overview

The setup involves two environments:
1. **Sandbox environment** (with internet access) - for downloading Ollama and models
2. **Secure environment** (no internet access) - where you'll actually run Ollama

## Prerequisites

- Access to both sandbox and secure ABLE environments
- Python 3.x with `requests` library installed
- File transfer capability between sandbox and secure environments

## Step 1: Download Ollama (Sandbox Environment)

In your sandbox environment with internet access:

```bash
mkdir ~/oLlama
cd ~/oLlama

# Download Ollama for Linux
wget https://ollama.com/download/ollama-linux-amd64.tgz

# Extract it
tar -xzf ollama-linux-amd64.tgz

# This creates a bin/ directory with the ollama binary
```

## Step 2: Download Models (Sandbox Environment)

Still in the sandbox environment:

```bash
# Install Ollama temporarily
cd ~/oLlama/bin/ollama

# Start Ollama server
~/oLlama/bin/ollama serve &

# Pull the model you want (e.g., llama3.2)
~/oLlama/bin/ollama pull llama3.2

# Wait for download to complete
# The model is now stored in ~/.ollama/models/
```

## Step 3: Transfer Files to Secure Environment

Transfer the following from sandbox to secure environment. You will now need to log on to the secured machine (with no internet):

```bash
# In ABLE, prepare files for transfer
# 1. Ollama binary
cp -r /ableruntime/b54328/oLlama/ ~/oLlama/.

# 2. Model files (the entire .ollama/models directory)
cp -r /ableruntime/b54328/.ollama/models ~/.ollama/models/

```

## Step 4: Start Ollama Server

```bash
# Start the Ollama server (use full path if not in PATH)
~/oLlama/bin/ollama serve &

# Or if installed system-wide:
# ollama serve &

# Verify server is running
curl http://localhost:11434/api/tags

# Check available models
~/oLlama/bin/ollama list
```

**Expected output:**
```
NAME                ID              SIZE      MODIFIED
llama3.2:latest     a80c4f17acd5    2.0 GB    4 minutes ago
```

## Step 6: Test with Command Line

```bash
# Interactive chat
~/oLlama/bin/ollama run llama3.2

# Single query
~/oLlama/bin/ollama run llama3.2 "What is the capital of France?"
```

## Step 7: Use with Python Script

Save the following as [./scripts/API_Call_ollama_v0.0.py](`API_Call_ollama_v0.0.py`):

Run the script:

```bash
python API_Call_ollama_v0.0.py
```

You can test now and interact with the model.

## Troubleshooting

### Error: "Name or service not known" or connection refused

**Problem:** Ollama server is not running.

**Solution:**
```bash
# Check if ollama is running
ps aux | grep ollama

# If not running, start it
~/oLlama/bin/ollama serve &

# Verify it's accessible
curl http://localhost:11434/api/tags
```

### Error: "models": []

**Problem:** No models are installed.

**Solution:** Make sure you copied the model files correctly from sandbox to `~/.ollama/models/` in the secure environment.

### Keep Ollama Running Persistently

To keep Ollama running even after logging out:

```bash
# Option 1: Use nohup
nohup ~/oLlama/bin/ollama serve > ollama.log 2>&1 &

# Option 2: Use screen (recommended for interactive monitoring)
screen -S ollama
~/oLlama/bin/ollama serve
# Press Ctrl+A, then D to detach

# To reattach later:
screen -r oLlama
```

## API Endpoint Reference

Ollama provides several API endpoints:

- **Chat endpoint:** `POST http://localhost:11434/api/chat`
- **Generate endpoint:** `POST http://localhost:11434/api/generate`
- **List models:** `GET http://localhost:11434/api/tags`
- **Show model info:** `POST http://localhost:11434/api/show`

### Example Chat API Request

```json
{
  "model": "llama3.2",
  "messages": [
    {
      "role": "user",
      "content": "Hello!"
    }
  ],
  "stream": false,
  "options": {
    "num_predict": 80000
  }
}
```

### Example Response

```json
{
  "model": "llama3.2",
  "created_at": "2025-03-27T13:30:00Z",
  "message": {
    "role": "assistant",
    "content": "Hello! How can I help you today?"
  },
  "done": true
}
```

## Available Models

Popular models you can use (download in sandbox first):

- `llama3.2` - Meta's latest Llama model (2GB, good balance)
- `llama3.2:1b` - Smallest version (1.3GB, fastest)
- `llama3.2:3b` - Medium version (3GB)
- `mistral` - Mistral AI's model (4GB, high quality)
- `phi3` - Microsoft's small model (2.3GB)
- `codellama` - Specialized for code (3.8GB)

To pull a different model in sandbox:
```bash
ollama pull <model-name>
```

Then copy model to ABLE environment
```bash
cp /ableruntime/b54328/.ollama/models/* ~/.ollama/models/.
```

## Directory Structure

```
~/.ollama/
├── models/
│   ├── manifests/
│   │   └── registry.ollama.ai/
│   │       └── library/
│   │           └── llama3.2/
│   ├── blobs/
│   │   └── sha256-<hash>  # Actual model weights
└── ...

~/ollama/
└── bin/
    └── ollama  # Ollama binary
```

## Notes for ANL ABLE Environment

- This setup was tested on ANL's ABLE secure environment
- The secure environment has no internet access, hence the two-step process
- Use your institution's approved file transfer method between sandbox and secure
- Model files are large (2-10GB), ensure you have adequate storage and transfer quota
- Running `ollama serve` consumes minimal resources when idle, but will use GPU/CPU during inference

## Performance Tips

- First query may be slow as model loads into memory
- Subsequent queries are much faster
- For GPU acceleration, ensure CUDA drivers are available (Ollama will auto-detect)
- Adjust `num_predict` (max tokens) based on your needs to control response length

## License

Ollama is licensed under MIT License. Individual models have their own licenses (check model pages on ollama.com).

## Resources

- [Ollama Official Documentation](https://github.com/ollama/ollama)
- [Ollama Model Library](https://ollama.com/library)
- [API Documentation](https://github.com/ollama/ollama/blob/main/docs/api.md)
