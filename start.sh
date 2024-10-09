#!/bin/bash

# UFW 설정
setup_ufw() {
    echo "Setting up UFW..."
    sudo apt install ufw -y
    sudo ufw allow 7865  # Fooocus 포트
    sudo ufw allow 8888  # Fooocus-API 포트
    sudo ufw enable
}

# Cloudflared 설치 확인 및 설치
setup_cloudflared() {
    if ! command -v cloudflared >/dev/null 2>&1; then
        echo "Installing Cloudflared..."
        wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O cloudflared
        chmod +x cloudflared
        sudo mv cloudflared /usr/local/bin/
    else
        echo "Cloudflared is already installed."
    fi
}

# 작업 디렉토리 설정
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Fooocus 저장소 클론 및 업데이트
setup_fooocus() {
    echo "Setting up Fooocus..."
    if [ ! -d "Fooocus" ]; then
        git clone https://github.com/lllyasviel/Fooocus.git
    fi
    cd Fooocus
    git pull
    
    # Conda 환경 설정
    echo "Setting up Fooocus Conda environment..."
    if [ -L ~/.conda/envs/fooocus ]; then
        rm ~/.conda/envs/fooocus
    fi

    eval "$(conda shell.bash hook)"
    
    if ! conda info --envs | grep -q '^fooocus'; then
        conda env create -f environment.yaml
        conda activate fooocus
        pip install -r requirements_versions.txt
        pip install torch==2.1.0 torchvision==0.16.0 torchaudio==2.1.0 --index-url https://download.pytorch.org/whl/cu121
        pip install opencv-python-headless pyngrok
        conda install -y conda-forge::glib
        rm -rf ~/.cache/pip
    else
        echo "Fooocus Conda environment already exists."
    fi
    
    cd "$SCRIPT_DIR"
}

# Fooocus-API 설정
setup_fooocus_api() {
    echo "Setting up Fooocus-API..."
    if [ ! -d "Fooocus-API" ]; then
        git clone https://github.com/mrhan1993/Fooocus-API.git
    fi
    cd Fooocus-API
    git pull
    
    # Conda 환경 설정
    echo "Setting up Fooocus-API Conda environment..."
    if ! conda info --envs | grep -q '^fooocus-api'; then
        conda env create -f environment.yaml
        conda activate fooocus-api
        pip install -r requirements.txt
        pip install torch==2.1.0 torchvision==0.16.0 torchaudio==2.1.0 --index-url https://download.pytorch.org/whl/cu121
    else
        echo "Fooocus-API Conda environment already exists."
    fi
    
    cd "$SCRIPT_DIR"
}

# 모델 경로 설정
setup_model_paths() {
    echo "Setting up model paths..."
    
    # 기본 경로 설정
    local config_file="$SCRIPT_DIR/Fooocus/config.txt"
    
    if [ -f "$config_file" ]; then
        echo "Reading paths from config.txt"
        path_checkpoints=$(grep '"path_checkpoints":' "$config_file" | cut -d'"' -f4)
        path_vae_approx=$(grep '"path_vae_approx":' "$config_file" | cut -d'"' -f4)
        path_loras=$(grep '"path_loras":' "$config_file" | cut -d'"' -f4)
    else
        echo "Config file not found. Using default paths."
        path_checkpoints="$SCRIPT_DIR/Fooocus/models/checkpoints"
        path_vae_approx="$SCRIPT_DIR/Fooocus/models/vae_approx"
        path_loras="$SCRIPT_DIR/Fooocus/models/loras"
    fi
    
    # 경로 생성
    mkdir -p "$path_checkpoints" "$path_vae_approx" "$path_loras"
    
    # Fooocus-API에 심볼릭 링크 생성
    local api_models_dir="$SCRIPT_DIR/Fooocus-API/models"
    mkdir -p "$api_models_dir"
    ln -sf "$path_checkpoints" "$api_models_dir/checkpoints"
    ln -sf "$path_vae_approx" "$api_models_dir/vae_approx"
    ln -sf "$path_loras" "$api_models_dir/loras"
    
    # config.txt 복사
    if [ -f "$config_file" ]; then
        cp "$config_file" "$SCRIPT_DIR/Fooocus-API/"
    fi
    
    echo "Model paths:"
    echo "Checkpoints: $path_checkpoints"
    echo "VAE Approx: $path_vae_approx"
    echo "LoRAs: $path_loras"
}

# 모델 파일 다운로드
download_model_files() {
    echo "Checking and downloading model files..."
    
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

# Fooocus 실행
run_fooocus() {
    cd "$SCRIPT_DIR"
    conda activate fooocus
    echo "Starting Fooocus from $(pwd)"
    python Fooocus/entry_with_update.py --always-high-vram > fooocus.log 2>&1 &
    FOOOCUS_PID=$!
    echo "Fooocus started in background (PID: $FOOOCUS_PID) on port 7865. Check fooocus.log for output."
}

# Fooocus-API 실행
run_fooocus_api() {
    cd "$SCRIPT_DIR"
    conda activate fooocus-api
    echo "Starting Fooocus-API from $(pwd)"
    python Fooocus-API/main.py --port 8888 > fooocus_api.log 2>&1 &
    API_PID=$!
    echo "Fooocus-API started in background (PID: $API_PID) on port 8888. Check fooocus_api.log for output."
}

# 메인 실행 부분
echo "Starting setup process..."

setup_ufw
setup_cloudflared
setup_fooocus
setup_fooocus_api
setup_model_paths
download_model_files

echo "Starting services..."
run_fooocus
sleep 5  # Fooocus 초기화 시간
run_fooocus_api

echo
echo "Setup complete. Both services are running in the background."
echo "To check their status, use:"
echo "  tail -f fooocus.log     # for Fooocus logs"
echo "  tail -f fooocus_api.log # for Fooocus-API logs"
echo
echo "To stop the services, use:"
echo "  kill $FOOOCUS_PID     # to stop Fooocus"
echo "  kill $API_PID         # to stop Fooocus-API"