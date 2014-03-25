#!/bin/bash
#
#   GpgWallet       GPLv3              v10.8.1
#   Thomas Dwyer    <devel@tomd.tel>   http://tomd.tel/
#
set_wallet() {
    #
    # Use multiple wallets by creating a symbolic link like so
    # ln -s /usr/bin/pgw pgw:work # Active Wallet would be $GNUPGHOME/work
    # ln -s /usr/bin/pgw pgw:private # Active Wallet would be $GNUPGHOME/private
    # Default: $GNUPGHOME/wallet
    #
    local c="$(echo "${1}" | rev | cut -d '/' -f 1 | rev | cut -d ':' -f 1)"
    local w="$(echo "${1}" | rev | cut -d '/' -f 1 | rev | cut -d ':' -f 2)"
    if [[ "${c}" == "${w}" ]] ;then WALLET="wallet" ;else WALLET="${w}" ;fi
} set_wallet ${0}
[[ ! -d ${GNUPGHOME} ]] && GNUPGHOME="${HOME}/.gnupg"
WAL="${GNUPGHOME}/${WALLET}"
#
CONFIG="${WAL}/.config"
. $CONFIG 2>/dev/null
#
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
-t  str         :Search wallet with: -d, -k, -v and/or string found in name
-update         :Pull latest wallet from git server
-accnt  name    :Account pair (user:name pass:name)
-chrono commit  :View a past verion of an object, list select or commit
-revert commit  :Revert an object to an earlier state, list select or commit
"
#
[[ -z ${KEYID} ]] && KEYID="$(cat "${WAL}/.KEYID")"
[[ -z ${CIPHER} ]] && CIPHER="TWOFISH"
[[ -z ${DIGEST} ]] && DIGEST="SHA512"
[[ -z ${PAGER} ]] && \
PAGER=$(which less 2>/dev/null) ;[[ ! -x ${PAGER} ]] && PAGER=""
XDO=$(which xdotool 2>/dev/null) ;[[ ! -x ${XDO} ]] && XDO=""
XCLIP_EXE=$(which xclip 2>/dev/null) ;[[ ! -x ${XCLIP_EXE} ]] && XCLIP_EXE=""
SCREEN=$(which screen 2>/dev/null) ;[[ ! -x ${SCREEN} ]] && SCREEN=""
TREE=$(which tree 2>/dev/null) ;[[ ! -x ${TREE} ]] && TREE=""
XCRYPTB=$(which cryptboard 2>/dev/null) ;[[ ! -x ${XCRYPTB} ]] && XCRYPTB=""
PINENTRY_X=$(which pish 2>/dev/null) ;[[ ! -x ${PINENTRY_X} ]] && PINENTRY_X=""
GIT_EXE=$(which git 2>/dev/null) ;[[ ! -x ${GIT_EXE} ]] && GIT_EXE=""
GPG=$(which gpg 2>/dev/null) ;[[ ! -x ${GPG} ]] && GPG=""
#
[[ ${PAGER} == "less" ]] && LESS="--RAW-CONTROL-CHARS"
GIT="${GIT_EXE} -C ${WAL}"
XCLIP="${XCLIP_EXE} -selection"
XCS=( ["1"]="primary" ["2"]="secondary" ["3"]="clipboard" )
#
SALT=$(${GPG} --armor --quiet --batch --yes --gen-random 1 24)
GPGhash="${GPG} --armor --quiet --batch --yes --print-md ${DIGEST}"
GPGde="${GPG} --armor --quiet --batch --yes"
GPGen="${GPG} --armor --quiet --batch --yes --sign"
GPGen+=" --cipher-algo ${CIPHER}"
GPGen+=" --digest-algo ${DIGEST}"
if [[ -z ${KEYID} ]]
    then GPGen+=" --default-recipient-self"
else
    for uid in $(echo -n ${KEYID} |sed 's/ /\n/g') ;do
        GPGen+=" --recipient ${uid}"
    done
