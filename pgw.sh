#!/bin/bash
#   GpgWallet       GPLv3              v10.5
#   Thomas Dwyer    <devel@tomd.tel>   http://tomd.tel/
DBUG=           # If DBUG not Null display parsed args
HELP="
Usage ${0} [-l (search-term)] [-e] [-d] [-clip] [-screen] [-window #]
                [-s example.com] [-k username (-p password)] [-v filename]
-d  domainname  :Domain, Each domain contains a Keyring and a Vault
-k  keyname     :Keyring, Think User/Password. Value i.e. passwd is prompted for
    -v          :Key Value, Provide value in command instead of through a prompt
-f  filename    :Vault, Encrypted file management with native interface
-e              :Encrypt
-stdout         :Send to plaintext to stdout
-clip   #       :Send to selection 3=Clipboard 2=Secondary 1=Primary: DEFAULT  1
-screen         :Send to gnu-screen copy buffer 
-window #       :Send to stdin of gnu-screen window Number
-s  str         :Search wallet with: -d, -k, -v and/or string found in name
-t  str         :Same as Search but view your wallet in a colored tree format
" ;GPG=$(which gpg)
SCREEN=$(which screen)
XCLIP=$(which xclip)
[[ -z $GNUPGHOME ]] && export GNUPGHOME="$HOME/.gnupg" ;WAL="$GNUPGHOME/wallet"
KEYID="$(cat "${WAL}/.KEYID")"
# - - - List, Encrypt, or Decrypt objects - - - #
main() {
    case "${cmd}" in
        find)
            findUI
        ;;
        tree)
            if [[ $(expr 4 + $(treeUI | wc -l)) -lt $(tput lines) ]] ;then
                treeUI ;else treeUI | less ;fi
        ;;
        encrypt)
            [[ ! -d ${wdir}  ]] && mkdir -p ${wdir}
            [[ "${typ}" != "keyring" ]] && \
                ${GPG} -r "${KEYID}" -o ${wdir}/${obj} -e ${val} || \
                echo -n "${val}" | ${GPG} -e -r "${KEYID}" > ${wdir}/${obj}
        ;;
        decrypt)
            if [[ "${dst}" == "stdout" ]] ;then
                ${GPG} --batch --quiet -d ${wdir}/${obj} ;exit 0 ;fi
            case "${dst}" in
                clip)
                    s=( ["1"]="primary" ["2"]="secondary" ["3"]="clipboard" )
                    ${GPG} --batch --quiet -d ${wdir}/${obj} | \
                        ${XCLIP} -selection ${s[${sel}]} -in
                ;;
                screen)
                    ${SCREEN} -S $STY \
                    -X register . $(${GPG} --batch --quiet -d ${wdir}/${obj})
                ;;
                window)
                    ${SCREEN} -S $STY -p "${num}" \
                    -X stuff $(${GPG} --batch --quiet -d ${wdir}/${obj})
            esac
    esac ; exit ${?}
}
# - - - Parse the arguments - - - #
parse_args() {
    flags='' ;for arg in ${@} ;do
        case "${flag}" in
            -s)
                cmd='find' ; str="${arg}"
            ;;
            -t)
                cmd='tree' ; str="${arg}"
            ;;
            -e)
                cmd='encrypt'
            ;;
            -stdout)
                cmd='decrypt' ; dst='stdout'
            ;;
            -clip)
                cmd='decrypt' ; dst='clip' ; sel="${arg}"
            ;;
            -screen)
                cmd='decrypt' ; dst='screen'
            ;;
            -window)
                cmd='decrypt' ; dst='window' ; num="${arg}"
            ;;
            -d)
                dom="${arg}"
            ;;
            -k)
                typ='keyring' ; obj="${arg}"
            ;;
            -v)
                val="${arg}"
            ;;
            -f)
                typ='vault' ; val="${arg}"
                obj="$(echo ${arg} |sed 's/\//\n/g' |tail -n1)"
                [[ $(echo $obj |rev |cut -d '.' -f 1) != 'gpg' ]] && obj+=".gpg"
        esac ; flag="${arg}"
    done ; wdir="${WAL}/${dom}/${typ}" ; validate
}
# - - - Check for errors - - - #
validate() {
    [[ ! -z $DBUG ]] && echo "ARGS*$ted:$srv:$wdir:$obj:$val:$dst:$num"
    [[ ! "1 2 3" =~ ${sel}  ]] && sel='1'
    if [[ ${cmd} != "tree" && ${cmd} != "find" ]] ;then
        if [[ -z ${KEYID} ]] ;then echo "Put GPG uid in: ${WAL}/.KEYID" ; exit 1
        elif [[ -z ${cmd} || -z ${dom} || -z ${typ} || -z ${obj} ]] ;then
            echo "${HELP}" ; exit 255
        elif [[ ${dst} == 'window' && -z ${num} ]] ;then
            echo "Missing Window Number" ; exit 128
        elif [[ ${cmd} == 'encrypt' && ${typ} == 'vault' && ! -f ${val} ]] ;then
            echo "File not found" ; exit 128
        elif [[ ${cmd} == "encrypt" && ${typ} == "keyring" && -z ${val} ]] ;then
            read -sp "Enter passwd: " val ;echo; read -sp "Re-enter passwd: " v
            if [[ ${val} != ${v} || -z ${val} ]] ;then
                echo 'Passwords did not match!' ; exit 128 ; fi
        fi
    else [[ "-d -k -v -p ZZZ" =~ "${str}" ]] && str='' ;fi ; main
}
# - - - tree command view - - - #
treeUI() {
    cd ${WAL} ;a="tree --noreport --prune -C"
    if [[ -z ${dom} ]] ;then
        if [[ -z ${str} ]] ;then
            [[ -z ${typ} ]] && $a || $a ./*/${typ}
        else
            [[ -z ${typ} ]] && $a -P "*${str}*" || $a -P "*${str}*" ./*/${typ}
        fi
    else
        [[ -z ${str} ]] && $a ${dom}/${typ} || $a -P "*${str}*" ${dom}/${typ}
    fi
}
# - - - find command view - - - #
findUI() {
    cd ${WAL} ;a="find -mindepth"
    if [[ -z ${dom} ]] ;then
        if [[ -z ${str} ]] ;then
            [[ -z ${typ} ]] && $a 3 || $a 3 -path "./*/${typ}/*"
        else
            [[ -z ${typ} ]] && $a 3 -name "*${str}*" || \
                $a 3 -path "./*/${typ}/*" -name "*${str}*"
        fi
    else
        cd ${dom}/${typ} ; [[ -z ${str} ]] && $a 1 || $a 1 -name "*${str}*"
    fi
}
#
# The idea is to transparently use Git to provide:
#   password recovery
#   remote backup
#   device sync
# All with an extremely common and well supported program in the standard way
# Even if PGW dies Git will still work.
# Exactly the reason I'm using GnuPG.
#
# - - - Git Commit, push, pull, merge - - - #
GIT="$(which git) -C ${WAL}"
gitSync() {
    ${GIT} pull origin master
    ${GIT} push origin master
}
# - - - Git commit - - - #
gitCommit() {
    ${GIT} commit -m "pgw ${dom}/${typ}/${obj}"
}
# - - - Git deletion - - - #
gitRm() {
    ${GIT} rm "${dom}/${typ}/${obj}" ;gitSync
}
# - - - Git undo - - - #
gitUndo() {
    local todo = true
}
# - - - Git init - - - #
gitInit() {
    # If ${WAL}/.GPWGIT file exists
    # git init
    # Ignore .KEYID
    # Perhaps allow for basic config like name/email in .GPWGIT
    #
    if [[ -f ${WAL}/.gitignore ]] ;then
        local todo = true ;fi
}
parse_args ${@} ZZZ #The ZZZ is flag+value for-loop padding
# /* vim: set ts=4 sw=4 tw=80 et :*/
