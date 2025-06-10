# syntax=docker/dockerfile:labs
# vim: filetype=dockerfile softtabstop=2 tabstop=2 shiftwidth=2 fileencoding=utf-8 expandtab
# ────────────────────────────────────────────────────────────────────────────────
# Alpine-based minimal development environment for Claude Code and MCP servers
# ────────────────────────────────────────────────────────────────────────────────
FROM alpine:edge AS base
SHELL ["/bin/ash", "-euo", "pipefail", "-c"]

# User setup
ENV USER="claude"
ENV UID="1000"
ENV HOME="/home/${USER}"
ARG WORKDIR="/workspace"
ENV WORKDIR="${WORKDIR}"
# Define volumes for persistence
VOLUME [ \
  "${WORKDIR}", \
  "${WORKDIR}/.rustup", \
  "${WORKDIR}/.cargo", \
  "${HOME}/.claude", \
  "${HOME}/.claude.json", \
  "${HOME}/.local/share/claude-code", \
  "${HOME}/.npm", \
  "${HOME}/.cache" \
]
# ────────────────────────────────────────────────────────────────────────────────
# APK Package compression
# ────────────────────────────────────────────────────────────────────────────────
RUN \
  (\
  echo '#!/bin/sh'; \
  echo 'SKIP_PKGS=""'; \
  echo 'if [ -r "/tmp/.processed-pkgs" ]; then'; \
  echo '  SKIP_PKGS=$(cat "/tmp/.processed-pkgs" | tr "\n" " ")'; \
  echo 'fi'; \
  echo 'SKIP_PKGS="$SKIP_PKGS upx sudo apk "'; \
  echo 'PKGS=""'; \
  echo 'for pkg in $(apk info -q); do'; \
  echo '  if ! echo " $SKIP_PKGS " | grep -q " $pkg "; then'; \
  echo '    PKGS="$PKGS $pkg"'; \
  echo '  fi'; \
  echo 'done'; \
  echo 'if [ -z "$PKGS" ]; then'; \
  echo '  exit 0'; \
  echo 'fi'; \
  echo 'BIN_LIST=""'; \
  echo 'NEW_PROCESSED_PKGS=""'; \
  echo 'for pkg in $PKGS; do'; \
  echo '  NEW_PROCESSED_PKGS="$NEW_PROCESSED_PKGS $pkg"'; \
  echo '  FILES=$(apk info -L "$pkg" 2>/dev/null)'; \
  echo '  for f in $FILES; do'; \
  echo '    if [ -f "/$f" ] && [ -x "/$f" ]; then'; \
  echo '      FILE_TYPE=$(file -i "/$f" 2>/dev/null)'; \
  echo '      if echo "$FILE_TYPE" | grep -q -E "application/x-(pie-)?executable; charset=binary"; then'; \
  echo '        if ! upx -t "/$f" >/dev/null 2>&1; then'; \
  echo '          BIN_LIST="$BIN_LIST/$f\n"'; \
  echo '        fi'; \
  echo '      fi'; \
  echo '    fi'; \
  echo '  done'; \
  echo 'done'; \
  echo 'if [ -n "$BIN_LIST" ]; then'; \
  echo '  printf "%b" "$BIN_LIST" | xargs -r -I {} -P "$(($(nproc)/4))" sh -c "upx -q \"{}\" || echo \"{}\" >> /tmp/.failed-compress"'; \
  echo 'fi'; \
  echo 'if [ -n "$NEW_PROCESSED_PKGS" ]; then'; \
  echo '  for pkg in $NEW_PROCESSED_PKGS; do'; \
  echo '    echo "$pkg" >> "/tmp/.processed-pkgs"'; \
  echo '  done'; \
  echo '  sort -u "/tmp/.processed-pkgs" > "/tmp/.processed-pkgs.tmp"'; \
  echo '  mv "/tmp/.processed-pkgs.tmp" "/tmp/.processed-pkgs"'; \
  echo 'fi'; \
  ) | tee "/usr/local/bin/compress-packages" > /dev/null \
  && chmod +x "/usr/local/bin/compress-packages"

