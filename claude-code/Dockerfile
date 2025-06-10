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
VOLUME ["${WORKDIR}"]
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
    bash bash-completion sudo shadow coreutils \
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
    tokei shellcheck shfmt \
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
  mkdir -p "${WORKDIR}" "${HOME}/.local/bin" "${HOME}/.config" "${HOME}/.init.d" && \
  chown -R "${UID}:${UID}" "${HOME}" "${WORKDIR}"


# ────────────────────────────────────────────────────────────────────────────────
# Install Rust toolchain and tools during build
# ────────────────────────────────────────────────────────────────────────────────
USER "${USER}"
ENV RUSTUP_HOME="${HOME}/.rustup"
ENV CARGO_HOME="${HOME}/.cargo"
ENV PATH="${PATH}:${CARGO_HOME}/bin"

# # Install Rust and cargo tools
# RUN --mount=type=secret,id=github_token \
#   # Setup GitHub token for cargo-binstall if available
#   if [ -f /run/secrets/github_token ]; then \
#     export GITHUB_TOKEN=$(cat /run/secrets/github_token); \
#   fi && \
#   # Initialize rustup
#   rustup-init -y --no-modify-path --profile minimal --default-toolchain stable && \
#   # Add musl target
#   rustup target add x86_64-unknown-linux-musl && \
#   # Add components
#   rustup component add rust-src rust-analyzer && \
#   # Install nightly toolchain
#   rustup toolchain install nightly && \
#   # Install cargo-binstall
#   cargo install --locked cargo-binstall && \
#   # Install tools via cargo-binstall
#   cargo binstall -y --no-confirm \
#     cargo-cache \
#     cargo-watch \
#     cargo-edit \
#     cargo-update \
#     cargo-make \
#     hyperfine && \
#   # Clean up cargo cache
#   cargo-cache --remove-dir all && \
#   # Remove toolchains but keep cargo binaries
#   rm -rf "${RUSTUP_HOME}/toolchains" "${RUSTUP_HOME}/downloads" "${RUSTUP_HOME}/tmp"

# USER root
# # Compress cargo binaries
# RUN \
#   find "${CARGO_HOME}/bin" -type f -executable | while read -r bin; do \
#     upx -q "$bin" 2>/dev/null || true; \
#   done

# ────────────────────────────────────────────────────────────────────────────────
# Create initialization scripts
# ────────────────────────────────────────────────────────────────────────────────
USER "${USER}"

