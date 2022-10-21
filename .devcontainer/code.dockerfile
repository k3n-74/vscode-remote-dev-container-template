FROM debian:11.3

# nointeractiveは問題に気づきにくくなるので推奨されていないらしい。
# なので、本当はtextを指定したほうが良い。
ENV DEBIAN_FRONTEND=noninteractive

# WORKDIRに指定するパス
ARG WORKDIR_PATH=/tmp/workdir-for-docker-build

# 最初はrootユーザで作業開始
USER root

# /bin/shにはsourceがなくてdocker buildでエラーになるからbashに変更する
SHELL ["/bin/bash", "-c"]

############################################
# SHELL ["/bin/bash", "-c"] の問題と回避方法
############################################
# docker build 中はSHELL ["/bin/bash", "-c"]では.bashrcが即リターンになり、
# source ~/.profile や ~/.bashrc が効かない。
# どうしても、この問題を回避できない場合は、
# 該当箇所だけを SHELL ["/bin/bash", "-icl"] で実行する。
# 問題の原因は.bashrcの下記先頭処理で即リターンになり、その後の処理が実行されないこと。
# case $- in
#     *i*) ;;
#       *) return;;
# esac
# 上記処理は.bashrcの呼び出し元のプロセスの起動オプションの中にiが含まれていたら
# 処理を継続する。iが含まれていいなかったら即リターンという意味。
# よって、処理を継続するためにはbash -icにする必要がある。
# ただ、iを指定すると内部的にはl(エル)も指定したことになるため、
# l(エル)が原因で発生する警告文を理解しやすくするためにbash -iclと指定する。


############
## ユーザ(イカ娘)を追加する
############

# 非ルートユーザを追加する方法の公式ドキュメント
# https://code.visualstudio.com/docs/remote/containers-advanced#_adding-a-nonroot-user-to-your-dev-container
# 公式Dockerfileで利用されているDebian用スクリプト。
# 公式ドキュメントに書いていないことまで書いてある
# https://github.com/microsoft/vscode-dev-containers/blob/master/script-library/common-debian.sh

ARG USERNAME=ika-musume
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN set -xeu \
    && groupadd --gid ${USER_GID} ${USERNAME} \
    && useradd --uid ${USER_UID} --gid ${USER_GID} -m ${USERNAME} \
    # Add sudo support. Omit if you don't need to install software after connecting.
    && apt-get update \
    && apt-get install -y sudo locales \
    && apt-get clean \
    && echo "${USERNAME} ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME} \
    # Ensure ~/.local/bin is in the PATH for root and non-root users for bash. (zsh is later)
    && echo 'export PATH=$PATH:$HOME/.local/bin' | tee -a /root/.bashrc >> /home/${USERNAME}/.bashrc \
    && chown ${USER_UID}:${USER_GID} /home/${USERNAME}/.bashrc \
    # デフォルトロケールをja_JP.UTF-8に変更する
    # ja_JP.UTF-8の行のコメントを解除
    && sed -i -E 's/# (ja_JP.UTF-8)/\1/' /etc/locale.gen \
    && locale-gen \
    && update-locale LANG=ja_JP.UTF-8 \
    # ika-musumeのシェルを/bin/shから/bin/bashに変更する
    && chsh -s /bin/bash ${USERNAME}

ENV LANG="ja_JP.UTF-8"

############
## コンテナをリビルドした後にvscode extensionsの再インストールを抑止して
## vscode起動時間を短縮するための設定
## https://code.visualstudio.com/docs/remote/containers-advanced#_avoiding-extension-reinstalls-on-container-rebuild
############

RUN mkdir -p /home/$USERNAME/.vscode-server/extensions \
      /home/$USERNAME/.vscode-server-insiders/extensions \
    && chown -R $USERNAME \
      /home/$USERNAME/.vscode-server \
      /home/$USERNAME/.vscode-server-insiders


############
## USERを${USERNAME}にスイッチする
############

USER ${USERNAME}


############
## 基本的なパッケージをインストールする
############

