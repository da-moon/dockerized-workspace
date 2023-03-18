# syntax = docker/dockerfile:labs
# vim: filetype=dockerfile softtabstop=2 tabstop=2 shiftwidth=2 fileencoding=utf-8 expandtab
# code: language=dockerfile insertSpaces=true tabSize=2
# ────────────────────────────────────────────────────────────────────────────────
# hadolint ignore=DL3007
FROM archlinux:latest
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
USER "root"
ENV USER="gitpod"
ENV UID="33333"
ENV HOME="/home/${USER}"
#  ╭──────────────────────────────────────────────────────────╮
#  │                      initial setup                       │
#  ╰──────────────────────────────────────────────────────────╯
# hadolint ignore=DL3059
RUN pacman-key --init ;
# hadolint ignore=DL3059
RUN pacman-key --populate "archlinux";
RUN \
  # ─── DOWNLOAD SIXTEEN PACKAGES CONCURRENTLY ─────────────────────────────────────
  sed -i \
  -e "/ParallelDownloads/d" \
  -e  '/\[options\]/a ParallelDownloads = 16' \
  "/etc/pacman.conf" \
  # ─── USE PACMAN AVATAR FOR SHOWING PROGRESS ─────────────────────────────────────
  && sed -i \
  -e "/Color/d" \
  -e "/ILoveCandy/d" \
  -e '/\[options\]/a Color' \
  -e '/\[options\]/a ILoveCandy' \
  "/etc/pacman.conf" \
  && ( \
  # we use this to update installed packages one time after contaienr starts. this
  # gets executed whe the first shell is opened. This approach is to make the
  # docker images as small as possible since upgrading all packages creates large
  # diffs and large image sizes
  echo '[ ! -r "/.pacman-update" ] && ( sudo pacman -Syyu --noconfirm && sudo touch "/.pacman-update" )' ; \
  echo 'alias pacman="sudo pacman"' ; \
  ) | tee "/etc/profile.d/pacman.sh" > /dev/null ;
#  ╭──────────────────────────────────────────────────────────╮
#  │                 finding fastest sources                  │
#  ╰──────────────────────────────────────────────────────────╯
RUN \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
  pacman -Syy --noconfirm --needed "reflector" \
  && reflector \
  --verbose \
  -p https \
  --latest 5 \
  --sort rate \
  --save "/etc/pacman.d/mirrorlist"
#  ╭──────────────────────────────────────────────────────────╮
#  │                   user and group setup                   │
#  ╰──────────────────────────────────────────────────────────╯
# hadolint ignore=SC2016
RUN \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
  pacman -Syy --noconfirm --needed "sudo" "openssl" \
  && ! getent group "${USER}" > /dev/null \
  && groupadd --gid "${UID}" "${USER}" > /dev/null > /dev/null \
  && useradd \
  --no-log-init \
  --create-home \
  --home-dir "${HOME}" \
  --gid "${UID}" \
  --uid "${UID}" \
  --shell "/bin/bash" \
  # ─── USER PASSWORD IS THE SAME AS THE USERNAME ──────────────────────────────────
  --password \
  "$(openssl passwd -1 -salt SaltSalt '${USER}' 2>/dev/null)" \
  "${USER}" \
  # ─── CREATE SUDO GROUP ID IT DOES NOT EXIST ─────────────────────────────────────
  && ! getent group sudo > /dev/null && groupadd sudo \
  # ─── ALLOW PASSWORDLESS SUDO FOR USERS BELONGING TO WHELL GROUP ─────────────────
  && sed -i \
  -e '/%wheel.*NOPASSWD:\s*ALL/d' \
  -e '/%wheel\s\+ALL=(ALL\(:ALL\)\?)\s\+ALL/d' \
  "/etc/sudoers" \
  && ( \
  echo "%wheel ALL=(ALL) ALL" ; \
  echo "%wheel ALL=(ALL) NOPASSWD: ALL" ; \
  ) | tee -a "/etc/sudoers" > /dev/null  \
  # ─── UPDATE USER GROUP MEMBERSHIP ───────────────────────────────────────────────
  && usermod -aG wheel,root,sudo "${USER}" \
  # ─── ENSURE USER HOME HAS THE RIGHT OWNERSHIP ───────────────────────────────────
  && chown "$(id -u "${USER}"):$(id -g "${USER}")" "${HOME}" -R
