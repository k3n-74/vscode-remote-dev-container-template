vscode dev container のひな型。  
内容は下記の通り。

## 🚀 ベースイメージ

- Debian

## 🚀 ログインユーザ

- root ではなく 一般ユーザ。
- ユーザ名は `ika-musume` 。

## 🚀 基本的な linux パッケージ

- git, vim, nano, wget, curl, jq, zip, unzip といった良く使用するパッケージをインストール。

## 🚀 docker ( サブコマンドになった compose も含む )

- `docker in docker` ではなく `docker outside of docker` でセットアップしてある。

## 🚀 AWS

- プロファイル
  - ホストの `~/.aws` をコンテナにマウントする。

* AWS のクレデンシャル取得を簡単にする便利関数  
  MFA ありで Jump アカウントで認証して、そこからのスイッチロールをするプロファイルの利用を簡単にするためのシェル関数。

  - `useawsprofile` 関数を呼ぶと、その後 profile name と TOTP の入力を求められる。
  - `useawsprofile` 関数のソースは `/.devcontainer/useawsprofile.sh` 。
  - profile に必ず `role_session_name` を定義しておくこと。

* ツール
  - AWS CLI
  - Session Manager Plugin
  - AWS SAM CLI

## 🚀 Homebrew

- サンプルとして `lazydocker` をインストールしている。
- homebrew をインストールするとコンテナのビルドに時間がかかるので、不要な場合はコメントアウトしたほうが良い。

## 🚀 Python

- pyenv, poetry
- poetry の設定について
  - `installer.parallel false`  
    安定性のため。
  - `virtualenvs.create false`  
    `poetry add cfn-lint --group dev` でインストールした開発ツールを vscode に認識させる手間を省くため。

## 🚀 node.js

- volta

## 🚀 Java

- コメントアウトしてあるが apt-get でインストールする例が書いてある。  
  例えば、OpenAPI Generator といったツールを使いたい程度の場合は、そのコメントアウトを解除すれば良い。

## 🚀 vscode 関係

- コンテナリビルド後の起動時間を短縮するために vscode extension のインストール先を docker volume にしてある。

## 🚀 サイドカーコンテナ

- コメントアウトを解除すると下記が別コンテナで起動し、利用できるようになる。
  - mysql
  - swagger-editor
  - swagger-ui