RUN set -xeu \
    && sudo apt-get update \
    && sudo apt-get -y install zlib1g-dev libssl-dev libffi-dev \
      libreadline-dev libsqlite3-dev libbz2-dev \
      libncurses5-dev libgdbm-dev liblzma-dev \
      tk-dev git vim nano wget curl software-properties-common \
      groff-base less jq zip unzip build-essential file \
      ca-certificates bzip2 dialog liblttng-ust0 procps \
      make llvm libncursesw5-dev xz-utils libxml2-dev libxmlsec1-dev \
    && sudo apt-get clean

############
## python
############

# https://github.com/pyenv/pyenv#automatic-installer
# https://github.com/pyenv/pyenv-installer
ARG PYENV_GIT_TAG="v2.3.2"
# pyenvをインストール
RUN set -xeu \
    && curl https://pyenv.run | bash \
    && echo 'export PYENV_ROOT="$HOME/.pyenv"' >> /home/${USERNAME}/.profile \
    && echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"' >> /home/${USERNAME}/.profile \
    && echo 'eval "$(pyenv init -)"' >> /home/${USERNAME}/.profile
# pythonとPoetryをインストール
ARG DEFAULT_PYTHON_VERSION="3.9.13"
ARG POETRY_VERSION="1.2.0"
RUN set -xeu \
    # pyenv を有効化するためのおまじない
    && export PYENV_ROOT="/home/${USERNAME}/.pyenv" \
    && command -v pyenv >/dev/null || export PATH="${PYENV_ROOT}/bin:${PATH}" \
    && eval "$(pyenv init -)" \
    # pyenvでpythonをインストールしてデフォルト設定をする
    && pyenv install ${DEFAULT_PYTHON_VERSION} \
    && pyenv global ${DEFAULT_PYTHON_VERSION} \
    # Poetryをインストールする
    && curl -sSL https://install.python-poetry.org | python3 - --version ${POETRY_VERSION} \
    # 以下、ここではpoetryコマンドへのパスが通っていない状態なのでpoetryコマンドをフルパスで指定している
    # 補完を有効化 ← エラーになるからコメントアウト
    # && /home/${USERNAME}/.local/share/pypoetry/venv/bin/poetry completions bash | sudo tee /etc/bash_completion.d/poetry.bash-completion \
    # パッケージの並列インストールを無効化
    && /home/${USERNAME}/.local/share/pypoetry/venv/bin/poetry config installer.parallel false \
    # 仮想環境が無いときに仮想環境を自動作成する機能を無効化
    # ( poetryで作成した仮想環境をVS Codeに認識させる手間を省くため )
    && /home/${USERNAME}/.local/share/pypoetry/venv/bin/poetry config virtualenvs.create false


############
## node.js
############

ARG DEFAULT_NODE_VERSION=18.5.0
ARG DEFAULT_NPM_VERSION=8.12.1
RUN set -xeu \
    # voltaをインストール
    && curl https://get.volta.sh | bash \
    # voltaを使うためのおまじない
    && export VOLTA_HOME="$HOME/.volta" \
    && export PATH="$VOLTA_HOME/bin:$PATH" \
    # デフォルトの node, npm をインストール
    && volta install node@${DEFAULT_NODE_VERSION} npm@${DEFAULT_NPM_VERSION}

############
## Java
############

# RUN set -xeu \
#     && sudo apt-get update \
#     && sudo apt-get -y install openjdk-11-jdk \
#     && sudo apt-get clean


############
## Docker client, Docker Compose
############

# https://docs.docker.com/engine/install/debian/

WORKDIR $WORKDIR_PATH
RUN set -xeu \
    && sudo apt-get update \
    && sudo apt-get -y install \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
    && sudo apt-get clean \
    && sudo mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    # dockerのstableリポジトリをaptのソースリストに追加
    && echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
        $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null \
    # Docker CLI と Compose だけインストール
    # TODO: バージョン指定でインストールするように変更する
    && sudo apt-get update \
    #  sudo apt-get install -y docker-ce-cli=<VERSION_STRING>
    && sudo apt-get install -y docker-ce-cli docker-compose-plugin \
    # ゴミ掃除
    && sudo rm -rf $WORKDIR_PATH