#  ╭──────────────────────────────────────────────────────────╮
#  │                    install core tools                    │
#  ╰──────────────────────────────────────────────────────────╯
RUN \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
  pacman -Syy --noconfirm --needed \
  "openssh" \
  "nushell" \
  "man-db" \
  "wget" \
  "curl" \
  "make" \
  "jq" \
  "unzip" \
  "unrar" \
  "dialog" \
  "psutils" \
  "moreutils" \
  "rclone" \
  "expac" \
  "bash-completion" ;

#  ╭──────────────────────────────────────────────────────────╮
#  │              install makepkg dependencies                │
#  ╰──────────────────────────────────────────────────────────╯
RUN \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
  pacman -Syy --noconfirm --needed \
  "base-devel" \
  "git" \
  # ─── BASE GIT CONFIGS ───────────────────────────────────────────────────────────
  && git --version > /dev/null 2>&1 && ( \
  git config --system push.recurseSubmodules "on-demand" \
  && git config --system diff.submodule "log" \
  && git config --system status.submoduleSummary "true" \
  ) || exit 1 ;
#  ╭──────────────────────────────────────────────────────────╮
#  │                   install aur packages                   │
#  ╰──────────────────────────────────────────────────────────╯
USER "${USER}"
# hadolint ignore=SC2034
RUN \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  AUR_CLONE_URLS=( \
  "https://aur.archlinux.org/aura-bin.git" \
  "https://aur.archlinux.org/paru-bin.git" \
  "https://aur.archlinux.org/go-task.git" \
  "https://aur.archlinux.org/git-completion.git" \
  "https://aur.archlinux.org/fzf-extras.git" \
  "https://aur.archlinux.org/powershell-bin.git" \
  "https://aur.archlinux.org/shellcheck-bin.git" \
  ) ; \
  export MAKEFLAGS="-j$(nproc)" ; \
  for url in "${AUR_CLONE_URLS[@]}";do \
  git clone "${url}" "/tmp/"$(basename "${url%.git}")"" \
  && pushd "/tmp/"$(basename "${url%.git}")"" > /dev/null 2>&1 ; \
  for i in {1..5}; do makepkg -sicr --noconfirm && break || sleep 15; done \
  && popd > /dev/null 2>&1 || exit 1 ; \
  done ;
#  ╭──────────────────────────────────────────────────────────╮
#  │                 setup powershell profile                 │
#  ╰──────────────────────────────────────────────────────────╯
USER "${USER}"
SHELL ["/usr/bin/pwsh", "-NoLogo", "-Command"]
RUN $parent=Split-Path -parent $PROFILE ; if (-not(Test-Path -Path $parent -PathType Container)) {$null = New-Item -ItemType Directory -Path $parent -Force -ErrorAction Stop}
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
#  ╭──────────────────────────────────────────────────────────╮
#  │                          docker                          │
#  ╰──────────────────────────────────────────────────────────╯
USER "root"
# hadolint ignore=SC2016
RUN \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
  pacman -Syy --noconfirm --needed \
  "docker" \
  "docker-buildx" \
  "docker-machine" \
  "docker-scan" \
  "docker-compose" \
  && ( \
  echo '#!/bin/sh' ; \
  echo 'sudoIf() { if [ "$(id -u)" -ne 0 ]; then sudo "$@"; else "$@"; fi }' ; \
  # ─── DOCKER FROM DOCKER ─────────────────────────────────────────────────────────
  echo 'if [ -r "/var/run/docker.sock" ];then' ; \
  echo 'SOCKET_GID="$(stat -c "%g" "/var/run/docker.sock")" ; ' ; \
  echo '  if [ "${SOCKET_GID}" != 0 ]; then' ; \
  echo '      if [ "$(cat "/etc/group" | grep :${SOCKET_GID}:)" = "" ]; then sudoIf groupadd --gid "${SOCKET_GID}" "docker-host"; fi' ; \
  echo '      if [ "$(id "$(whoami)" | grep -E "groups=.*(=|,)${SOCKET_GID}\(")" = "" ]; then sudoIf usermod -aG "${SOCKET_GID}" "$(whoami)"; fi' ; \
  echo '  fi' ; \
  echo 'fi' ; \
  ) | tee '/usr/local/share/docker-from-docker.sh' > /dev/null \
  && chmod +x '/usr/local/share/docker-from-docker.sh' ;
