#!/bin/bash
#   GpgWallet       GPLv3              v10.8.1
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
-update         :Pull latest wallet from git server
-accnt  name    :Account pair (user:name pass:name)
-chrono commit  :View a past verion of an object, list select or commit
-revert commit  :Revert an object to an earlier state, list select or commit
"
set_wallet() {
  local c="$(echo "${1}" | \
              rev | \
              cut -d '/' -f 1 | \
              rev | \
              cut -d '.' -f 1)"
  local w="$(echo "${1}" | \
              rev | \
              cut -d '/' -f 1 | \
              rev | \
              cut -d '.' -f 2)"
  if [[ "${c}" == "${w}" ]] ;then
    WALLET="wallet"
  else
    WALLET="${w}"
  fi
}
set_wallet ${0}
[[ -z ${GNUPGHOME} ]] && GNUPGHOME="${HOME}/.gnupg"
WAL="${GNUPGHOME}/${WALLET}"
KEYID="$(cat "${WAL}/.KEYID")"
PINENTRY=$(which pish) # git clone http://github.com/tdwyer/pish
GPG=$(which gpg) ;[[ ${?} -gt 0 ]] && (echo "Install gpg (GnuPG) >=2.0")
GPGen="${GPG} -a --yes -s --cipher-algo TWOFISH --digest-algo SHA512"
GPGde="${GPG} -a --batch --quiet"
GPGhash="${GPG} -a --print-md SHA512"
SALT=$(${GPG} -a --gen-random 1 24)
[[ -z ${PAGER} ]] && PAGER=$(which less)
[[ ${PAGER} == "less" ]] && LESS="--RAW-CONTROL-CHARS"
XCLIP=$(which xclip)
XCS=( ["1"]="primary" ["2"]="secondary" ["3"]="clipboard" )
SCREEN=$(which screen 2>/dev/null) 
FIND=$(which find)
TREE=$(which tree)
GIT="$(which git) -C ${WAL}"
# - - - Main - - - #
main() {
    parse_args ${@} ZZZ #pad for-args with ZZZ
    case "${meta}" in
        accnt)
            local accnt_name="${obj}"
            local items="user pass"
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
# - - - List, Encrypt, or Decrypt objects - - - #
run_cmd() {
    local wdir="${WAL}/${dom}/${typ}"
    case "${cmd}" in
        help)
            echo "${help}"
        ;;
        find)
            findUI
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
                    ${GPGen} -r "${KEYID}" -o ${wdir}/${obj} -e ${val}
                    [[ -d ${WAL}/.git ]] && gitSync
                ;;
                keyring)
                    pinentryKeyValue
            esac
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
                clip)
                    ${GPGde} -d ${wdir}/${obj} | ${XCLIP}\
                    -selection ${XCS[${sel}]} -in
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
    cd ${wdir}
    local bN="About"
    local bY="Enter"
    local pT="Value:"
    local dT="Enter value for key ${obj}@${dom}"
    local vT="Re-enter value for key ${obj}@${dom}"
    if [[ -z ${val} ]] ;then
        case "${obj}" in
            url|user:*)
                local vT=
                ${PINENTRY}  -N "${bn}" -Y "${bY}" -p "${pT}" -t "${dT}" | \
                    ${GPGen} -r "${KEYID}" -o ${wdir}/${obj} -e
                local vB="Enter? <${obj}@${dom}> = $(gpg --batch -d ${wdir}/${obj})"
                ${PINENTRY} -N "${bn}" -Y "${bY}" -p "${pT}" -t "${vB}" -b
                if [[ ! ${?} -eq 0 ]] ;then
                    echo "Aborting . . ."
                    gitClean
                else
                    [[ -d ${WAL}/.git ]] && gitSync
                fi
            ;;
                *)
                ${PINENTRY} -N "${bn}" -Y "${bY}" -p "${pT}" -t "${dT}" | \
                    ${GPGen} -r "${KEYID}" -o ${wdir}/${obj} -e
                if [[ ${?} -eq 0 ]] ;then
                    if [[ \
                    $(echo -n "${SALT}$(${PINENTRY} -N "${bn}" -Y "${bY}" -p "${pT}" -t "${vT}")" | ${GPGhash}) \
                    != \
                    $(echo -n "${SALT}$(${GPGde} -d ${wdir}/${obj})" | ${GPGhash}) \
                    ]]
                    then
                        echo "Passwords did not match"
                        gitClean
                    else
                        [[ -d ${WAL}/.git ]] && gitSync
                    fi
                else
                    echo "Aborting . . ."
                    gitClean
                fi
        esac
    else
        echo -n "${val}" | ${GPGen} -r "${KEYID}" -o ${wdir}/${obj} -e
        val=""
    fi
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
    local uniques="-e -stdout -clip -screen -window -t -update"
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
            if [[ -z ${dom} || -z ${typ} || -z ${obj} ]] ;then
                echo "${HELP}" ; exit 201
            fi
            case ${typ} in
                keyring)
                    local ok=true #handled in pinentryKeyValue
                ;;
                vault)
                    if [[ -f ${val} ]] ;then echo ${HELP} ;exit 203 ;fi
            esac
        ;;       
        decrypt)
            [[ -z ${dom} || -z ${typ} || -z ${obj} ]] && selectList
            if [[ ! "stdout clip screen window" =~ ${dst} ]] ;then
                echo "${HELP}" ; exit 204
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
                        echo "${HELP}" ; exit 205
                    fi
                ;;
                screen)
                    if [[ -z $STY ]] ;then
                        echo ' - No $STY for GNU Screen found -'
                        exit 206
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
            echo "${HELP}" ; exit 250
    esac
}
# - - - Ask echo - - - #
ask_prompt() {
    read -p "Enter ${obj} value: " val
    echo; read -p "Set ${obj} value (y/n): " v
    if [[ ${v,,} != "y" ]] ;then
        echo "Aborting. . ."
        val=""
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
