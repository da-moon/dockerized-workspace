# syntax = docker/dockerfile:labs
# vim: filetype=dockerfile softtabstop=2 tabstop=2 shiftwidth=2 fileencoding=utf-8 expandtab
# code: language=dockerfile insertSpaces=true tabSize=2
# ────────────────────────────────────────────────────────────────────────────────
# NOTE: some interesting references
# https://bbs.archlinux.org/viewtopic.php?id=229027
# ────────────────────────────────────────────────────────────────────────────────
# hadolint ignore=DL3007
FROM archlinux:latest
SHELL ["/bin/bash", "-euo", "pipefail", "-c"]
# USER "root"
USER root
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
  "/etc/security/pam_env.conf" \
  # ─── DOWNLOAD SIXTEEN PACKAGES CONCURRENTLY ─────────────────────────────────────
  && sed -i \
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
  # https://www.reddit.com/r/archlinux/comments/3ctiou/lpt_speed_up_makepkg_by_skippingparallelizing/
  && sed -i \
  # skip running tests
  -e 's/ check / !check /g' \
  # use multiple cores
  -e 's/COMPRESSXZ.*/COMPRESSXZ=(xz -T 0 -c -z -)/g' \
  # skip compression
  -e "s/PKGEXT.*/PKGEXT='.pkg.tar'/g" \
  "/etc/makepkg.conf" \
  && pacman-key --init > /dev/null 2>&1 \
  && pacman-key --populate "archlinux" > /dev/null 2>&1 \
  && ( \
  echo 'alias pacman="sudo pacman"' ; \
  ) | tee "/etc/profile.d/pacman.sh" > /dev/null ;
# ────────────────────────────────────────────────────────────
ARG CHAOTIC_AUR_KEY="3056513887B78AEB"
# Chaotic-AUR
RUN \
  pacman-key --recv-key "${CHAOTIC_AUR_KEY}" --keyserver "keyserver.ubuntu.com" > /dev/null 2>&1 \
  && pacman-key --lsign-key "${CHAOTIC_AUR_KEY}" > /dev/null 2>&1 \
  && pacman -U --noprogressbar --noconfirm \
  'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' \
  'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' \
  && ( \
  echo '[chaotic-aur]' ; \
  echo 'Include = /etc/pacman.d/chaotic-mirrorlist' ; \
  ) | tee -a "/etc/pacman.conf" > /dev/null ;
#  ╭──────────────────────────────────────────────────────────╮
#  │                 finding fastest sources                  │
#  ╰──────────────────────────────────────────────────────────╯
RUN \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
  pacman --quiet --noprogressbar -Syy --noconfirm --needed "reflector" \
  && reflector \
  --verbose \
  -p https \
  --latest 5 \
  --sort rate \
  --save "/etc/pacman.d/mirrorlist" > /dev/null 2>&1 \
  && pacman --quiet --noprogressbar -Syyu --noconfirm  ;