#  ╭──────────────────────────────────────────────────────────╮
#  │                          fonts                           │
#  ╰──────────────────────────────────────────────────────────╯
USER "root"
RUN \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
  pacman -Syy --noconfirm --needed \
  "noto-fonts" \
  "ttf-ubuntu-font-family" \
  "ttf-font-awesome" ;
#  ╭──────────────────────────────────────────────────────────╮
#  │             install modern cli applications              │
#  ╰──────────────────────────────────────────────────────────╯
# hadolint ignore=DL3059
USER "root"
RUN \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
  pacman -Syy --noconfirm --needed \
  "sd" \
  "duf" \
  "shfmt"  \
  "ripgrep" \
  "fd" \
  "tokei" \
  "hyperfine"  ;
#  ────────────────────────────────────────────────────────────
# ensures shell always has the latest gipod variables
# hadolint ignore=SC2016
RUN \
  ( \
  echo 'if gp version > /dev/null 2>&1 ; then' ;\
  echo '  eval "$(gp env --export)" ;' ;\
  echo 'fi' ;\
  ) | tee "/etc/profile.d/gitpod.sh" > /dev/null || exit 1
#  ────────────────────────────────────────────────────────────
USER "root"
# hadolint ignore=SC2016
RUN \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
  pacman -Syy --noconfirm --needed "just" \
  && just --version > /dev/null 2>&1 \
  && echo 'eval "$(just --completions bash)" ;' > "/etc/profile.d/just.sh" \
  || exit 1 ;
#  ────────────────────────────────────────────────────────────
USER "root"
# hadolint ignore=SC2016
RUN \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
  pacman -Syy --noconfirm --needed "starship" \
  && starship --version > /dev/null 2>&1 \
  && echo 'eval "$(starship init bash)" ;' > "/etc/profile.d/starship.sh" \
  || exit 1;
#  ────────────────────────────────────────────────────────────
USER "root"
RUN \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
  pacman -Syy --noconfirm --needed "git-delta" \
  # ─── USE DELTA FOR GIT DIFFS ────────────────────────────────────────────────────
  && delta --version > /dev/null 2>&1 && ( \
  git config --system pager.diff delta \
  && git config --system pager.log delta \
  && git config --system pager.reflog delta \
  && git config --system pager.show delta \
  && git config --system interactive.difffilter "delta --color-only --features=interactive" \
  && git config --system delta.features "side-by-side line-numbers decorations" \
  && git config --system delta.whitespace-error-style "22 reverse" \
  && git config --system delta.decorations.commit-decoration-style "bold yellow box ul" \
  && git config --system delta.decorations.file-style "bold yellow ul" \
  && git config --system delta.decorations.file-decoration-style "none" \
  && git config --system delta.decorations.commit-style "raw" \
  && git config --system delta.decorations.hunk-header-decoration-style "blue box" \
  && git config --system delta.decorations.hunk-header-file-style "red" \
  && git config --system delta.decorations.hunk-header-line-number-style "#067a00" \
  && git config --system delta.decorations.hunk-header-style "file line-number syntax" \
  && git config --system delta.interactive.keep-plus-minus-markers "false" \
  ) || exit 1 ;
#  ────────────────────────────────────────────────────────────
USER "root"
RUN \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
  pacman -Syy --noconfirm --needed \
  "exa" \
  && exa --version > /dev/null 2>&1 && ( \
  echo 'alias la="exa -alhF" ;' ; \
  echo 'alias ll="exa -lhF" ;' ; \
  echo 'alias llfu="exa -bghHliS --git" ;' ; \
  echo 'alias llt="exa -T" ;' ; \
  echo 'alias ls="exa" ;' ; \
  ) | tee "/etc/profile.d/exa.sh" > /dev/null || exit 1 ;
#  ────────────────────────────────────────────────────────────
USER "root"
RUN \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
  pacman -Syy --noconfirm --needed "bat" \
  && bat --version > /dev/null 2>&1 && ( \
  echo 'alias cat="bat -pp" ;' ; \
  echo "export MANPAGER='sh -c \"col -bx | bat --language man --style plain\"' ;" ; \
  ) | tee "/etc/profile.d/bat.sh" > /dev/null || exit 1  ;