# Rust toolchain initialization script
RUN \
  ( \
    echo '#!/bin/bash' ; \
    echo 'set -euo pipefail' ; \
    echo '' ; \
    echo '# Rust toolchain installation with proper locking' ; \
    echo '(' ; \
    echo '  flock -x -n 3 || exit 55' ; \
    echo '  if [ ! -d "${HOME}/.rustup/toolchains/stable"* ]; then' ; \
    echo '    echo "Installing Rust stable toolchain..."' ; \
    echo '    rustup toolchain install stable' ; \
    echo '    rustup default stable' ; \
    echo '  fi' ; \
    echo ') 3> "/tmp/rust-stable.lock"' ; \
    echo '' ; \
    echo '(' ; \
    echo '  flock -x -n 4 || exit 55' ; \
    echo '  if [ ! -d "${HOME}/.rustup/toolchains/nightly"* ]; then' ; \
    echo '    echo "Installing Rust nightly toolchain..."' ; \
    echo '    rustup toolchain install nightly' ; \
    echo '  fi' ; \
    echo ') 4> "/tmp/rust-nightly.lock"' ; \
    echo '' ; \
    echo '# Wait for both locks to be released' ; \
    echo '{' ; \
    echo '  flock -s 3' ; \
    echo '  flock -u 3' ; \
    echo '} 3<"/tmp/rust-stable.lock"' ; \
    echo '' ; \
    echo '{' ; \
    echo '  flock -s 4' ; \
    echo '  flock -u 4' ; \
    echo '} 4<"/tmp/rust-nightly.lock"' ; \
    echo '' ; \
    echo '# Clean up lock files' ; \
    echo '[ -f "/tmp/rust-stable.lock" ] && rm -f "/tmp/rust-stable.lock"' ; \
    echo '[ -f "/tmp/rust-nightly.lock" ] && rm -f "/tmp/rust-nightly.lock"' ; \
    echo '' ; \
    echo 'export PATH="${PATH}:${CARGO_HOME}/bin"' ; \
  ) | tee "${HOME}/.init.d/01-rust.sh" > /dev/null && \
  chmod +x "${HOME}/.init.d/01-rust.sh"

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
    echo '    if [ -n "${TAVILY_API_KEY:-}" ]; then' ; \
    echo '      claude mcp add --scope user -- tavily-mcp npx -y tavily-mcp@0.1.3 2>/dev/null || true' ; \
    echo '    fi' ; \
    echo '    ' ; \
    echo '    claude mcp add --scope user -- sequential-thinking npx -y @modelcontextprotocol/server-sequential-thinking 2>/dev/null || true' ; \
    echo '    ' ; \
    echo '    if [ -n "${PERPLEXITY_API_KEY:-}" ]; then' ; \
    echo '      claude mcp add --scope user -- perplexity-ask npx -y server-perplexity-ask 2>/dev/null || true' ; \
    echo '    fi' ; \
    echo '    ' ; \
    echo '    if [ -n "${EXA_API_KEY:-}" ]; then' ; \
    echo '      claude mcp add --scope user -- exa npx -y exa-mcp-server --tools=web_search_exa,github_search,crawling 2>/dev/null || true' ; \
    echo '    fi' ; \
    echo '    ' ; \
    echo '    if [ -n "${FIRECRAWL_API_KEY:-}" ]; then' ; \
    echo '      claude mcp add --scope user -- firecrawl npx -y firecrawl-mcp 2>/dev/null || true' ; \
    echo '    fi' ; \
    echo '    ' ; \
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
RUN \
  # Starship prompt
  echo 'eval "$(starship init bash)"' >> "${HOME}/.bashrc" && \
  # Zoxide
  echo 'eval "$(zoxide init bash)"' >> "${HOME}/.bashrc" && \
  echo 'alias cd="z"' >> "${HOME}/.bashrc" && \
  # Atuin
  mkdir -p "${HOME}/.config/atuin" && \
  echo "db_path = \"${WORKDIR}/.history.db\"" > "${HOME}/.config/atuin/config.toml" && \
  echo 'eval "$(atuin init bash)"' >> "${HOME}/.bashrc" && \
  # Better ls
  echo 'alias ls="eza"' >> "${HOME}/.bashrc" && \
  echo 'alias ll="eza -l"' >> "${HOME}/.bashrc" && \
  echo 'alias la="eza -la"' >> "${HOME}/.bashrc" && \
  # Better cat
  echo 'alias cat="bat -pp"' >> "${HOME}/.bashrc" && \
  # FZF
  echo '[ -f /usr/share/fzf/completion.bash ] && source /usr/share/fzf/completion.bash' >> "${HOME}/.bashrc" && \
  echo '[ -f /usr/share/fzf/key-bindings.bash ] && source /usr/share/fzf/key-bindings.bash' >> "${HOME}/.bashrc" && \
  # Environment variables
  echo 'export EDITOR="hx"' >> "${HOME}/.bashrc" && \
  echo 'export VISUAL="hx"' >> "${HOME}/.bashrc" && \
  echo 'export PATH="${HOME}/.local/bin:${CARGO_HOME}/bin:${PATH}"' >> "${HOME}/.bashrc" && \
  # Poetry
  echo 'export PATH="${HOME}/.local/bin:${PATH}"' >> "${HOME}/.bashrc" && \
  # Task completions
  echo 'eval "$(task --completion bash 2>/dev/null)"' >> "${HOME}/.bashrc" && \
  # Run init scripts
  echo 'for script in "${HOME}"/.init.d/*.sh; do [ -r "$script" ] && source "$script"; done' >> "${HOME}/.bashrc"

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
    # ERROR:
    # su: must be suid to work properly
    # echo 'exec su - "${USER}" -c '"'"'cd "${WORKDIR}" && exec "$@"'"'"' -- "$@"' ; \
    echo 'exec "$@"' ; \

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