#  ╭──────────────────────────────────────────────────────────╮
#  │                   user and group setup                   │
#  ╰──────────────────────────────────────────────────────────╯
# hadolint ignore=SC2016
RUN \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
  pacman --quiet --noprogressbar -S --noconfirm --needed "sudo" "openssl" \
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
  (\
  echo 'SKIP_PKGS=(); \' ; \
  echo 'if [ -r "/tmp/.processed-pkgs" ]; then \' ; \
  echo '  readarray -t SKIP_PKGS < "/tmp/.processed-pkgs" ; \' ; \
  echo 'fi ; \' ; \
  echo 'SKIP_PKGS+=("upx" "sudo"); \' ; \
  echo 'PKGS=($(comm -2 -3 <(pacman -Qe | awk "{print \$1}"| sort)  <(printf "%s\n" "${SKIP_PKGS[@]}" | sort) )) ; \' ; \
  echo 'BIN_LIST=() ; \' ; \
  echo 'for pkg in "${PKGS[@]}";do \' ; \
  echo '  if [[ ! " ${SKIP_PKGS[*]} " =~ " ${pkg} " ]]; then \' ; \
  echo '    SKIP_PKGS+=("${pkg}"); \' ; \
  echo '  fi ; \' ; \
  echo '  for f in $(pacman -Qql "${pkg}"); do \' ; \
  echo '    [ ! -d "${f}" ] && [ -x "${f}" ] \' ; \
  echo '    && file -i "${f}" | grep -q -E "application/x-(pie-)?executable; charset=binary" \' ; \
  echo '    && BIN_LIST+=("${f}"); \' ; \
  echo '  done ; \' ; \
  echo 'done ; \' ; \
  echo 'printf "%s\n" "${BIN_LIST[@]}" | xargs -r -I {} -P "$(($(nproc)/4))" bash -c "upx -q \"{}\" || echo \"{}\" > /tmp/.failed-compress" ; \' ; \
  echo 'printf "%s\n" "${SKIP_PKGS[@]}" | tee "/tmp/.processed-pkgs" > /dev/null ;' ; \
  ) | tee "/usr/local/bin/compress-packages" > /dev/null \
  && chmod +x "/usr/local/bin/compress-packages" ;
RUN \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
  pacman --quiet --noprogressbar -S --noconfirm --needed \
  "base-devel" \
  "upx" \
  "git" \
  "openssh" \
  "man-db" \
  "wget" \
  "curl" \
  "jq" \
  "unzip" \
  "unrar" \
  "expac" \
  "bash-completion" \
  # ─── GIT CONFIG ───────────────────────────────────────────────────────────
  && git --version > /dev/null 2>&1 && ( \
  git config --system 'format.signoff'                                  'true' ; \
  git config --system 'init.defaultBranch'                              'master' ; \
  git config --system 'core.attributesfile'                             '.gitattributes' ; \
  git config --system 'core.autocrlf'                                   'false' ; \
  git config --system 'tag.forceSignAnnotated'                          'true' ; \
  git config --system 'push.recursesubmodules'                          'on-demand' ; \
  git config --system 'pull.rebase'                                     'true' ; \
  git config --system 'rebase.autostash'                                'true' ; \
  git config --system 'status.submodulesummary'                         'true' ; \
  git config --system 'pager.diff'                                      '[ -x "$(command -v delta)" ] && delta || less --tab=2 -RFX' ; \
  git config --system 'pager.grep'                                      '[ -x "$(command -v delta)" ] && delta || less -RFX' ; \
  git config --system 'pager.blame'                                     '[ -x "$(command -v delta)" ] && delta || less -RFX' ; \
  git config --system 'pager.log'                                       '[ -x "$(command -v delta)" ] && delta || less -RFX' ; \
  git config --system 'pager.reflog'                                    '[ -x "$(command -v delta)" ] && delta || less -RFX' ; \
  git config --system 'pager.show'                                      '[ -x "$(command -v delta)" ] && delta || less -RFX' ; \
  git config --system 'diff.submodule'                                  'log' ; \
  git config --system 'diff.tool'                                       'difftastic' ; \
  git config --system 'diff.image.command'                              'compare $2 $1 png:- | montage -geometry +4+4 $2 - $1 png:- | display -title "$1"' ; \
  git config --system 'diff.difftastic.command'                         'difft' ; \
  git config --system 'diff.difftastic.binary'                          'true' ; \
  git config --system 'difftool.prompt'                                 'false' ; \
  git config --system 'difftool.difftastic.cmd'                         'difft --color always $LOCAL $REMOTE' ; \
  git config --system 'difftool.delta.cmd'                              'diff -u --unified=3 --ignore-case -w $LOCAL $REMOTE | delta' ; \
  git config --system 'gui.editor'                                      'code -w' ; \
  git config --system 'fetch.prune'                                     'true' ; \
  git config --system 'merge.log'                                       'true' ; \
  git config --system 'merge.tool'                                      'code' ; \
  git config --system 'mergetool.code.cmd'                              'code --wait --merge $REMOTE $LOCAL $BASE $MERGED' ; \
  git config --system 'alias.view-contributors'                         'shortlog -e -s -n' ; \
  git config --system 'alias.upstream'                                  'remote get-url origin' ; \
  git config --system 'alias.root'                                      'rev-parse --show-toplevel' ; \
  git config --system 'alias.scope'                                     'rev-parse --show-prefix' ; \
  git config --system 'alias.url'                                       'ls-remote --get-url' ; \
  git config --system 'alias.aliases'                                   'config --get-regexp alias' ; \
  git config --system 'alias.spush'                                     'push --recurse-submodules=on-demand' ; \
  git config --system 'alias.sfetch'                                    'submodule foreach --recursive git fetch' ; \
  git config --system 'alias.supdate'                                   'submodule update --remote --merge' ; \
  git config --system 'alias.default-branch'                            'rev-parse --abbrev-ref HEAD' ; \
  git config --system 'alias.current-branch'                            '!git for-each-ref --format="%(upstream:short)" $(git symbolic-ref -q HEAD)' ; \
  git config --system 'alias.branch-prune'                              '!git fetch -p && for b in $(git for-each-ref --format="%(if:equals=[gone])%(upstream:track)%(then)%(refname:short)%(end)" refs/heads); do git branch -d $b; done' ; \
  git config --system 'alias.ca'                                        'commit --signoff --gpg-sign --amend --reuse-message=HEAD' ; \
  git config --system 'alias.c'                                         'commit --signoff --gpg-sign' ; \
  git config --system 'alias.cF'                                        '!git commit --signoff --gpg-sign --file=$(git rev-parse --show-toplevel)/.git/COMMIT_EDITMSG' ; \
  git config --system 'alias.codegpt'                                   '! codegpt commit --preview' ; \
  git config --system 'alias.commit-edit-message'                       '! $EDITOR $(git rev-parse --show-toplevel)/.git/COMMIT_EDITMSG' ; \
  git config --system 'alias.commit-summary'                            'log --color --graph --pretty=format:"%C(red)%h%C(reset) %s %C(bold blue)[%an](mailto:%ae)%C(reset) %C(green)%C(bold)%cr" --abbrev-commit' ; \
  git config --system 'alias.head-hash'                                 'rev-parse HEAD' ; \
  git config --system 'alias.latest-commit'                             'log -1 HEAD --stat' ; \
  git config --system 'alias.untracked'                                 'ls-files --others --exclude-standard' ; \
  git config --system 'alias.tracked'                                   '!git ls-tree -r $(git symbolic-ref --quiet --short HEAD || git rev-parse HEAD) --name-only' ; \
  git config --system 'alias.tags'                                      'for-each-ref --format="%(refname:short) (%(committerdate:relative))" --sort=committerdate refs/tags' ; \
  git config --system 'alias.latest-tag'                                '!git describe --tags $(git rev-list --tags --max-count=1 2>/dev/null) 2>/dev/null' ; \
  git config --system 'alias.release-notes'                             'log --color --pretty=format:"* %C(red)%h%C(reset) %s %C(bold blue)[%an](mailto:%ae)%C(reset)" --abbrev-commit --dense --no-merges' ; \
  git config --system 'alias.staged'                                    'diff --name-only --staged' ; \
  git config --system 'alias.re-stage'                                  'git add $(git diff --name-only --staged)' ; \
  git config --system 'alias.difft'                                     'difftool --tool difftastic' ; \
  git config --system 'alias.diffd'                                     'difftool --tool delta' ; \
  git config --system 'alias.not-staged'                                'diff-files --name-only -B -R -M' ; \
  git config --system 'alias.all-changes'                               'diff --name-only HEAD' ; \
  git config --system 'alias.ui'                                        '!f() { cd "$(git rev-parse --show-toplevel)" && gitui; }; f' ; \
  git config --system 'alias.zipball'                                   '!git archive --format=zip --output=$(basename -s.git $(git remote get-url origin))-$(git describe --abbrev=0).zip $(git describe --abbrev=0)' ; \
  git config --system 'alias.tarball'                                   '!git archive --format=tar.gz --output=$(basename -s.git $(git remote get-url origin))-$(git describe --abbrev=0).tar.gz $(git describe --abbrev=0)' ; \
  git config --system 'alias.conflicts'                                 '! $EDITOR $(git diff --name-only --diff-filter=U)' ; \
  git config --system 'alias.issues'                                    '! gh issue list --assignee "@me"' ; \
  git config --system 'alias.changes'                                   'diff-index --name-only -B -R -M -C HEAD' ; \
  git config --system 'alias.rel-changes'                               'ls-files -m -o --exclude-standard' ; \
  git config --system 'alias.ignored'                                   'ls-files --others --ignored --exclude-standard' ; \
  git config --system 'alias.modified-files'                            'diff --name-only' ; \
  git config --system 'alias.restage'                                   '!git add $(git diff --name-only)' ; \
  git config --system 'alias.stage-all'                                 '!git add $(git diff --name-only HEAD)' ; \
  git config --system "alias.next-patch-release"                        '!git describe --tags $(git rev-list --tags --max-count=1 2>/dev/null) 2>/dev/null'"| awk -F. '{gsub(\"v\",\"\",\$1);printf \"%s.%s.%s\", \$1,\$2,\$3+1}END {if (NR==0){print \"0.0.1\"}}'" ; \
  git config --system "alias.next-minor-release"                        '!git describe --tags $(git rev-list --tags --max-count=1 2>/dev/null) 2>/dev/null'"| awk -F. '{gsub(\"v\",\"\",\$1);printf \"%s.%s.0\", \$1,\$2+1}END {if (NR==0){print \"0.0.1\"}}'" ; \
  git config --system "alias.next-major-release"                        '!git describe --tags $(git rev-list --tags --max-count=1 2>/dev/null) 2>/dev/null'"| awk -F. '{gsub(\"v\",\"\",\$1);printf \"%s.0.0\", \$1+1}END {if (NR==0){print \"0.0.1\"}}'" ; \
  git config --system 'alias.fa'                                        '!f() { cd "$(git rev-parse --show-toplevel)" && git ls-files -m -o --exclude-standard | fzf -0 --print0 --multi --reverse --height=40% --tabstop=2 --prompt=" │ " --color="prompt:0,hl:178,hl+:178" --preview-window="right:60%" --height="80%" --bind="tab:ignore" --bind="shift-tab:ignore" --bind="ctrl-t:ignore" --bind="ctrl-g:ignore" --bind="right:toggle+down" --bind="left:toggle+up" --bind="ctrl-space:select-all" --bind="alt-space:deselect-all" --preview="git difftool --tool=delta  {}" | xargs -0 -t -o -I {} git add "{}";  }; f' ; \
  git config --system "alias.spark"                                     '!git log --date=short --pretty=format:%ad | sort | uniq -c | awk "{print $1}" | spark' ; \
  git config --system "alias.commit-count"                              '!git log --date=short --pretty=format:%ad | sort | uniq -c' ; \
  git config --system "alias.commit-count-ordered"                      '!git log --date=short --pretty=format:%ad | sort | uniq -c | sort -r | head' ; \
  ) || exit 1 ; \
  compress-packages ;
#  ╭──────────────────────────────────────────────────────────╮
#  │              install core pakages from aur               │
#  ╰──────────────────────────────────────────────────────────╯
USER "${USER}"
# hadolint ignore=SC2034,SC2046
RUN \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  export PIP_NO_CACHE_DIR="off" ; \
  export MAKEFLAGS="-j$(nproc)" ; \
  AUR_CLONE_URLS=( \
  "https://aur.archlinux.org/su-exec.git" \
  "https://aur.archlinux.org/paru-bin.git" \
  ) ; \
  for url in "${AUR_CLONE_URLS[@]}";do \
  git clone --quiet "${url}" "/tmp/"$(basename "${url%.git}")"" \
  && pushd "/tmp/"$(basename "${url%.git}")"" > /dev/null 2>&1 ; \
  for i in {1..5}; do makepkg -sicr --noconfirm && break || sleep 15; done ; \
  rm -rf "/tmp/"$(basename "${url%.git}")"" \
  && popd > /dev/null 2>&1 || exit 1 ; \
  done ;
#  ╭──────────────────────────────────────────────────────────╮
#  │                         docker                           │
#  ╰──────────────────────────────────────────────────────────╯
USER "root"
# hadolint ignore=SC2016
RUN \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
  pacman --quiet -S --noconfirm --needed "docker" "docker-compose" "docker-buildx" > /dev/null 2>&1 ; \

  # ─── DOCKER FROM DOCKER ─────────────────────────────────────────────────────────
  ( \
  echo '#!/bin/sh' ; \
  echo 'sudoIf() { if [ "$(id -u)" -ne 0 ]; then sudo "$@"; else "$@"; fi }' ; \
  echo 'if [ -r "/var/run/docker.sock" ];then' ; \
  echo 'SOCKET_GID="$(stat -c "%g" "/var/run/docker.sock")" ; ' ; \
  echo '  if [ "${SOCKET_GID}" != 0 ]; then' ; \
  echo '      if [ "$(cat "/etc/group" | grep :${SOCKET_GID}:)" = "" ]; then sudoIf groupadd --gid "${SOCKET_GID}" "docker-host"; fi' ; \
  echo '      if [ "$(id "$(whoami)" | grep -E "groups=.*(=|,)${SOCKET_GID}\(")" = "" ]; then sudoIf usermod -aG "${SOCKET_GID}" "$(whoami)"; fi' ; \
  echo '  fi' ; \
  echo 'fi' ; \
  ) | tee '/usr/local/share/docker-from-docker.sh' > /dev/null \
  && chmod +x '/usr/local/share/docker-from-docker.sh' ; \
  # ─── DOCKER ALIASES ───────────────────────────────────────────────────────
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
  ) | tee "/etc/profile.d/docker.sh" > /dev/null || exit 1 ; \
  compress-packages ;