#  ────────────────────────────────────────────────────────────
USER "root"
# hadolint ignore=SC2016
RUN \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
  pacman -Syy --noconfirm --needed "fzf" \
  && fzf --version > /dev/null 2>&1 && ( \
  echo '_fzf_complete_make() {' ; \
  echo '  FZF_COMPLETION_TRIGGER="" _fzf_complete "-1" "${@}" < <(make -pqr 2>/dev/null \' ; \
  echo '  | awk -F":" "/^[a-zA-Z0-9][^\$#\/\t=]*:([^=]|\$)/ {split(\$1,A,/ /);for(i in A)print A[i]}" \' ; \
  echo '  | grep -v Makefile \' ; \
  echo '  | sort -u)' ; \
  echo '}' ; \
  echo '[[ -n ${BASH} ]] && complete -F _fzf_complete_make -o default -o bashdefault make' ; \
  echo '[ -r "/usr/share/fzf/key-bindings.bash" ] && source "/usr/share/fzf/key-bindings.bash"' ; \
  echo '[ -r "/usr/share/fzf/completion.bash" ] && source "/usr/share/fzf/completion.bash"' ; \
  ) | tee "/etc/profile.d/fzf.sh" > /dev/null || exit 1 ;

#  ╭──────────────────────────────────────────────────────────╮
#  │                 rust setup                               │
#  ╰──────────────────────────────────────────────────────────╯
USER "root"
ENV RUSTUP_HOME="${HOME}/.rustup"
ENV CARGO_HOME="${HOME}/.cargo"
ENV PATH="${PATH}:${CARGO_HOME}/bin"
# hadolint ignore=SC2016
RUN \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
  pacman -Syy --noconfirm --needed "rustup" \
  && rustup --version > /dev/null 2>&1 \
  && rustup toolchain install nightly stable \
  && rustup default stable \
  && cargo --version > /dev/null 2>&1 \
  &&  ( \
  echo 'eval "$(rustup completions bash rustup)";' ; \
  echo 'eval "$(rustup completions bash cargo)";' ; \
  echo 'export RUSTUP_HOME="${HOME}/.rustup";' ; \
  echo 'export CARGO_HOME="${HOME}/.cargo";' ; \
  echo 'export PATH="${PATH}:${CARGO_HOME}/bin";' ; \
  ) | tee "/etc/profile.d/rust.sh" > /dev/null || exit 1 ;
#  ╭──────────────────────────────────────────────────────────╮
#  │                 install lua packages                     │
#  ╰──────────────────────────────────────────────────────────╯
USER "root"
ENV PATH="${PATH}:${HOME}/.luarocks/bin"
# hadolint ignore=SC2016
RUN \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
  pacman -Syy --noconfirm --needed \
  "lua" \
  "luajit" \
  "luarocks" ;
#  ╭──────────────────────────────────────────────────────────╮
#  │                 install go packages                      │
#  ╰──────────────────────────────────────────────────────────╯
USER "root"
ENV GO111MODULE="on"
ENV CGO_ENABLED="0"
ENV CGO_LDFLAGS="-s -w -extldflags '-static'"
# hadolint ignore=SC2016
RUN \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
  pacman -Syy --noconfirm --needed \
  "go" "goreleaser" "mage" \
  && go version > /dev/null 2>&1 \
  &&  ( \
  echo 'export PATH="${PATH}:$(go env GOPATH)/bin";' ; \
  ) | tee "/etc/profile.d/go.sh" > /dev/null || exit 1 ;
#  ╭──────────────────────────────────────────────────────────╮
#  │                 install ruby packages                    │
#  ╰──────────────────────────────────────────────────────────╯
USER "root"
ENV GEM_PATH="${HOME}/.gem"
# hadolint ignore=SC2016,DL3028
RUN \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
  pacman -Syy --noconfirm --needed \
  "ruby" \
  && gem --version > /dev/null 2>&1 \
  && gem install --no-user-install \
  "bundler" \
  "serverspec" \
  &&  ( \
  echo 'export GEM_HOME="$(ruby -e "puts Gem.user_dir")";' ; \
  echo 'export PATH="${PATH}:${GEM_HOME}/bin";' ; \
  ) | tee "/etc/profile.d/ruby.sh" > /dev/null || exit 1 ;
#  ╭──────────────────────────────────────────────────────────╮
#  │                     python packages                      │
#  ╰──────────────────────────────────────────────────────────╯
USER "root"
ENV PATH="${PATH}:${HOME}/.local/bin"
# hadolint ignore=DL3004,SC2016
RUN \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
  pacman -Syy --noconfirm --needed \
  "python" \
  "python-pip" \
  "python-setuptools" \
  "python-pre-commit" \
  && sudo -i -u "${USER}" bash -c 'curl -sSL https://install.python-poetry.org | python3 -' \
  && ln -sf "${HOME}/.local/bin/poetry" "/usr/local/bin/poetry" \
  && poetry --version > /dev/null 2>&1 \
  && ( \
  echo 'eval "$(poetry completions bash)" ;' ; \
  ) | tee "/etc/profile.d/poetry.sh" > /dev/null || exit 1 ;