# ────────────────────────────────────────────────────────────────────────────────
# Base system setup
# ────────────────────────────────────────────────────────────────────────────────
RUN \
  # Enable edge repositories for latest packages
  echo "https://dl-cdn.alpinelinux.org/alpine/edge/main" > /etc/apk/repositories && \
  echo "https://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories && \
  echo "https://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories && \
  # Update package index
  apk update && \
  # Install base dependencies
  apk add --no-cache \
    # Core utilities
    bash bash-completion sudo shadow coreutils su-exec \
    # Build essentials
    build-base cmake gcc g++ musl-dev linux-headers \
    # Version control
    git openssh-client \
    # Network tools
    curl wget ca-certificates \
    # Compression tools
    xz zstd bzip2 gzip tar unzip \
    # Text processing
    jq yq-go yq-go-bash-completion less file findutils grep \
    # Process management
    procps htop \
    # Development tools
    make \
    # For binary compression
    upx \
    # Python and tools
    python3 python3-dev py3-pip py3-wheel py3-setuptools \
    pipx pre-commit poetry uv uv-bash-completion \
    # Node.js and npm
    nodejs npm \
    # Rust build dependencies
    rustup \
    # Additional libs for Python packages with native extensions
    libffi-dev openssl-dev \
    # Text editors
    helix neovim nano \
    # Search and replace tools
    ripgrep fd sd \
    # File managers and viewers
    bat eza ncdu duf \
    # Git tools
    delta \
    # Process viewers
    bottom \
    # Terminal multiplexers
    zellij \
    # Shell enhancements
    starship zoxide fzf atuin \
    # Development tools
    tokei shellcheck shfmt hyperfine \
    # Task runners
    go-task \
  # Compress packages
  && compress-packages \
  # Clean up
  && rm -rf /var/cache/apk/*


# ────────────────────────────────────────────────────────────────────────────────
# User creation
# ────────────────────────────────────────────────────────────────────────────────
RUN \
  # Create user and group
  addgroup -g "${UID}" "${USER}" && \
  adduser -D -G "${USER}" -u "${UID}" -h "${HOME}" -s /bin/bash "${USER}" && \
  # Enable passwordless sudo
  echo "${USER} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/"${USER}" && \
  chmod 440 /etc/sudoers.d/"${USER}" && \
  # Create directories
  mkdir -p "${WORKDIR}" "${HOME}/.local/bin" "${HOME}/.config" "${HOME}/.init.d" "${HOME}/.provision.d" && \
  chown -R "${UID}:${UID}" "${HOME}" "${WORKDIR}" && \
  # Add provision directory to PATH
  echo 'export PATH="${PATH}:${HOME}/.provision.d"' >> /etc/profile.d/00-provision.sh


# ────────────────────────────────────────────────────────────────────────────────
# Install Rust toolchain and tools during build
# ────────────────────────────────────────────────────────────────────────────────
USER "${USER}"
ENV RUSTUP_HOME="${WORKDIR}/.rustup"
ENV CARGO_HOME="${WORKDIR}/.cargo"
ENV PATH="${PATH}:${CARGO_HOME}/bin"

# # Note: Rust toolchain installation moved to provision script
# Only keep minimal setup here for image building
RUN \
  echo "Rust toolchain will be provisioned on first use via ~/.provision.d/rust-provision.sh"

# ────────────────────────────────────────────────────────────────────────────────
# Create initialization scripts
# ────────────────────────────────────────────────────────────────────────────────
USER "${USER}"

# Rust toolchain provisioning script
RUN \
  ( \
    echo '#!/bin/bash' ; \
    echo 'set -euo pipefail' ; \
    echo '' ; \
    echo '# This script provisions Rust toolchain and tools' ; \
    echo '# Run this when you need to work on a Rust project' ; \
    echo '' ; \
    echo 'export RUSTUP_HOME="${WORKDIR}/.rustup"' ; \
    echo 'export CARGO_HOME="${WORKDIR}/.cargo"' ; \
    echo 'export PATH="${PATH}:${CARGO_HOME}/bin"' ; \
    echo '' ; \
    echo '# Initialize rustup if not already done' ; \
    echo 'if ! command -v rustup >/dev/null 2>&1; then' ; \
    echo '  rustup-init -y --no-modify-path --profile minimal --default-toolchain stable' ; \
    echo 'fi' ; \
    echo '' ; \
    echo '# Add musl target' ; \
    echo 'rustup target add x86_64-unknown-linux-musl' ; \
    echo '' ; \
    echo '# Add components' ; \
    echo 'rustup component add rust-src rust-analyzer' ; \
    echo '' ; \
    echo '# Install toolchains' ; \
    echo '(' ; \
    echo '  flock -x -n 3 || exit 55 ;' ; \
    echo '  ! ( rustup toolchain list | grep -q "nightly" ) && rustup toolchain install nightly ;' ; \
    echo '  ! ( rustup component list --toolchain nightly --installed |  grep -q "rust-analyzer" ) || rustup component add rust-analyzer --toolchain nightly ;' ; \
    echo ') 3> "/tmp/rust-nightly.lock"' ; \
    echo '(' ; \
    echo '  flock -x -n 4 || exit 55 ;' ; \
    echo '  ! ( rustup toolchain list | grep -q "stable" ) && (rustup toolchain install stable && rustup default stable );' ; \
    echo '  ! ( rustup component list --toolchain stable --installed | grep -q "rust-analyzer" ) || rustup component add rust-analyzer --toolchain stable ;' ; \
    echo ') 4> "/tmp/rust-stable.lock"' ; \
    echo '{' ; \
    echo '  flock -s 3 ;' ; \
    echo '  flock -u 3 ;' ; \
    echo '} 3<"/tmp/rust-nightly.lock" ;' ; \
    echo '{' ; \
    echo '  flock -s 4 ;' ; \
    echo '  flock -u 4 ;' ; \
    echo '} 4<"/tmp/rust-stable.lock"' ; \
    echo '[ -r "/tmp/rust-nightly.lock" ] && rm -f "/tmp/rust-nightly.lock" ;' ; \
    echo '[ -r "/tmp/rust-stable.lock" ] && rm -f "/tmp/rust-stable.lock" ;' ; \
    echo '' ; \
    echo '# Install cargo tools' ; \
    echo 'if ! command -v cargo-binstall >/dev/null 2>&1; then' ; \
    echo '  cargo install --locked cargo-binstall' ; \
    echo 'fi' ; \
    echo '' ; \
    echo 'cargo binstall -y --no-confirm \\' ; \
    echo '  cargo-cache \\' ; \
    echo '  cargo-watch \\' ; \
    echo '  cargo-edit \\' ; \
    echo '  cargo-update \\' ; \
    echo '  cargo-make' ; \
    echo '' ; \
    echo '# Clean up cargo cache' ; \
    echo 'cargo-cache --remove-dir all' ; \
    echo '' ; \
    echo '# Compress binaries' ; \
    echo 'find "${CARGO_HOME}/bin" -type f -executable | while read -r bin; do' ; \
    echo '  upx -q "$bin" 2>/dev/null || true;' ; \
    echo 'done' ; \
    echo '' ; \
    echo 'echo "Rust environment provisioned successfully!"' ; \
    echo 'echo "Run: source /etc/profile.d/rust.sh to update PATH"' ; \
  ) | tee "${HOME}/.provision.d/rust-provision.sh" > /dev/null && \
  chmod +x "${HOME}/.provision.d/rust-provision.sh"

USER "root"
RUN \
  npm install -g \
    @anthropic-ai/claude-code \
  && npm cache clean --quiet --force ;
USER "${USER}"
# MCP servers initialization script
RUN \
  ( \
    echo '#!/bin/bash' ; \
    echo 'set -euo pipefail' ; \
    echo '' ; \
    echo 'MCP_LOCKFILE="/tmp/mcp-servers.lock"' ; \
    echo 'MCP_INITIALIZED="${WORKDIR}/.mcp-initialized"' ; \
    echo '' ; \
    echo '(' ; \
    echo '  flock -x -n 5 || exit 55' ; \
    echo '  ' ; \
    echo '  if [ ! -f "${MCP_INITIALIZED}" ] && command -v claude >/dev/null 2>&1; then' ; \
    echo '    echo "Setting up MCP servers..."' ; \
    echo '    ' ; \
    echo '    claude mcp add --scope user -- context7 npx -y @upstash/context7-mcp@latest 2>/dev/null || true' ; \
    echo '    ' ; \
    echo '    claude mcp add --scope user -- tavily-mcp npx -y tavily-mcp@0.1.3 2>/dev/null || true' ; \
    echo '    claude mcp add --scope user -- sequential-thinking npx -y @modelcontextprotocol/server-sequential-thinking 2>/dev/null || true' ; \
    echo '    claude mcp add --scope user -- perplexity-ask npx -y server-perplexity-ask 2>/dev/null || true' ; \
    echo '    claude mcp add --scope user -- exa npx -y exa-mcp-server --tools=web_search_exa,github_search,crawling 2>/dev/null || true' ; \
    echo '    claude mcp add --scope user -- firecrawl npx -y firecrawl-mcp 2>/dev/null || true' ; \
    echo '    claude mcp add --scope user -- gitlab-mcp-doc uvx --from mcpdoc mcpdoc \' ; \
    echo '      --urls \' ; \
    echo '      GitLabAdmin:https://raw.githubusercontent.com/da-moon/llms.txt/refs/heads/master/gitlab/administration.txt \' ; \
    echo '      GitLabAPI:https://raw.githubusercontent.com/da-moon/llms.txt/refs/heads/master/gitlab/api.txt \' ; \
    echo '      GitLabArchitecture:https://raw.githubusercontent.com/da-moon/llms.txt/refs/heads/master/gitlab/architecture.txt \' ; \
    echo '      GitLabCI:https://raw.githubusercontent.com/da-moon/llms.txt/refs/heads/master/gitlab/ci.txt \' ; \
    echo '      GitLabCloudSeed:https://raw.githubusercontent.com/da-moon/llms.txt/refs/heads/master/gitlab/cloud_seed.txt \' ; \
    echo '      GitLabDowngrade:https://raw.githubusercontent.com/da-moon/llms.txt/refs/heads/master/gitlab/downgrade_ee_to_ce.txt \' ; \
    echo '      GitLabDrawers:https://raw.githubusercontent.com/da-moon/llms.txt/refs/heads/master/gitlab/drawers.txt \' ; \
    echo '      GitLabEditorExtensions:https://raw.githubusercontent.com/da-moon/llms.txt/refs/heads/master/gitlab/editor_extensions.txt \' ; \
    echo '      GitLabInstall:https://raw.githubusercontent.com/da-moon/llms.txt/refs/heads/master/gitlab/install.txt \' ; \
    echo '      GitLabIntegration:https://raw.githubusercontent.com/da-moon/llms.txt/refs/heads/master/gitlab/integration.txt \' ; \
    echo '      GitLabOperations:https://raw.githubusercontent.com/da-moon/llms.txt/refs/heads/master/gitlab/operations.txt \' ; \
    echo '      GitLabPolicy:https://raw.githubusercontent.com/da-moon/llms.txt/refs/heads/master/gitlab/policy.txt \' ; \
    echo '      GitLabRaketasks:https://raw.githubusercontent.com/da-moon/llms.txt/refs/heads/master/gitlab/raketasks.txt \' ; \
    echo '      GitLabSecurity:https://raw.githubusercontent.com/da-moon/llms.txt/refs/heads/master/gitlab/security.txt \' ; \
    echo '      GitLabSolutions:https://raw.githubusercontent.com/da-moon/llms.txt/refs/heads/master/gitlab/solutions.txt \' ; \
    echo '      GitLabSubscriptions:https://raw.githubusercontent.com/da-moon/llms.txt/refs/heads/master/gitlab/subscriptions.txt \' ; \
    echo '      GitLabTopics:https://raw.githubusercontent.com/da-moon/llms.txt/refs/heads/master/gitlab/topics.txt \' ; \
    echo '      GitLabTutorials:https://raw.githubusercontent.com/da-moon/llms.txt/refs/heads/master/gitlab/tutorials.txt \' ; \
    echo '      GitLabUpdate:https://raw.githubusercontent.com/da-moon/llms.txt/refs/heads/master/gitlab/update.txt \' ; \
    echo '      GitLabUser:https://raw.githubusercontent.com/da-moon/llms.txt/refs/heads/master/gitlab/user.txt \' ; \
    echo '      --allowed-domains '"'"'*'"'"' \' ; \
    echo '      --transport stdio 2>/dev/null || true' ; \
    echo '    ' ; \
    echo '    touch "${MCP_INITIALIZED}"' ; \
    echo '    echo "MCP servers setup complete."' ; \
    echo '  fi' ; \
    echo ') 5> "${MCP_LOCKFILE}"' ; \
    echo '' ; \
    echo '{' ; \
    echo '  flock -s 5' ; \
    echo '  flock -u 5' ; \
    echo '} 5<"${MCP_LOCKFILE}"' ; \
    echo '' ; \
    echo '[ -f "${MCP_LOCKFILE}" ] && rm -f "${MCP_LOCKFILE}"' ; \
  ) | tee "${HOME}/.init.d/02-mcp-servers.sh" > /dev/null && \
  chmod +x "${HOME}/.init.d/02-mcp-servers.sh"

# ────────────────────────────────────────────────────────────────────────────────
# Configure Helix editor
# ────────────────────────────────────────────────────────────────────────────────
RUN \
  mkdir -p "${HOME}/.config/helix" && \
  wget -qO "${HOME}/.config/helix/config.toml" \
    "https://raw.githubusercontent.com/da-moon/.dotfiles/master/config/helix/config.toml" 2>/dev/null || \
  echo 'theme = "monokai_pro_spectrum"' > "${HOME}/.config/helix/config.toml"

# ────────────────────────────────────────────────────────────────────────────────
# Shell configuration
# ────────────────────────────────────────────────────────────────────────────────
USER root
RUN \
  # Starship prompt
  echo 'eval "$(starship init bash)"' | tee "/etc/profile.d/starship.sh" > /dev/null && \
  # Zoxide
  ( \
    echo 'export _ZO_DATA_DIR="${WORKDIR}/.zoxide/"' ; \
    echo '[ ! -d "${_ZO_DATA_DIR}" ] && mkdir -p "${_ZO_DATA_DIR}" ;' ; \
    echo 'eval "$(zoxide init bash)"' ; \
    echo 'alias cd="z"' ; \
  ) | tee "/etc/profile.d/zoxide.sh" > /dev/null && \
  # Atuin
  ( \
    echo '[ ! -d "${HOME}/.config/atuin" ] && mkdir -p "${HOME}/.config/atuin" ;' ; \
    echo "echo 'db_path = \"${WORKDIR}/.history.db\"' > '${HOME}/.config/atuin/config.toml' ;" ; \
    echo 'eval "$(atuin init bash)"' ; \
  ) | tee "/etc/profile.d/atuin.sh" > /dev/null && \
  # Better ls and cat
  ( \
    echo 'alias ls="eza"' ; \
    echo 'alias ll="eza -l"' ; \
    echo 'alias la="eza -la"' ; \
  ) | tee "/etc/profile.d/eza.sh" > /dev/null && \
  ( \
    echo 'alias cat="bat -pp"' ; \
  ) | tee "/etc/profile.d/bat.sh" > /dev/null && \
  # FZF
  ( \
    echo '[ -f /usr/share/fzf/completion.bash ] && source /usr/share/fzf/completion.bash' ; \
    echo '[ -f /usr/share/fzf/key-bindings.bash ] && source /usr/share/fzf/key-bindings.bash' ; \
  ) | tee "/etc/profile.d/fzf.sh" > /dev/null && \
  # Environment variables
  ( \
    echo 'export EDITOR="hx"' ; \
    echo 'export VISUAL="hx"' ; \
    echo 'export PATH="${HOME}/.local/bin:${CARGO_HOME}/bin:${PATH}"' ; \
  ) | tee "/etc/profile.d/editor.sh" > /dev/null && \
  # Task completions
  echo 'eval "$(task --completion bash 2>/dev/null)"' | tee "/etc/profile.d/task.sh" > /dev/null && \
  # Rust environment
  ( \
    echo 'export RUSTUP_HOME="${WORKDIR}/.rustup"' ; \
    echo 'export CARGO_HOME="${WORKDIR}/.cargo"' ; \
    echo 'export PATH="${PATH}:${CARGO_HOME}/bin"' ; \
  ) | tee "/etc/profile.d/rust.sh" > /dev/null

USER "${USER}"
# Configure user's bashrc and profile
RUN \
  # Configure bashrc to follow gitpod pattern
  ( \
    echo '# Source global definitions' ; \
    echo 'if [ -f /etc/bashrc ]; then' ; \
    echo '  . /etc/bashrc' ; \
    echo 'fi' ; \
    echo '' ; \
    echo '# Source profile.d scripts' ; \
    echo 'for i in /etc/profile.d/*.sh; do' ; \
    echo '  if [ -r "$i" ]; then' ; \
    echo '    . "$i"' ; \
    echo '  fi' ; \
    echo 'done' ; \
    echo '' ; \
    echo '# Run init scripts' ; \
    echo 'for script in "${HOME}"/.init.d/*.sh; do' ; \
    echo '  [ -r "$script" ] && source "$script"' ; \
    echo 'done' ; \
  ) | tee "${HOME}/.bashrc" > /dev/null && \
  # Configure profile
  ( \
    echo '# if running bash' ; \
    echo 'if [ -n "$BASH_VERSION" ]; then' ; \
    echo '  # include .bashrc if it exists' ; \
    echo '  if [ -f "$HOME/.bashrc" ]; then' ; \
    echo '    . "$HOME/.bashrc"' ; \
    echo '  fi' ; \
    echo 'fi' ; \
  ) | tee "${HOME}/.profile" > /dev/null

# ────────────────────────────────────────────────────────────────────────────────
# Entrypoint
# ────────────────────────────────────────────────────────────────────────────────
USER root
RUN \
  ( \
    echo '#!/bin/bash' ; \
    echo 'set -euo pipefail' ; \
    echo '' ; \
    echo 'chown -R "${UID}:${UID}" "${WORKDIR}" 2>/dev/null || true' ; \
    echo '' ; \
    echo 'if [ -d "${HOME}/.ssh" ]; then' ; \
    echo '  chmod 700 "${HOME}/.ssh"' ; \
    echo '  [ -f "${HOME}/.ssh/authorized_keys" ] && chmod 644 "${HOME}/.ssh/authorized_keys"' ; \
    echo '  [ -f "${HOME}/.ssh/config" ] && chmod 644 "${HOME}/.ssh/config"' ; \
    echo '  find "${HOME}/.ssh" -type f -name "id_*" ! -name "*.pub" -exec chmod 600 {} \; 2>/dev/null || true' ; \
    echo '  find "${HOME}/.ssh" -type f -name "id_*.pub" -exec chmod 644 {} \; 2>/dev/null || true' ; \
    echo 'fi' ; \
    echo '' ; \
    echo '# Run init scripts before executing command' ; \
    echo 'if [ -d "${HOME}/.init.d" ]; then' ; \
    echo '  for script in "${HOME}"/.init.d/*.sh; do' ; \
    echo '    [ -r "$script" ] && source "$script"' ; \
    echo '  done' ; \
    echo 'fi' ; \
    echo '' ; \
    echo '# Switch to user and execute command' ; \
    echo 'if [ "$(id -u)" = "0" ]; then' ; \
    echo '  exec su-exec "${USER}" "$@"' ; \
    echo 'else' ; \
    echo '  exec "$@"' ; \
    echo 'fi' ; \

  ) | tee /entrypoint.sh > /dev/null && \
  chmod +x /entrypoint.sh

# ────────────────────────────────────────────────────────────────────────────────
# Final setup
# ────────────────────────────────────────────────────────────────────────────────
USER "${USER}"
WORKDIR "${WORKDIR}"

# Environment variables
ENV TERM="xterm-256color"
ENV COLORTERM="truecolor"
ENV EDITOR="hx"
ENV VISUAL="hx"
ENV PIP_BREAK_SYSTEM_PACKAGES="1"
ENV PATH="${HOME}/.local/bin:${CARGO_HOME}/bin:${PATH}"
ENV RUSTUP_HOME="${WORKDIR}/.rustup"
ENV CARGO_HOME="${WORKDIR}/.cargo"

ENTRYPOINT ["/entrypoint.sh"]
CMD ["claude"]
