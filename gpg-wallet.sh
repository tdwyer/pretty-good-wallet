#!/bin/bash -
#===============================================================================
#
#          FILE: gpg-wallet
#       LICENSE: GPGv3
#
#       INSTALL: install -Dm755 gpg-wallet/gpg-wallet.sh /usr/bin/gpg-wallet
#
#         USAGE: gpg-wallet google.com bobyjones
#
#   DESCRIPTION: Think gnome-keyring, but no extra daemon or password.
#                Use gpg-agent to encrypt each password to a file, and
#                decrypt the password to standard out.
#
#       OPTIONS: { --new | --batch * * pass kfp 'force'| --rm } 'Service' 'User'
#  REQUIREMENTS: Bash GnuPG gpg-agent
#          BUGS: Prob.
#         NOTES: Best with "keychain" which maintains an unlocked gpg-agent
#        AUTHOR: Thomas Dwyer devel@tomd.tel
#  ORGANIZATION: http://tomd.tel/
#       CREATED: 12/30/2013 12:01 UTC
#       UPDATED: 01/23/2014 07:00 UTC
#      REVISION: 2.5
#===============================================================================
#
MKD=/usr/bin/mkdir
RM=/usr/bin/rm
GPG=/usr/bin/gpg
#
RING="${HOME}/.gpg-wallet"
CONF="${RING}/defaults.conf"

main() {
  #
  #
  [[ -z ${1} ]] && \
    esc 254 "
    Usage: ${0} {--new | --batch 'kfp' 'pwd' | --rm} 'Service' 'User'
    "

  [[ ! -d "${RING}" ]] && ${MKD} "${RING}"

  [[ ! -f "${CONF}" ]] && jen_config
  source "${CONF}"

  [[ -z ${KEY_FPRINT} ]] && set_default_kfp

  find "${CONF}" -type d -exec chmod 0700 {} \;
  find "${CONF}" -type f -exec chmod 0600 {} \;

  #
  #
  case "${1}" in
    --new)
      new_account
    ;;
    --batch)
      [[ -z ${2} || -z ${3} || -z ${4} ]] && \
        esc 131 "Usage: ${0} --batch 'Service' 'User' 'Pass' 'kfp' 'force'" || \
        batch_add "${2}" "${3}" "${4}" "${5}" "${6}"
    ;;
    --rm)
      [[ -z ${2} || -z ${3} || ! -z ${4} ]] && \
        esc 132 "Usage: ${0} --rn 'Service' 'User'" || \
        del_account "${2}" "${3}"
      esc 0
    ;;
    --conf)
      jen_config
      esc 0
    ;;
    *)
      [[ -z ${2} || ! -z ${3} ]] && \
        esc 133 "Usage: ${0} 'Service' 'User'" || \
        get_pass "${1}" "${2}"
  esac
  esc 253 "
  Usage: ${0} {--new | --batch 'kfp' 'pwd' | --rm} 'Service' 'User'
  "
}

esc() {
  # Meh, lets just fail with return status
  #

  [[ -z ${1} ]] && exit 250

  [[ ! -z ${2} ]] && echo "${2}"

  exit ${1}
}

jen_config() {
  #
  #
  echo 'KEY_FPRINT=""' >> "${CONF}"
  set_default_kfp
}

