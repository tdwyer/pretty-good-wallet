#!/bin/bash
#
# GpgWallet v10.0
# Thomas Dwyer <devel@tomd.tel> : http://tomd.tel
# GPLv3
#
HELP="Usage ${0} {-l|-d|-e} {-s|-u|-p|-f}
-l example.com :List of services in db Or list of service's objects
-e :Encrypt
    -u :Username
        -p :Password, Will be asked for if none provided and username specified
    -f :File
-d :Decrypt
    --clip     :Send to X11 clipboard
    --screen   :Send to gnu-screen copy buffer 
    --window # :Send to stdin of gnu-screen window #
    --stdout   :[Default] Send to stdout Redirect decrypted file to >plain.txt"
wal="$HOME/.gnupg/gpgwallet"
srv=''
dir=''
obj=''
data=''
verify=''
sendto=''
uid="$(cat ${wal}/uid)"
GPG=$(which gpg)
SCREEN=$(which screen)
XCLIP=$(which xclip)
#
main() {
    case "${1}" in
        -l)        
            [[ -z ${srv} ]] && find "${wal}" -maxdepth 1 -mindepth 1 -type d ||\
            find "${wal}/${srv}" -type f
        ;;
        -d)
            out="$(gpg --use-agent --batch --quiet -d ${ciphertext})"
            case "${sendto}" in
                --clip)
                    echo -n "${out}" | ${XCLIP} -selection clipboard -in
                    exit ${?}
                ;;
                --screen)
                    ${SCREEN} -S $STY -X register . ${out}
                    exit ${?}
                ;;
                --window)
                    screen -S $STY -p $window -X stuff "${out}"
                    exit ${?}
            esac ; echo -n "${out}"
        ;;
        -e)
            [[ ! -d ${destdir}  ]] && mkdir -p ${destdir}
            [[ "${dir}" != "passwd" ]] && \
                ${GPG} -i -r "${uid}" -o ${ciphertext} -e ${data} || \
                echo -n "${data}" | ${GPG} -e -r "${uid}" > ${ciphertext}
        ;;
        *)
            echo "${HELP}"
    esac
    exit ${?}
}
#
parse_args() {
    flag=''
    for value in ${@} ;do
        case "${flag}" in
            -l)
                [[ ${value} != "Padding" ]] && srv="${value}"
            ;;
            -d)
                sendto="${value}"
            ;;
            --window)
                window=${value}
                if [[ -z ${window} ]] ;then echo "Missing Window #" ; exit 1 ;fi
            ;;
            -s)
                srv="${value}"
            ;;
            -u)
                dir='passwd' ; obj="${value}"
            ;;
            -p)
                data="${value}"
            ;;
            -f)
                dir='files' ; obj="${value}" ; data=${obj}
        esac ; flag="${value}"
    done
    if [[ ${1} != "-l" ]] ;then
        destdir="${wal}/${srv}/${dir}" ; ciphertext="${destdir}/${obj}"
        if [[ -z ${srv} || -z ${dir} || -z ${obj} ]] ;then
            echo "${HELP}" ; exit 1
        elif [[ ${1} == "-e" && ${dir} == "passwd" && -z ${data} ]] ;then
            read -sp "Enter passwd: " data ;echo; read -sp "Reenter passwd: " vp
            #
            if [[ ${data} != ${vp} || -z ${data} ]] ;then
                echo 'Passwords did not match!' ; exit 128
            fi
        elif [[ ${1} == '-e' && ${dir} == 'files' && ! -f ${data} ]] ;then
            echo "File not found" ; exit 128
        elif [[ -z ${uid} ]] ;then
            echo "Put your GPG uid or fingerprint in: ${wal}/uid" ; exit 1
        fi
    fi
}
parse_args ${@} Padding
main ${@}
/* vim: set ts=4 sw=4 tw=80 et :*/