# Bind MountしたDocker Daemonのポートにika-musumeがアクセスできるようにする
# https://docs.docker.com/engine/install/linux-postinstall/#manage-docker-as-a-non-root-user
# Bastion host の場合( ${IS_BASTION_HOST}="YES" )は本設定を実行しない。
RUN set -xeu \
  && { \
    echo -e "\n# change docker daemon port owner to ${USERNAME}."; \
    echo -e "test \"\${IS_BASTION_HOST}\" != \"YES\" && ( test -x /var/run/docker.sock || ( sudo chown -R ${USERNAME} /var/run/docker.sock && sudo chmod -R +rwx /var/run/docker.sock ) )"; \
    echo -e "\n"; \
  } >> /home/${USERNAME}/.profile


############
## AWS CLI V2 と Session Manager plugin
############

WORKDIR $WORKDIR_PATH
# https://github.com/aws/aws-cli/blob/v2/CHANGELOG.rst
ARG AWS_CLI_VERSION="2.7.13"
# https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html#plugin-version-history
ARG AWS_SESSION_MANAGER_PLUGIN_VERSION="1.2.339.0"
RUN set -xeu \
    # AWS CLI V2
    && sudo curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWS_CLI_VERSION}.zip" -o "awscliv2.zip" \
    && sudo unzip awscliv2.zip \
    && sudo ./aws/install \
    # Session Manager plugin
    && sudo curl "https://s3.amazonaws.com/session-manager-downloads/plugin/${AWS_SESSION_MANAGER_PLUGIN_VERSION}/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb" \
    && sudo dpkg -i session-manager-plugin.deb \
    # ゴミ掃除
    && sudo rm session-manager-plugin.deb \
    && sudo rm awscliv2.zip \
    && sudo rm -rf ./aws \
    && sudo rm -rf $WORKDIR_PATH

# ############
# ## AWS SAM CLI
# ############

WORKDIR $WORKDIR_PATH
# https://github.com/aws/aws-sam-cli/releases
ARG AWS_SAM_CLI_VERSION="1.53.0"
RUN set -xeu \
    && sudo curl -L "https://github.com/aws/aws-sam-cli/releases/download/v${AWS_SAM_CLI_VERSION}/aws-sam-cli-linux-x86_64.zip" -o "aws-sam-cli-linux-x86_64.zip" \
    && sudo unzip aws-sam-cli-linux-x86_64.zip -d sam-installation \
    && sudo ./sam-installation/install \
    # ゴミ掃除
    && sudo rm -rf $WORKDIR_PATH


# # ############
# # ## Homebrew
# # 
# # Homebrew以外からインストールしたpythonがあるとコンフリクトを起こす。(brew doctorでエラーがレポートされた)
# # Homebrewを使用する場合はpythonをHomebrewからインストールする必要がある。
# # そういった理由によりHomebrewのインストールはコメントアウトしておく。
# # 下記は動作確認済みのスクリプトなので、今後必要になった時に利用可能。
# # ############

RUN set -xeu \
    && cd /tmp \
    && sudo apt-get update \
    && /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)" \
    # ~/.linuxbreは無いからコメントアウト。余談だがこいつの実行にはpsコマンドが必要だからprocpsをapt-get installする必要あり。
    # && test -d ~/.linuxbrew && eval $(~/.linuxbrew/bin/brew shellenv) \
    # /home/linuxbrew/.linuxbrewはある。ただし、この時点で存在しない環境変数($INFOPATH)にアクセスする処理がある。
    && set +u \
    && test -d /home/linuxbrew/.linuxbrew && eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv) \
    && set -u \
    # ~/.bash_profileは無いからコメントアウト
    # && test -r ~/.bash_profile && echo "eval \$($(brew --prefix)/bin/brew shellenv)" >>~/.bash_profile \
    && echo "eval \$($(brew --prefix)/bin/brew shellenv)" >> ~/.profile \
    && brew --version

# homebrewでインストールするときの例。lazydockerをインストールする。
RUN set -xeu \
    # docker build中はbrewコマンドを利用可能な状態にするために下記３行のコマンド実行が必要
    && set +u \
    && eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv) \
    && set -u \
    # lazydocker をインストール
    && brew install lazydocker




###########
# pip install
###########

# 本当は pip install -r requirements.txt が良い。

