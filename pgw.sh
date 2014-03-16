#!/bin/bash
#   GpgWallet       GPLv3              v10.7
#   Thomas Dwyer    <devel@tomd.tel>   http://tomd.tel/
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
" ; [[ ${1} == "--help" || ${1} == "-h" ]] && (echo "${HELP}" ; exit 0)
GPG=$(which gpg) ;[[ ${?} -gt 0 ]] && (echo "Install gpg (GnuPG) >=2.0")
GPGen="${GPG} -a -s --cipher-algo TWOFISH --digest-algo SHA512"
GPGde="${GPG} -a --batch --quiet"
SCREEN=$(which screen 2>/dev/null) 
XCLIP=$(which xclip)
XCS=( ["1"]="primary" ["2"]="secondary" ["3"]="clipboard" )
FIND=$(which find)
TREE=$(which tree)
[[ -z $PAGER ]] && PAGER="less"
[[ $PAGER == "less" ]] && LESS="--RAW-CONTROL-CHARS"
[[ -z $GNUPGHOME ]] && GNUPGHOME="$HOME/.gnupg" ;WAL="$GNUPGHOME/wallet"
KEYID="$(cat "${WAL}/.KEYID")"
# - - - List, Encrypt, or Decrypt objects - - - #
main() {
    case "${cmd}" in
        find)
            findUI
        ;;
        tree)
            if [[ $(expr 4 + $(treeUI | wc -l)) -lt $(tput lines) ]] ;then
                treeUI
            else
                treeUI -C | $PAGER
            fi
        ;;
        encrypt)
            [[ ! -d ${wdir}  ]] && mkdir -p ${wdir}
            case "${typ}" in
                vault)
                    ${GPGen} -r "${KEYID}" -o ${wdir}/${obj} -e ${val}
                ;;
                keyring)
                    echo -n "${val}" | ${GPGen} -r "${KEYID}" -o ${wdir}/${obj} -e
            esac
            [[ -d ${WAL}/.git ]] && gitCommit
        ;;
        decrypt)
            local plaintext=$(${GPGde} -d ${wdir}/${obj})
            if [[ "${dst}" == "stdout" ]] ;then echo -n ${plaintext} ;exit 0 ;fi
            case "${dst}" in
                clip)
                    echo -n ${plaintext} | ${XCLIP} -selection ${XCS[${sel}]} -in
                ;;
                screen)
                    ${SCREEN} -S $STY -X register . "${plaintext}"
                ;;
                window)
                    ${SCREEN} -S $STY -p "${sel}" -X stuff "${plaintext}"
            esac
    esac ; exit ${?}
}
# - - - Parse the arguments - - - #
parse_args() {
    flags='' ;for arg in ${@} ;do
        case "${flag}" in
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
                [[ $(echo $obj |rev |cut -d '.' -f 1) != 'asc' ]] && obj+=".asc"
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
                cmd='decrypt' ; dst='window' ; sel="${arg}"
            ;;
            -s)
                cmd='find' ; str="${arg}"
            ;;
            -t)
                cmd='tree' ; str="${arg}"
        esac ; flag="${arg}"
    done ; wdir="${WAL}/${dom}/${typ}" ; validate
}
# - - - Check for errors - - - #
validate() {
    case ${cmd} in
        encrypt)
            if [[ -z ${dom} || -z ${typ} || -z ${obj} ]] ;then
                echo "${HELP}" ; exit 201
            fi
            case ${typ} in
                keyring)
                    if [[ -z ${val} ]] ;then
                        read -sp "Enter passwd: " val
                        echo; read -sp "Re-enter passwd: " v
                        if [[ ${val} != ${v} || -z ${val} ]] ;then
                            echo 'Passwords did not match!' ;exit 203
                        fi
                    fi
                ;;
                vault)
                    if [[ -z ${val} ]] ;then echo ${HELP} ;exit 202 ;fi
            esac
        ;;       
        decrypt)
            if [[ ! "stdout clip screen window" =~ ${dst} ]] ;then
                echo "${HELP}" ; exit 101
            fi
            case ${dst} in
                clip)
                    [[ -z ${XCS[${sel}]} ]] && sel=1
                ;;
                window)
                    $(expr ${sel} + 1 1>/dev/null 2>&1)
                    if [[ ! ${?} -eq 0 ]] ;then
                        echo "Destination Window number: ${sel} :is invalid"
                        echo "${HELP}" ; exit 102
                    fi
                ;;
                screen)
                    [[ -z $STY ]] && echo ' - No $STY -'
            esac
            [[ -z ${dom} || -z ${typ} || -z ${obj} ]] && selectList
        ;;
        tree)
            [[ "-d -k -v -f ZZZ" =~ "${str}" ]] && str=''
        ;;
        *)
            echo "${HELP}" ; exit 255
    esac ; main
}
# - - - tree command view - - - #
treeUI() {
    cd ${WAL} ;a="--noreport --prune" ;s="*${str}*"
    for p in ${@} ;do a+=" ${p}" ;done
    [[ ${typ} == "vault" ]] && s+=".asc"
    [[ ${typ} == "keyring" ]] && a+=" -I *.asc"
    a+=" -P "
    ${TREE} ${a} "${s}" ${dom}
}
# - - - Gen index - - - #
genIndex() {
    index=$(find $(ls --color=never) -type f)
    [[ ! -z ${dom} ]] && index=$(echo $index |sed 's/ /\n/g' |grep -E "${dom}//*")
}
# - - - Select from list - - - #
selectList() {
    cd ${WAL} ;genIndex
    genList
    read -p "$(echo -ne ${WHT}) Enter choice #$(echo -ne ${clr}) " choice 
    dom=$(echo ${index} |cut -d ' ' -f ${choice} |cut -d '/' -f 1)
    typ=$(echo ${index} |cut -d ' ' -f ${choice} |cut -d '/' -f 2)
    obj=$(echo -n ${index} |cut -d ' ' -f ${choice} |cut -d '/' -f 3)
    wdir="${WAL}/${dom}/${typ}" ;main 
}
# - - - Gen select list - - - #
genList() {
    evalColors
    cd ${WAL} ;start_color=2 ;LN=1
    for line in $(echo $index) ;do
        # Set color
        if [[ -z ${t} ]] ;then
            t='togle'
            local c1=$(tput bold;tput setaf ${start_color})
            local c2=$(tput bold;tput setaf $(expr $start_color + 1))
            local c3=$(tput bold;tput setaf $(expr $start_color + 2))
            local d1=$(tput bold;tput setaf 0)
            local d2=$(tput bold;tput setaf 0)
            local d3=$(tput bold;tput setaf 0)
        else
            t=''
            local c1=$(tput setaf ${start_color})
            local c2=$(tput setaf $(expr $start_color + 1))
            local c3=$(tput setaf $(expr $start_color + 2))
            local d1=$(tput setaf ${start_color})
            local d2=$(tput setaf $(expr $start_color + 1))
            local d3=$(tput setaf $(expr $start_color + 2))
        fi
        # align columns
        dom="$(echo ${line} |cut -d '/' -f 1)"
        typ="$(echo ${line} |cut -d '/' -f 2)"
        obj="$(echo ${line} |cut -d '/' -f 3)"
        ln="" ;n=$(expr 4 - $(echo -n ${LN} |wc -c))
        while [[ $n -gt 0 ]] ;do n=$(expr $n - 1) ;ln+=" " ;done ;ln+="${LN}"
        n=$(expr 26 - $(echo -n ${dom} |wc -c))
        while [[ $n -gt 0 ]] ;do n=$(expr $n - 1) ;dom+=" " ;done
        n=$(expr 10 - $(echo -n ${typ} |wc -c))
        while [[ $n -gt 0 ]] ;do n=$(expr $n - 1) ;typ+=" " ;done
        echo -ne "${c3}${ln}${nrm}${d1} - ${clr}" ;LN=$(expr $LN + 1)
        echo -ne "${c1}${dom}${clr}"
        echo -ne "${d2}- ${nrm}${c2}${typ}${clr}"
        echo -e "${d3}- ${nrm}${c3}${obj}${clr}"
    done ;
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
    ${GIT} add *
    ${GIT} commit -m "pgw ${dom}/${typ}/${obj}"
    gitSync
}
# - - - Git deletion - - - #
gitRm() {
    ${GIT} rm "${dom}/${typ}/${obj}" ;gitCommit
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
# - - - Color me encrypted - - - #
evalColors() {
    BlD=$(tput blink;tput bold;tput setaf 0)
    RrD=$(tput blink;tput bold;tput setaf 1)
    GrN=$(tput blink;tput bold;tput setaf 2)
    YeL=$(tput blink;tput bold;tput setaf 3)
    BlU=$(tput blink;tput bold;tput setaf 4)
    MaG=$(tput blink;tput bold;tput setaf 5)
    CyN=$(tput blink;tput bold;tput setaf 6)
    WhT=$(tput blink;tput bold;tput setaf 7)
    bLk=$(tput blink;tput setaf 0)
    rEd=$(tput blink;tput setaf 1)
    gRn=$(tput blink;tput setaf 2)
    yEl=$(tput blink;tput setaf 3)
    bLu=$(tput blink;tput setaf 4)
    mAg=$(tput blink;tput setaf 5)
    cYn=$(tput blink;tput setaf 6)
    wHt=$(tput blink;tput setaf 7)
    BLD=$(tput bold;tput setaf 0)
    RED=$(tput bold;tput setaf 1)
    GRN=$(tput bold;tput setaf 2)
    YEL=$(tput bold;tput setaf 3)
    BLU=$(tput bold;tput setaf 4)
    MAG=$(tput bold;tput setaf 5)
    CYN=$(tput bold;tput setaf 6)
    WHT=$(tput bold;tput setaf 7)
    blk=$(tput setaf 0)
    red=$(tput setaf 1)
    grn=$(tput setaf 2)
    yel=$(tput setaf 3)
    blu=$(tput setaf 4)
    mag=$(tput setaf 5)
    cyn=$(tput setaf 6)
    wht=$(tput setaf 7)
    nrm=$(tput sgr0)
    clr='\033[m' #GNU less command likes this better then echo -ne $(tput sgr0)
    Nl="s/^/$(tput setaf 7)/g" # sed -e ${Nl} -e ${nL} Will color 'nl' number lists
    nL="s/\t/$(echo -ne '\033[m')\t/g"
}
#
# - - - RUN - - - #
parse_args ${@} ZZZ #The ZZZ is flag+value for-loop padding
exit 1
# vim: set ts=4 sw=4 tw=80 et
