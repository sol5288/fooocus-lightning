#!/bin/bash

# 현재 작업 디렉토리: /
sudo apt install ufw -y
sudo ufw allow 7865
sudo ufw allow 8888  # Fooocus-API 포트 추가
sudo ufw enable  # UFW 활성화

# Function to check if Cloudflared is installed
check_cloudflared() {
    command -v cloudflared >/dev/null 2>&1
}

# Set this variable to false to ensure installation in permanent storage.
install_in_temp_dir=false

# 현재 작업 디렉토리: /
# Check if Cloudflared is already installed
if ! check_cloudflared; then
    # Download and setup Cloudflared
    wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O cloudflared
    chmod +x cloudflared
    sudo mv cloudflared /usr/local/bin/
else
    echo "Cloudflared is already installed. Skipping installation."
fi

# 현재 작업 디렉토리: /
# Check if the Fooocus repository exists, if not clone it
if [ ! -d "Fooocus" ]; then
    git clone https://github.com/lllyasviel/Fooocus.git
fi
cd Fooocus
git pull

# 현재 작업 디렉토리: /Fooocus
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

# 현재 작업 디렉토리: /Fooocus
# Clone and setup Fooocus-API
cd ..
if [ ! -d "Fooocus-API" ]; then
    git clone https://github.com/mrhan1993/Fooocus-API.git
fi
cd Fooocus-API
git pull

# 현재 작업 디렉토리: /Fooocus-API
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

# 현재 작업 디렉토리: /Fooocus-API
# Read paths from config.txt
config_file="../Fooocus/config.txt"
if [ -f "$config_file" ]; then
    path_checkpoints=$(grep '"path_checkpoints":' "$config_file" | cut -d'"' -f4)
    path_vae_approx=$(grep '"path_vae_approx":' "$config_file" | cut -d'"' -f4)
    path_loras=$(grep '"path_loras":' "$config_file" | cut -d'"' -f4)
else
    echo "Warning: config.txt not found. Using default paths."
    path_checkpoints="../Fooocus/models/checkpoints"
    path_vae_approx="../Fooocus/models/vae_approx"
    path_loras="../Fooocus/models/loras"
fi

# Copy config.txt from Fooocus to Fooocus-API
if [ -f "../Fooocus/config.txt" ]; then
    cp ../Fooocus/config.txt .
    echo "Copied config.txt from Fooocus to Fooocus-API"
else
    echo "Warning: config.txt not found in Fooocus directory"
fi

# Create directories if they don't exist
mkdir -p "$path_checkpoints"
mkdir -p "$path_vae_approx"
mkdir -p "$path_loras"

# 변수 값 로그 출력
echo "Path variables:"
echo "path_checkpoints: $path_checkpoints"
echo "path_vae_approx: $path_vae_approx"
echo "path_loras: $path_loras"

# 변수 값 검증
if [ -z "$path_checkpoints" ] || [ -z "$path_vae_approx" ] || [ -z "$path_loras" ]; then
    echo "Error: One or more path variables are empty. Please check your config.txt file."
    exit 1
fi

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

# 현재 작업 디렉토리: /
# Function to run Fooocus in background
run_fooocus() {
    conda activate fooocus
    python Fooocus/entry_with_update.py --always-high-vram > fooocus.log 2>&1 &
    echo "Fooocus started in background. Check fooocus.log for output."
}

# Function to run Fooocus-API in background
run_fooocus_api() {
    conda activate fooocus-api
    python Fooocus-API/main.py --port 8888 > fooocus_api.log 2>&1 &
    echo "Fooocus-API started in background on port 8888. Check fooocus_api.log for output."
}

# Run both Fooocus and Fooocus-API in background
run_fooocus
sleep 5  # Give some time for Fooocus to initialize
run_fooocus_api

echo "Both services are running in the background."
echo "To check their status, use:"
echo "  tail -f fooocus.log     # for Fooocus logs"
echo "  tail -f fooocus_api.log # for Fooocus-API logs"