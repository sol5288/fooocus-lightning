# fooocus-lightning"

**Fooocus Lightning AI**는 첨단 AI 기술을 활용하여 집중력과 생산성을 크게 향상시키기 위해 개발된 정교한 프로젝트입니다. 이 저장소는 Fooocus AI 시스템을 효율적으로 배포하고 실행하기 위한 포괄적인 설정 및 구성 지침을 제공합니다.

## 목차

- [설치](#설치)
- [모델 다운로드](#모델-다운로드)
  - [Loras 모델](#loras-모델)
  - [체크포인트](#체크포인트)
- [문제 해결](#문제-해결)
  - [Fooocus UI 공백 오류](#fooocus-ui-공백-오류)

## 설치

Fooocus Lightning AI를 시작하려면 아래 단계를 따라주세요:

### 1. 저장소 클론하기

먼저 저장소를 로컬 컴퓨터에 클론합니다. 터미널을 열고 다음 명령어를 실행하세요:

```sh
git clone https://github.com/sol5288/fooocus-lightning.git
cd fooocus-lightning
```

이 명령어는 저장소의 로컬 복사본을 만들고 프로젝트 디렉토리로 이동합니다.

### 2. 애플리케이션 시작하기

다음으로, 제공된 시작 스크립트를 실행하여 애플리케이션을 시작합니다:

```sh
sh start.sh
```

이 스크립트는 필요한 환경을 설정하고 Fooocus AI 시스템을 실행합니다. 이 과정에서 나타나는 메시지나 오류를 주의 깊게 살펴보세요.

## 모델 다운로드

Fooocus Lightning AI를 충분히 활용하려면 다양한 모델을 다운로드해야 합니다. 필요한 모델 유형에 따라 아래 지침을 따르세요:

### Loras 모델

Loras 모델을 다운로드하려면 `models/loras` 디렉토리로 이동하세요:

```sh
cd fooocus-lightning-ai/Fooocus/models/loras
```

여기에서 시스템에 필요한 Loras 모델을 다운로드하는 지침이나 스크립트를 찾을 수 있습니다.

### 체크포인트

체크포인트를 다운로드하려면 `models/checkpoints` 디렉토리로 이동하세요:

```sh
cd fooocus-lightning-ai/Fooocus/models/checkpoints
```

이 디렉토리에는 필요한 체크포인트 파일이 있습니다. 이 파일들을 다운로드하기 위한 제공된 지침이나 스크립트를 따르세요.

## 문제 해결

Fooocus 사용자 인터페이스에서 공백 화면 등의 문제가 발생하면 다음 문제 해결 단계를 따라 문제를 해결하세요:

### Fooocus UI 공백 오류
![샘플 이미지 1](https://github.com/epic-miner/image/blob/main/Screenshot%202024-07-18%20102413.png)

1. **저장소 업데이트**

   저장소의 최신 버전을 확보하기 위해 다음과 같이 업데이트하세요:

   ```sh
   cd fooocus-lightning/
   git fetch origin main   # 원격 main 브랜치에서 최신 변경사항을 가져옵니다
   git merge origin/main   # 가져온 변경사항을 현재 브랜치에 병합합니다
   ```

   이렇게 하면 로컬 저장소가 최신 업데이트와 동기화됩니다.

2. **애플리케이션 재시작**

   업데이트 후, 다음 명령어를 사용하세요:

   ```sh
   sh start.sh
   ```

3. **새 터미널 열기**

   새 터미널 창을 엽니다.

   ![Fooocus 웹 UI](https://github.com/epic-miner/image/blob/main/Screenshot%202024-07-18%20124725.png)

4. **Cloudflared 명령 실행**

   다음 명령어를 실행하여 터널을 설정합니다:

   ![Fooocus 명령](https://github.com/epic-miner/image/blob/main/Screenshot%202024-07-18%20124827.png)
   ```sh
   cloudflared tunnel --url localhost:7865
   ```

   이 명령어는 로컬 서버로의 안전한 터널을 생성합니다.

5. **Fooocus 웹 UI 접속**

   명령어 실행 후, 터미널 출력을 스크롤하여 URL을 찾습니다. 이 URL을 클릭하여 Fooocus 웹 UI에 접속하세요.

   ![Fooocus 웹 UI](https://github.com/epic-miner/image/blob/main/Screenshot%202024-07-18%20101016.png)

   추가 문제가 발생하면 문서를 참조하거나 지원팀에 문의하여 추가 도움을 받으세요.

## 공백 화면 오류 해결을 위한 비디오 튜토리얼

Fooocus Lightning AI 시작을 돕기 위해 시스템 설정과 사용법을 안내하는 종합적인 비디오 튜토리얼을 제작했습니다. 아래에서 전체 튜토리얼을 시청하세요:

아래 이미지를 클릭하여 비디오 튜토리얼을 시청하세요:

[![비디오 보기](https://img.youtube.com/vi/qCz4rg0E4EY/0.jpg)](https://www.youtube.com/watch?v=qCz4rg0E4EY)

위 이미지를 클릭하거나 [여기](https://youtu.be/M922HHKUta8?si=I_TRWMi1yo2dERUg)를 클릭하여 튜토리얼을 시청하세요.

설정 중 시각적 가이드가 필요하거나 문제가 발생하면 이 비디오가 필요한 지침과 통찰을 제공할 것입니다.