#  ╭──────────────────────────────────────────────────────────╮
#  │                      useful dev cli tools                │
#  ╰──────────────────────────────────────────────────────────╯
USER "root"
ENV COLORTERM="truecolor"
ENV EDITOR="hx"
ENV VISUAL="hx"
ENV _ZO_DATA_DIR="${WORKDIR}/.zoxide/"
ENV GEM_PATH="${WORKDIR}/.gem"
ENV npm_config_prefix="${WORKDIR}/.npm"
ENV PATH="${PATH}:${npm_config_prefix}/bin"
ENV GO_PATH="${WORKDIR}/.go"
ENV GO111MODULE="on"
ENV CGO_ENABLED="0"
ENV CGO_LDFLAGS="-s -w -extldflags '-static'"
ENV PATH="${PATH}:${HOME}/.local/bin"
ENV PATH="${PATH}:${HOME}/.luarocks/bin"
# hadolint ignore=SC2016
RUN \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
  pacman --quiet -S --noconfirm --needed \
  "chaotic-aur/powershell-bin" \
  "go" \
  "lua" \
  "luajit" \
  "luarocks" \
  "python" \
  "python-pip" \
  "python-poetry" \
  "python-setuptools" \
  "ruby" \
  "nodejs" \
  "npm" \
  "yarn" \
  "starship" \
  "fzf" \
  "go-yq" \
  "github-cli" \
  "git-delta" \
  "difftastic" \
  "zellij" \
  "zoxide" \
  "xplr" \
  "ripgrep" \
  "eza" \
  "atuin" \
  "bash-preexec" \
  "bat" \
  "just" \
  "make" \
  "go-task" ; \
  #  ╭──────────────────────────────────────────────────────────╮
  #  │                     go setup                             │
  #  ╰──────────────────────────────────────────────────────────╯
  go version > /dev/null 2>&1 && ( \
  echo 'export PATH="${PATH}:$(go env GOPATH)/bin";' ; \
  ) | tee "/etc/profile.d/go.sh" > /dev/null || exit 1 ; \
  #  ╭──────────────────────────────────────────────────────────╮
  #  │                     ruby setup                           │
  #  ╰──────────────────────────────────────────────────────────╯
  gem --version > /dev/null 2>&1 && ( \
  echo "export GEM_PATH="${GEM_PATH}";" ; \
  echo 'export GEM_HOME="$(ruby -e "puts Gem.user_dir")";' ; \
  echo 'export PATH="${PATH}:${GEM_HOME}/bin";' ; \
  ) | tee "/etc/profile.d/ruby.sh" > /dev/null || exit 1 ; \
  #  ╭──────────────────────────────────────────────────────────╮
  #  │                     python setup                         │
  #  ╰──────────────────────────────────────────────────────────╯
  poetry --version > /dev/null 2>&1 && ( \
  echo 'eval "$(poetry completions bash)" ;' ; \
  ) | tee "/etc/profile.d/poetry.sh" > /dev/null || exit 1 ; \
  #  ╭──────────────────────────────────────────────────────────╮
  #  │                 nodejs setup                             │
  #  ╰──────────────────────────────────────────────────────────╯
  #  ╭──────────────────────────────────────────────────────────╮
  #  │                 powershell init                          │
  #  ╰──────────────────────────────────────────────────────────╯
  pwsh --version > /dev/null 2>&1 && ( \
  pwsh -c '$parent=Split-Path -parent $PROFILE ; if (-not(Test-Path -Path $parent -PathType Container)) {$null = New-Item -ItemType Directory -Path $parent -Force -ErrorAction Stop}' ; \
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
  ) || exit 1 ; \
  go-task --version > /dev/null 2>&1 && ( \
  ln -sf "$(which "go-task" 2>/dev/null)" "/usr/local/bin/task" ; \
  ) || exit 1 ; \
  starship --version > /dev/null 2>&1 && echo 'eval "$(starship init bash)" ;' > "/etc/profile.d/starship.sh" || exit 1 ; \
  yq --version > /dev/null 2>&1 && echo 'eval "$(yq shell-completion bash)" ;' > "/etc/profile.d/yq.sh" || exit 1 ; \
  just --version > /dev/null 2>&1 && ( \
  echo 'eval "$(just --completions bash)" ;' > "/etc/profile.d/just.sh" ; \
  ) || exit 1 ; \
  zoxide --version > /dev/null 2>&1 && ( \
  ( \
  echo "export _ZO_DATA_DIR="${_ZO_DATA_DIR}";" ; \
  echo '[ ! -d "${_ZO_DATA_DIR}" ] && mkdir -p "${_ZO_DATA_DIR}" ;' ; \
  echo 'eval "$(zoxide init bash)" ;' ; \
  echo 'alias cd="z"' ; \
  ) | tee "/etc/profile.d/zoxide.sh" > /dev/null || exit 1 ; \
  ) || exit 1 ; \
  bat --version > /dev/null 2>&1 && ( \
  echo 'alias cat="bat -pp" ;' ; \
  echo "export MANPAGER='sh -c \"col -bx | bat --language man --style plain\"' ;" ; \
  ) | tee "/etc/profile.d/bat.sh" > /dev/null || exit 1  ; \
  eza --version > /dev/null 2>&1 && ( \
  echo 'alias la="eza -alhF" ;' ; \
  echo 'alias ll="eza -lhF" ;' ; \
  echo 'alias llfu="eza -bghHliS --git" ;' ; \
  echo 'alias llt="eza -T" ;' ; \
  echo 'alias ls="eza" ;' ; \
  ) | tee "/etc/profile.d/eza.sh" > /dev/null || exit 1 ; \
  gh --version > /dev/null 2>&1 && ( \
  echo 'eval "$(gh completion -s bash)" ;' > "/etc/profile.d/gh.sh" ; \
  pwsh --version && ( \
  pwsh -c ' \
  Invoke-Expression -Command $(gh completion -s powershell | Out-String) | Out-File -Append -Encoding ascii "$PROFILE" \
  ' ; \
  ) || exit 0 ; \
  ) || exit 1 ; \
  atuin --version > /dev/null 2>&1 && ( \
  echo '[ ! -d "${HOME}/.config/atuin" ] && mkdir -p "${HOME}/.config/atuin" ;' ; \
  echo 'wget -qO "${HOME}/.config/atuin/config.toml" "https://raw.githubusercontent.com/da-moon/.dotfiles/master/config/atuin/config.toml" ;' ; \
  echo 'sed -i -e "/db_path/d" "${HOME}/.config/atuin/config.toml" ;' ; \
  echo "echo 'db_path = \"${WORKDIR}/.history.db\"' >> '${HOME}/.config/atuin/config.toml' ;" ; \
  echo '[[ -r "/usr/share/bash-preexec/bash-preexec.sh" ]] && source "/usr/share/bash-preexec/bash-preexec.sh"' ; \
  echo 'eval "$(atuin init bash)" ;' ; \
  ) | tee "/etc/profile.d/atuin.sh" > /dev/null || exit 1 ; \
  xplr --version > /dev/null 2>&1 && ( \
  echo '[ ! -d "${HOME}/.config/xplr" ] && mkdir -p "${HOME}/.config/xplr" ;' ; \
  echo 'wget -qO "${HOME}/.config/xplr/init.lua" "https://raw.githubusercontent.com/da-moon/.dotfiles/master/config/xplr/init.lua" ;' ; \
  ) | tee "/etc/profile.d/xplr.sh" > /dev/null  || exit 1 ; \
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
  echo '[ -r "/usr/share/fzf/fzf-extras.bash" ] && source "/usr/share/fzf/fzf-extras.bash"' ; \
  ) | tee "/etc/profile.d/fzf.sh" > /dev/null || exit 1 ; \
  ( \
  echo 'if hx --version > /dev/null 2>&1 ; then' ;\
  echo '  export EDITOR="hx" ;' ;\
  echo '  export VISUAL="hx" ;' ;\
  echo '  [ ! -d "${HOME}/.config/helix" ] && mkdir -p "${HOME}/.config/helix" ;' ; \
  echo '  wget -qO "${HOME}/.config/helix/config.toml" "https://raw.githubusercontent.com/da-moon/.dotfiles/master/config/helix/config.toml" ;' ; \
  echo 'fi' ;\
  ) | tee "/etc/profile.d/editor.sh" > /dev/null || exit 1 ; \
  # NOTE: ensures shell always has the latest gipod variables
  ( \
  echo 'if gp version > /dev/null 2>&1 ; then' ;\
  echo '  eval "$(gp env --export)" ;' ;\
  echo 'fi' ;\
  ) | tee "/etc/profile.d/gitpod.sh" > /dev/null || exit 1 ; \
  echo '[ -r "${HOME}/.local/share/bash-completion/completions/git-forgit.bash" ] && source "${HOME}/.local/share/bash-completion/completions/git-forgit.bash"' > "/etc/profile.d/forgit.sh" > /dev/null || exit 1 ; \
  compress-packages ;
