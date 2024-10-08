#!/bin/bash

sudo apt install ufw -y
sudo ufw allow 7865
sudo ufw allow 8888  # Fooocus-API 포트 추가

# Function to check if Cloudflared is installed
check_cloudflared() {
    command -v cloudflared >/dev/null 2>&1
}

# Set this variable to false to ensure installation in permanent storage.
install_in_temp_dir=false

# Check if Cloudflared is already installed
if ! check_cloudflared; then
    # Download and setup Cloudflared
    wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O cloudflared
    chmod +x cloudflared
    sudo mv cloudflared /usr/local/bin/
else
    echo "Cloudflared is already installed. Skipping installation."
fi

# Check if the Fooocus repository exists, if not clone it
if [ ! -d "Fooocus" ]; then
    git clone https://github.com/lllyasviel/Fooocus.git
fi
cd Fooocus
git pull

# Set the installation folder
echo "Installation folder: ~/.conda/envs/fooocus"
if [ -L ~/.conda/envs/fooocus ]; then
    rm ~/.conda/envs/fooocus
fi

eval "$(conda shell.bash hook)"

# Check if the conda environment already exists
if conda info --envs | grep -q '^fooocus'; then
    echo "The fooocus environment already exists. Skipping installation."
else
    echo "Installing Fooocus environment"
    conda env create -f environment.yaml
    conda activate fooocus
    pip install -r requirements_versions.txt
    pip install torch==2.1.0 torchvision==0.16.0 torchaudio==2.1.0 --index-url https://download.pytorch.org/whl/cu121
    pip install opencv-python-headless
    pip install pyngrok
    conda install -y conda-forge::glib
    rm -rf ~/.cache/pip
fi

# Clone and setup Fooocus-API
cd ..
if [ ! -d "Fooocus-API" ]; then
    git clone https://github.com/mrhan1993/Fooocus-API.git
fi
cd Fooocus-API
git pull

# Copy config.txt from Fooocus to Fooocus-API
if [ -f "../Fooocus/config.txt" ]; then
    cp ../Fooocus/config.txt .
    echo "Copied config.txt from Fooocus to Fooocus-API"
else
    echo "Warning: config.txt not found in Fooocus directory"
fi

# Create and activate Fooocus-API environment
conda env create -f environment.yaml
conda activate fooocus-api

# Install additional requirements for Fooocus-API
pip install -r requirements.txt
pip install torch==2.1.0 torchvision==0.16.0 torchaudio==2.1.0 --index-url https://download.pytorch.org/whl/cu121

# Function to check if a file exists
file_exists() {
    [ -f "$1" ]
}

# Read paths from config.txt
config_file="../Fooocus/config.txt"
if [ -f "$config_file" ]; then
    path_checkpoints=$(grep '"path_checkpoints":' "$config_file" | cut -d'"' -f4)
    path_vae_approx=$(grep '"path_vae_approx":' "$config_file" | cut -d'"' -f4)
    path_loras=$(grep '"path_loras":' "$config_file" | cut -d'"' -f4)
else
    echo "Warning: config.txt not found. Using default paths."
    path_checkpoints="repositories/Fooocus/models/checkpoints"
    path_vae_approx="repositories/Fooocus/models/vae_approx"
    path_loras="repositories/Fooocus/models/loras"
fi

# Create directories if they don't exist
mkdir -p "$path_checkpoints"
mkdir -p "$path_vae_approx"
mkdir -p "$path_loras"

# Download checkpoints if not exist
if ! file_exists "$path_checkpoints/juggernautXL_version6Rundiffusion.safetensors"; then
    wget -P "$path_checkpoints" https://huggingface.co/lllyasviel/fav_models/resolve/main/fav/juggernautXL_version6Rundiffusion.safetensors
fi

# Download VAE models if not exist
if ! file_exists "$path_vae_approx/xlvaeapp.pth"; then
    wget -P "$path_vae_approx" https://huggingface.co/lllyasviel/misc/resolve/main/xlvaeapp.pth
fi
if ! file_exists "$path_vae_approx/vaeapp_sd15.pth"; then
    wget -P "$path_vae_approx" https://huggingface.co/lllyasviel/misc/resolve/main/vaeapp_sd15.pth
fi
if ! file_exists "$path_vae_approx/xl-to-v1_interposer-v3.1.safetensors"; then
    wget -P "$path_vae_approx" https://huggingface.co/lllyasviel/misc/resolve/main/xl-to-v1_interposer-v3.1.safetensors
fi

# Download LoRA if not exist
if ! file_exists "$path_loras/sd_xl_offset_example-lora_1.0.safetensors"; then
    wget -P "$path_loras" https://huggingface.co/lllyasviel/fav_models/resolve/main/fav/sd_xl_offset_example-lora_1.0.safetensors
fi

cd ..

# Function to run Fooocus in background
run_fooocus() {
    conda activate fooocus
    python Fooocus/entry_with_update.py --always-high-vram &
}

# Function to run Fooocus-API
run_fooocus_api() {
    conda activate fooocus-api
    python Fooocus-API/main.py
}

# Run both Fooocus and Fooocus-API
run_fooocus
echo "Starting Fooocus-API..."
run_fooocus_api