set_default_kfp() {
  #
  #
  kfp="${1}"

  [[ -z ${kfp} ]] && use="n" || use="y"

  while [[ "${use,,}" != "y" ]] ; do
    read -p "
    > * < - > * < - > * < - > * < - > * < - > * < - > * < - > * < - > * <
    >                                                                   <
    >      Enter New FINGERPRINT or Leave Blank to Keep Current Key     <
    >       Default Key: ${KEY_FPRINT}       <
    >                                                                   <
    > * < - > * < - > * < - > * < - > * < - > * < - > * < - > * < - > * <

    Enter New FINGERPRINT: " kfp
    #
    kfp="$(echo -n ${kfp} | sed 's/ //g')"
    [[ -z ${kfp} ]] && kfp="${KEY_FPRINT}"
    #
    read -p "
    > * < - > * < - > * < - > * < - > * < - > * < - > * < - > * < - > * <
    >                                                                   <
    >               Set the Default GPG Key FINGERPRINT to              <
    >         GPG key: ${kfp}         <
    >                                                                   <
    > * < - > * < - > * < - > * < - > * < - > * < - > * < - > * < - > * <

    (y/n/Q): " use

    [[ "${use^^}" == "Q" ]] && esc 141 "Abort: User Quit in set_default_kfp"
  done

  [[ ! -z ${kfp} ]] && \
    sed -i 's/.*KEY_FPRINT.*/KEY_FPRINT="'"${kfp}"'"/' "${CONF}" || \
    echo "
    > * < - > * < - > * < - > * < - > * < - > * < - > * < - > * < - > * <
    >                                                                   <
    >             Default GPG Key FINGERPRINT Left unchanged            <
    >       Default Key: ${KEY_FPRINT}       <
    >                                                                   <
    > * < - > * < - > * < - > * < - > * < - > * < - > * < - > * < - > * <
    "
  source "${CONF}"

  [[ -z ${KEY_FPRINT} ]] && esc 142 "Abort: Set Key Failed KEY_FPRINT Null"
}

new_account() {
  #
  #

  info="$(ask_info)"
  kfp="$(echo -n ${info} | cut -d ' ' -f 1)"
  srv="$(echo -n ${info} | cut -d ' ' -f 2)"
  usr="$(echo -n ${info} | cut -d ' ' -f 3)"

  pass="$(ask_passwd)"

  srv_h="$(get_hash ${kfp} ${srv})"
  usr_h="$(get_hash ${kfp} ${srv} ${usr})"

  [[ ! -d "${RING}"/"${srv_h}" ]] && ${MKD} -p "${RING}"/"${srv_h}"

  [[ -f "${RING}/${srv_h}/${usr_h}" ]] && account_exists "${srv}" "${usr}"

  enc_pass "${srv_h}" "${usr_h}" "${pass}" "${kfp}"
}

ask_info() {
  #
  #
  use='n'

  while [[ "${use,,}" != "y" ]] ;do
    read -p "
    > * < - > * < - > * < - > * < - > * < - > * < - > * < - > * < - > * <
    >                                                                   <
    >   Enter Alternate Key Fingerprint or Leave Blank to use Default   <
    >       Default Key: ${KEY_FPRINT}       <
    >                                                                   <
    > * < - > * < - > * < - > * < - > * < - > * < - > * < - > * < - > * <

    Alternate: " kfp
    #
    # Set kfp to the Default Key Fingerprint if user entered no new key
    kfp="$(echo -n ${kfp} | sed 's/ //g')"
    [[ -z ${kfp} ]] && kfp="${KEY_FPRINT}"
    #
    read -p '
    > * < - > * < - > * < - > * < - > * < - > * < - > * < - > * < - > * <
    >                                                                   <
    >                        Set Account Details                        <
    >                                                                   <
    > * < - > * < - > * < - > * < - > * < - > * < - > * < - > * < - > * <

    Enter Service Name: ' srv
    read -p '    Enter Username: ' usr
    #
    read -p "
    > * < - > * < - > * < - > * < - > * < - > * < - > * < - > * < - > * <
    >                                                                   <
    >         Encrypt Account ${usr}@${srv} with GPG key
    >         GPG key: ${kfp}         <
    >                                                                   <
    > * < - > * < - > * < - > * < - > * < - > * < - > * < - > * < - > * <

    (y/n): " use
    #
  done

  info="${kfp} ${srv} ${usr}"
  echo -n ${info}
}

ask_passwd() {
  #
  #
  p1="X"
  p2="Y"

  while [[ "${p1}" != "${p2}" ]] ; do
    [[ "${p1}" != "X" || "${p2}" != "Y" ]] && \
    read -s -p "

    > * < - > * < - > * < - > * < - > * < - > * < - > * < - > * < - > * <
    >                                                                   <
    >                       Password Did Not Match                      <
    >                                                                   <
    > * < - > * < - > * < - > * < - > * < - > * < - > * < - > * < - > * <

    Enter Password: " p1 || \
    read -s -p '
    > * < - > * < - > * < - > * < - > * < - > * < - > * < - > * < - > * <
    >                                                                   <
    >                       Set Account Password                        <
    >              Sorry, No Spaces Allowed (Plese Fix Me)              <
    >                                                                   <
    > * < - > * < - > * < - > * < - > * < - > * < - > * < - > * < - > * <

    Enter Password: ' p1
    #
    read -s -p '
    Re-Enter Password: ' p2
  done

  echo -n "${p1}"
}

