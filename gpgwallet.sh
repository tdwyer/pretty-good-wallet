#!/bin/bash
#
# GpgWallet v10.0
# Thomas Dwyer <devel@tomd.tel> : http://tomd.tel
# GPLv3
#
HELP="Usage ${0} [-l (example.com)] [-e] [-d (--clip|-screen|--window Num|--stdout)]
               [-s example.com] [-u username (-p password)] [-f filename]
-l example.com :List services in db OR List stored objects for service
-e             :Encrypt
-d             :Decrypt
    --clip     :Send to X11 clipboard
    --screen   :Send to gnu-screen copy buffer 
    --window # :Send to stdin of gnu-screen window Number
    --stdout   :[Default] Send to stdout Redirect decrypted file to >plain.txt
-s example.com :Service, a service name must be given when (de|en)crypting
-u username    :Username, of service/user pair to which the password is for
    -p passwd  :Password to encrypt, Prompted for if not provided
-f file        :File to encrypt/decrypt"
WAL="$HOME/.gnupg/wallet"
KEY="$(cat "${WAL}/KEY")"
GPG=$(which gpg)
SCREEN=$(which screen)
XCLIP=$(which xclip)
# - - - Main program: List, Encrypt, or Decrypt objects - - - #
main() {
    action=$1 ;srv=$2 ;dir=$3 ;w_dir=$4 ;w_file=$5 ;bits=$6 ;sendto=$6 ;w_num=$7
    case "${action}" in
        list)        
            [[ -z ${srv} ]] && find "${WAL}" -maxdepth 1 -mindepth 1 -type d ||\
            find "${WAL}/${srv}" -type f
        ;;
        encrypt)
            [[ ! -d ${w_dir}  ]] && mkdir -p ${w_dir}
            [[ "${dir}" != "passwd" ]] && \
                ${GPG} -i -r "${KEY}" -o ${w_file} -e ${bits} || \
                echo -n "${bits}" | ${GPG} -e -r "${KEY}" > ${w_file}
        ;;
        decrypt)
            plaintext="$(gpg --use-agent --batch --quiet -d ${w_file})"
            case "${sendto}" in
                --clip)
                    echo -n "${plaintext}" | ${XCLIP} -selection clipboard -in
                    exit ${?}
                ;;
                --screen)
                    ${SCREEN} -S $STY -X register . "${plaintext}"
                    exit ${?}
                ;;
                --window)
                    screen -S $STY -p $w_num -X stuff "${plaintext}"
                    exit ${?}
            esac ; echo -n "${plaintext}"
    esac
    exit ${?}
}
# - - - Parse the arguments, set variable values, and check for errors - - - #
parse_args() {
    flag=''
    for value in ${@} ;do
        case "${flag}" in
            -l)
                action='list' ; [[ ${value} != "Padding" ]] && srv="${value}"
            ;;
            -e)
                action='encrypt'
            ;;
            -d)
                action='decrypt' ; sendto="${value}"
            ;;
            --window)
                w_num=${value}
                if [[ -z ${w_num} ]] ;then echo "Missing Window #" ; exit 1 ;fi
            ;;
            -s)
                srv="${value}"
            ;;
            -u)
                dir='passwd' ; obj="${value}"
            ;;
            -p)
                bits="${value}"
            ;;
            -f)
                dir='files' ; obj="${value}" ; bits=${obj}
        esac ; flag="${value}"
    done
    # - - - Check for missing values and other errors - - - #
    if [[ ${1} != "-l" ]] ;then
        w_dir="${WAL}/${srv}/${dir}" ; w_file="${w_dir}/${obj}"
        if [[ -z ${srv} || -z ${dir} || -z ${obj} || -z ${action} ]] ;then
            echo "${HELP}" ; exit 1
        elif [[ ${1} == "-e" && ${dir} == "passwd" && -z ${bits} ]] ;then
            read -sp "Enter passwd: " bits ;echo; read -sp "Reenter passwd: " vp
            if [[ ${bits} != ${vp} || -z ${bits} ]] ;then
                echo 'Passwords did not match!' ; exit 128
            fi
        elif [[ ${1} == '-e' && ${dir} == 'files' && ! -f ${bits} ]] ;then
            echo "File not found" ; exit 128
        elif [[ -z ${KEY} ]] ;then
            echo "Put your GPG uid or fingerprint in: ${WAL}/KEY" ; exit 1
        fi
    fi
    main ${action} ${srv} ${dir} ${w_dir} ${w_file} ${bits} ${sendto} ${w_num}
}
parse_args ${@} Padding
# /* vim: set ts=4 sw=4 tw=80 et :*/