#  ────────────────────────────────────────────────────────────
#  ╭──────────────────────────────────────────────────────────╮
#  │                 rust setup                               │
#  ╰──────────────────────────────────────────────────────────╯
USER "root"
ENV RUSTUP_HOME="${WORKDIR}/.rustup"
ENV CARGO_HOME="${WORKDIR}/.cargo"
ENV PATH="${PATH}:${CARGO_HOME}/bin"
# hadolint ignore=SC2016
RUN \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
  pacman --quiet --noprogressbar -S --noconfirm --needed "rustup" "cargo-binstall" ; \
  #  ────────────────────────────────────────────────────────────
  # NOTE: installing rustup toolchains after container starts up. this helps with minimizing docker image size
  # https://stackoverflow.com/questions/28227739/lock-a-file-in-bash-using-flock-and-lockfile
  #  ────────────────────────────────────────────────────────────
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
  echo '[ -r "/tmp/rust-nightly.lock" ] && rm -f "/tmp/rust-nightly.lock" ;' ; \
  echo '[ -r "/tmp/rust-stable.lock" ] && rm -f "/tmp/rust-stable.lock" ;' ; \
  echo 'export RUSTUP_HOME="${HOME}/.rustup";' ; \
  echo 'export CARGO_HOME="${HOME}/.cargo";' ; \
  echo 'export PATH="${PATH}:${CARGO_HOME}/bin";' ; \
  ) | tee -a "/etc/profile.d/00-rust.sh" > /dev/null \
  && rustup default "stable" \
  # NOTE: shisho adds a lot to build time and I don't use it at
  # the moment so it has been commented out
  # && cargo install --locked --git "https://github.com/flatt-security/shisho.git" \
  && cargo binstall --quiet --no-confirm \
  "cargo-cache" \
  "cargo-make" \
  "cargo-edit" \
  "cargo-deny" \
  "cargo-udeps" \
  "cargo-update" \
  "legdur" \
  "smartcat" \
  "aichat" \
  "pipr" \
  "ttdl" \
  "prose" \
  "jaq" \
  && find "${CARGO_HOME}/bin" \
  -type f \
  -executable \
  -exec sh -c "file -i '{}' |  grep -q -E 'application/x-(pie-)?executable; charset=binary'" \; \
  -print \
  | xargs \
  -P `nproc` \
  --no-run-if-empty \
  bash -c ' \
  for pkg do \
  strip "$pkg" || true ; \
  upx "$pkg" || true ; \
  done' bash ; \
  # For fixing the following error:
  #
  # ❯ sudo su -
  # -bash: /etc/bash_completion.d/cargo: No such file or directory
  ( \
  [ -d "/usr/share/bash-completion/completions" ] && ( \
  ( [ ! -r "/usr/share/bash-completion/completions/cargo" ] && rustup completions bash cargo > "/usr/share/bash-completion/completions/cargo" || exit 0 ; ) ; \
  ( [ ! -r "/usr/share/bash-completion/completions/rustup" ] && rustup completions bash rustup > "/usr/share/bash-completion/completions/rustup" || exit 0 ; ) ; \
  ) || exit 0 ; \
  ) ; \
  [ -r "${CARGO_HOME}/.crates.toml" ] && ( \
  while read BIN; do \
  ln -sf "$(which "${BIN}")" "/usr/local/bin/${BIN}" ; \
  done < <(yq eval '.v1.*|sort|.[]' "${CARGO_HOME}/.crates.toml"); \
  ) || exit 0 \
  && cargo-cache --remove-dir "all" > /dev/null 2>&1 \
  && rustup toolchain list | cut -d' ' -f1 | xargs -r -I {} rustup --quiet toolchain uninstall {}  ; \
  compress-packages ;