get_hash() {
  #
  #
  kfp="${1}"
  srv="${2}"
  usr="${3}"
  #
  srv_h=""
  string="${srv}"

  [[ ! -z ${usr} ]] && srv_h="$(gnupg_hash ${kfp} ${srv})"

  [[ ! -z ${srv_h} ]] && string="${srv_h}${usr}"

  hash="$(gnupg_hash ${kfp} ${string})"

  echo -n ${hash}
}

gnupg_hash() {
  #
  #
  salt="${1}"
  string="${2}"

  hash="$(echo -n ${salt}${string} | gpg --print-md sha256 | sed 's/ //g')"

  echo -n ${hash}
}

account_exists() {
  #
  #
  srv="${1}"
  usr="${2}"

  echo "

    > * < - > * < - > * < - > * < - > * < - > * < - > * < - > * < - > * <
    >                                                                   <
    >            The Username for this Service already exists           <
    >      This entry will have to be removed to save new password      <
    >                                                                   <
    > * < - > * < - > * < - > * < - > * < - > * < - > * < - > * < - > * <
  "

  x=''
  while [[ "${x,,}" != "y" && "${x,,}" != "n" ]] ;do
    read -p "    Delete ${usr}@${srv} (y/n): " x
  done

  case "${x,,}" in
    y)
      del_account "${srv}" "${usr}"
    ;;
    n)
      esc 181 "Abort: Account Exists"
    ;;
    *)
      esc 182 "Abort: Something went horribly wrong in del_account()"
  esac
}

batch_add() {
  #
  #
  srv="${1}"
  usr="${2}"
  pass="${3}"
  kfp="${4}"
  force="${5}"
  #
  dont_force=1

  [[ ${kfp} == "force" || ${force} == "force" ]] && dont_force=0
  [[ -z ${kfp} || ${kfp} == "force" ]] && kfp="${KEY_FPRINT}"

  srv_h="$(get_hash ${kfp} ${srv})"
  usr_h="$(get_hash ${kfp} ${srv} ${usr})"

  [[ ! -d "${RING}"/"${srv_h}" ]] && ${MKD} -p "${RING}"/"${srv_h}"

  [[ -f "${RING}/${srv_h}/${usr_h}" && ${dont_force} -gt 0 ]] && \
    esc 191 "Abort: Account Exists"

  enc_pass "${srv_h}" "${usr_h}" "${pass}" "${kfp}"
}

enc_pass() {
  #
  #
  srv_h="${1}"
  usr_h="${2}"
  pass="${3}"
  kfp="${4}"

  echo -n "${pass}" | ${GPG} -e -r "${kfp}" > "${RING}"/"${srv_h}"/"${usr_h}"

  exit ${?}
}

del_account() {
  #
  #
  srv="${1}"
  usr="${2}"
  kfp="${3}"

  [[ -z ${kfp} ]] && kfp="${KEY_FPRINT}"

  srv_h="$(get_hash ${kfp} ${srv})"
  usr_h="$(get_hash ${kfp} ${srv} ${usr})"

  [[ ! -f "${RING}/${srv_h}/${usr_h}" ]] && \
    esc 213 "Abort: Delete Failed Account Not Found" || \
    ${RM} "${RING}"/"${srv_h}"/"${usr_h}"
}

get_pass() {
  #
  #
  srv="${1}"
  usr="${2}"
  kfp="${3}"

  [[ -z ${srv} ]] && esc 221 "Abort: Get Pass Failed Service String Empty"
  [[ -z ${usr} ]] && esc 222 "Abort: Get Pass Failed User String Empty"
  [[ -z ${kfp} ]] && kfp="${KEY_FPRINT}"

  srv_h="$(get_hash ${kfp} ${srv})"
  usr_h="$(get_hash ${kfp} ${srv} ${usr})"

  ${GPG} --use-agent --batch --quiet -d "${RING}"/"${srv_h}"/"${usr_h}"

  esc ${?}
}

main ${@}
exit 255
# vim: set ts=2 sw=2 tw=80 et :