#  ╭──────────────────────────────────────────────────────────╮
#  │                 install nodejs packages                  │
#  ╰──────────────────────────────────────────────────────────╯
USER "root"
# hadolint ignore=SC2016
RUN \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
  pacman -Syy --noconfirm --needed \
  "nodejs" \
  "npm" \
  "yarn" \
  && npm  --version >/dev/null 2>&1 \
  && yarn --version >/dev/null 2>&1 \
  && echo 'export PATH="$(npm -g bin):${PATH}" ;' > "/etc/profile.d/npm.sh" || exit 1 \
  && echo 'export PATH="$(yarn global bin):${PATH}" ;' > "/etc/profile.d/yarn.sh" || exit 1 ;
# hadolint ignore=DL3016
RUN \
  npm install --silent -g \
  "prettier" \
  "@commitlint/cli" \
  "@commitlint/config-conventional" \
  "cspell-cli" \
  "github-label-sync" \
  "markdownlint-cli" \
  "remark" \
  "remark-cli" \
  "remark-frontmatter" \
  "remark-stringify" \
  "remark-toc" \
  "remark-preset-lint-recommended" \
  "remark-lint-list-item-indent" \
  "remark-reference-links" \
  "standard-readme-spec" \
  "yo" \
  "generator-standard-readme" ;
#  ╭──────────────────────────────────────────────────────────╮
#  │                    install text editors                  │
#  ╰──────────────────────────────────────────────────────────╯
# pacman -Si helix | awk -F':' '/^ .*: / {print $1}' | sed 's/\s//g'
USER "root"
ENV COLORTERM="truecolor"
ENV EDITOR="nvim"
ENV VISUAL="nvim"
RUN \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
  pacman -Syy --noconfirm --needed \
  "neovim"
# Install language servers
# hadolint ignore=DL3016,DL3013
RUN \
  npm install -g --silent awk-language-server && awk-language-server --version > /dev/null 2>&1 && \
  npm install -g --silent bash-language-server && bash-language-server --version > /dev/null 2>&1 && \
  npm install -g --silent dockerfile-language-server-nodejs && docker-langserver --node-ipc > /dev/null 2>&1 && \
  npm install -g --silent yaml-language-server && yaml-language-server --node-ipc > /dev/null 2>&1 && \
  npm install -g --silent vscode-json-languageserver ; \
  python3 -m pip install -q --no-cache-dir "python-lsp-server[all]" ; \
  go version > /dev/null 2>&1 && { \
    go install golang.org/x/tools/gopls@latest && gopls version > /dev/null 2>&1 ; \
    go install github.com/hashicorp/terraform-ls@latest && terraform-ls version > /dev/null 2>&1 ; \
  } ; \
  wget -qO - "https://api.github.com/repos/artempyanykh/marksman/releases/latest" \
  | jq -r "\
  .assets[]|select(\
  .browser_download_url \
  | (\
  contains(\"linux\") \
  and (contains(\"sha256\") | not) \
  )).browser_download_url" \
  | xargs -r -I {} wget -qO "/usr/local/bin/marksman" {} \
  && chmod +x "/usr/local/bin/marksman" \
  && marksman --version ;