RUN du --human-readable --max-depth 1 "${HOME}" > /.rustup
#  ╭──────────────────────────────────────────────────────────╮
#  │                 install ruby packages                    │
#  ╰──────────────────────────────────────────────────────────╯
USER "root"
# hadolint ignore=SC2016,DL3028
RUN \
  gem install --quiet --no-user-install "bundler" "serverspec"
#  ╭──────────────────────────────────────────────────────────╮
#  │                 install nodejs packages                  │
#  ╰──────────────────────────────────────────────────────────╯
USER "root"
# hadolint ignore=SC2016
RUN \
  npm install --silent -g \
  "github-label-sync" \
  "remark" \
  "remark-cli" \
  "remark-frontmatter" \
  "remark-stringify" \
  "remark-toc" \
  "remark-preset-lint-recommended" \
  "remark-lint-list-item-indent" \
  "remark-reference-links" \
  && npm cache clean --quiet --force
#  ╭──────────────────────────────────────────────────────────╮
#  │                      dev tools                           │
#  ╰──────────────────────────────────────────────────────────╯
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
  [ -d "${HOME}/.config/helix/runtime" ] && rm -rf "${HOME}/.config/helix/runtime" ; \
  mkdir -p "${HOME}/.config/helix" \
  && mv "${dir}/runtime" "${HOME}/.config/helix/runtime" \
  && ln -sf "${HOME}/.local/bin/hx" "/usr/local/bin/hx" \
  && rm -rf "${dir}" \
  && chown -R "$(id -u "${USER}"):$(id -g "${USER}")" \
  "${HOME}/.local/bin" \
  "${HOME}/.config/helix" \
  && hx --version > /dev/null 2>&1 && ( \
  [ ! -d "${HOME}/.init.d/" ] && ( mkdir -p "${HOME}/.init.d" && chown "$(id -u "${USER}"):$(id -g "${USER}")" "${HOME}/.init.d") ; \
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
  echo '    rm -f "${self}" ;' ; \
  echo '  } 20<"${lockfile}"' ; \
  echo '  [ -r "${lockfile}" ] && rm -f "${lockfile}" ;' ; \
  echo 'fi' ; \
  ) | tee "${HOME}/.init.d/helix.sh" > /dev/null \
  && chmod +x "${HOME}/.init.d/helix.sh" \
  && chown "$(id -u "${USER}"):$(id -g "${USER}")" "${HOME}/.init.d/helix.sh" \
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
  pacman --quiet -S --noconfirm --needed "helm" "kustomize" "kube-linter" "kubectl" ; \
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
  ) | tee -a "/etc/profile.d/kubernetes.sh" > /dev/null || exit 1 ; \
  compress-packages ;
