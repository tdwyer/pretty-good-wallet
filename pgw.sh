#!/bin/bash
#
#   GpgWallet       GPLv3              v10.9
#   Thomas Dwyer    <devel@tomd.tel>   http://tomd.tel/
#
SELF="$(echo "${0}" | rev | cut -d '/' -f 1 | rev | cut -d ':' -f 1)"
WAL="$(echo "${0}" | rev | cut -d '/' -f 1 | rev | cut -d ':' -f 2)"
if [[ "${SELF}" == "${WAL}" ]] ;then WALLET="wallet" ;else WALLET="${WAL}" ;fi
SELF="${SELF}"
[[ ! -d ${GNUPGHOME} ]] && GNUPGHOME="${HOME}/.gnupg"
WAL="${GNUPGHOME}/${WALLET}"
CONFIG="${WAL}/.pgw.conf"
# - - - Setup/Read Configuration - - - #
read_config() {
    if [[ ! -d ${WAL} ]] ;then
        mkdir -p "${WAL}" ;chmod 0700 "${WAL}"
        cp /usr/share/pgw/pgw.conf "${WAL}/.pgw.conf"
        echo '.pgw.conf' >> "${WAL}/.gitignore"
        gitInit
    elif [[ ! -f ${CONFIG} ]] ;then
        #
        cp /usr/share/pgw/pgw.conf "${WAL}/.pgw.conf"
    elif [[ ! -f "${WAL}/.gitignore" ]] ;then
        #
        echo '.pgw.conf' >> "${WAL}/.gitignore"
    elif [[ ! -d "${WAL}/.git" ]] ;then
        #
        gitInit
    fi
    #
    . $CONFIG 2>/dev/null # Source Wallet Configuration File
}
#
HELP="
Usage ${SELF} [-e] [-d domain] [-k user (-v pass)] [-f filename] [-accnt name]
          [-stdout] [-auto] [-clip] [-screen] [-window #]
          [-t (search-string)] [-update] [-chrono (commit)] [-revert (commit)]
-e              :Encrypt
-d  domainname  :Domain, Each domain contains a Keyring and a Vault
-k  keyname     :Keyring, Think User/Password. Value i.e. passwd is prompted for
    -v          :Key Value, Provide value in command instead of through a prompt
-f  filename    :Vault, Encrypted file management with native interface
-accnt  name    :Account pair (user:name pass:name)
-stdout         :Send to plaintext to stdout
-auto           :Auto-Type into user selected window. Best used with -accnt
-clip   #       :Send to selection 3=Clipboard 2=Secondary 1=Primary. DEFAULT: 1
-screen         :Send to gnu-screen copy buffer 
-window #       :Send to stdin of gnu-screen window Number
-t  str         :Search wallet with: -d, -k, -v and/or string found in name
-update         :Pull latest wallet from git server
-chrono commit  :View older verion. DEFAULT: Select from list
-revert commit  :Revert to older version. DEFAULT: Select from list
"
[[ -z ${NO_COLOR} ]] && NO_COLOR=0
[[ -z ${KEYID} ]] && KEYID=""
[[ -z ${CIPHER} ]] && CIPHER="TWOFISH"
[[ -z ${DIGEST} ]] && DIGEST="SHA512"
[[ -z ${PAGER} ]] && \
PAGER=$(whereis -b less |cut -d ' ' -f 2)
GIT_EXE=$(whereis -b git |cut -d ' ' -f 2)
XCLIP_EXE=$(whereis -b xclip |cut -d ' ' -f 2)
XDO=$(whereis -b xdotool |cut -d ' ' -f 2)
SCREEN=$(whereis -b screen |cut -d ' ' -f 2)
TREE=$(whereis -b tree |cut -d ' ' -f 2)
XCRYPTB=$(whereis -b cryptboard |cut -d ' ' -f 2)
PINENTRY=$(whereis -b pish |cut -d ' ' -f 2)
GPG=$(whereis -b gpg |cut -d ' ' -f 2)
[[ ! -x ${PAGER} ]] && PAGER=""
[[ ! -x ${GIT_EXE} ]] && GIT_EXE=""
[[ ! -x ${XCLIP_EXE} ]] && XCLIP_EXE=""
[[ ! -x ${XDO} ]] && XDO=""
[[ ! -x ${SCREEN} ]] && SCREEN=""
[[ ! -x ${TREE} ]] && TREE=""
[[ ! -x ${XCRYPTB} ]] && XCRYPTB=""
[[ ! -x ${PINENTRY} ]] && PINENTRY=""
[[ ! -x ${GPG} ]] && GPG=""
[[ ${PAGER} == "less" ]] && LESS="--RAW-CONTROL-CHARS"
GIT="${GIT_EXE} -C ${WAL}"
XCLIP="${XCLIP_EXE} -selection"
XCD=( ["1"]="primary" ["2"]="secondary" ["3"]="clipboard" )
SALT=$(${GPG} --armor --quiet --batch --yes --gen-random 1 24)
GPGhash="${GPG} --armor --quiet --batch --yes --print-md ${DIGEST}"
GPGde="${GPG} --armor --quiet --batch --yes"
GPGen="${GPG} --armor --quiet --batch --yes --sign"
GPGen+=" --cipher-algo ${CIPHER}"
GPGen+=" --digest-algo ${DIGEST}"
if [[ -z ${KEYID} ]]
    then GPGen+=" --default-recipient-self"
else
    for key in ${KEYID} ;do
        GPGen+=" -r ${key}"
    done
fi
#
# - - - Main - - - #
main() {
    read_config
    parse_args ${@} ZZZ #pad for-args with ZZZ
    case "${meta}" in
        accnt)
            local accnt_name="${obj}"
            if [[ ${cmd} == "encrypt" && ! -z ${val} ]]
                then local items="pass user"
                else local items="user pass"
            fi
            for item in ${items} ;do
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
            -e)
                cmd='encrypt'
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
                typ='vault' ; val="$(readlink -f ${arg})"
                obj="$(echo ${arg} |sed 's/\//\n/g' |tail -n1)"
                [[ $(echo $obj |rev |cut -d '.' -f 1) != 'asc' ]] && obj+=".asc"
            ;;
            -accnt)
                meta="accnt" ; obj="${arg}"
            ;;
            -stdout)
                cmd='decrypt' ; dst='stdout' ; sel="${arg}"
            ;;
            -auto)
                cmd='decrypt' ; dst='auto'
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
    local opts=" ZZZ -auto -chrono -revert -d -k -v -f ${uniques}"
    local uniqueN=0 ;local obj_typeN=0
    for item in ${@} ;do
        for unique in uniques ;do
            [[ "${unique}" == "${item}" ]] && uniqueN=$(expr ${x} + 1)
        done
        for obj_type in "-k -f" ;do
            [[ "${otype}" == "${item}" ]] && obj_typeN=$(expr ${y} + 1)
        done
        if [[ ${uniqueN} -gt 1 ]] ;then
            echo "Can only give one command which encrypts or decrypts"
            exit 200
        elif [[ ${obj_typeN} -gt 1 ]] ;then
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
            case ${typ} in
                keyring)
                    case ${check} in
                        1)
                            exit 221 # User Aborted
                        ;;
                        2)
                            exit 222 # Passwords did not match
                    esac
                ;;
                vault)
                    if [[ -z ${val} ]] ;then
                        echo "${HELP}"
                        exit 223
                    fi
            esac
        ;;       
        decrypt)
            [[ -z ${dom} || -z ${typ} || -z ${obj} ]] && selectList
            if [[ ! "stdout auto clip screen window" =~ ${dst} ]] ;then
                echo "${HELP}"
                exit 231
            fi
            case ${dst} in
                clip)
                    [[ -z ${XCD[${sel}]} ]] && sel=1
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
            [[ ! -d ${wdir}  ]] && mkdir -p ${wdir} ;cd ${wdir}
            check=0
            case "${typ}" in
                vault)
                    ${GPGen} -o ${wdir}/${obj} -e ${val}
                ;;
                keyring)
                    if [[ -z ${val} ]] ;then
                        local obj_typ=$(echo ${obj} |cut -d ':' -f 1)
                        if [[ "${obj_typ}" == "user" || "${obj_typ}" == "url" ]]
                            then prompt
                            echo -n "${val}" | ${GPGen} -o ${wdir}/${obj} -e
                        else
                            pinentryKeyValue
                        fi
                    else
                        echo -n "${val}" | ${GPGen} -o ${wdir}/${obj} -e
                    fi
            esac
            if [[ ${check} -eq 0 ]]
                then gitSync
                else gitClean
            fi
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
                        ${XDO} windowfocus --sync ${xwindow}
                    fi
                    ${XDO} type "$(${GPGde} -d ${wdir}/${obj})"
                    #
                    local accnt_type="$(echo -n ${obj} |cut -d ':' -f 1)"
                    if [[ ${accnt_type} == "user" && "${meta}" == "accnt" ]]
                        then ${XDO} key --window ${xwindow} Tab
                    elif [[ ${accnt_type} == "pass" || ${accnt_type} == "url" ]]
                        then ${XDO} key --window ${xwindow} Return
                    fi
                ;;
                clip)
                    if [[ -z ${XCRYPTB} ]] ;then
                        ${GPGde} -d ${wdir}/${obj} | ${XCLIP} ${XCD[${sel}]} -in
                    else
                        cat ${wdir}/${obj} | ${XCLIP} ${XCD[3]} -i
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
            echo "Key values did not match"
            check=2
        fi
    else
        echo "User Aborted . . ."
        check=1
    fi
}
# - - - Prompt for value - - - #
prompt() {
    read -p "Enter ${obj} value: " val
    echo; read -p "Set ${obj} value (y/n): " v
    if [[ ${v,,} != "y" ]] ;then
        echo "User Aborted . . ."
        check=1
    fi
}
# - - - Git init - - - #
gitInit() {
    cd ${WAL}
    ${GIT} init
    gitSync
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
# - - - Git remove - - - #
gitRm() {
    ${GIT} rm "${dom}/${typ}/${obj}"
}
# - - - Git clean working directory - - - #
gitClean() {
    ${GIT} checkout -- ${dom}/${typ}/${obj}
}
# - - - Sync repos - - - #
gitSync() {
    local remotes=$(${GIT} remote -v)
    gitAdd
    [[ ! -z ${remotes} ]] && gitPull
    gitCommit
    [[ ! -z ${remotes} ]] && gitPush
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
    if [[ ! -z ${dom} ]] ;then
        index=$(echo $index |sed 's/ /\n/g' |grep -E "${dom}//*")
    fi
}
# - - - Gen select list - - - #
genList() {
    [[ ! -z ${index} ]] && local lines=$index
    [[ ! -z ${chronoIndex} ]] && local lines=$chronoIndex
    cd ${WAL}
    local ln=0
    if [[  ${NO_COLOR} -eq 0 ]] ;then
        evalColors
        local color_1=${blu} ;local color_2=${wht}
    else
        local color_1="" ;local color_2=""
    fi
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
    ReD=$(tput blink;tput bold;tput setaf 1)
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
