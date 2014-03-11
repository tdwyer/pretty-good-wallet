#!/bin/bash
#   GpgWallet       GPLv3              v10.4.2
#   Thomas Dwyer    <devel@tomd.tel>   http://tomd.tel/
DBUG=           # If DBUG not Null display parsed args
HELP="
Usage ${0} [-l (search-term)] [-e] [-d] [-clip] [-screen] [-window #]
                [-s example.com] [-u username (-p password)] [-f filename]
-l  term        :Locate objects, Refine search with: -s, -u, -f, and/or term
-e              :Encrypt
-d              :Send to plaintext to stdout
-clip   #       :Send to selection 3=Clipboard 2=Secondary 1=Primary: DEFAULT  1
-screen         :Send to gnu-screen copy buffer 
-window #       :Send to stdin of gnu-screen window Number
-s  mail.con    :Service, a service name must be given when (de|en)crypting
-u  username    :Username, of service/user pair to which the password is for
    -p pwd      :Password to encrypt, Prompted for if not provided
-f  file        :File to encrypt/decrypt
" ;GPG=$(which gpg)
SCREEN=$(which screen)
XCLIP=$(which xclip)
[[ -z $GNUPGHOME ]] && export GNUPGHOME="$HOME/.gnupg" ;WAL="$GNUPGHOME/wallet"
KEYID="$(cat "${WAL}/.KEYID")"
# - - - List, Encrypt, or Decrypt objects - - - #
main() {
    case "${led}" in
        tree)
            $(which tree >/dev/null 2>&1) ;[[ $? -gt 0 ]] && \
            findUI | less || treeUI | less
        ;;
        encrypt)
            [[ ! -d ${wdir}  ]] && mkdir -p ${wdir}
            [[ "${dir}" != "passwd" ]] && \
                ${GPG} -r "${KEYID}" -o ${wdir}/${obj} -e ${_in} || \
                echo -n "${_in}" | ${GPG} -e -r "${KEYID}" > ${wdir}/${obj}
        ;;
        decrypt)
            plaintext="$(${GPG} --batch --quiet -d ${wdir}/${obj})"
            case "${dst}" in
                clipboard)
                    s=( ["1"]="primary" ["2"]="secondary" ["3"]="clipboard" )
                    echo -n "${plaintext}" | ${XCLIP} -selection ${s[$cto]} -in
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
            -l)
                led='tree' ; trm="${arg}"
            ;;
            -e)
                led='encrypt'
            ;;
            -d)
                led='decrypt' ; dst='stdout'
            ;;
            -clip)
                led='decrypt' ; dst='clipboard' ; cto="${arg}"
            ;;
            -screen)
                led='decrypt' ; dst='screen'
            ;;
            -window)
                led='decrypt' ; dst='window' ; num="${arg}"
            ;;
            -s)
                srv="${arg}"
            ;;
            -u)
                dir='passwd' ; obj="${arg}"
            ;;
            -p)
                _in="${arg}"
            ;;
            -f)
                dir='files' ; _in="${arg}"
                obj="$(echo ${arg} |sed 's/\//\n/g' |tail -n1)"
                [[ $(echo $obj |rev |cut -d '.' -f 1) != 'gpg' ]] && obj+=".gpg"
        esac ; flag="${arg}"
    done ; wdir="${WAL}/${srv}/${dir}" ; validate
}
# - - - Check for errors - - - #
validate() {
    [[ ! -z $DBUG ]] && echo "ARGS*$ted:$srv:$wdir:$obj:$_in:$dst:$num"
    [[ ! "1 2 3" =~ ${cto}  ]] && cto='1'
    if [[ ${led} != "tree" ]] ;then
        if [[ -z ${KEYID} ]] ;then echo "Put GPG uid in: ${WAL}/.KEYID" ; exit 1
        elif [[ -z ${led} || -z ${srv} || -z ${dir} || -z ${obj} ]] ;then
            echo "${HELP}" ; exit 255
        elif [[ ${dst} == 'window' && -z ${num} ]] ;then
            echo "Missing Window Number" ; exit 128
        elif [[ ${led} == 'encrypt' && ${dir} == 'files' && ! -f ${_in} ]] ;then
            echo "File not found" ; exit 128
        elif [[ ${led} == "encrypt" && ${dir} == "passwd" && -z ${_in} ]] ;then
            read -sp "Enter passwd: " _in ;echo; read -sp "Re-enter passwd: " v
            if [[ ${_in} != ${v} || -z ${_in} ]] ;then
                echo 'Passwords did not match!' ; exit 128 ; fi
        fi
    else [[ "-s -u -f ZZZ" =~ "${trm}" ]] && trm='' ;fi ; main
}
# - - - tree command view - - - #
treeUI() {
    cd ${WAL} ;a="tree --noreport --prune -C"
    if [[ -z ${srv} ]] ;then
        if [[ -z ${trm} ]] ;then
            [[ -z ${dir} ]] && $a || $a ./*/${dir}
        else
            [[ -z ${dir} ]] && $a -P "*${trm}*" || $a -P "*${trm}*" ./*/${dir}
        fi
    else
        [[ -z ${trm} ]] && $a ${srv}/${dir} || $a -P "*${trm}*" ${srv}/${dir}
    fi
}
# - - - find command view - - - #
findUI() {
    cd ${WAL} ;a="find -mindepth"
    if [[ -z ${srv} ]] ;then
        if [[ -z ${trm} ]] ;then
            [[ -z ${dir} ]] && $a 2 || $a 2 -path "./*/${dir}/*"
        else
            [[ -z ${dir} ]] && $a 2 -name "*${trm}*" || \
                $a 2 -path "./*/${dir}/*" -name "*${trim}*"
        fi
    else
        cd ${srv}/${dir} ; [[ -z ${trm} ]] && $a 1 || $a 1 -name "*${trm}*"
    fi
}
parse_args ${@} ZZZ #The ZZZ is flag+value for-loop padding
# /* vim: set ts=4 sw=4 tw=80 et :*/