# hashicorp
# hadolint ignore=SC2016,SC2034,DL3013,DL4006
RUN \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  export PIP_NO_CACHE_DIR="off" ; \
  export MAKEFLAGS="-j$(nproc)" ; \
  AUR_CLONE_URLS=( \
  "https://aur.archlinux.org/tfenv.git" \
  "https://aur.archlinux.org/tfsec-bin.git" \
  "https://aur.archlinux.org/tflint-bin.git" \
  "https://aur.archlinux.org/terraform-docs-bin.git" \
  ) ; \
  GROUPS_ARR=( \
  "tfenv" \
  "consul" \
  "vault" \
  ) ; \
  pacman --quiet --noprogressbar -S --noconfirm --needed "consul" "vault" ; \
  for url in "${AUR_CLONE_URLS[@]}";do \
  git clone --quiet "${url}" "/tmp/"$(basename "${url%.git}")"" \
  && chown -R "$(id -u "${USER}"):$(id -g "${USER}")" "/tmp/"$(basename "${url%.git}")"" \
  && pushd "/tmp/"$(basename "${url%.git}")"" > /dev/null 2>&1 ; \
  for i in {1..5}; do su-exec "${USER}" makepkg -sicr --noprogressbar --nocheck --skipinteg --noconfirm && break || sleep 15; done \
  && popd > /dev/null 2>&1 || exit 1 ; \
  rm -rf "/tmp/"$(basename "${url%.git}")"" ; \
  go clean -modcache > /dev/null 2>&1 ; \
  su-exec "${USER}" go clean -modcache > /dev/null 2>&1 ; \
  go clean -cache > /dev/null 2>&1 ; \
  su-exec "${USER}" go clean -cache > /dev/null 2>&1 ; \
  done ; \
  rm -rf "$(go env GOPATH)/pkg/mod" ; \
  for group in "${GROUPS_ARR[@]}";do \
  getent group "${group}" > /dev/null 2>&1 && usermod -aG "${group}" "${USER}" || continue ; \
  done ; \
  # https://jdimpson.livejournal.com/5685.html
  # https://stackoverflow.com/questions/8295908/how-to-use-a-variable-to-indicate-a-file-descriptor-in-bash
  tflint --version > /dev/null 2>&1 && ( \
  [ ! -d "${HOME}/.init.d/" ] && ( mkdir -p "${HOME}/.init.d" && chown "$(id -u "${USER}"):$(id -g "${USER}")" "${HOME}/.init.d") ; \
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
  echo '    [ -r "${lockfile}" ] && rm -f "${lockfile}" ;' ; \
  echo '  fi' ; \
  echo 'done ;' ; \
  echo 'rm -f "${self}" ;' ; \
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
  ) | tee "/etc/profile.d/terraform.sh" > /dev/null || exit 1 ; \
  compress-packages ;
