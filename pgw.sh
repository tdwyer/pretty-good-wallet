#!/bin/bash
#
#   GpgWallet       GPLv3              v10.9.3
#   Thomas Dwyer    <devel@tomd.tel>   http://tomd.tel/
#
SELF="$(echo "${0}" | rev | cut -d '/' -f 1 | rev | cut -d ':' -f 1)"
WAL="$(echo "${0}" | rev | cut -d '/' -f 1 | rev | cut -d ':' -f 2)"
if [[ "${SELF}" == "${WAL}" ]] ;then WALLET="wallet" ;else WALLET="${WAL}" ;fi
[[ ! -d ${GNUPGHOME} ]] && GNUPGHOME="${HOME}/.gnupg"
WAL="${GNUPGHOME}/${WALLET}"
CONFIG="${WAL}/.pgw.conf"
# - - - Setup/Read Configuration File - - - #
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
# - - - Configure Runtime Environment - - - #
config_env() {
    HELP="
    Usage ${SELF} [-e] [-d domain] [-k user (-v pass)] [-f filename] [-accnt name]
            [-stdout] [-auto] [-clip] [-screen] [-window #]
            [-t (search-string)] [-update] [-version (commit)] [-revert (commit)]
    -enc            :Encrypt
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
    -version commit :View older version. DEFAULT: Select from list
    -revert  commit :Revert to older version. DEFAULT: Select from list

    NOTE: If Cryptboard available, -clip will put encrypted message in X11 clipboard
    "
    # [[ -z ${NO_COLOR} ]] Then tree and list output will have colors
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
}
#
# - - - Main - - - #
main() {
    read_config ${@}
    config_env ${@} # Runtime Environment has Priority
    parse_args ${@}
    validate ${@}
    run_cmd ${@}
}
# - - - Process Account - - - #
main_accnt() {
    local accnt_name="${obj}"
    if [[ ${cmd} == "encrypt" && ! -z ${val} ]]
        then local items="pass user"
        else local items="user pass"
    fi
    for item in ${items} ;do
        typ='keyring'
        obj="${item}:${accnt_name}"
        validate ${@}
        run_cmd ${@}
        val=''
        [[ ${invalid} ]] && break
    done
}
# - - - Parse the arguments - - - #
parse_args() {
    cmd='' ;dom='' ;typ='' ;obj='' ;val='' ;dst='' ;sel='' treeish=''
    for (( i=1; i<=${#}; i++ )); do
        flag=$(echo ${@:${i}:1} | grep -G '^-')
        value=$(echo ${@:$(expr ${i} + 1):1} | grep -vG '^-')
        [[ ${value} ]] && i=$(expr ${i} + 1)
        #
        case ${flag} in
            -h|--help)
                cmd+='help'
            ;;
            -enc)
                cmd+='encrypt'
            ;;
            -d)
                dom="${value}"
            ;;
            -k)
                typ+='keyring' ; obj="${value}"
            ;;
            -v)
                typ+=':value:' ; val="${value}"
            ;;
            -f)
                typ+='vault' ; val="$(readlink -f ${value} 2>/dev/null)"
                obj="$(echo ${value} |rev |cut -d '/' -f 1 |rev)"
                if [[ $(echo $obj |rev |cut -d '.' -f 1 |rev) != 'asc' ]]
                    then obj+=".asc"
                fi
            ;;
            -accnt)
                cmd+=':accnt:' ; typ+='accnt' ; obj="${value}"
            ;;
            -stdout)
                cmd+='decrypt' ; dst='stdout' ; sel="${value}"
                if [[ $(echo "${sel}" |grep -vG '^/') ]]
                    then sel=$(echo -n $(pwd)/${sel})
                fi
            ;;
            -auto)
                cmd+='decrypt' ; dst='auto'
            ;;
            -clip)
                cmd+='decrypt' ; dst='clip' ; sel="${value}"
            ;;
            -screen)
                cmd+='decrypt' ; dst='screen'
            ;;
            -window)
                cmd+='decrypt' ; dst='window' ; sel="${value}"
            ;;
            -t)
                cmd+='tree' ; str="${value}"
            ;;
             -update)
                cmd+='update'
            ;;
            -version)
                cmd+=':version:' ; treeish="${value}"
            ;;
            -revert)
                cmd+='revert' ; treeish="${value}"
        esac
    done
}
# - - - Check for errors - - - #
validate() {
    case ${typ} in
        keyring|keyring:vlaue:|:value:keyring)
            local ok=true
        ;;
        vault)
            local ok=true
        ;;
        accnt)
            local ok=true
        ;;
        '')
            local ok=true
        ;;
        *)
            echo "Can no specify -k -f or -accnt at the same time"
            exit 251
    esac
    case ${cmd} in
        help)
            echo "${HELP}"
            exit 0
        ;;
        encrypt)
            validateEncrypt
        ;;
        decrypt)
            validateDecrypt
        ;;
        tree)
            local ok=true
        ;;
        :accnt:encrypt|:accnt:decrypt|encrypt:accnt:|decrypt:accnt:)
            typ='keyring'
        ;;
        update)
            local ok=true
        ;;
        :version:encrypt|:version:decrypt|encrypt:version:|decrypt:version:)
            validateVersion
        ;;
        revert)
            validateRevert
        ;;
        *)
            echo " - -> Command Not Supported: [ ${SELF} ${@} ]"
            echo "${HELP}"
            exit 250
    esac
    wdir="${WAL}/${dom}/${typ}" # Shorten this validated path
}
# - - - Verify Encrypt - - - #
validateEncrypt() {
    case ${typ} in
        keyring)
            [[ ${invalid} ]] && exit 221 # Aborted saving
        ;;
        keyring:vlaue:|:value:keyring)
            local ok=true
        ;;
        vault)
            if [[ -z ${val} ]] ;then
                echo "${HELP}"
                exit 223
            fi
        ;;
        *)
            echo "${HELP}"
            exit 220
    esac
}
# - - - Verify Decrypt - - - #
validateDecrypt() {
    [[ -z ${dom} || -z ${typ} || -z ${obj} ]] && objectSelect
    case ${dst} in
        stdout)
            local ok=true #Can select filename. GPG prompts to overwrite
        ;;
        auto)
            local ok=true
        ;;
        clip)
            [[ -z ${XCD[${sel}]} ]] && sel=1
        ;;
        screen)
            if [[ -z $STY ]] ;then
                echo ' - No $STY for GNU Screen found -'
                exit 232
            fi
        ;;
        window)
            $(expr ${sel} + 1 1>/dev/null 2>&1)
            if [[ ! ${?} -eq 0 ]] ;then
                echo "Destination Window number: ${sel} :is invalid"
                echo "${HELP}"
                exit 233
            fi
        ;;
        *)
            echo "${HELP}"
            exit 230
    esac
}
# - - - Verify revert - - - #
validateRevert() {
    [[ -z ${dom} || -z ${typ} || -z ${obj} ]] && objectSelect
    [[ -z ${treeish} ]] && versionSelect
}
# - - - Verify revert - - - #
validateVersion() {
    [[ -z ${dom} || -z ${typ} || -z ${obj} ]] && objectSelect
    [[ -z ${treeish} ]] && versionSelect
}
# - - - List, Encrypt, or Decrypt objects - - - #
run_cmd() {
    case "${cmd}" in
        help)
            echo "${help}"
        ;;
        *:accnt:*)
            accnt_action
        ;;
        encrypt)
            encryptValue
        ;;
        decrypt)
            decryptValue
        ;;
        tree)
            local tree_lines=$(expr 4 + $(treeUI | wc -l))
            local term_lines=$(tput lines)
            treeUI ${tree_lines} ${term_lines}
        ;;
        update)
            gitPull
        ;;
        *:version:*)
            gitRevert
            decryptValue
            gitClean
        ;;
        revert)
            gitRevert
            gitSync
    esac
}
# - - - Account Action - - - #
accnt_action() {
    [[ ${val} ]] && local keys="pass user" || local keys="user pass"
    local accnt_name="${obj}"
    case ${cmd} in
        *encrypt*)
            for key in ${keys} ;do
                obj="${key}:${accnt_name}"
                validateEncrypt
                encryptValue
            done
        ;;
        *decrypt*)
            for key in ${keys} ;do
                obj="${key}:${accnt_name}"
                validateDecrypt
                decryptValue
            done
    esac
    val=''
}
# - - - Encrypt value - - - #
encryptValue() {
    [[ ! -d ${wdir}  ]] && mkdir -p ${wdir} ;cd ${wdir}
    case "${typ}" in
        vault)
            ${GPGen} -o ${wdir}/${obj} -e ${val}
        ;;
        keyring)
            local obj_typ=$(echo ${obj} |cut -d ':' -f 1)
            if [[ "${obj_typ}" == "user" || "${obj_typ}" == "url" ]]
                then prompt
                echo -n "${val}" | ${GPGen} -o ${wdir}/${obj} -e
            else
                pinentryKeyValue
            fi
        ;;
        keyring|keyring:vlaue:|:value:keyring)
            echo -n "${val}" | ${GPGen} -o ${wdir}/${obj} -e
    esac
    val=""
    [[ ${invalid} ]] && gitClean || gitSync
}
# - - - Prompt for value - - - #
prompt() {
    read -p "Enter ${obj} value: " val
    echo; read -p "Set ${obj} value to ${val} (y/n): " v
    if [[ ${v,,} != "y" ]] ;then
        echo "User Aborted . . ."
        invalid=true
    fi
}
# - - - Encrypt key value - - - #
pinentryKeyValue() {
    cd ${wdir}
    local N_txt="Abort"
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
            invalid=true
        fi
    else
        echo "User Aborted . . ."
        invalid=true
    fi
}
# - - - Decyrpt value - - - #
decryptValue() {
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
            local obj_typ=$(echo ${obj} |cut -d ':' -f 1)
            if [[ "${obj_typ}" == "user" ]]
                then ${XDO} key --window ${xwindow} Tab
            elif [[ ${obj_typ} == "pass" || ${obj_typ} == "url" ]]
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
}
# - - - Git init - - - #
gitInit() {
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
# - - - Git move - - - #
gitMv() {
    ${GIT} mv "${dom}/${typ}/${obj}" "${dom}/${typ}/${val}"
}
# - - - Git clean working directory - - - #
gitClean() {
    for new_file in $(${GIT} status --porcelain |grep -G '^.?' |sed 's/^...//g')
        do rm ${WAL}/${new_file}
    done
    ${GIT} checkout -- .
}
# - - - Sync repos - - - #
gitSync() {
    local remotes=$(${GIT} remote -v)
    gitAdd
    [[ ${remotes} ]] && gitPull
    gitCommit
    [[ ${remotes} ]] && gitPush
}
# - - - Git Revert - - - #
gitRevert() {
    ${GIT} show ${treeish}:${dom}/${typ}/${obj} > "${WAL}/${dom}/${typ}/${obj}"
}
# - - - tree command view - - - #
treeUI() {
    [[ -z ${1} ]] && local min=1 || local min=${1}
    [[ -z ${2} ]] && local max=10 || local max=${2}
    cd ${WAL} ;a="--noreport --prune" ;s="*${str}*"
    [[ ${typ} == "vault" ]] && s="*.asc" # FIXME: I am very annoying
    [[ ${typ} == "keyring" ]] && a+=" -I *.asc"
    a+=" -P "
    if [[ ${min} -lt ${max} ]]
        then ${TREE} ${a} "${s}" ${dom}
    elif [[ ${NO_COLOR} ]]
        then ${TREE} ${a} "${s}" ${dom} | ${PAGER}
        else ${TREE} ${a} "${s}" ${dom} -C | ${PAGER}
    fi
}
# - - - Version Select - - - #
versionSelect() {
    echo
    echo "                    :: Select Version ::"
    echo
    cd ${WAL} ;versionIndex
    genList
    echo
    read -p "$(echo -ne ${WHT}) Enter choice #$(echo -ne ${clr}) " choice
    local line=$(echo ${versionIndex} |sed 's/ /\n/g' |sed -n "${choice}p")
    treeish="$(echo ${line} |cut -d '#' -f 1)"
    versionIndex=''
}
# - - - Version Index - - - #
versionIndex() {
    versionIndex="$(${GIT} log --oneline ${dom}/${typ}/${obj} |sed 's/ /#/g')"
}
# - - - Select from list - - - #
objectSelect() {
    echo
    echo "                     :: Select Item ::"
    echo
    cd ${WAL} ;objectIndex
    genList
    echo
    read -p "$(echo -ne ${WHT}) Enter choice #$(echo -ne ${clr}) " choice
    dom=$(echo ${objectIndex} |cut -d ' ' -f ${choice} |cut -d '/' -f 1)
    typ=$(echo ${objectIndex} |cut -d ' ' -f ${choice} |cut -d '/' -f 2)
    obj=$(echo -n ${objectIndex} |cut -d ' ' -f ${choice} |cut -d '/' -f 3)
    objectIndex=''
}
# - - - Gen index - - - #
objectIndex() {
    objectIndex=$(find $(ls --color=never) -type f)
    if [[ ${dom} ]] ;then
        objectIndex=$(echo ${objectIndex} |sed 's/ /\n/g' |grep -E "${dom}//*")
    fi
}
# - - - Gen select list - - - #
genList() {
    [[ ${objectIndex} ]] && local lines=${objectIndex}
    [[ ${versionIndex} ]] && local lines=${versionIndex}
    cd ${WAL}
    local ln=0
    if [[ ${NO_COLOR} ]] ;then
        local color_1="" ;local color_2=""
    else
        evalColors
        local color_1=${blu} ;local color_2=${wht}
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
        if [[ ${objectIndex} ]] ;then
            dom="$(echo ${line} |cut -d '/' -f 1)"
            typ="$(echo ${line} |cut -d '/' -f 2)"
            obj="$(echo ${line} |cut -d '/' -f 3)"
            n=$(expr 26 - $(echo -n ${dom} |wc -c))
            while [[ $n -gt 0 ]] ;do n=$(expr $n - 1) ;dom+=" " ;done
            n=$(expr 10 - $(echo -n ${typ} |wc -c))
            while [[ $n -gt 0 ]] ;do n=$(expr $n - 1) ;typ+=" " ;done
            echo -ne "-> ${dom}- ${typ}${ln} - ${obj}"
        elif [[ ${versionIndex} ]] ;then
            echo -ne "-> ${ln} - ${line}" |sed -e 's/#/ /g'
        fi
        echo -e "${clr}"
    done
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
    Nl="s/^/$(tput setaf 7)/g" # sed -e ${Nl} -e ${nL} Will color 'nl' num lists
    nL="s/\t/$(echo -ne '\033[m')\t/g"
}
#
# - - - RUN - - - #
main ${@}
exit 0
# vim: set ts=4 sw=4 tw=80 et :
