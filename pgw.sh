#!/bin/bash
#   GpgWallet       v10.2              GPLv3
#   Thomas Dwyer    <devel@tomd.tel>   http://tomd.tel/
DBUG=           # If DBUG not Null display parsed args
HELP="
Usage ${0} [-l (mail.con)] [-e] [-d (--clip|--screen|--window #)]
                [-s example.com] [-u username (-p password)] [-f filename]
-l  mail.con    :List services in db OR List stored objects for service
-e              :Encrypt
-d              :Decrypt: [Default] Send plaintext to stdout
    --clip      :Send to X11 clipboard
    --screen    :Send to gnu-screen copy buffer 
    --window #  :Send to stdin of gnu-screen window Number
-s  mail.con    :Service, a service name must be given when (de|en)crypting
-u  username    :Username, of service/user pair to which the password is for
    --pass pwd  :Password to encrypt, Prompted for if not provided
-f  file        :File to encrypt/decrypt
" ;GPG=$(which gpg)
SCREEN=$(which screen)
XCLIP=$(which xclip)
WAL="$HOME/.gnupg/wallet"
KEYID="$(cat "${WAL}/KEYID")"
# - - - List, Encrypt, or Decrypt objects - - - #
main() {
    [[ ! -z $DBUG ]] && echo "ARGS*$led:$srv:$wdir:$obj:$_in:$dst:$num"
    case "${led}" in
        list)        
            [[ -z ${srv} ]] && find "${WAL}" -mindepth 1 -maxdepth 1 -type d ||\
            find "${WAL}/${srv}" -type f
        ;;
        encrypt)
            [[ ! -d ${wdir}  ]] && mkdir -p ${wdir}
            [[ "${dir}" != "passwd" ]] && \
                ${GPG} -i -r "${KEYID}" -o ${wdir}/${obj} -e ${_in} || \
                echo -n "${_in}" | ${GPG} -e -r "${KEYID}" > ${wdir}/${obj}
        ;;
        decrypt)
            plaintext="$(${GPG} --use-agent --batch --quiet -d ${wdir}/${obj})"
            case "${dst}" in
                clipboard)
                    echo -n "${plaintext}" | ${XCLIP} -selection clipboard -in
                ;;
                screen)
                    ${SCREEN} -S $STY -X register . "${plaintext}"
                ;;
                window)
                    ${SCREEN} -S $STY -p "${num}" -X stuff "${plaintext}"
                ;;
                *)
                    echo -n "${plaintext}"
            esac
    esac ; exit ${?}
}
# - - - Parse the arguments - - - #
parse_args() {
    flags='' ;for arg in ${@} ;do
        case "${flag}" in
            -l)
                led='list' ; [[ -z ${srv} && ${arg} != 'X' ]] && srv="${arg}"
            ;;
            -e)
                led='encrypt'
            ;;
            -d)
                led='decrypt'
            ;;
            --clip)
                dst='clipboard'
            ;;
            --screen)
                dst='screen'
            ;;
            --window)
                dst='window' ; num="${arg}"
            ;;
            -s)
                srv="${arg}"
            ;;
            -u)
                dir='passwd' ; obj="${arg}"
            ;;
            -p)
                _in="${arg}" # _in :is to be encrypted
            ;;
            -f)
                dir='files' ; _in="${arg}" # _in :is to be encrypted
                obj="$(echo ${arg} |sed 's/\//\n/g' |tail -n1)"
        esac ; flag="${arg}"
    done ; wdir="${WAL}/${srv}/${dir}" ; validate
}
# - - - Check for errors - - - #
validate() {
    if [[ ${led} != "list" ]] ;then
        if [[ -z ${KEYID} ]] ;then echo "Put GPG uid in: ${WAL}/KEYID" ; exit 1
        elif [[ -z ${led} || -z ${srv} || -z ${dir} || -z ${obj} ]] ;then
            echo "${HELP}" ; exit 255
        elif [[ ${dst} == 'window' && -z ${num} ]] ;then
            echo "Missing Window Number" ; exit 128
        elif [[ ${led} == 'encrypt' && ${dir} == 'files' && ! -f ${_in} ]] ;then
            echo "File not found" ; exit 128
            #
        elif [[ ${led} == "encrypt" && ${dir} == "passwd" && -z ${_in} ]] ;then
            read -sp "Enter passwd: " _in ;echo; read -sp "Re-enter passwd: " v
            if [[ ${_in} != ${v} || -z ${_in} ]] ;then
                echo 'Passwords did not match!' ; exit 128 ; fi
        fi
    fi ; main
}
parse_args ${@} X #The X is flag+value for-loop padding
# /* vim: set ts=4 sw=4 tw=80 et :*/