# Generic
# hadolint ignore=SC2034,DL3013,DL4006,SC2016
RUN \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  export PIP_NO_CACHE_DIR="off" ; \
  export MAKEFLAGS="-j$(nproc)" ; \
  export CGO_ENABLED=1; \
  export CGO_LDFLAGS="-g -O2" ; \
  AUR_CLONE_URLS=( \
  "https://aur.archlinux.org/driftctl-bin.git" \
  ) ; \
  GROUPS_ARR=( \
  "caddy" \
  "traefik" \
  ) ; \
  pacman --quiet --noprogressbar -S --noconfirm --needed \
  "caddy" \
  "traefik" \
  ; \
  for url in "${AUR_CLONE_URLS[@]}";do \
  git clone --quiet "${url}" "/tmp/"$(basename "${url%.git}")"" \
  && chown -R "$(id -u "${USER}"):$(id -g "${USER}")" "/tmp/"$(basename "${url%.git}")"" \
  && pushd "/tmp/"$(basename "${url%.git}")"" > /dev/null 2>&1 ; \
  for i in {1..5}; do su-exec "${USER}" makepkg -sicr --nocheck --skipinteg --noconfirm --noprogressbar && break || sleep 15; done \
  && popd > /dev/null 2>&1 || exit 1 ; \
  rm -rf "/tmp/"$(basename "${url%.git}")"" ; \
  go clean -modcache ; \
  su-exec "${USER}" go clean -modcache ; \
  go clean -cache ; \
  su-exec "${USER}" go clean -cache ; \
  done ; \
  rm -rf "$(go env GOPATH)/pkg/mod" ; \
  for group in "${GROUPS_ARR[@]}";do \
  getent group "${group}" > /dev/null 2>&1 && usermod -aG "${group}" "${USER}" || continue ; \
  done ; \
  python3 -m pip install -q --no-cache-dir --break-system-packages \
  "checkov" \
  driftctl version >/dev/null 2>&1 && ( \
  echo 'eval "$(driftctl completion bash)" ;' ; \
  ) | tee -a "/etc/profile.d/generic-iac.sh" > /dev/null ; \
  compress-packages ;
