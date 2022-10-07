#!/bin/bash 

# assume-roleコマンドを実行してAWSセッションを取得する
useawsprofile(){
  set -uC

  # Ctrl+Cで抜けた時に+uCを実行する。
  trap 'set +uC; return 1;' SIGINT

  read -p "profile name > " _UAP_TARGET_PROFILE
  if [ -z "${_UAP_TARGET_PROFILE}" ]; then
    echo "エラー：Profile Name を入力してください。"
    set +uC
    return 1
  fi

  if [ -z "$(aws configure list-profiles | grep -e "^${_UAP_TARGET_PROFILE}$")" ]; then
    echo "エラー：入力されたProfile Nameは存在しません。"
    set +uC
    return 1
  fi

  local _UAP_NEXT_PROFILE="${_UAP_TARGET_PROFILE}"

  local _UAP_CONFIG_CREDENTIALS_PROFILE=""
  local _UAP_CONFIG_MFA_SERIAL=""
  local _UAP_CONFIG_TARGET_ROLE_ARN=""
  local _UAP_CONFIG_REGION=""
  local _UAP_CONFIG_ROLE_SESSION_NAME=""
  # local _UAP_DATE=$(date +%s)

  echo -n "loading... : "

  while : 
  do
    echo -n "${_UAP_NEXT_PROFILE}  "

    local _UAP_TEMP_MFA_SERIAL=$(aws configure get mfa_serial --profile ${_UAP_NEXT_PROFILE})
    local _UAP_TEMP_TARGET_ROLE_ARN=$(aws configure get role_arn --profile ${_UAP_NEXT_PROFILE})
    local _UAP_TEMP_REGION=$(aws configure get region --profile ${_UAP_NEXT_PROFILE})
    local _UAP_TEMP_ROLE_SESSION_NAME=$(aws configure get role_session_name --profile ${_UAP_NEXT_PROFILE})

    # 最終的に有効になるMFA_SERIALの値を取得
    if [ -z "${_UAP_CONFIG_MFA_SERIAL}" -a -n "${_UAP_TEMP_MFA_SERIAL}" ]; then
      _UAP_CONFIG_MFA_SERIAL="${_UAP_TEMP_MFA_SERIAL}"
    fi

    # 最終的に有効になるROLE_ARNの値を取得
    if [ -z "${_UAP_CONFIG_TARGET_ROLE_ARN}" -a -n "${_UAP_TEMP_TARGET_ROLE_ARN}" ]; then
      _UAP_CONFIG_TARGET_ROLE_ARN="${_UAP_TEMP_TARGET_ROLE_ARN}"
    fi

    # 最終的に有効になるREGIONの値を取得
    if [ -z "${_UAP_CONFIG_REGION}" -a -n "${_UAP_TEMP_REGION}" ]; then
      _UAP_CONFIG_REGION="${_UAP_TEMP_REGION}"
    fi

    # 最終的に有効になるROLE_SESSION_NAMEの値を取得
    if [ -z "${_UAP_CONFIG_ROLE_SESSION_NAME}" -a -n "${_UAP_TEMP_ROLE_SESSION_NAME}" ]; then
      _UAP_CONFIG_ROLE_SESSION_NAME="${_UAP_TEMP_ROLE_SESSION_NAME}"
    fi

    _UAP_CONFIG_CREDENTIALS_PROFILE=${_UAP_NEXT_PROFILE}

    # 次のsource_profileを取得
    _UAP_NEXT_PROFILE=$(aws configure get source_profile --profile ${_UAP_NEXT_PROFILE})
    _UAP_NEXT_PROFILE_EXIT_CODE=${?}
    if [ ${_UAP_NEXT_PROFILE_EXIT_CODE} -ne 0 \
        -o -z "${_UAP_NEXT_PROFILE}" ]; then
      # 次のsource_profileが無かったらループを抜ける
      break
    fi
  done

  echo ""

  if [ -z "${_UAP_CONFIG_MFA_SERIAL}" ]; then
    echo "エラー：~/.aws/configファイル に mfa_serial が定義されていません。"
    set +uC
    return 1
  fi

  if [ -z "${_UAP_CONFIG_TARGET_ROLE_ARN}" ]; then
    echo "エラー：~/.aws/configファイル に Assume Role 先の role_arn が定義されていません。"
    set +uC
    return 1
  fi

  if [ -z "${_UAP_CONFIG_REGION}" ]; then
    echo "~/.aws/configファイル で リージョン未指定なので ap-northeast-1 を使用します。"
    _UAP_CONFIG_REGION="ap-northeast-1"
  fi

  if [ -z "${_UAP_CONFIG_ROLE_SESSION_NAME}" ]; then
    echo "エラー：~/.aws/configファイル に role_session_name が定義されていません。"
    set +uC
    return 1
  fi

  read -p "totp > " _UAP_TOKEN_CODE
  if [ -z "${_UAP_TOKEN_CODE}" ]; then
    echo "エラー：TOTP を入力してください。"
    set +uC
    return 1
  fi

  _UAP_ASSUME_ROLE_OUTPUT=$(aws sts assume-role \
    --role-arn          ${_UAP_CONFIG_TARGET_ROLE_ARN} \
    --serial-number     ${_UAP_CONFIG_MFA_SERIAL} \
    --role-session-name ${_UAP_CONFIG_ROLE_SESSION_NAME} \
    --profile           ${_UAP_CONFIG_CREDENTIALS_PROFILE} \
    --duration-second   43200 \
    --token-code        ${_UAP_TOKEN_CODE} \
    --region            ${_UAP_CONFIG_REGION} \
    --output            json
  )

  export AWS_DEFAULT_REGION=${_UAP_CONFIG_REGION}
  export AWS_ROLE_SESSION_NAME=${_UAP_CONFIG_ROLE_SESSION_NAME}
  export AWS_ACCESS_KEY_ID=$(echo ${_UAP_ASSUME_ROLE_OUTPUT} | jq -r .Credentials.AccessKeyId)
  export AWS_SECRET_ACCESS_KEY=$(echo ${_UAP_ASSUME_ROLE_OUTPUT} | jq -r .Credentials.SecretAccessKey)
  export AWS_SESSION_TOKEN=$(echo ${_UAP_ASSUME_ROLE_OUTPUT} | jq -r .Credentials.SessionToken)

  set +uC

}