# 要インタラクティブオプション。
# 本来ならパスが足りず警告が出力されるが、pythonインストールの後処理にその対策がしてある。
# 開発で必要なものは poetry add -D black でインストールして欲しいからコメントアウト。
# RUN set -xeu \
#   && pip3 install \
#     wheel \
#     cfn-lint \
#     yq \
#     aws-sam-cli \
#     black \
#     pylint \
#     pydot \
#     mypy \
#     pytest \
#     pytest-cov \
#     pytest-html \
#     uvicorn[standard]


###########
# npm install
###########

    # nvmコマンドを有効化するためには、source ~/.profile を実行する必要がある。
    # しかし、source ~/.profile はインタラクティブオプションが付いている状態でしか機能しない。
    # インタラクティブオプションは極力使わないほうが安全なので、下記３行でnvmコマンドを有効化する。
# RUN set -xeu \
#   && export NVM_DIR="$HOME/.nvm" \
#   && [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" \
#   && [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" \
#   # npm install を実行
#   && npm install -g serve


###########
# apt-get install
# その他、雑多のパッケージ
###########

RUN set -xeu \
  && sudo apt-get update \
  && sudo apt-get -y install peco uuid-runtime default-mysql-client \
  && sudo apt-get -y upgrade bash-completion \
  && sudo apt-get clean


###########
# ユーザ環境設定
###########

# home directoryに.ika-musume directoryを作成する
RUN set -xeu \
  && mkdir /home/${USERNAME}/.${USERNAME}

# bash promptoをカスタマイズ
RUN set -xeu \
  && { \
    echo -e "\n# customize bash prompto."; \
    echo 'if [ "${IS_BASTION_HOST}" = "YES" ]; then'; \
    echo '  # bastion host'; \
    echo '  export PS1="${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u @ bastion-host\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "'; \
    echo 'else'; \
    echo '  export PS1="${debian_chroot:+($debian_chroot)}\[\033[01;35m\]\u\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "'; \
    echo 'fi'; \
    echo -e "\n"; \
  } >> /home/${USERNAME}/.profile

# useawsprofile関数を登録
COPY useawsprofile.sh /home/${USERNAME}/.${USERNAME}/
RUN set -xeu \
  && { \
    echo -e "\n# add useawsprofile function"; \
    echo "source /home/${USERNAME}/.${USERNAME}/useawsprofile.sh"; \
    echo -e "\n"; \
  } >> /home/${USERNAME}/.profile

# npm run [tab]のcompletionを登録
COPY npm-run-completion.sh /home/${USERNAME}/.${USERNAME}/
RUN set -xeu \
  && { \
    echo -e "\n# npm run [tab] completion"; \
    echo "source /etc/bash_completion"; \
    echo "source /home/${USERNAME}/.${USERNAME}/npm-run-completion.sh"; \
    echo -e "\n"; \
  } >> /home/${USERNAME}/.profile


# # node_modules volumeの所有者がrootになっているのでika-musumeに変更
# RUN set -xeu \
#   && { \
#     echo -e "\n# change node_modules owner to ika-musume."; \
#     echo "test -w /workspace/webui/foo/node_modules || sudo chown -R ${USERNAME} /workspace/webui/foo/node_modules"; \
#     echo "test -w /workspace/webui/bar/node_modules || sudo chown -R ${USERNAME} /workspace/webui/bar/node_modules"; \
#     echo -e "\n"; \
#   } >> /home/${USERNAME}/.profile

# # PYTHONPATHの指定
# RUN set -xeu \
#     && { \
#       echo -e "\n# add PYTHONPATH"; \
#       set +u; \
#       echo "export PYTHONPATH=/workspace/server/services/web-api/lambda-layer-web-api/python:$PYTHONPATH"; \
#       set -u; \
#       echo -e "\n"; \
#     } >> /home/${USERNAME}/.profile


###########
# vscode shell integration の manual installation
# https://code.visualstudio.com/docs/terminal/shell-integration#_manual-installation
###########
RUN set -xeu \
    && echo '[[ "$TERM_PROGRAM" == "vscode" ]] && . "$(code --locate-shell-integration-path bash)"' >> /home/${USERNAME}/.profile


EXPOSE 3000
# EXPOSE 3000 3001 3002 3120 3500 3501 8000

# 最後にDEBIAN_FRONTENDを元に戻しておく。
ENV DEBIAN_FRONTEND=dialog

ENTRYPOINT [ "/bin/bash" ]
