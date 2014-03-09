#!/bin/bash
#   GpgWallet       v10.2              GPLv3
#   Thomas Dwyer    <devel@tomd.tel>   http://tomd.tel/
DBUG=           # If DBUG not Null display parsed args
HELP="
Usage ${0} [-l (mail.con)] [-e] [-d (--clip|--screen|--window #|--stdout)]
                [-s example.com] [-u username (-p password)] [-f filename]
-l  mail.con    :List services in db OR List stored objects for service
-e              :Encrypt
-d              :Decrypt, [Default action] Send plaintext to stdout
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
KEY="$(cat "${WAL}/KEY")"
# - - - List, Encrypt, or Decrypt objects - - - #
main() {
    [[ ! -z $DBUG ]] && echo "ARGS*$led:$srv:$wdir:$obj:$txt:$dst:$num"
    case "${led}" in
        list)        
            [[ -z ${srv} ]] && find "${WAL}" -maxdepth 1 -mindepth 1 -type d ||\
            find "${WAL}/${srv}" -type f
        ;;
        encrypt)
            [[ ! -d ${wdir}  ]] && mkdir -p ${wdir}
            [[ "${dir}" != "passwd" ]] && \
                ${GPG} -i -r "${KEY}" -o ${wdir}/${obj} -e ${txt} || \
                echo -n "${txt}" | ${GPG} -e -r "${KEY}" > ${wdir}/${obj}
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
                    screen -S $STY -p $num -X stuff "${plaintext}"
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
                dst='window' ; num=${arg}
            ;;
            -s)
                srv="${arg}"
            ;;
            -u)
                dir='passwd' ; obj="${arg}"
            ;;
            -p)
                txt="${arg}"
            ;;
            -f)
                dir='files' ; txt="${arg}"
                obj="$(echo ${arg} |sed 's/\//\n/g' |tail -n1)"
        esac ; flag="${arg}"
    done ; wdir="${WAL}/${srv}/${dir}" ; validate
}
# - - - Check for errors - - - #
validate() {
    if [[ ${led} != "list" ]] ;then
        if [[ -z ${KEY} ]] ;then
            echo "Put your GPG uid or fingerprint in: ${WAL}/KEY" ; exit 1
        elif [[ -z ${led} || -z ${srv} || -z ${dir} || -z ${obj} ]] ;then
            echo "${HELP}" ; exit 255
        elif [[ ${dst} == 'window' && -z ${num} ]] ;then
            echo "Missing Window Number" ; exit 128
        elif [[ ${led} == 'encrypt' && ${dir} == 'files' && ! -f ${txt} ]] ;then
            echo "File not found" ; exit 128
        elif [[ ${led} == "encrypt" && ${dir} == "passwd" && -z ${txt} ]] ;then
            read -sp "Enter passwd: " txt ;echo; read -sp "Re-enter passwd: " v
            if [[ ${txt} != ${v} || -z ${txt} ]] ;then
                echo 'Passwords did not match!' ; exit 128 ; fi
        fi
    fi ; main
}
parse_args ${@} X #The X is flag+value for-loop padding
# /* vim: set ts=4 sw=4 tw=80 et :*/