# Setup Helix installer script
# hadolint ignore=DL3004,SC2016
RUN \
( \
  echo '#!/usr/bin/env bash' ; \
  echo 'set -euo pipefail ;' ; \
  echo '! wget --version > /dev/null 2>&1 && { echo "*** "wget" not found"; exit 1; } ' ; \
  echo '! jq --version > /dev/null 2>&1 && { echo "*** "jq" not found"; exit 1; } ' ; \
  echo '! sudo --version > /dev/null 2>&1 && { echo "*** "sudo" not found"; exit 1; } ' ; \
  echo '! xz --version > /dev/null 2>&1 && { echo "*** "xz" not found"; exit 1; } ' ; \
  echo '! tar --version > /dev/null 2>&1 && { echo "*** "xz" not found"; exit 1; } ' ; \
  echo '! xargs --version > /dev/null 2>&1 && { echo "*** "xz" not found"; exit 1; } ' ; \
  echo 'dir="$(mktemp -d)" ;' ; \
  echo 'architecture="x86_64"' ; \
  echo 'wget -qO - "https://api.github.com/repos/helix-editor/helix/releases/latest" \' ; \
  echo '| jq -r "\' ; \
  echo '.assets[]|select(\' ; \
  echo '.browser_download_url \' ; \
  echo '| (\' ; \
  echo 'contains(\"${architecture}\") \' ; \
  echo 'and contains(\"linux\") \' ; \
  echo 'and contains(\"tar\") \' ; \
  echo 'and (contains(\"sha256\") | not) \' ; \
  echo ')).browser_download_url" \' ; \
  echo '  | xargs -r -I {} wget -O - {} 2> /dev/null \' ; \
  echo '  | xz -d -c  \' ; \
  echo '  | tar -xv -C "${dir}" --strip-components=1 ' ; \
  echo 'chmod +x "${dir}/hx"' ; \
  echo '[ ! -d "${HOME}/.local/bin" ] && mkdir -p "${HOME}/.local/bin" ;' ; \
  echo 'mv -f "${dir}/hx" "${HOME}/.local/bin/hx"' ; \
  echo '[ -d "${HOME}/.config/helix/runtime" ] && sudo rm -r "${HOME}/.config/helix/runtime"' ; \
  echo 'mkdir -p "${HOME}/.config/helix"' ; \
  echo 'mv "${dir}/runtime" "${HOME}/.config/helix/runtime"' ; \
  echo 'hx --version && rm -r "${dir}"' ; \
  echo 'hx --grammar fetch' ; \
  echo 'hx --grammar build' ; \
) | tee "/usr/local/share/install-helix.sh" > /dev/null \
&& chmod +x "/usr/local/share/install-helix.sh" \
&& chown "$(id -u "${USER}"):$(id -g "${USER}")" "/usr/local/share/install-helix.sh" \
&& sudo -i -u "${USER}" bash -c '/usr/local/share/install-helix.sh' \
&& [ -r "${HOME}/.local/bin/hx" ] && ln -sf "${HOME}/.local/bin/hx" "/usr/local/bin/hx"
#  ╭──────────────────────────────────────────────────────────╮
#  │                  infrustructure as code                  │
#  ╰──────────────────────────────────────────────────────────╯
USER "root"
# hadolint ignore=SC2034,DL3013,DL4006
RUN \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  pacman -Syy --noconfirm --needed \
  "packer" \
  "consul" \
  "consul-template" \
  "vault" \
  "pulumi" \
  "kustomize" \
  "kubectl" \
  "helm" \
  "kube-linter" \
  "istio" \
  "caddy" \
  "traefik" \
  "ansible" \
  "aws-cli-v2" \
&& python3 -m pip install -q --no-cache-dir \
  "checkov" ;
# ────────────────────────────────────────────────────────────────────────────────
USER "${USER}"
# hadolint ignore=SC2034
RUN \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  AUR_CLONE_URLS=( \
  # cloud
  "https://aur.archlinux.org/azure-cli.git" \
  "https://aur.archlinux.org/azcopy.git" \
  "https://aur.archlinux.org/bicep-bin.git" \
  "https://aur.archlinux.org/google-cloud-cli.git" \
  # terraform
  "https://aur.archlinux.org/tfsec-bin.git" \
  "https://aur.archlinux.org/tflint-bin.git" \
  "https://aur.archlinux.org/terrascan.git" \
  "https://aur.archlinux.org/tfenv.git" \
  "https://aur.archlinux.org/terraform-docs-bin.git" \
  # ansible
  "https://aur.archlinux.org/ansible-completion-git.git" \
  # generic tools
  "https://aur.archlinux.org/pulumictl.git" \
  "https://aur.archlinux.org/infracost.git" \
  "https://aur.archlinux.org/driftctl-bin.git" \
  "https://aur.archlinux.org/rancher-k3d-bin.git" \
  "https://aur.archlinux.org/envoyproxy-bin.git" \
  "https://aur.archlinux.org/gojira.git" \
  "https://aur.archlinux.org/k6.git" \
  "https://aur.archlinux.org/litmusctl.git" \
  ) ; \
  export MAKEFLAGS="-j$(nproc)" ; \
  for url in "${AUR_CLONE_URLS[@]}";do \
  git clone "${url}" "/tmp/"$(basename "${url%.git}")"" \
  && pushd "/tmp/"$(basename "${url%.git}")"" > /dev/null 2>&1 ; \
  for i in {1..5}; do makepkg -sicr --noconfirm && break || sleep 15; done \
  && popd > /dev/null 2>&1 || exit 1 ; \
  done ;
# ────────────────────────────────────────────────────────────────────────────────

USER "root"
# hadolint ignore=SC2016
RUN \
  GROUPS_ARR=( \
  "tfenv" \
  "consul" \
  "vault" \
  "caddy" \
  "traefik" \
  ) ; \
  for group in "${GROUPS_ARR[@]}";do \
    getent group "${group}" > /dev/null 2>&1 && usermod -aG "${group}" "${USER}" || continue ; \
  done ; \
  driftctl version >/dev/null 2>&1 && ( \
  echo 'eval "$(driftctl completion bash)" ;' ; \
  ) | tee "/etc/profile.d/driftctl.sh" > /dev/null || exit 0


# ────────────────────────────────────────────────────────────────────────────────
USER "${USER}"
# hadolint ignore=SC2154
RUN \
  # Setup TFlint plugins
  TFLINT_PLUGINS_RELEASES_URLS=( \
    "https://api.github.com/repos/terraform-linters/tflint-ruleset-terraform/releases/latest" \
    "https://api.github.com/repos/terraform-linters/tflint-ruleset-opa/releases/latest" \
    "https://api.github.com/repos/terraform-linters/tflint-ruleset-aws/releases/latest" \
    "https://api.github.com/repos/terraform-linters/tflint-ruleset-azurerm/releases/latest" \
    "https://api.github.com/repos/terraform-linters/tflint-ruleset-google/releases/latest" \
    ) ; \
  mkdir -p "${HOME}/.tflint.d/plugins" ; \
  architecture="amd64" ; \
  for url in "${TFLINT_PLUGINS_RELEASES_URLS[@]}";do \
    wget -qO - "$url" \
    | jq -r "\
    .assets[]|select(\
    .browser_download_url \
    | (\
    contains(\"${architecture}\") \
    and contains(\"linux\") \
    and (contains(\"sha256\") | not) \
    )).browser_download_url" \
    | xargs -r -I {} wget -qO - {} 2> /dev/null \
    | bsdtar -xvf- -C "${HOME}/.tflint.d/plugins" ; \
  done ; \
  find "${HOME}/.tflint.d/plugins" -type f -exec chmod +x {} \; ; \
  tfenv --version >/dev/null 2>&1 && ( \
    tfenv tfenv install "latest" \
    && tfenv use "latest" ; \
  ) || exit 0 ;
# ────────────────────────────────────────────────────────────────────────────────
SHELL ["/usr/bin/pwsh", "-NoLogo", "-Command"]
# hadolint ignore=DL4006
RUN 'driftctl completion powershell | Out-String | Invoke-Expression' | Out-File -Append -Encoding ascii "$PROFILE"
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
#  ╭──────────────────────────────────────────────────────────╮
#  │                   user profile config                    │
#  ╰──────────────────────────────────────────────────────────╯
USER "${USER}"
ARG WORKDIR="/workspace"
ENV WORKDIR "${WORKDIR}"
WORKDIR "${WORKDIR}"
RUN \
  ( \
  echo "[ -r '/entrypoint' ] && /entrypoint bash --login" ; \
  ) | tee "${HOME}/.bashrc" > /dev/null ; \
  # ─── SSH SETUP ──────────────────────────────────────────────────────────────────
  mkdir -p "${HOME}/.ssh" \
  && chmod 700 "${HOME}/.ssh" \
  && ( \
  echo "Host git.sr.ht" ; \
  echo "  User git" ; \
  echo "  StrictHostKeyChecking no" ; \
  echo "  MACs hmac-sha2-512" ; \
  echo "  UserKnownHostsFile=/dev/null" ; \
  echo "  IdentityFile=~/.ssh/id_rsa_sourcehut" ; \
  ) | tee "${HOME}/.ssh/config" > /dev/null \
  && chmod 644 "${HOME}/.ssh/config" ;
#  ╭──────────────────────────────────────────────────────────╮
#  │                         finalize                         │
#  ╰──────────────────────────────────────────────────────────╯
USER "root"
# hadolint ignore=SC2016
RUN \
( \
  echo 'set -euo pipefail ;' ; \
  echo 'chmod 700 "${HOME}/.ssh" ;' ; \
  echo '[ -r "${HOME}/.ssh/authorized_keys" ] && chmod 644 "${HOME}/.ssh/authorized_keys" ;' ; \
  echo '[ -r "${HOME}/.ssh/known_hosts" ] && chmod 644 "${HOME}/.ssh/known_hosts" ;' ; \
  echo '[ -r "${HOME}/.ssh/config" ] && chmod 644 "${HOME}/.ssh/config" ;' ; \
  echo 'find "${HOME}/.ssh" -type f -name "id*" -exec chmod 600 {} \;' ; \
  echo 'find "${HOME}/.ssh" -type f -name "id*.pub" -exec chmod 644 {} \;' ; \
  echo 'exit 0 ;' ; \
) | tee /usr/local/share/fix-ssh-permissions.sh > /dev/null \
&& chmod +x /usr/local/share/fix-ssh-permissions.sh  ;
RUN \
  ln -sf "/usr/share/zoneinfo/America/New_York" "/etc/localtime" \
  && chown "$(id -u "${USER}"):$(id -g "${USER}")" -R  \
  "${WORKDIR}" "${HOME}" \
  # ─── CLEAN UP PACMAN BUILD DEPS ─────────────────────────────────────────────────
  && pacman -Qdtq | pacman -Rs --noconfirm - || true \
  # ─── REMOVE TEMPORARY FILES ─────────────────────────────────────────────────────
  && rm -rf \
  /tmp/*
#  ╭──────────────────────────────────────────────────────────╮
#  │                    Entrypoint script                     │
#  ╰──────────────────────────────────────────────────────────╯
# hadolint ignore=SC2016
RUN \
  ( \
  echo '#!/bin/sh' ; \
  # ─── FIX KARY-COMMENTS VSCODE EXTENSION ─────────────────────────────────────────
  echo 'path_pattern="*/karyfoundation.comment*/dictionary.js"; ' ; \
  echo 'while read path; do' ; \
  echo '  if test -n "${path}"; then' ; \
  echo '    sed "/shellscript/r"<( \ ' ; \
  echo "    leading_whitespaces=\"\$(grep -Po \"[[:space:]]+(?=case 'shellscript':)\" \"\${path}\")\"; " ; \
  echo "      language='terraform'; ! grep -q \"case '\${language}':\" \"\${path}\" && (echo -n \"\${leading_whitespaces}\";echo \"case '\${language}':\" );" ; \
  echo "      language='dockerfile'; ! grep -q \"case '\${language}':\" \"\${path}\" && (echo -n \"\${leading_whitespaces}\";echo \"case '\${language}':\" );" ; \
  echo "      language='just'; ! grep -q \"case '\${language}':\" \"\${path}\" && (echo -n \"\${leading_whitespaces}\";echo \"case '\${language}':\" );" ; \
  echo "      language='hcl'; ! grep -q \"case '\${language}':\" \"\${path}\" && (echo -n \"\${leading_whitespaces}\";echo \"case '\${language}':\" );" ; \
  echo "      language='packer'; ! grep -q \"case '\${language}':\" \"\${path}\" && (echo -n \"\${leading_whitespaces}\";echo \"case '\${language}':\" );" ; \
  echo '    ) -i -- "${path}" ;' ; \
  echo '  fi ;' ; \
  echo 'done <<< "$(find "${HOME}" -type f -path "${path_pattern}" 2>/dev/null || true )" ;' ; \
  ) | tee '/usr/local/share/kary-comments.sh' > /dev/null \
  && chmod +x '/usr/local/share/kary-comments.sh' ; \
  ( \
  echo '#!/bin/sh' ; \
  echo '[ -r "/usr/local/share/docker-from-docker.sh" ] && bash "/usr/local/share/docker-from-docker.sh"' ; \
  echo '[ -r "/usr/local/share/kary-comments.sh" ] && bash "/usr/local/share/kary-comments.sh"' ; \
  echo '[ -r "/usr/local/share/fix-ssh-permissions.sh" ] && bash "/usr/local/share/fix-ssh-permissions.sh"' ; \
  echo 'exec "$@"' ; \
  ) | tee '/entrypoint' > /dev/null \
  && chmod +x '/entrypoint' ;
# ────────────────────────────────────────────────────────────────────────────────
USER "${USER}"
VOLUME ["${HOME}","${WORKDIR}}"]
ENV TERM "xterm"
ENV DOCKER_BUILDKIT "1"
ENTRYPOINT [ "/entrypoint" ]
CMD [ "sleep", "infinity" ]
