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
ARG WORKDIR="/workspace"
ENV WORKDIR "${WORKDIR}"

#  ╭──────────────────────────────────────────────────────────╮
#  │                      initial setup                       │
#  ╰──────────────────────────────────────────────────────────╯
# hadolint ignore=SC2016
RUN \
sed \
  -e '/XDG_/d' \
  -e '$aXDG_CACHE_HOME  DEFAULT=@{WORKDIR}/.cache' \
  -e '$aXDG_CONFIG_HOME DEFAULT=@{WORKDIR}/.config' \
  -e '$aXDG_DATA_HOME   DEFAULT=@{WORKDIR}/.local/share' \
  -e '$aXDG_STATE_HOME  DEFAULT=@{WORKDIR}/.local/state' \
  "/etc/security/pam_env.conf" ;
# hadolint ignore=DL3059
RUN \
  pacman-key --init \
  && pacman-key --populate "archlinux" ;
# Polar Repo
# RUN \
#   pacman-key --keyserver "hkps://keys.openpgp.org" --recv-key "D7E35661EB1A280A" \
#   && pacman-key --lsign-key "D7E35661EB1A280A" \
#   && ( \
#     echo '[polarrepo]' ; \
#     echo 'Server = https://polarrepo.polarian.dev' ; \
#   ) | tee -a "/etc/pacman.conf" > /dev/null ;
# Chaotic-AUR
RUN \
  pacman-key --recv-key "FBA220DFC880C036" --keyserver "keyserver.ubuntu.com" \
  && pacman-key --lsign-key "FBA220DFC880C036" \
  && pacman -U --noconfirm \
    'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' \
    'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' \
  && ( \
    echo '[chaotic-aur]' ; \
    echo 'Include = /etc/pacman.d/chaotic-mirrorlist' ; \
  ) | tee -a "/etc/pacman.conf" > /dev/null ;
RUN \
  # ─── DOWNLOAD SIXTEEN PACKAGES CONCURRENTLY ─────────────────────────────────────
  sed -i \
  -e "/ParallelDownloads/d" \
  -e  '/\[options\]/a ParallelDownloads = 16' \
  "/etc/pacman.conf" ; \
  # ─── USE PACMAN AVATAR FOR SHOWING PROGRESS ─────────────────────────────────────
  sed -i \
  -e "/Color/d" \
  -e "/ILoveCandy/d" \
  -e '/\[options\]/a Color' \
  -e '/\[options\]/a ILoveCandy' \
  "/etc/pacman.conf" ; \
  # https://www.reddit.com/r/archlinux/comments/3ctiou/lpt_speed_up_makepkg_by_skippingparallelizing/
  sed -i \
    # skip running tests
    -e 's/ check / !check /g' \
    # use multiple cores
    -e 's/COMPRESSXZ.*/COMPRESSXZ=(xz -T 0 -c -z -)/g' \
    # skip compression
    -e "s/PKGEXT.*/PKGEXT='.pkg.tar'/g" \
    "/etc/makepkg.conf" ; \
  ( \
    # we use this to update installed packages one time after container starts. this
    # gets executed whe the first shell is opened. This approach is to make the
    # docker images as small as possible since upgrading all packages creates large
    # diffs and large image sizes
    echo '[ ! -r "/.pacman-update" ] && ( sudo pacman --quiet -Syyu --noconfirm && sudo touch "/.pacman-update" )' ; \
    echo 'alias pacman="sudo pacman"' ; \
  ) | tee "/etc/profile.d/pacman.sh" > /dev/null ;
#  ╭──────────────────────────────────────────────────────────╮
#  │                 finding fastest sources                  │
#  ╰──────────────────────────────────────────────────────────╯
RUN \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
  pacman --quiet -Syy --noconfirm --needed "reflector" \
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
  pacman --quiet -Syy --noconfirm --needed "sudo" "openssl" \
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
#  │              install makepkg dependencies                │
#  ╰──────────────────────────────────────────────────────────╯
RUN \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
  pacman --quiet -Syy --noconfirm --needed \
  "base-devel" \
  "upx" \
  "git" \
  # ─── BASE GIT CONFIGS ───────────────────────────────────────────────────────────
  && git --version > /dev/null 2>&1 && ( \
  git config --system push.recurseSubmodules "on-demand" \
  && git config --system diff.submodule "log" \
  && git config --system status.submoduleSummary "true" \
  ) || exit 1 ;
#  ╭──────────────────────────────────────────────────────────╮
#  │                    install core tools                    │
#  ╰──────────────────────────────────────────────────────────╯
RUN \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
  pacman --quiet -Syy --noconfirm --needed \
  "openssh" \
  "rsync" \
  "man-db" \
  "wget" \
  "curl" \
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
#  │              install core pakages from aur               │
#  ╰──────────────────────────────────────────────────────────╯
USER "${USER}"
# hadolint ignore=SC2034
RUN \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  export PIP_NO_CACHE_DIR="off" ; \
  export MAKEFLAGS="-j$(nproc)" ; \
  AUR_CLONE_URLS=( \
  "https://aur.archlinux.org/aura-bin.git" \
  "https://aur.archlinux.org/paru-bin.git" \
  "https://aur.archlinux.org/su-exec.git" \
  ) ; \
  for url in "${AUR_CLONE_URLS[@]}";do \
    git clone "${url}" "/tmp/"$(basename "${url%.git}")"" \
    && pushd "/tmp/"$(basename "${url%.git}")"" > /dev/null 2>&1 ; \
    for i in {1..5}; do makepkg -sicr --noconfirm && break || sleep 15; done \
    && popd > /dev/null 2>&1 || exit 1 ; \
  done ;
#  ╭──────────────────────────────────────────────────────────╮
#  │                       shells                             │
#  ╰──────────────────────────────────────────────────────────╯
USER "root"
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# hadolint ignore=SC2016
RUN \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  export PIP_NO_CACHE_DIR="off" ; \
  export MAKEFLAGS="-j$(nproc)" ; \
  AUR_CLONE_URLS=( \
    "https://aur.archlinux.org/shellcheck-bin.git" \
    "https://aur.archlinux.org/powershell-bin.git" \
  ) ; \
  pacman --quiet -Syy --noconfirm --needed \
    "shfmt" \
    "nushell" \
    "starship" ; \
  for url in "${AUR_CLONE_URLS[@]}";do \
    git clone "${url}" "/tmp/"$(basename "${url%.git}")"" \
    && chown -R "$(id -u "${USER}"):$(id -g "${USER}")" "/tmp/"$(basename "${url%.git}")"" \
    && pushd "/tmp/"$(basename "${url%.git}")"" > /dev/null 2>&1 ; \
    for i in {1..5}; do su-exec "${USER}" makepkg -sicr --noconfirm && break || sleep 15; done \
    && popd > /dev/null 2>&1 || exit 1 ; \
    rm -r "/tmp/"$(basename "${url%.git}")"" ; \
  done ; \
  pwsh --version > /dev/null 2>&1 ; \
  starship --version > /dev/null 2>&1 \
  && echo 'eval "$(starship init bash)" ;' > "/etc/profile.d/starship.sh" || exit 1 ;
