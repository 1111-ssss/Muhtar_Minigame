FROM ghcr.io/cirruslabs/flutter:3.47.7

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       clang \
       cmake \
       ninja-build \
       pkg-config \
       libgtk-3-dev \
       libasound2-dev \
       libpulse-dev \
       xvfb \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
COPY muhtar_minigame/pubspec.yaml muhtar_minigame/pubspec.lock ./muhtar_minigame/
RUN cd muhtar_minigame && flutter pub get
COPY . .

RUN cd muhtar_minigame && flutter build linux --release

WORKDIR /workspace/muhtar_minigame
CMD ["xvfb-run", "-a", "flutter", "run", "-d", "linux"]
