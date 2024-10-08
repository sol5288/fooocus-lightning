#!/bin/bash

# ... (이전 코드 유지)

# Clone and setup Fooocus-API
cd ..
if [ ! -d "Fooocus-API" ]; then
    git clone https://github.com/mrhan1993/Fooocus-API.git
fi
cd Fooocus-API
git pull

# Create and activate Fooocus-API environment
conda env create -f environment.yaml
conda activate fooocus-api

# Install additional requirements for Fooocus-API
pip install -r requirements.txt
pip install torch==2.1.0 torchvision==0.16.0 torchaudio==2.1.0 --index-url https://download.pytorch.org/whl/cu121

# ... (중간 코드 유지)

# Function to run Fooocus in background
run_fooocus() {
    conda activate fooocus
    python Fooocus/entry_with_update.py --always-high-vram &
}

# Function to run Fooocus-API
run_fooocus_api() {
    conda activate fooocus-api
    python Fooocus-API/main.py --port 8888
}

# Run both Fooocus and Fooocus-API
run_fooocus
echo "Starting Fooocus-API..."
run_fooocus_api