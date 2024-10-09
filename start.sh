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
# 기본 경로 설정
DEFAULT_CHECKPOINTS="../Fooocus/models/checkpoints"
DEFAULT_VAE_APPROX="../Fooocus/models/vae_approx"
DEFAULT_LORAS="../Fooocus/models/loras"

# config.txt 파일 경로 설정
config_file="../Fooocus/config.txt"

# 경로 설정 함수
set_paths() {
    # 기본값으로 시작
    path_checkpoints="$DEFAULT_CHECKPOINTS"
    path_vae_approx="$DEFAULT_VAE_APPROX"
    path_loras="$DEFAULT_LORAS"

    # config 파일이 존재하면 값을 읽어옴
    if [ -f "$config_file" ]; then
        echo "Reading paths from config.txt"
        
        local checkpoints_line=$(grep '"path_checkpoints":' "$config_file")
        local vae_line=$(grep '"path_vae_approx":' "$config_file")
        local loras_line=$(grep '"path_loras":' "$config_file")
        
        # 각 경로를 개별적으로 확인하고 설정
        if [ ! -z "$checkpoints_line" ]; then
            local temp_path=$(echo "$checkpoints_line" | cut -d'"' -f4)
            if [ ! -z "$temp_path" ]; then
                path_checkpoints="$temp_path"
            fi
        fi
        
        if [ ! -z "$vae_line" ]; then
            local temp_path=$(echo "$vae_line" | cut -d'"' -f4)
            if [ ! -z "$temp_path" ]; then
                path_vae_approx="$temp_path"
            fi
        fi
        
        if [ ! -z "$loras_line" ]; then
            local temp_path=$(echo "$loras_line" | cut -d'"' -f4)
            if [ ! -z "$temp_path" ]; then
                path_loras="$temp_path"
            fi
        fi
    else
        echo "Config file not found. Using default paths."
    fi

    # 경로 출력 및 검증
    echo "Using the following paths:"
    echo "Checkpoints: $path_checkpoints"
    echo "VAE Approx: $path_vae_approx"
    echo "LoRAs: $path_loras"
}

# 경로 설정 함수 호출
set_paths

# 디렉토리 생성
create_directories() {
    for dir in "$path_checkpoints" "$path_vae_approx" "$path_loras"; do
        if [ ! -z "$dir" ]; then
            mkdir -p "$dir"
            if [ $? -ne 0 ]; then
                echo "Error: Could not create directory: $dir"
                return 1
            fi
        fi
    done
    return 0
}

# 디렉토리 생성 실행
if ! create_directories; then
    echo "Error: Failed to create one or more directories. Exiting."
    exit 1
fi

# 파일 다운로드 함수
download_files() {
    # Checkpoints
    if [ ! -f "$path_checkpoints/juggernautXL_version6Rundiffusion.safetensors" ]; then
        wget -P "$path_checkpoints" https://huggingface.co/lllyasviel/fav_models/resolve/main/fav/juggernautXL_version6Rundiffusion.safetensors
    fi

    # VAE models
    if [ ! -f "$path_vae_approx/xlvaeapp.pth" ]; then
        wget -P "$path_vae_approx" https://huggingface.co/lllyasviel/misc/resolve/main/xlvaeapp.pth
    fi
    if [ ! -f "$path_vae_approx/vaeapp_sd15.pth" ]; then
        wget -P "$path_vae_approx" https://huggingface.co/lllyasviel/misc/resolve/main/vaeapp_sd15.pth
    fi
    if [ ! -f "$path_vae_approx/xl-to-v1_interposer-v3.1.safetensors" ]; then
        wget -P "$path_vae_approx" https://huggingface.co/lllyasviel/misc/resolve/main/xl-to-v1_interposer-v3.1.safetensors
    fi

    # LoRA
    if [ ! -f "$path_loras/sd_xl_offset_example-lora_1.0.safetensors" ]; then
        wget -P "$path_loras" https://huggingface.co/lllyasviel/fav_models/resolve/main/fav/sd_xl_offset_example-lora_1.0.safetensors
    fi
}

# 파일 다운로드 실행
download_files

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

# Run both services
run_fooocus
sleep 5  # Give some time for Fooocus to initialize
run_fooocus_api

echo "Both services are running in the background."
echo "To check their status, use:"
echo "  tail -f fooocus.log     # for Fooocus logs"
echo "  tail -f fooocus_api.log # for Fooocus-API logs"