# ────────────────────────────────────────────────────────────────────────────────
# SHELL ["/usr/bin/pwsh", "-NoLogo", "-Command"]
# # hadolint ignore=DL4006
# RUN 'driftctl completion powershell | Out-String | Invoke-Expression' | Out-File -Append -Encoding ascii "$PROFILE"
# SHELL ["/bin/bash", "-euo", "pipefail", "-c"]
#  ╭──────────────────────────────────────────────────────────╮
#  │                   extra packages                         │
#  ╰──────────────────────────────────────────────────────────╯
# "extra/aws-cli-v2" \
# "aur/semgrep-bin" \
USER "root"
RUN \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  export PIP_NO_CACHE_DIR="off" ; \
  export MAKEFLAGS="-j$(nproc)" ; \
  export CGO_ENABLED=1 ; \
  export CGO_LDFLAGS="-g -O2" ; \
  mkdir -p "${HOME}/.local/state/paru" \
  && chown -R "$(id -u "${USER}"):$(id -g "${USER}")" \
  "${WORKDIR}" "${HOME}" \
  && paru -S --noconfirm --needed \
  "markdownlint" \
  "consul-template" \
  "packer" \
  "azure-cli" \
  "chaotic-aur/topgrade" \
  "python-pre-commit" \
  "python-certifi" \
  "goreleaser" \
  "shfmt" \
  "nushell" \
  "mage" \
  "bottom" \
  "cocogitto" \
  "eva" \
  "hck" \
  "mdcat" \
  "navi" \
  "xh" \
  "xcp" \
  "neovim" \
  "sd" \
  "duf" \
  "ncdu" \
  "ripgrep-all" \
  "fd" \
  "tokei" \
  "hyperfine" \
  "bat-extras" \
  "prettier" \
  "entr" \
  "podman" \
  "docker-machine" \
  "docker-scan" \
  "docker-compose" \
  "noto-fonts" \
  "ttf-ubuntu-font-family" \
  "ttf-font-awesome" \
  "gitui" \
  "rsync" \
  "unrar" \
  "dialog" \
  "psutils" \
  "rclone" \
  "moreutils" \
  "vector" \
  "pulumi" \
  "istio" \
  "trivy" \
  "python-lsp-jsonrpc" \
  "python-lsp-black" \
  "python-lsp-server" \
  "bash-language-server" \
  "yaml-language-server" \
  "vscode-json-languageserver" \
  "gopls" \
  "marksman" \
  "cfssl"  \
  "chaotic-aur/google-cloud-cli" \
  && su-exec "${USER}" paru -S --noconfirm --needed --removemake --cleanafter \
  "aur/devc-bin" \
  "aur/nodejs-cspell" \
  "aur/commitlint" \
  "aur/commitlint-config-conventional" \
  "aur/earthly-bin" \
  "aur/forgit" \
  "aur/git-fuzzy-git" \
  "aur/git-completion" \
  "aur/git-shelf" \
  "aur/diffsitter-bin" \
  "aur/vendir-bin" \
  "aur/qsv-bin" \
  "aur/shellcheck-bin" \
  "aur/docker-sbom" \
  "aur/fzfx-git" \
  "aur/fzf-extras" \
  "aur/shellcheck-bin" \
  "aur/terrascan" \
  "aur/opa" \
  "aur/pulumictl" \
  "aur/infracost" \
  "aur/k6" \
  "aur/rancher-k3d-bin" \
  "aur/envoyproxy-bin" \
  "aur/gojira" \
  "aur/litmusctl" \
  "aur/inlyne-bin" \
  "aur/jql" \
  "aur/ripsecrets" \
  "aur/rnr-bin" \
  "aur/awk-language-server" \
  "aur/dockerfile-language-server-bin" \
  "aur/terraform-ls-bin" \
  && curl -fsSL "https://plandex.ai/install.sh" | bash > /dev/null 2>&1 \
  && go install \
  "github.com/Gelio/go-global-update@latest" \
  && go clean -modcache > /dev/null 2>&1 \
  && su-exec "${USER}" go clean -modcache > /dev/null 2>&1 \
  && go clean -cache > /dev/null 2>&1 \
  && su-exec "${USER}" go clean -cache > /dev/null 2>&1 \
  && compress-packages ;
#  ╭──────────────────────────────────────────────────────────╮
#  │                   user profile config                    │
#  ╰──────────────────────────────────────────────────────────╯
USER "${USER}"
WORKDIR "${WORKDIR}"
RUN \
  ( \
  echo '[ -r "/entrypoint" ] && exec /entrypoint sudo -E -u "${USER}"' ; \
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
  echo "Host github.com" ; \
  echo "  StrictHostKeyChecking no" ; \
  echo "  MACs hmac-sha2-512" ; \
  echo "  UserKnownHostsFile=/dev/null" ; \
  echo "  IdentitiesOnly yes" ; \
  echo "  BatchMode yes" ; \
  echo "  IdentityFile=~/.ssh/id_rsa_github" ; \
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
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  ln -sf "/usr/share/zoneinfo/America/New_York" "/etc/localtime" ; \
  chown "$(id -u "${USER}"):$(id -g "${USER}")" -R  "${WORKDIR}" "${HOME}" ; \
  [ "$(pacman -Qdtq)" != "" ] && pacman -Rs $(pacman -Qdtq) ; \
  npm cache clean --quiet --force ; \
  go clean -modcache ; \
  su-exec "${USER}" go clean -modcache ; \
  go clean -cache ; \
  su-exec "${USER}" go clean -cache ; \
  rm -rf /tmp/* "${HOME}/.cache" ;
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
    echo ');' ; \
    echo 'exec "$@"' ; \
  ) | tee '/entrypoint' > /dev/null \
  && chmod +x '/entrypoint' \
  && chown "$(id -u "${USER}"):$(id -g "${USER}")" '/entrypoint';

# RUN du --human-readable --max-depth 1 "${HOME}" > /.size \ && expac --humansize M "%n %m" -l'\n' -Q $(pacman -Qq) | sort -hk 2 > /.package-size

USER "${USER}"
VOLUME ["${HOME}","${WORKDIR}"]
ENV TERM="xterm"
ENV DOCKER_BUILDKIT="1"
ENV BUILDKIT_PROGRESS="plain"
# ENV TERM_PROGRAM="vscode"
ENTRYPOINT [ "/entrypoint" ]
CMD [ "sleep", "infinity" ]
