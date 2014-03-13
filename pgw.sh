#!/bin/bash
#   GpgWallet       GPLv3              v10.4.3
#   Thomas Dwyer    <devel@tomd.tel>   http://tomd.tel/
DBUG=           # If DBUG not Null display parsed args
HELP="
Usage ${0} [-l (search-term)] [-e] [-d] [-clip] [-screen] [-window #]
                [-s example.com] [-k username (-p password)] [-v filename]
-f  str         :Find, search wallet with: -d, -k, -v and/or string in name
-t  str         :Same as -f except with tree command
-e              :Encrypt
-stdout         :Send to plaintext to stdout
-clip   #       :Send to selection 3=Clipboard 2=Secondary 1=Primary: DEFAULT  1
-screen         :Send to gnu-screen copy buffer 
-window #       :Send to stdin of gnu-screen window Number
-d  domainname  :Domain, Each domain contains a Keyring and a Vault
-k  username    :Keyring, User/Password password is prompted for
    -p pwd      :Password, Provide password instead of being prompted
-v  filename    :Vault, Security and easily store related files
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
            treeUI | less
        ;;
        encrypt)
            [[ ! -d ${wdir}  ]] && mkdir -p ${wdir}
            [[ "${dir}" != "keyring" ]] && \
                ${GPG} -r "${KEYID}" -o ${wdir}/${obj} -e ${_in} || \
                echo -n "${_in}" | ${GPG} -e -r "${KEYID}" > ${wdir}/${obj}
        ;;
        decrypt)
            plaintext="$(${GPG} --batch --quiet -d ${wdir}/${obj})"
            case "${dst}" in
                clip)
                    s=( ["1"]="primary" ["2"]="secondary" ["3"]="clipboard" )
                    echo -n "${plaintext}" | ${XCLIP} -selection ${s[${sl}]} -in
                ;;
                screen)
                    ${SCREEN} -S $STY -X register . "${plaintext}"
                ;;
                window)
                    ${SCREEN} -S $STY -p "${num}" -X stuff "${plaintext}"
                ;;
                stdout)
                    echo -n "${plaintext}"
            esac
    esac ; exit ${?}
}
# - - - Parse the arguments - - - #
parse_args() {
    flags='' ;for arg in ${@} ;do
        case "${flag}" in
            -f)
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
                cmd='decrypt' ; dst='clip' ; sl="${arg}"
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
                dir='keyring' ; obj="${arg}"
            ;;
            -p)
                _in="${arg}"
            ;;
            -v)
                dir='vault' ; _in="${arg}"
                obj="$(echo ${arg} |sed 's/\//\n/g' |tail -n1)"
                [[ $(echo $obj |rev |cut -d '.' -f 1) != 'gpg' ]] && obj+=".gpg"
        esac ; flag="${arg}"
    done ; wdir="${WAL}/${dom}/${dir}" ; validate
}
# - - - Check for errors - - - #
validate() {
    [[ ! -z $DBUG ]] && echo "ARGS*$ted:$srv:$wdir:$obj:$_in:$dst:$num"
    [[ ! "1 2 3" =~ ${sl}  ]] && sl='1'
    if [[ ${cmd} != "tree" && ${cmd} != "find" ]] ;then
        if [[ -z ${KEYID} ]] ;then echo "Put GPG uid in: ${WAL}/.KEYID" ; exit 1
        elif [[ -z ${cmd} || -z ${dom} || -z ${dir} || -z ${obj} ]] ;then
            echo "${HELP}" ; exit 255
        elif [[ ${dst} == 'window' && -z ${num} ]] ;then
            echo "Missing Window Number" ; exit 128
        elif [[ ${cmd} == 'encrypt' && ${dir} == 'vault' && ! -f ${_in} ]] ;then
            echo "File not found" ; exit 128
        elif [[ ${cmd} == "encrypt" && ${dir} == "keyring" && -z ${_in} ]] ;then
            read -sp "Enter passwd: " _in ;echo; read -sp "Re-enter passwd: " v
            if [[ ${_in} != ${v} || -z ${_in} ]] ;then
                echo 'Passwords did not match!' ; exit 128 ; fi
        fi
    else [[ "-d -k -p -v ZZZ" =~ "${str}" ]] && str='' ;fi ; main
}
# - - - tree command view - - - #
treeUI() {
    cd ${WAL} ;a="tree --noreport --prune -C"
    if [[ -z ${dom} ]] ;then
        if [[ -z ${str} ]] ;then
            [[ -z ${dir} ]] && $a || $a ./*/${dir}
        else
            [[ -z ${dir} ]] && $a -P "*${str}*" || $a -P "*${str}*" ./*/${dir}
        fi
    else
        [[ -z ${str} ]] && $a ${dom}/${dir} || $a -P "*${str}*" ${dom}/${dir}
    fi
}
# - - - find command view - - - #
findUI() {
    cd ${WAL} ;a="find -mindepth"
    if [[ -z ${dom} ]] ;then
        if [[ -z ${str} ]] ;then
            [[ -z ${dir} ]] && $a 3 || $a 3 -path "./*/${dir}/*"
        else
            [[ -z ${dir} ]] && $a 3 -name "*${str}*" || \
                $a 3 -path "./*/${dir}/*" -name "*${str}*"
        fi
    else
        cd ${dom}/${dir} ; [[ -z ${str} ]] && $a 1 || $a 1 -name "*${str}*"
    fi
}
parse_args ${@} ZZZ #The ZZZ is flag+value for-loop padding
# /* vim: set ts=4 sw=4 tw=80 et :*/
