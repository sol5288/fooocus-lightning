#!/bin/bash

# 작업 디렉토리 설정
WORKSPACE_DIR="/teamspace/studios/this_studio/fooocus-lightning"
cd "$WORKSPACE_DIR"

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

# Fooocus 설정
setup_fooocus() {
    echo "Setting up Fooocus..."
    if [ ! -d "$WORKSPACE_DIR/Fooocus" ]; then
        git clone https://github.com/lllyasviel/Fooocus.git
    fi
    cd "$WORKSPACE_DIR/Fooocus"
    git pull
    
    # Conda 환경 설정
    echo "Setting up Fooocus Conda environment..."
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
    
    cd "$WORKSPACE_DIR"
}

# Fooocus-API 설정
setup_fooocus_api() {
    echo "Setting up Fooocus-API..."
    if [ ! -d "$WORKSPACE_DIR/Fooocus-API" ]; then
        git clone https://github.com/mrhan1993/Fooocus-API.git
    fi
    cd "$WORKSPACE_DIR/Fooocus-API"
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
    
    cd "$WORKSPACE_DIR"
}

# 모델 경로 설정
setup_model_paths() {
    echo "Setting up model paths..."
    
    # 기본 경로 설정
    local config_file="$WORKSPACE_DIR/Fooocus/config.txt"
    
    if [ -f "$config_file" ]; then
        echo "Reading paths from config.txt"
        path_checkpoints=$(grep '"path_checkpoints":' "$config_file" | cut -d'"' -f4)
        path_vae_approx=$(grep '"path_vae_approx":' "$config_file" | cut -d'"' -f4)
        path_loras=$(grep '"path_loras":' "$config_file" | cut -d'"' -f4)
    else
        echo "Config file not found. Using default paths."
        path_checkpoints="$WORKSPACE_DIR/Fooocus/models/checkpoints"
        path_vae_approx="$WORKSPACE_DIR/Fooocus/models/vae_approx"
        path_loras="$WORKSPACE_DIR/Fooocus/models/loras"
    fi
    
    # 경로 생성
    mkdir -p "$path_checkpoints" "$path_vae_approx" "$path_loras"
    
    # Fooocus-API에 심볼릭 링크 생성
    local api_models_dir="$WORKSPACE_DIR/Fooocus-API/models"
    mkdir -p "$api_models_dir"
    ln -sf "$path_checkpoints" "$api_models_dir/checkpoints"
    ln -sf "$path_vae_approx" "$api_models_dir/vae_approx"
    ln -sf "$path_loras" "$api_models_dir/loras"
    
    # config.txt 복사
    if [ -f "$config_file" ]; then
        cp "$config_file" "$WORKSPACE_DIR/Fooocus-API/"
    fi
    
    echo "Model paths:"
    echo "Checkpoints: $path_checkpoints"
    echo "VAE Approx: $path_vae_approx"
    echo "LoRAs: $path_loras"
}

# Fooocus 실행
run_fooocus() {
    cd "$WORKSPACE_DIR/Fooocus"
    conda activate fooocus
    echo "Starting Fooocus from $(pwd)"
    python entry_with_update.py --always-high-vram > "$WORKSPACE_DIR/fooocus.log" 2>&1 &
    FOOOCUS_PID=$!
    echo "Fooocus started in background (PID: $FOOOCUS_PID) on port 7865. Check fooocus.log for output."
}

# Fooocus-API 실행
run_fooocus_api() {
    cd "$WORKSPACE_DIR/Fooocus-API"
    conda activate fooocus-api
    echo "Starting Fooocus-API from $(pwd)"
    python main.py --port 8888 > "$WORKSPACE_DIR/fooocus_api.log" 2>&1 &
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

echo "Starting services..."
run_fooocus
sleep 5  # Fooocus 초기화 시간
run_fooocus_api

echo
echo "Setup complete. Both services are running in the background."
echo "To check their status, use:"
echo "  tail -f $WORKSPACE_DIR/fooocus.log     # for Fooocus logs"
echo "  tail -f $WORKSPACE_DIR/fooocus_api.log # for Fooocus-API logs"
echo
echo "To stop the services, use:"
echo "  kill $FOOOCUS_PID     # to stop Fooocus"
echo "  kill $API_PID         # to stop Fooocus-API"