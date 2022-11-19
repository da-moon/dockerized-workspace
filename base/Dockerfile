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
  "man-db" \
  "wget" \
  "curl" \
  "make" \
  "jq" \
  "unzip" \
  "unrar" \
  "dialog" \
  "psutils" \
  "bash-completion" ;
#  ╭──────────────────────────────────────────────────────────╮
#  │              install makpkg dependencies                 │
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
#  │                          docker                          │
#  ╰──────────────────────────────────────────────────────────╯
# hadolint ignore=SC2016
RUN \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
pacman -Syy --noconfirm --needed \
"docker" \
"docker-compose" \
&& ( \
  echo '#!/bin/sh' ; \
  echo 'sudoIf() { if [ "$(id -u)" -ne 0 ]; then sudo "$@"; else "$@"; fi }' ; \
  # ─── DOCKER FROM DOCKER ─────────────────────────────────────────────────────────
  echo 'if [ -r "/var/run/docker.sock" ];then' ; \
  echo 'SOCKET_GID="$(stat -c "%g" "/var/run/docker.sock")" ; ' ; \
  echo '  if [ "${SOCKET_GID}" != 0 ]; then' ; \
  echo '      if [ "$(cat "/etc/group" | grep :${SOCKET_GID}:)" =  ]; then sudoIf groupadd --gid "${SOCKET_GID}" "docker-host"; fi' ; \
  echo '      if [ "$(id "$(whoami)" | grep -E "groups=.*(=|,)${SOCKET_GID}\(")" = "" ]; then sudoIf usermod -aG "${SOCKET_GID}" "$(whoami)"; fi' ; \
  echo '  fi' ; \
  echo 'fi' ; \
) | tee '/usr/local/share/docker-from-docker.sh' > /dev/null \
&& chmod +x '/usr/local/share/docker-from-docker.sh' ;
#  ╭──────────────────────────────────────────────────────────╮
#  │                          fonts                           │
#  ╰──────────────────────────────────────────────────────────╯
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
RUN \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
pacman -Syy --noconfirm --needed \
  "sd" \
  "shfmt"  \
  "ripgrep" \
  "fd" \
  "tokei" \
  "hyperfine"  ;
#  ────────────────────────────────────────────────────────────
# hadolint ignore=SC2016
RUN \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
pacman -Syy --noconfirm --needed "just" \
&& just --version > /dev/null 2>&1 \
  && echo 'eval "$(just --completions bash)" ;' > "/etc/profile.d/just.sh" \
  || exit 1 ;
#  ────────────────────────────────────────────────────────────
# hadolint ignore=SC2016
RUN \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
pacman -Syy --noconfirm --needed "starship" \
&& starship --version > /dev/null 2>&1 \
  && echo 'eval "$(starship init bash)" ;' > "/etc/profile.d/starship.sh" \
  || exit 1;
#  ────────────────────────────────────────────────────────────
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
RUN \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
pacman -Syy --noconfirm --needed "bat" \
&& bat --version > /dev/null 2>&1 && ( \
  echo 'alias cat="bat -pp" ;' ; \
  echo "export MANPAGER='sh -c \"col -bx | bat --language man --style plain\"' ;" ; \
) | tee "/etc/profile.d/bat.sh" > /dev/null || exit 1  ;
#  ────────────────────────────────────────────────────────────
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
#  │                 install lua packages                     │
#  ╰──────────────────────────────────────────────────────────╯
ENV PATH="${PATH}:${HOME}/.luarocks/bin"
RUN \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
pacman -Syy --noconfirm --needed "lua" ;
# hadolint ignore=DL3059
RUN \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
pacman -Syy --noconfirm --needed "luajit" ;
# hadolint ignore=DL3059
RUN \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
pacman -Syy --noconfirm --needed "luarocks" ;
#  ╭──────────────────────────────────────────────────────────╮
#  │                     python packages                      │
#  ╰──────────────────────────────────────────────────────────╯
ENV PATH="${PATH}:${HOME}/.local/bin"
RUN \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
pacman -Syy --noconfirm --needed \
"python" \
"python-pip" \
"python-setuptools" \
"python-pre-commit" ;
#  ╭──────────────────────────────────────────────────────────╮
#  │                 install nodejs packages                  │
#  ╰──────────────────────────────────────────────────────────╯
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
RUN \
--mount=type=cache,id=yarn-cache,sharing=shared,target=/usr/local/share/.cache/yarn \
yarn --silent global add \
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
  "standard-readme-spec" \
  "yo" \
  "generator-standard-readme" ;
#  ╭──────────────────────────────────────────────────────────╮
#  │                   install aur packages                   │
#  ╰──────────────────────────────────────────────────────────╯
USER "${USER}"
# hadolint ignore=SC2034
RUN \
  --mount=type=cache,id=pacman-db,sharing=private,mode=0777,target=/var/lib/pacman/sync \
  --mount=type=cache,id=pacman-cache,sharing=shared,mode=0777,target=/var/cache/pacman \
AUR_CLONE_URLS=( \
"https://aur.archlinux.org/neovim-git.git" \
"https://aur.archlinux.org/aura-bin.git" \
"https://aur.archlinux.org/git-completion.git" \
"https://aur.archlinux.org/fzf-extras.git" \
) ; \
export MAKEFLAGS="-j$(nproc)" ; \
for url in "${AUR_CLONE_URLS[@]}";do \
git clone "${url}" "/tmp/"$(basename "${url%.git}")"" \
&& pushd "/tmp/"$(basename "${url%.git}")"" > /dev/null 2>&1 ; \
for i in {1..5}; do makepkg -sicr --noconfirm && break || sleep 15; done \
&& popd > /dev/null 2>&1 || exit 1 ; \
done ;
#  ╭──────────────────────────────────────────────────────────╮
#  │                   user profile config                    │
#  ╰──────────────────────────────────────────────────────────╯
ENV EDITOR="nvim"
ENV VISUAL="nvim"
RUN \
  # ─── SSH SETUP ──────────────────────────────────────────────────────────────────
  mkdir -p "${HOME}/.ssh" \
  && chmod 700 "${HOME}/.ssh" \
  && ( \
    echo "Host git.sr.ht" ; \
    echo "  User git" ; \
    echo "  StrictHostKeyChecking no" ; \
    echo "  MACs hmac-sha2-512" ; \
    echo "  UserKnownHostsFile=/dev/null" ; \
  ) | tee "${HOME}/.ssh/config" > /dev/null \
  && chmod 644 "${HOME}/.ssh/config" ;
#  ╭──────────────────────────────────────────────────────────╮
#  │                         finalize                         │
#  ╰──────────────────────────────────────────────────────────╯
USER "root"
ARG WORKDIR="/workspace"
ENV WORKDIR "${WORKDIR}"
WORKDIR "${WORKDIR}"
RUN \
chown "$(id -u "${USER}"):$(id -g "${USER}")" -R  \
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
  echo 'exec "$@"' ; \
) | tee '/entrypoint' > /dev/null \
&& chmod +x '/entrypoint' ;
# ────────────────────────────────────────────────────────────────────────────────
USER "${USER}"
VOLUME ["${HOME}","${WORKDIR}}"]
ENV TERM "xterm"
ENV COLORTERM "truecolor"
ENV DOCKER_BUILDKIT "1"
ENTRYPOINT [ "/entrypoint" ]
CMD [ "sleep", "infinity" ]