fi
#
# - - - Main - - - #
main() {
    parse_args ${@} ZZZ #pad for-args with ZZZ
    case "${meta}" in
        accnt)
            local accnt_name="${obj}"
            if [[ ${cmd} == "encrypt" && ! -z ${val} ]]
                then local items="pass user"
                else local items="user pass"
            fi
            for item in ${items} ;do
                echo
                typ='keyring'
                obj="${item}:${accnt_name}"
                validate
                run_cmd
                val=''
            done
        ;;
        chrono)
            validate
            if [[ -z ${treeish} ]] ;then
                chronoSelect
                gitChronoVision
            else
                gitChronoVision
            fi
        ;;
        *)
            validate
            run_cmd
    esac
}
# - - - Parse the arguments - - - #
parse_args() {
    flags='' ;for arg in ${@} ;do
        case "${flag}" in
            -h|--help)
                cmd="help"
            ;;
            -d)
                dom="${arg}"
            ;;
            -accnt)
                meta="accnt" ; obj="${arg}"
            ;;
            -k)
                typ='keyring' ; obj="${arg}"
            ;;
            -v)
                val="${arg}"
            ;;
            -f)
                typ='vault' ; val="$(readlink -f ${arg})"
                obj="$(echo ${arg} |sed 's/\//\n/g' |tail -n1)"
                [[ $(echo $obj |rev |cut -d '.' -f 1) != 'asc' ]] && obj+=".asc"
            ;;
            -e)
                cmd='encrypt'
            ;;
            -stdout)
                cmd='decrypt' ; dst='stdout' ; sel="${arg}"
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
            -t)
                cmd='tree' ; str="${arg}"
            ;;
             -update)
                cmd="update"
            ;;
            -chrono)
                meta="chrono" ; treeish="${args}"
            ;;
            -revert)
                cmd="revert" ; treeish="${args}"
        esac ; flag="${arg}"
    done
}
# - - - Check for errors - - - #
validate() {
    local uniques="-h --help -e -stdout -clip -screen -window -t -update"
    local opts=" ZZZ -chrono -revert -d -k -v -f ${uniques}"
    local uniqueN=0 ;local otypeN=0 # I know there is a joke here somewhere...One ring?
    for item in ${@} ;do
        for unique in uniques ;do
            [[ "${unique}" == "${item}" ]] && uniqueN=$(expr ${x} + 1)
        done
        for otype in "-k -f" ;do
            [[ "${otype}" == "${item}" ]] && otypeN=$(expr ${y} + 1)
        done
        if [[ ${uniqueN} -gt 1 ]] ;then
            echo "Can only give one command which encrypts or decrypts"
            exit 200
        elif [[ ${otypeN} -gt 1 ]] ;then
            echo "Can not give -f and -k at the same time"
            exit 200
        fi
    done
    for o in ${opts} ;do
        [[ "${o}" == "${dom}" ]] && dom=''
        [[ "${o}" == "${obj}" ]] && obj=''
        [[ "${o}" == "${val}" ]] && val=''
        [[ "${o}" == "${sel}" ]] && sel=''
        [[ "${o}" == "${str}" ]] && str=''
        [[ "${o}" == "${treeish}" ]] && treeish=''
    done
    case ${cmd} in
        help)
            local ok=true #takes no args
        ;;
        encrypt)
            local gpghead="-----BEGIN PGP MESSAGE-----"
            ISGPG=0
            if [[ -z ${dom} || -z ${typ} || -z ${obj} ]] ;then
                echo "${HELP}"
                exit 2
            elif [[ ! -z ${val} ]] ;then
                if [[ -f ${val} ]] ;then
                    if [[ "$(head -n 1 ${val})" == ${gpghead} ]]
                        then ISGPG=1
                    fi
                else
                    if [[ "$(echo "${val}" |head -n 1)" == "${gpghead}" ]]
                        then ISGPG=2
                    fi
                fi
            elif [[ -z ${val} ]] ;then
                if [[ "$(${XCLIP} ${XCS[3]} -o |head -n 1)" == ${gpghead} ]]
                    then ISGPG=3
                fi
            fi
            case ${typ} in
                keyring)
                    case ${pin_check} in
                        1)
                            echo "Key values did not match"
                            exit 221 
                        ;;
                        2)
                            echo "User Aborted . . ."
                            exit 222
                    esac
                ;;
                vault)
                    if [[ -z ${val} && ! ${ISGPG} -eq 3 ]] ;then
                        echo "${HELP}"
                        exit 223
                    fi
            esac
        ;;       
        decrypt)
            [[ -z ${dom} || -z ${typ} || -z ${obj} ]] && selectList
            if [[ ! "stdout clip screen window" =~ ${dst} ]] ;then
                echo "${HELP}"
                exit 231
            fi
            case ${dst} in
                stdout)
                    local ok=true #checking error in: for o in ${opts}
                ;;
                clip)
                    [[ -z ${XCS[${sel}]} ]] && sel=1
                ;;
                window)
                    $(expr ${sel} + 1 1>/dev/null 2>&1)
                    if [[ ! ${?} -eq 0 ]] ;then
                        echo "Destination Window number: ${sel} :is invalid"
                        echo "${HELP}"
                        exit 232
                    fi
                ;;
                screen)
                    if [[ -z $STY ]] ;then
                        echo ' - No $STY for GNU Screen found -'
                        exit 233
                    fi
            esac
        ;;
        tree)
            local ok=true #checking error in: for o in ${opts}
        ;;
        update)
            local ok=true #takes no args
        ;;
        revert)
            [[ -z ${dom} || -z ${typ} || -z ${obj} ]] && selectList
        ;;
        *)
            echo "${HELP}"
            exit 250
    esac
}
# - - - List, Encrypt, or Decrypt objects - - - #
run_cmd() {
    local wdir="${WAL}/${dom}/${typ}"
    case "${cmd}" in
        help)
            echo "${help}"
        ;;
        tree)
            if [[ $(expr 4 + $(treeUI | wc -l)) -lt $(tput lines) ]] ;then
                treeUI
            else
                treeUI -C | ${PAGER}
            fi
        ;;
        encrypt)
            [[ ! -d ${wdir}  ]] && mkdir -p ${wdir}
            cd ${wdir}
            case "${typ}" in
                vault)
                    case "${ISGPG}" in
                        0)
                            if [[ -f ${val} ]] ;then
                                ${GPGen} -o ${wdir}/${obj} -e ${val}
                            else
                                echo -n "${val}" | ${GPGen} -o ${wdir}/${obj} -e
                            fi
                        ;;
                        1)
                            cat ${val} > ${wdir}/${obj}
                        ;;
                        2)
                            echo -n "${val}" > ${wdir}/${obj}
                        ;;
                        3)
                            ${XCLIP} ${XCS[3]} -o > ${wdir}/${obj}
                    esac
                    [[ -d ${WAL}/.git ]] && gitSync
                ;;
                keyring)
                    if [[ ${ISGPG} -gt 0 ]] ;then
                        ${XCLIP} ${XCS[3]} -o > ${wdir}/${obj}
                    elif [[ ! -z ${val} ]] ;then
                        echo -n "${val}" | ${GPGen} -o ${wdir}/${obj} -e
                    else
                        local obj_typ=$(echo ${obj} |cut -d ':' -f 1)
                        if [[ "${obj_typ}" == "user" || "${obj_typ}" == "url" ]]
                            then ask_prompt
                            else pinentryKeyValue
                        fi
                    fi
            esac
            val=""
        ;;
        decrypt)
            case "${dst}" in
                stdout)
                    if [[ -z ${sel} ]] ;then
                        ${GPGde} -d ${wdir}/${obj}
                    else
                        ${GPGde} -o ${sel} -d ${wdir}/${obj}
                    fi
                ;;
                auto)
                    if [[ -z ${xwindow} ]] ;then
                        xwindow="$(${XDO} selectwindow 2>&1 |tail -n 1)"
                        ${XDO} windowraise ${xwindow}
                        ${XDO} windowfocus --sync ${windowfocus}
                    fi
                    ${XDO} type "$(${GPGde} -d ${wdir}/${obj})"
                    #
                    local accnt_type="$(echo -n ${obj} |cut -d ':' -f 1)"
                    if [[ ${accnt_type} == "user" && "${meta}" == "accnt" ]]
                        then ${XDO} key --window ${xwindow} Tab
                    elif [[ ${accnt_type} == "pass" ]]
                        then ${XDO} key --window ${xwindow} Enter
                    fi
                ;;
                clip)
                    if [[ -z ${XCRYPTB} ]] ;then
                        ${GPGde} -d ${wdir}/${obj} | ${XCLIP} ${XCS[${sel}]} -in
                    else
                        cat ${wdir}/${obj} | ${XCLIP} ${XCS[3]} -i
                    fi
                ;;
                screen)
                    ${SCREEN}\
                    -S $STY -X register . "$(${GPGde} -d ${wdir}/${obj})"
                ;;
                window)
                    ${SCREEN}\
                    -S $STY -p "${sel}" -X stuff "$(${GPGde} -d ${wdir}/${obj})"
            esac
        ;;
        update)
            gitPull
        ;;
        revert)
            if [[ -z ${treeish} ]] ;then
                chronoSelect
                gitRevert
            else
                gitRevert
            fi
    esac
}
# - - - Encrypt key vlaue - - - #
pinentryKeyValue() {
    pin_check=0
    cd ${wdir}
    local N_txt="About"
    local Y_txt="Enter"
    local p_txt="Value:"
    local ask_txt="Enter value for key ${obj}@${dom}"
    local check_txt="Re-enter value for key ${obj}@${dom}"
    local pincmd="${PINENTRY} -N ${N_txt} -Y ${Y_txt} -p ${p_txt}"
    ${pincmd} -t "${ask_txt}" | ${GPGen} -o ${wdir}/${obj} -e
    if [[ ${?} -eq 0 ]] ;then
        if [[ \
        $(echo -n "${SALT}$(${pincmd} -t "${check_txt}")" | ${GPGhash}) \
        != \
        $(echo -n "${SALT}$(${GPGde} -d ${wdir}/${obj})" | ${GPGhash}) \
        ]]
        then
            pin_check=1 # Passwords did not match
            gitClean
        else
            [[ -d ${WAL}/.git ]] && gitSync
        fi
    else
        pin_check=2 # User Abort
        gitClean
    fi
}
# - - - Ask echo - - - #
ask_prompt() {
    read -p "Enter ${obj} value: " val
    echo; read -p "Set ${obj} value (y/n): " v
    if [[ ${v,,} != "y" ]] ;then
        echo "User Aborted . . ."
    fi
}
# - - - Sync repos - - - #
gitSync() {
    gitAdd
    gitPull
    gitCommit
    gitPush
}
# - - - Delete Object - - - #
gitRemove() {
    local todo = true
    #gitRm
    #gitSync
}
# - - - Git init - - - #
gitInit() {
    local todo = true
}
# - - - Git pull - - - #
gitPull() {
    ${GIT} pull origin master
}
# - - - Git add - - - #
gitAdd() {
    ${GIT} add --all
}
# - - - Git commit - - - #
gitCommit() {
    local msg="[${cmd}]"
    [[ ! -z ${treeish} ]] && local msg+="<${treeish}>"
    local msg+=" ${dom}/${typ}/${obj}"
    local msg+=" $(date '+%F %T')"
    local msg+=" ${USER}@${HOSTNAME}"
    ${GIT} commit -m "pgw ${msg}"
}
# - - - Git push - - - #
gitPush() {
    ${GIT} push origin master
}
# - - - Git deletion - - - #
gitRm() {
    ${GIT} rm "${dom}/${typ}/${obj}"
}
# - - - Git clean working directory - - - #
gitClean() {
    ${GIT} checkout -- ${dom}/${typ}/${obj}
}
# - - - Git log - - - #
gitLog() {
    ${GIT} log --oneline ${dom}/${typ}/${obj}
    git log --oneline --follow #show the commits that changed file, even across renames
}
# - - - Git Revert - - - #
gitRevert() {
    ${GIT} show ${treeish}:${dom}/${typ}/${obj} > ${dom}/${typ}/${obj}
    gitSync
}
# - - - Git Chrono Vision - - - #
gitChronoVision() {
    ${GIT} show ${treeish}:${dom}/${typ}/${obj} > ${dom}/${typ}/${obj}
    run_cmd
    gitClean
}
# - - - Chrono Select - - - #
chronoSelect() {
    echo
    echo " ::Select Version #"
    echo
    while [[ $n -gt 0 ]] ;do n=$(expr $n - 1) ;local dash+="<-- " ;done
    cd ${WAL} ;genChronoIndex
    genList
    echo
    read -p "$(echo -ne ${WHT}) Enter choice #$(echo -ne ${clr}) " choice
    local line=$(echo ${chronoIndex} |sed 's/ /\n/g' |sed -n "${choice}p")
    treeish="$(echo ${line} |cut -d '~' -f 1)"
}
# - - - Chrono Index - - - #
genChronoIndex() {
    chronoIndex="$(${GIT} log --oneline ${dom}/${typ}/${obj} |sed 's/ /~/g')"
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
# - - - Select from list - - - #
selectList() {
    echo
    echo " ::Select Item #"
    echo
    cd ${WAL} ;genIndex
    genList
    echo
    read -p "$(echo -ne ${WHT}) Enter choice #$(echo -ne ${clr}) " choice 
    dom=$(echo ${index} |cut -d ' ' -f ${choice} |cut -d '/' -f 1)
    typ=$(echo ${index} |cut -d ' ' -f ${choice} |cut -d '/' -f 2)
    obj=$(echo -n ${index} |cut -d ' ' -f ${choice} |cut -d '/' -f 3)
    index=''
}
# - - - Gen index - - - #
genIndex() {
    index=$(find $(ls --color=never) -type f)
    [[ ! -z ${dom} ]] && index=$(echo $index |sed 's/ /\n/g' |grep -E "${dom}//*")
}
# - - - Gen select list - - - #
genList() {
    evalColors
    [[ ! -z ${index} ]] && local lines=$index
    [[ ! -z ${chronoIndex} ]] && local lines=$chronoIndex
    cd ${WAL} ;local color_1=${blu} ;local color_2=${wht} ;local ln=0
    for line in $(echo $lines) ;do
        local ln=$(expr $ln + 1)
        # Set color
        if [[ -z ${t} ]] ;then
            local t='togle'
            local color=${color_1}
        else
            local t=''
            local color=${color_2}
        fi
        echo -ne "${color}"
        if [[ ! -z ${index} ]] ;then
            dom="$(echo ${line} |cut -d '/' -f 1)"
            typ="$(echo ${line} |cut -d '/' -f 2)"
            obj="$(echo ${line} |cut -d '/' -f 3)"
            n=$(expr 26 - $(echo -n ${dom} |wc -c))
            while [[ $n -gt 0 ]] ;do n=$(expr $n - 1) ;dom+=" " ;done
            n=$(expr 10 - $(echo -n ${typ} |wc -c))
            while [[ $n -gt 0 ]] ;do n=$(expr $n - 1) ;typ+=" " ;done
            echo -ne "-> ${dom}- ${typ}${ln} - ${obj}"
        elif [[ ! -z ${chronoIndex} ]] ;then
            echo -ne "-> ${ln} - ${line}" |sed -e 's/~/ /g'
        fi
        echo -e "${clr}"
    done ;
}
# - - - Color me encrypted - - - #
evalColors() {
    BlK=$(tput blink;tput bold;tput setaf 0)
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
    BLK=$(tput bold;tput setaf 0)
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
main ${@}
exit 0
# vim: set ts=4 sw=4 tw=80 et :