USER "${USER}"
SHELL ["/usr/bin/pwsh", "-NoLogo", "-Command"]
RUN $parent=Split-Path -parent $PROFILE ; if (-not(Test-Path -Path $parent -PathType Container)) {$null = New-Item -ItemType Directory -Path $parent -Force -ErrorAction Stop}
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
#  ╭──────────────────────────────────────────────────────────╮
#  │                    virtualization                        │
#  ╰──────────────────────────────────────────────────────────╯
USER "root"
# hadolint ignore=SC2016
RUN \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
  pacman --quiet -Syy --noconfirm --needed \
  "podman" \
  "docker" \
  "docker-buildx" \
  "docker-machine" \
  "docker-scan" \
  "docker-compose" ; \
  ( \
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
  && chmod +x '/usr/local/share/docker-from-docker.sh' ; \
  ( \
    echo "alias docker-run='docker run --rm -it -v \"\${PWD}:/workspace\"' ;" ; \
    echo "alias docker-run-u='docker-run --user \"\$(id -u):\$(id -g)\"' ;" ; \
    echo "alias ubuntu-c='docker-run -w \"/workspace\" ubuntu:hirsute' ;" ; \
    echo "alias debian-c='docker-run -w \"/workspace\" debian:bullseye' ;" ; \
    echo "alias alpine-c='docker-run -w \"/workspace\" alpine:edge' ;" ; \
    echo "alias pureos-c='docker-run -w \"/workspace\" pureos/pureos:byzantium-slim' ;" ; \
    echo "alias arch-c='docker-run -w \"/workspace\" archlinux bash -c \"pacman-key --init && pacman-key --populate \"archlinux\" && exec bash --login\"' ;" ; \
    echo "alias gitlint='docker run -u \"\$(id -u):\$(id -g)\" -w \"/repo\" --rm -it --ulimit nofile=1024 -v \"\$(pwd):/repo\" \"jorisroovers/gitlint\"' ;" ; \
    echo "alias gitleaks='docker run -u \"\$(id -u):\$(id -g)\" -v \"\$(pwd):/path\" -w \"/path\" --rm -it \"zricethezav/gitleaks:latest\"' ;" ; \
    echo "alias code-server='docker-run --network host -d -u \"\$(id -u):\$(id -g)\" \"codercom/code-server:latest\" --auth none' ;" ; \
    echo "alias rmcontainers='docker ps -aq | xargs -r docker rm -f' ;" ; \
    echo "alias gitlint='docker run -u \"\$(id -u):\$(id -g)\" -w \"/repo\" --rm -it --ulimit nofile=1024 -v \"\$(pwd):/repo\" \"jorisroovers/gitlint\"' ;" ; \
    echo "alias reveal-md='docker run --rm  -u \"\$(id -u):\$(id -g)\" -p \"1948:1948\" -p \"35729:35729\" -v \"\$(pwd):/slides\" \"webpronl/reveal-md:latest\" /slides --watch' ;" ; \
  ) | tee "/etc/profile.d/docker.sh" > /dev/null || exit 1 ;

#  ╭──────────────────────────────────────────────────────────╮
#  │                          fonts                           │
#  ╰──────────────────────────────────────────────────────────╯
USER "root"
RUN \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
  pacman --quiet -Syy --noconfirm --needed \
  "noto-fonts" \
  "ttf-ubuntu-font-family" \
  "ttf-font-awesome" ;

#  ╭──────────────────────────────────────────────────────────╮
#  │                          gitpod                          │
#  ╰──────────────────────────────────────────────────────────╯
# hadolint ignore=SC2016
RUN \
  ( \
  # ensures shell always has the latest gipod variables
  echo 'if gp version > /dev/null 2>&1 ; then' ;\
  echo '  eval "$(gp env --export)" ;' ;\
  echo 'fi' ;\
  ) | tee "/etc/profile.d/gitpod.sh" > /dev/null || exit 1
#  ╭──────────────────────────────────────────────────────────╮
#  │                     fuzzy finders                        │
#  ╰──────────────────────────────────────────────────────────╯
USER "root"
# hadolint ignore=SC2016
RUN \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
  export PIP_NO_CACHE_DIR="off" ; \
  export MAKEFLAGS="-j$(nproc)" ; \
  AUR_CLONE_URLS=( \
  "https://aur.archlinux.org/fzfx-git.git" \
  "https://aur.archlinux.org/fzf-extras.git" \
  ) ; \
  pacman --quiet -Syy --noconfirm --needed \
    "fzf" ; \
  for url in "${AUR_CLONE_URLS[@]}";do \
    git clone "${url}" "/tmp/"$(basename "${url%.git}")"" \
    && chown -R "$(id -u "${USER}"):$(id -g "${USER}")" "/tmp/"$(basename "${url%.git}")"" \
    && pushd "/tmp/"$(basename "${url%.git}")"" > /dev/null 2>&1 ; \
    for i in {1..5}; do su-exec "${USER}" makepkg -sicr --noconfirm && break || sleep 15; done \
    && popd > /dev/null 2>&1 || exit 1 ; \
    rm -r "/tmp/"$(basename "${url%.git}")"" ; \
  done ; \
  # FIXME : Syntax highlighting is messed up
  fzf --version > /dev/null 2>&1 && ( \
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
#  │               build tools and task runners               │
#  ╰──────────────────────────────────────────────────────────╯
USER "root"
# hadolint ignore=SC2016
RUN \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
  AUR_CLONE_URLS=( \
  "https://aur.archlinux.org/go-task.git" \
  "https://aur.archlinux.org/earthly-bin.git" \
  ) ; \
  pacman --quiet -Syy --noconfirm --needed \
    "just" \
    "make" ; \
  for url in "${AUR_CLONE_URLS[@]}";do \
    git clone "${url}" "/tmp/"$(basename "${url%.git}")"" \
    && chown -R "$(id -u "${USER}"):$(id -g "${USER}")" "/tmp/"$(basename "${url%.git}")"" \
    && pushd "/tmp/"$(basename "${url%.git}")"" > /dev/null 2>&1 ; \
    for i in {1..5}; do su-exec "${USER}" makepkg -sicr --noconfirm && break || sleep 15; done \
    && popd > /dev/null 2>&1 || exit 1 ; \
    rm -r "/tmp/"$(basename "${url%.git}")"" ; \
  done ; \
  go-task --version > /dev/null 2>&1 && ( \
    ln -sf "$(which "go-task" 2>/dev/null)" "/usr/local/bin/task" ; \
  ) || exit 1 ; \
  just --version > /dev/null 2>&1 && ( \
    echo 'eval "$(just --completions bash)" ;' > "/etc/profile.d/just.sh" ; \
  ) || exit 1 ;
#  ╭──────────────────────────────────────────────────────────╮
#  │                          git                             │
#  ╰──────────────────────────────────────────────────────────╯
USER "root"
# hadolint ignore=SC2016
RUN \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
  export PIP_NO_CACHE_DIR="off" ; \
  export MAKEFLAGS="-j$(nproc)" ; \
  AUR_CLONE_URLS=( \
  "https://aur.archlinux.org/forgit.git" \
  "https://aur.archlinux.org/git-fuzzy-git.git" \
  "https://aur.archlinux.org/git-completion.git" \
  "https://aur.archlinux.org/git-shelf.git" \
  ) ; \
  pacman --quiet -Syy --noconfirm --needed \
    "github-cli" \
    "git-delta" ; \
  for url in "${AUR_CLONE_URLS[@]}";do \
    git clone "${url}" "/tmp/"$(basename "${url%.git}")"" \
    && chown -R "$(id -u "${USER}"):$(id -g "${USER}")" "/tmp/"$(basename "${url%.git}")"" \
    && pushd "/tmp/"$(basename "${url%.git}")"" > /dev/null 2>&1 ; \
    for i in {1..5}; do su-exec "${USER}" makepkg -sicr --noconfirm && break || sleep 15; done \
    && popd > /dev/null 2>&1 || exit 1 ; \
    rm -r "/tmp/"$(basename "${url%.git}")"" ; \
  done ; \
  gh --version > /dev/null 2>&1 && ( \
    echo 'eval "$(gh completion -s bash)" ;' > "/etc/profile.d/gh.sh" ; \
    pwsh --version && ( \
      pwsh -c ' \
      "Invoke-Expression -Command $(gh completion -s powershell | Out-String)" \
      | Out-File -Append -Encoding ascii "$PROFILE" \
      ' ; \
    ) || exit 0 ; \
  ) || exit 1 ; \
  # ─── USE DELTA FOR GIT DIFFS ────────────────────────────────────────────────────
  delta --version > /dev/null 2>&1 && ( \
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
#  ╭──────────────────────────────────────────────────────────╮
#  │                  modern cli applications                 │
#  ╰──────────────────────────────────────────────────────────╯
USER "root"
ENV COLORTERM="truecolor"
ENV EDITOR="hx"
ENV VISUAL="hx"
ENV _ZO_DATA_DIR="/workspace/zoxide/"
# hadolint ignore=SC2016
RUN \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
  pacman --quiet -Syy --noconfirm --needed \
    "bottom" \
    "cocogitto" \
    "eva" \
    "hck" \
    "inlyne" \
    "jql" \
    "mdcat" \
    "navi" \
    "nu" \
    "pipr" \
    "qsv" \
    "rnr" \
    "topgrade" \
    "xh" \
    "zellij" \
    "zoxide" \
    "xplr" \
    "xcp" \
    "ripsecrets" \
    "neovim" \
    "sd" \
    "duf" \
    "ncdu" \
    "ripgrep" \
    "ripgrep-all" \
    "fd" \
    "tokei" \
    "hyperfine" \
    "exa" \
    "atuin" \
    "bat" \
    "bat-extras" ; \
  zoxide --version && ( \
  ( \
    echo 'export _ZO_DATA_DIR="/workspace/zoxide" ; ' ; \
    echo '[ ! -d "${_ZO_DATA_DIR}" ] && mkdir "${_ZO_DATA_DIR} ;" ;' \
    echo 'eval "$(zoxide init bash)" ;' ; \
    echo 'alias cd="z"' ; \
  ) | tee "/etc/profile.d/zoxide.sh" \
  ) ; \
  bat --version > /dev/null 2>&1 && ( \
  echo 'alias cat="bat -pp" ;' ; \
  echo "export MANPAGER='sh -c \"col -bx | bat --language man --style plain\"' ;" ; \
  ) | tee "/etc/profile.d/bat.sh" > /dev/null || exit 1  ; \
  exa --version > /dev/null 2>&1 && ( \
  echo 'alias la="exa -alhF" ;' ; \
  echo 'alias ll="exa -lhF" ;' ; \
  echo 'alias llfu="exa -bghHliS --git" ;' ; \
  echo 'alias llt="exa -T" ;' ; \
  echo 'alias ls="exa" ;' ; \
  ) | tee "/etc/profile.d/exa.sh" > /dev/null || exit 1 ; \
  ( \
  # ensures shell always has the latest gipod variables
  echo 'if hx --version > /dev/null 2>&1 ; then' ;\
  echo '  export EDITOR="hx" ;' ;\
  echo '  export VISUAL="hx" ;' ;\
  echo 'fi' ;\
  ) | tee "/etc/profile.d/edito.sh" > /dev/null || exit 1 ; \
  atuin --version > /dev/null 2>&1 && ( \
      echo 'mkdir -p "${HOME}/.config/atuin" && wget -qO "${HOME}/.config/atuin/config.toml" "https://raw.githubusercontent.com/da-moon/.dotfiles/master/config/atuin/config.toml" ;' \
      echo 'echo "db_path = \"${WORKDIR}/.history.db\" >> \"${HOME}/.config/atuin/config.toml\"' ; \
      echo 'eval "$(atuin init bash)" ;' ; \
  ) | tee "/etc/profile.d/atuin.sh" > /dev/null ; \
  xplr --version > /dev/null 2>&1 \
  && echo 'mkdir -p "${HOME}/.config/xplr" && wget -qO "${HOME}/.config/xplr/init.lua" "https://raw.githubusercontent.com/da-moon/.dotfiles/master/config/xplr/init.lua" ;' \
  
#  ────────────────────────────────────────────────────────────

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
  pacman --quiet -Syy --noconfirm --needed \
    "rustup" ; \
  # https://stackoverflow.com/questions/28227739/lock-a-file-in-bash-using-flock-and-lockfile
  rustup --version > /dev/null 2>&1 && ( \
    echo '(' ; \
    echo '  flock -x -n 3 || exit 55 ;' ; \
    echo '  ! ( rustup toolchain list | grep -q "nightly" ) && rustup toolchain install nightly ;' ; \
    echo ') 3> "/tmp/rust-nightly.lock"' ; \
    echo '(' ; \
    echo '  flock -x -n 4 || exit 55 ;' ; \
    echo '  ! ( rustup toolchain list | grep -q "stable" ) && (rustup toolchain install stable && rustup default stable );' ; \
    echo ') 4> "/tmp/rust-stable.lock"' ; \
    echo '{' ; \
    echo '  flock -s 3 ;' ; \
    echo '  flock -u 3 ;' ; \
    echo '} 3<"/tmp/rust-nightly.lock" ;' ; \
    echo '{' ; \
    echo '  flock -s 4 ;' ; \
    echo '  flock -u 4 ;' ; \
    echo '} 4<"/tmp/rust-stable.lock"' ; \
    echo '[ -r "/tmp/rust-nightly.lock" ] && rm "/tmp/rust-nightly.lock" ;' ; \
    echo '[ -r "/tmp/rust-stable.lock" ] && rm "/tmp/rust-stable.lock" ;' ; \
    echo 'export RUSTUP_HOME="${HOME}/.rustup";' ; \
    echo 'export CARGO_HOME="${HOME}/.cargo";' ; \
    echo 'export PATH="${PATH}:${CARGO_HOME}/bin";' ; \
  ) | tee -a "/etc/profile.d/00-rust.sh" > /dev/null ; \
  rustup toolchain install stable \
  && cargo install --locked \
    "cargo-binstall" \
    "huber" \
  && cargo binstall -y \
    "cargo-cache" \
    "cargo-update" \
    "pipr" \
  && cargo install --locked --git "https://hg.sr.ht/~cyplo/legdur" \
  && cargo install --locked --git "https://github.com/flatt-security/shisho.git" \
  && cargo-cache --remove-dir all \
  && rustup toolchain list | cut -d' ' -f1 | xargs -r -I {} rustup toolchain uninstall {} ; \
  # For fixing the following error:
  #
  # ❯ sudo su -
  # -bash: /etc/bash_completion.d/cargo: No such file or directory
  [ -d "/usr/share/bash-completion/completions" ] && ( \
    [ ! -r "/usr/share/bash-completion/completions/cargo" ]  \
      && rustup completions bash cargo > "/usr/share/bash-completion/completions/cargo" || exit 0 ; \
    [ ! -r "/usr/share/bash-completion/completions/rustup" ]  \
      && rustup completions bash rustup > "/usr/share/bash-completion/completions/rustup" || exit 0 ; \
  ) || exit 0
#  ╭──────────────────────────────────────────────────────────╮
#  │                 install go packages                      │
#  ╰──────────────────────────────────────────────────────────╯
USER "root"
ENV GO111MODULE="on"
ENV CGO_ENABLED="0"
ENV CGO_LDFLAGS="-s -w -extldflags '-static'"
# hadolint ignore=SC2016,SC2076
RUN \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
  pacman --quiet -Syy --noconfirm --needed \
  "go" "goreleaser" "mage" \
  && go version > /dev/null 2>&1 \
  &&  ( \
  echo 'export PATH="${PATH}:$(go env GOPATH)/bin";' ; \
  ) | tee "/etc/profile.d/go.sh" > /dev/null || exit 1 ; \
    SKIP_PKGS=(); \
  if [ -r "/tmp/.processed-pkgs" ]; then \
    readarray -t SKIP_PKGS < "/tmp/.processed-pkgs" ; \
  fi ; \
  SKIP_PKGS+=("upx"); \
  PKGS=($(comm -2 -3 <(pacman -Qe | awk '{print $1}'| sort)  <(printf "%s\n" "${SKIP_PKGS[@]}" | sort) )) ; \
  BIN_LIST=() ; \
  for pkg in "${PKGS[@]}";do \
    if [[ ! " ${SKIP_PKGS[*]} " =~ " ${pkg} " ]]; then \
      SKIP_PKGS+=("${pkg}"); \
    fi ; \
    for f in $(pacman -Qql "${pkg}"); do \
      [ ! -d "${f}" ] && [ -x "${f}" ] \
      && file -i "${f}" | grep -q -E 'application/x-(pie-)?executable; charset=binary' \
      && BIN_LIST+=("${f}"); \
    done ; \
  done ; \
  printf "%s\n" "${BIN_LIST[@]}" | xargs -r -I {} -P "$(($(nproc)/4))" upx -q "{}" ; \
  printf "%s\n" "${SKIP_PKGS[@]}" | tee "/tmp/.processed-pkgs" > /dev/null ;
#  ╭──────────────────────────────────────────────────────────╮
#  │                 install lua packages                     │
#  ╰──────────────────────────────────────────────────────────╯
USER "root"
ENV PATH="${PATH}:${HOME}/.luarocks/bin"
# hadolint ignore=SC2016
RUN \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
  pacman --quiet -Syy --noconfirm --needed \
  "lua" \
  "luajit" \
  "luarocks" ;
#  ╭──────────────────────────────────────────────────────────╮
#  │                 install ruby packages                    │
#  ╰──────────────────────────────────────────────────────────╯
USER "root"
ENV GEM_PATH="${HOME}/.gem"
# hadolint ignore=SC2016,DL3028
RUN \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
  pacman --quiet -Syy --noconfirm --needed \
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
  pacman --quiet -Syy --noconfirm --needed \
  "python" \
  "python-pip" \
  "python-setuptools" \
  "python-pre-commit" \
  && sudo -i -u "${USER}" \
    bash -c 'curl -sSL https://install.python-poetry.org | python3 -' > /dev/null 2>&1 \
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
  pacman --quiet -Syy --noconfirm --needed \
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
  "@devcontainers/cli" \
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
  && npm cache clean --quite --force ;
#  ╭──────────────────────────────────────────────────────────╮
#  │                      text editors                        │
#  ╰──────────────────────────────────────────────────────────╯
USER "root"
# Install language servers
# hadolint ignore=DL3016,DL3013
RUN \
  export PIP_NO_CACHE_DIR="off" ; \
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
  && marksman --version \
  && npm cache clean --quite --force \
  && go clean -modcache \
  && chown "$(id -u "${USER}"):$(id -g "${USER}")" -R "$(go env GOPATH)" "${HOME}" ;
#
# The following logins and runs the command. The login cause rust toolchain to get
# Installed which makes the image larger
# && sudo -i -u "${USER}" bash -c '/usr/local/share/install-helix.sh' \
#
# pacman -Si helix | awk -F':' '/^ .*: / {print $1}' | sed 's/\s//g'
#
# hadolint ignore=DL3004,SC2016,DL3047
RUN \
! wget --version > /dev/null 2>&1 && { echo "*** "wget" not found"; exit 1; } ; \
! jq --version > /dev/null 2>&1 && { echo "*** "jq" not found"; exit 1; } ; \
! sudo --version > /dev/null 2>&1 && { echo "*** "sudo" not found"; exit 1; } ; \
! xz --version > /dev/null 2>&1 && { echo "*** "xz" not found"; exit 1; } ; \
! tar --version > /dev/null 2>&1 && { echo "*** "tar" not found"; exit 1; } ; \
! xargs --version > /dev/null 2>&1 && { echo "*** "xargs" not found"; exit 1; } ; \
dir="$(mktemp -d)" ; \
architecture="x86_64" ; \
wget -qO - "https://api.github.com/repos/helix-editor/helix/releases/latest" \
| jq -r "\
.assets[]|select(\
.browser_download_url \
| (\
contains(\"${architecture}\") \
and contains(\"linux\") \
and contains(\"tar\") \
and (contains(\"sha256\") | not) \
)).browser_download_url" \
  | xargs -r -I {} wget -O - {} 2> /dev/null \
  | xz -d -c  \
  | tar -xv -C "${dir}" --strip-components=1 > /dev/null 2>&1 ; \
chmod +x "${dir}/hx" ; \
[ ! -d "${HOME}/.local/bin" ] && mkdir -p "${HOME}/.local/bin" ; \
mv -f "${dir}/hx" "${HOME}/.local/bin/hx" ; \
[ -d "${HOME}/.config/helix/runtime" ] && rm -r "${HOME}/.config/helix/runtime" ; \
mkdir -p "${HOME}/.config/helix" \
&& mv "${dir}/runtime" "${HOME}/.config/helix/runtime" \
&& ln -sf "${HOME}/.local/bin/hx" "/usr/local/bin/hx" \
&& rm -r "${dir}" \
&& chown -R "$(id -u "${USER}"):$(id -g "${USER}")" \
  "${HOME}/.local/bin" \
  "${HOME}/.config/helix" \
&& hx --version > /dev/null 2>&1 && ( \
  [ ! -d "${HOME}/.init.d/" ] && ( mkdir "${HOME}/.init.d" && chown "$(id -u "${USER}"):$(id -g "${USER}")" "${HOME}/.init.d") ; \
  ( \
    echo '#!/usr/bin/env bash' ; \
    echo 'if [ ! -d "${HOME}/.config/helix/runtime/grammars/sources" ]; then' ; \
    echo '  self="$(realpath -s "${BASH_SOURCE[0]}")";' ; \
    echo '  lockfile="/tmp/$(basename -s.sh "${self}").lock" ;' ; \
    echo '  (' ; \
    echo '    flock -x -n 20 || exit 55 ;' ; \
    echo '    wget -qO "${HOME}/.config/helix/config.toml" "https://raw.githubusercontent.com/da-moon/.dotfiles/master/config/helix/config.toml"' ; \
    echo '    # hx --grammar fetch' ; \
    echo '    # hx --grammar build' ; \
    echo '  ) 20> "${lockfile}"' ; \
    echo '  {' ; \
    echo '    flock -s 20 ;' ; \
    echo '    echo "[ $(basename -s.sh "${self}") ] : cleaning up self..." ;' ; \
    echo '    flock -u 20 ;' ; \
    echo '    rm "${self}" ;' ; \
    echo '  } 20<"${lockfile}"' ; \
    echo '  [ -r "${lockfile}" ] && rm "${lockfile}" ;' ; \
    echo 'fi' ; \
  ) | tee "${HOME}/.init.d/helix.sh" > /dev/null \
  && chmod +x "${HOME}/.init.d/helix.sh" \
  && chown "$(id -u "${USER}"):$(id -g "${USER}")" "${HOME}/.init.d/helix-grammar.sh" \
) || exit 1
#  ╭──────────────────────────────────────────────────────────╮
#  │                  infrustructure as code                  │
#  ╰──────────────────────────────────────────────────────────╯
USER "root"
# Kubernetes
ADD --chmod=0755 "https://raw.githubusercontent.com/ahmetb/kubectl-aliases/master/.kubectl_aliases" "/etc/profile.d/01-kubectl-aliases.sh"
# hadolint ignore=SC2016,SC2034,DL3013,DL4006
RUN \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  pacman --quiet -Syy --noconfirm --needed \
  "helm" \
  "kustomize" \
  "kube-linter" \
  "kubectl" ; \
  kubectl version --client=true > /dev/null 2>&1 && ( \
    echo 'eval "$(kubectl completion bash)" ;' ; \
  ) | tee -a "/etc/profile.d/kubernetes.sh" > /dev/null || exit 1 ; \
  helm version > /dev/null 2>&1 && ( \
    echo 'eval "$(helm completion bash)" ;' ; \
  ) | tee -a "/etc/profile.d/kubernetes.sh" > /dev/null || exit 1 ; \
  kustomize version > /dev/null 2>&1 && ( \
    echo 'eval "$(kustomize completion bash)" ;' ; \
  ) | tee -a "/etc/profile.d/kubernetes.sh" > /dev/null || exit 1 ; \
  kube-linter version > /dev/null 2>&1 && ( \
    echo 'eval "$(kube-linter completion bash)" ;' ; \
  ) | tee -a "/etc/profile.d/kubernetes.sh" > /dev/null || exit 1 ;
# hashicorp
# hadolint ignore=SC2016,SC2034,DL3013,DL4006
RUN \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  export PIP_NO_CACHE_DIR="off" ; \
  export MAKEFLAGS="-j$(nproc)" ; \
  AUR_CLONE_URLS=( \
  "https://aur.archlinux.org/tfenv.git" \
  "https://aur.archlinux.org/terraform-docs-bin.git" \
  "https://aur.archlinux.org/tfsec-bin.git" \
  "https://aur.archlinux.org/tflint-bin.git" \
  "https://aur.archlinux.org/terrascan.git" \
  ) ; \
  GROUPS_ARR=( \
    "tfenv" \
    "consul" \
    "vault" \
  ) ; \
  pacman --quiet -Syy --noconfirm --needed \
  "packer" \
  "consul" \
  "consul-template" \
  "vault" ; \
  for url in "${AUR_CLONE_URLS[@]}";do \
    git clone "${url}" "/tmp/"$(basename "${url%.git}")"" \
    && chown -R "$(id -u "${USER}"):$(id -g "${USER}")" "/tmp/"$(basename "${url%.git}")"" \
    && pushd "/tmp/"$(basename "${url%.git}")"" > /dev/null 2>&1 ; \
    for i in {1..5}; do su-exec "${USER}" makepkg -sicr --nocheck --skipinteg --noconfirm && break || sleep 15; done \
    && popd > /dev/null 2>&1 || exit 1 ; \
    rm -r "/tmp/"$(basename "${url%.git}")"" ; \
    go clean -modcache ; \
    su-exec "${USER}" go clean -modcache ; \
    go clean -cache ; \
    su-exec "${USER}" go clean -cache ; \
  done ; \
  for group in "${GROUPS_ARR[@]}";do \
    getent group "${group}" > /dev/null 2>&1 && usermod -aG "${group}" "${USER}" || continue ; \
  done ; \
  SKIP_PKGS=(); \
  if [ -r "/tmp/.processed-pkgs" ]; then \
    readarray -t SKIP_PKGS < "/tmp/.processed-pkgs" ; \
  fi ; \
  SKIP_PKGS+=("upx"); \
  PKGS=($(comm -2 -3 <(pacman -Qe | awk '{print $1}'| sort)  <(printf "%s\n" "${SKIP_PKGS[@]}" | sort) )) ; \
  BIN_LIST=() ; \
  for pkg in "${PKGS[@]}";do \
    if [[ ! " ${SKIP_PKGS[*]} " =~ " ${pkg} " ]]; then \
      SKIP_PKGS+=("${pkg}"); \
    fi ; \
    for f in $(pacman -Qql "${pkg}"); do \
      [ ! -d "${f}" ] && [ -x "${f}" ] \
      && file -i "${f}" | grep -q -E 'application/x-(pie-)?executable; charset=binary' \
      && BIN_LIST+=("${f}"); \
    done ; \
  done ; \
  printf "%s\n" "${BIN_LIST[@]}" | xargs -r -I {} -P "$(($(nproc)/4))" upx -q "{}" ; \
  printf "%s\n" "${SKIP_PKGS[@]}" | tee "/tmp/.processed-pkgs" > /dev/null ; \
  # https://jdimpson.livejournal.com/5685.html
  # https://stackoverflow.com/questions/8295908/how-to-use-a-variable-to-indicate-a-file-descriptor-in-bash
  tflint --version > /dev/null 2>&1 && ( \
    [ ! -d "${HOME}/.init.d/" ] && ( mkdir "${HOME}/.init.d" && chown "$(id -u "${USER}"):$(id -g "${USER}")" "${HOME}/.init.d") ; \
    ( \
      echo '#!/usr/bin/env bash' ; \
      echo 'self="$(realpath -s "${BASH_SOURCE[0]}")";' ; \
      echo '  TFLINT_PLUGINS=(' ; \
      echo '  "tflint-ruleset-opa"' ; \
      echo '  "tflint-ruleset-aws"' ; \
      echo '  "tflint-ruleset-azurerm"' ; \
      echo '  "tflint-ruleset-google"' ; \
      echo ') ;' ; \
      echo 'architecture="amd64" ;' ; \
      echo '[ ! -d "${HOME}/.tflint.d/plugins" ] && mkdir -p "${HOME}/.tflint.d/plugins" ;' ; \
      echo 'for index in "${!TFLINT_PLUGINS[@]}"; do' ; \
      echo '  plugin="${TFLINT_PLUGINS[$index]}" ;' ; \
      echo '  if [ ! -r "${HOME}/.tflint.d/plugins/${plugin}" ];then' ; \
      echo '    lockfile="/tmp/${plugin}.lock" ;' ; \
      echo '    fd="$((0x$(echo "${plugin}" | md5sum | cut -f 1 -d " " | cut -c 1-2)))" ;' ; \
      echo '    exec {fd}<>"${lockfile}"' ; \
      echo '    echo "*** Installing ${plugin} ..."' ; \
      echo '    (' ; \
      echo '      flock -x -n "${fd}" || exit 55 ;' ; \
      echo '      url="https://api.github.com/repos/terraform-linters/${plugin}/releases/latest" ;' ; \
      echo '      wget -qO - "${url}" \' ; \
      echo '      | jq -r "\' ; \
      echo '      .assets[]|select(\' ; \
      echo '      .browser_download_url \' ; \
      echo '      | (\' ; \
      echo '      contains(\"${architecture}\") \' ; \
      echo '      and contains(\"linux\") \' ; \
      echo '      and (contains(\"sha256\") | not) \' ; \
      echo '      )).browser_download_url" \' ; \
      echo '      | xargs -r -I {} wget -qO - {} 2> /dev/null \' ; \
      echo '      | bsdtar -xvf- -C "${HOME}/.tflint.d/plugins" > /dev/null 2>&1 ;' ; \
      echo '    ) >&${fd}' ; \
      echo '    {' ; \
      echo '      flock -s "${fd}" ;' ; \
      echo '      echo "*** ${plugin} installed "' ; \
      echo '      chmod +x "${HOME}/.tflint.d/plugins/${plugin}" ;' ; \
      echo '      flock -u "${fd}" ;' ; \
      echo '    } <&${fd}' ; \
      echo '    [ -r "${lockfile}" ] && rm "${lockfile}" ;' ; \
      echo '  fi' ; \
      echo 'done ;' ; \
      echo 'rm "${self}" ;' ; \
    ) | tee "${HOME}/.init.d/tflint.sh" > /dev/null \
    && chmod +x "${HOME}/.init.d/tflint.sh" \
    && chown "$(id -u "${USER}"):$(id -g "${USER}")" "${HOME}/.init.d/tflint.sh"  ; \
  ) || exit 1 ; \
  tfenv --version >/dev/null 2>&1 && ( \
    tfenv install "latest" \
    && tfenv use "latest" ; \
  ) ; \
  terraform-docs version > /dev/null 2>&1 && ( \
    echo 'eval "$(terraform-docs completion bash)" ;' ; \
  ) | tee "/etc/profile.d/terraform.sh" > /dev/null || exit 1 ;
# Generic
# hadolint ignore=SC2034,DL3013,DL4006,SC2016
RUN \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  export PIP_NO_CACHE_DIR="off" ; \
  export MAKEFLAGS="-j$(nproc)" ; \
  AUR_CLONE_URLS=( \
  # generic tools
  "https://aur.archlinux.org/opa.git" \
  "https://aur.archlinux.org/pulumictl.git" \
  "https://aur.archlinux.org/infracost.git" \
  "https://aur.archlinux.org/driftctl-bin.git" \
  "https://aur.archlinux.org/k6.git" \
  "https://aur.archlinux.org/rancher-k3d-bin.git" \
  "https://aur.archlinux.org/envoyproxy-bin.git" \
  "https://aur.archlinux.org/gojira.git" \
  "https://aur.archlinux.org/litmusctl.git" \
  ) ; \
  GROUPS_ARR=( \
    "caddy" \
    "traefik" \
  ) ; \
  pacman --quiet -Syy --noconfirm --needed \
    "polarrepo/google-cloud-cli" \
    "chaotic-aur/azure-cli" ; \
  pacman --quiet -Syy --noconfirm --needed \
  "aws-cli-v2" \
  "vector" \
  "pulumi" \
  "istio" \
  "caddy" \
  "traefik" \
  "cfssl" ; \
  for url in "${AUR_CLONE_URLS[@]}";do \
    git clone "${url}" "/tmp/"$(basename "${url%.git}")"" \
    && chown -R "$(id -u "${USER}"):$(id -g "${USER}")" "/tmp/"$(basename "${url%.git}")"" \
    && pushd "/tmp/"$(basename "${url%.git}")"" > /dev/null 2>&1 ; \
    for i in {1..5}; do su-exec "${USER}" makepkg -sicr --nocheck --skipinteg --noconfirm && break || sleep 15; done \
    && popd > /dev/null 2>&1 || exit 1 ; \
    rm -r "/tmp/"$(basename "${url%.git}")"" ; \
    go clean -modcache ; \
    su-exec "${USER}" go clean -modcache ; \
    go clean -cache ; \
    su-exec "${USER}" go clean -cache ; \
  done ; \
  SKIP_PKGS=(); \
  if [ -r "/tmp/.processed-pkgs" ]; then \
    readarray -t SKIP_PKGS < "/tmp/.processed-pkgs" ; \
  fi ; \
  SKIP_PKGS+=("upx"); \
  PKGS=($(comm -2 -3 <(pacman -Qe | awk '{print $1}'| sort)  <(printf "%s\n" "${SKIP_PKGS[@]}" | sort) )) ; \
  BIN_LIST=() ; \
  for pkg in "${PKGS[@]}";do \
    if [[ ! " ${SKIP_PKGS[*]} " =~ " ${pkg} " ]]; then \
      SKIP_PKGS+=("${pkg}"); \
    fi ; \
    for f in $(pacman -Qql "${pkg}"); do \
      [ ! -d "${f}" ] && [ -x "${f}" ] \
      && file -i "${f}" | grep -q -E 'application/x-(pie-)?executable; charset=binary' \
      && BIN_LIST+=("${f}"); \
    done ; \
  done ; \
  printf "%s\n" "${BIN_LIST[@]}" | xargs -r -I {} -P "$(($(nproc)/4))" upx -q "{}" ; \
  printf "%s\n" "${SKIP_PKGS[@]}" | tee "/tmp/.processed-pkgs" > /dev/null ; \
  for group in "${GROUPS_ARR[@]}";do \
    getent group "${group}" > /dev/null 2>&1 && usermod -aG "${group}" "${USER}" || continue ; \
  done ; \
  python3 -m pip install -q --no-cache-dir \
    "checkov" \
    "semgrep"; \
  driftctl version >/dev/null 2>&1 && ( \
  echo 'eval "$(driftctl completion bash)" ;' ; \
  ) | tee -a "/etc/profile.d/generic-iac.sh" > /dev/null ;
# ────────────────────────────────────────────────────────────────────────────────
# SHELL ["/usr/bin/pwsh", "-NoLogo", "-Command"]
# # hadolint ignore=DL4006
# RUN 'driftctl completion powershell | Out-String | Invoke-Expression' | Out-File -Append -Encoding ascii "$PROFILE"
# SHELL ["/bin/bash", "-o", "pipefail", "-c"]
#  ╭──────────────────────────────────────────────────────────╮
#  │                   user profile config                    │
#  ╰──────────────────────────────────────────────────────────╯
USER "${USER}"
WORKDIR "${WORKDIR}"
RUN \
  ( \
    echo '[ -r "/entrypoint" ] && exec /entrypoint bash --login' ; \
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
  echo "Host mpr" ; \
  echo "  HostName mpr.hunterwittenborn.com" ; \
  echo "  IdentityFile ~/.ssh/id_rsa_makedeb" ; \
  echo "  User mpr" ; \
  echo "  IdentitiesOnly yes" ; \
  echo "  StrictHostKeyChecking no" ; \
  echo "  MACs hmac-sha2-512" ; \
  echo "  UserKnownHostsFile=/dev/null" ; \
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
# hadolint ignore=SC2016,SC2046
RUN \
  ln -sf "/usr/share/zoneinfo/America/New_York" "/etc/localtime" ; \
  chown "$(id -u "${USER}"):$(id -g "${USER}")" -R  "${WORKDIR}" "${HOME}" ; \
  [ "$(pacman -Qdtq)" != "" ] && pacman -Rs $(pacman -Qdtq) ; \
  npm cache clean --quite --force ; \
  go clean -modcache ; \
  su-exec "${USER}" go clean -modcache ; \
  go clean -cache ; \
  su-exec "${USER}" go clean -cache ; \
  rm -rf /tmp/* ;
#  ╭──────────────────────────────────────────────────────────╮
#  │              vscode-server 'offline' setup               │
#  ╰──────────────────────────────────────────────────────────╯
# https://gist.github.com/b01/0a16b6645ab7921b0910603dfb85e4fb
USER "root"
# hadolint ignore=DL4001
RUN \
    ARCH="x64" ; \
    tag="$(curl --silent "https://api.github.com/repos/microsoft/vscode/releases/latest" \
    | grep '"tag_name":' \
    | sed -E 's/.*"([^"]+)".*/\1/')"; \
    tag_data="$(curl --silent "https://api.github.com/repos/microsoft/vscode/git/ref/tags/${tag}")" ; \
    sha="$(echo "${tag_data}" \
    | grep '"sha":' \
    | sed -E 's/.*"([^"]+)".*/\1/' )"; \
    sha_type="$(echo "${tag_data}" \
    | grep '"type":' \
    | sed -E 's/.*"([^"]+)".*/\1/')" ; \
    if [ "${sha_type}" != "commit" ]; then \
      combo_sha="$(curl -s "https://api.github.com/repos/microsoft/vscode/git/tags/${sha}" \
      | grep '"sha":' \
      | sed -E 's/.*"([^"]+)".*/\1/')"; \
      sha=$(echo "${combo_sha}" | sed -E "s/${sha}//" | xargs) ; \
    fi ; \
    [ -z "${sha}" ] && exit 1 ; \
    mkdir -vp "${HOME}/.vscode-server/bin/${sha}" \
    && chown "$(id -u "${USER}"):$(id -g "${USER}")" "${HOME}/.vscode-server/bin/${sha}" \
    && wget -qO - \
      "https://update.code.visualstudio.com/commit:${sha}/server-linux-${ARCH}/stable" \
    | su-exec "${USER}" tar \
      --no-same-owner \
      -xzv \
      --strip-components=1 \
      -C "${HOME}/.vscode-server/bin/${sha}" \
    && [ -r "${HOME}/.vscode-server/bin/${sha}/bin/remote-cli/code" ] \
    && chown -R "$(id -u "${USER}"):$(id -g "${USER}")" "${HOME}/.vscode-server" \
    && ln -sf "${HOME}/.vscode-server/bin/${sha}/bin/remote-cli/code" "/usr/local/bin/code" ;
# ────────────────────────────────────────────────────────────────────────────────
USER "root"
# https://stackoverflow.com/a/37541105
ADD --chown="${USER}" \
  "https://github.com/pouyakary/comment/releases/download/v11.2.0/comment-v-11.0.2.vsix" \
  "${HOME}/comment-v-11.0.2.vsix"
# hadolint ignore=SC2016
RUN \
  ( \
  echo '#!/bin/sh' ; \
  # ─── FIX KARY-COMMENTS VSCODE EXTENSION ─────────────────────────────────────────
  echo 'path_pattern="*/karyfoundation.comment*/dictionary.js"; ' ; \
  echo 'while read path; do' ; \
  echo '  if test -n "${path}"; then' ; \
  echo '    if ! awk -v patt="terraform,dockerfile,just,hcl,packer" "BEGIN {n = split(patt, words, /,/)}n {for (i in words) if (\$0 ~ \"\\\\<\" words[i] \"\\\\>\") {--n;delete words[i];}} END { exit n ;}" "${path}";then' ; \
  echo '      sed "/shellscript/r"<( \ ' ; \
  echo "      leading_whitespaces=\"\$(grep -Po \"[[:space:]]+(?=case 'shellscript':)\" \"\${path}\")\"; " ; \
  echo "        language='terraform'; ! grep -q \"case '\${language}':\" \"\${path}\" && (echo -n \"\${leading_whitespaces}\";echo \"case '\${language}':\" );" ; \
  echo "        language='dockerfile'; ! grep -q \"case '\${language}':\" \"\${path}\" && (echo -n \"\${leading_whitespaces}\";echo \"case '\${language}':\" );" ; \
  echo "        language='just'; ! grep -q \"case '\${language}':\" \"\${path}\" && (echo -n \"\${leading_whitespaces}\";echo \"case '\${language}':\" );" ; \
  echo "        language='hcl'; ! grep -q \"case '\${language}':\" \"\${path}\" && (echo -n \"\${leading_whitespaces}\";echo \"case '\${language}':\" );" ; \
  echo "        language='packer'; ! grep -q \"case '\${language}':\" \"\${path}\" && (echo -n \"\${leading_whitespaces}\";echo \"case '\${language}':\" );" ; \
  echo '      ) -i -- "${path}" ;' ; \
  echo '    fi ;' ; \
  echo '  fi ;' ; \
  echo 'done <<< "$(find "${HOME}" -type f -path "${path_pattern}" 2>/dev/null || true )" ;' ; \
  ) | tee '/usr/local/share/kary-comments.sh' > /dev/null \
  && chmod +x '/usr/local/share/kary-comments.sh' \
  && chown "$(id -u "${USER}"):$(id -g "${USER}")" '/usr/local/share/kary-comments.sh';
#  ╭──────────────────────────────────────────────────────────╮
#  │                    Entrypoint script                     │
#  ╰──────────────────────────────────────────────────────────╯
# hadolint ignore=SC2016
RUN \
  ( \
    echo '#!/bin/sh' ; \
    echo '[ -r "/usr/local/share/docker-from-docker.sh" ] && bash "/usr/local/share/docker-from-docker.sh" ;' ; \
    echo '[ -r "/usr/local/share/kary-comments.sh" ] && bash "/usr/local/share/kary-comments.sh" ;' ; \
    echo '[ -r "/usr/local/share/fix-ssh-permissions.sh" ] && bash "/usr/local/share/fix-ssh-permissions.sh" ;' ; \
    echo '[ -d "${HOME}/.init.d" ] && (' ; \
    echo '  find "${HOME}/.init.d" -type f -name "*.sh" | xargs -r -I {} -P "$(nproc)" bash "{}" ;' ; \
    # TODO: add a lock and delete only after init is complete
    # echo '  find "${HOME}/.init.d" -maxdepth 0 -empty -exec rm -r {} \; ;' ; \
    echo ');' ; \
    echo 'exec "$@"' ; \
  ) | tee '/entrypoint' > /dev/null \
  && chmod +x '/entrypoint' \
  && chown "$(id -u "${USER}"):$(id -g "${USER}")" '/entrypoint';
RUN du --human-readable --max-depth 1 "${HOME}" > /.size
USER "${USER}"
VOLUME ["${HOME}","${WORKDIR}"]
ENV TERM="xterm"
ENV DOCKER_BUILDKIT="1"
ENV BUILDKIT_PROGRESS="plain"
# ENV TERM_PROGRAM="vscode"
ENTRYPOINT [ "/entrypoint" ]
CMD [ "sleep", "infinity" ]
