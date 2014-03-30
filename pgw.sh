#!/bin/bash
#
#   GpgWallet       GPLv3              v10.10
#   Thomas Dwyer    <devel@tomd.tel>   http://tomd.tel/
#
SELF="$(echo "${0}" | rev | cut -d '/' -f 1 | rev | cut -d ':' -f 1)"
WALLET="$(echo "${0}" | rev | cut -d '/' -f 1 | rev | cut -d ':' -f 2)"
if [[ "${SELF}" == "${WALLET}" ]]
    then WALLET="wallet"
    else WALLET="${WALLET}"
fi
[[ ! -d ${GNUPGHOME} ]] && GNUPGHOME="${HOME}/.gnupg"
WAL="${GNUPGHOME}/${WALLET}"
CONFIG="${WAL}/.pgw.conf"
HELP="
Usage ${SELF} [-e] [-d domain] [-k user (-v pass)] [-f filename] [-accnt name]
        [-stdout] [-auto] [-clip] [-screen] [-window #]
        [-tree] [-list] [-update] [-version (commit)] [-revert (commit)]

View long help with --help

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
-tree           :View wallet Tree Search with Domain, Key, Accnt and/or Filename
-list           :View wallet List Search with Domain, Key, Accnt and/or Filename
-list -version  :List Versions Search with Domain, Key, Accnt and/or File name
-update         :Pull latest wallet from git server
-version commit :View older version. DEFAULT: Select from list
-revert  commit :Revert to older version. DEFAULT: Select from list
-clone-remote URI :Clone wallet from remote server
-add-remote   URI :Add remote server
"
MANLY_HELP="
Usage ${SELF} (item) (action)

View short help with -h

Define Item :: ${SELF} -d example.com -accnt main
--------------------------------------------------------------------------------
 -d    domain     :Domain name (contains Keyring and Vault)
 -f    file       :File to add/access to/from Vault
 -k    key        :Key name
  -v   value      :Value to store for key. Useful for scripting
                    Default prompt for value with pinentry
 -accnt name      :Account name
                    Creates two keys. user:<accnt> and pass:<accnt>
                    * Add account with -enc (supports -v or pinentry)
                    * Supported by -auto for Auto-Typed wiebsite login


Add Item to Wallet :: ${SELF} -d example.com -accnt main -enc
--------------------------------------------------------------------------------
 -enc             :Encrypt, Add defined item to the wallet


Access Item in Wallet :: ${SELF} -d example.com -accnt main -auto
--------------------------------------------------------------------------------
If Item is not fully defined, you will be prompted to select from a list items

 -auto            :Auto-Type
                    Works like KeePassX auto-type but you click on target window
                    Most useful when with the -accnt item definition
 -clip   #        :Add to X11 clipboard (Default is Primary Selection)
                    3=Clipboard 2=Secondary 1=Primary (Primary is Default)
                    * middle-click to paste Primary
                    * If Cryptboard is installed
                     -clip will only put encrypted messages in X11 Clipboard
 -stdout          :GPG decrypt directly to standard out
                    Useful for scripting

  ..GNU Screen Support..
 -screen          :Put in GNU Screen copy register ( Paste with Ctrl+A ] )
 -window #        :Stuff to stdin of GNU Screen Window-#
                    Think auto-type for screen


View and Search the Wallet :: ${SELF} -d example.com -t main
--------------------------------------------------------------------------------
 -tree             :Display wallet as a fancy Tree
                     If terminal too small open in less tree (or if set, $PAGER)
 -list             :List output in an easy-to-parse format for scripts
                     Format='./domain/{keyring|vault}/item-name'
 -list -version    :View list of versions

  ..Search options..
  Domain and/or Key, Account, or File name may be used to limit search results
 -d      name      :Only domains matching name
 -k      name      :Only keys matching name
 -f      name      :Only files matchin name
 -accnt  name      :Only keys matching name


Version Control :: ${SELF}  -d example.com -k pass:main -clip -version
--------------------------------------------------------------------------------
 -version commit   :View old version
                     Select from list if version commit is no provided
 -revert  commit   :Revert to old version
                     Select from list if version commit is no provided
 -update           :Pull wallet update from sync server

  ..Setup Remote Sync Server..
 -clone-remote URI :Clone wallet from remote server
                     URI user@git.ssh.example.com:git/wallet.git
 -add-remote   URI :Add remote server
                     URI user@git.ssh.example.com:git/wallet.git
 -make-remote  URI :Create and Add remote server
                     URI user@git.ssh.example.com
                     * You need a SSH user account on the server
                     * git must already be installed on the server
"
# - - - Check and Read Wallet Configuration - - - #
read_config() {
    if [[ -z $(ls ${WAL}) ]] ;then
            rm -r "${WAL}"
    fi
    if [[ -d ${WAL} ]] ;then
        if [[ ! -d "${WAL}/.git" ]] ;then
            read_config ${@}
            makeLocalRepository
        fi
    else
        read_config ${@}
        walletSetup
    fi
    #
    . $CONFIG 2>/dev/null # Source Wallet Configuration File
}
# - - - Wallet Setup - - - #
walletSetup() {
    echo
    echo "Wallet ( ${WAL} ) not found"
    config_env ${@}
    mkdir -p "${WAL}" ;chmod 0700 "${WAL}"
    echo
    echo "Would you like to . . ."
    echo "Clone a Wallet from your sync server?"
    echo "Make a New sync server?"
    echo "Local wallet only for now?"
    read -p "clone make local abort: " ansr
    case "${ansr,,}" in
        clone)
            cloneRemote
        ;;
        make)
            makeRemote
        ;;
        local)
            makeLocalWallet
        ;;
        *)
            echo
            echo "Abort..."
            echo
            rm -r "${WAL}"
            echo "${MANLY_HELP}" # Well may be new user show Manly help
            exit 0
    esac
}
# - - - Make Local Wallet - - - #
makeLocalWallet() {
    gitInit
    createConfig
    gitSync
    read -p "Would you like to add a Remote Server? (y/n): " add_yn
    if [[ "${add_yn,,}" == "y" ]] ;then
        addRemote
    else
        echo "Add a remote server with -add-remote or -make-remote"
    fi
}
# - - - Git Setup - - - #
makeLocalRepository() {
    gitInit
    gitSync
    read -p "Would you like to add a Remote Server? (y/n): " add_yn
    if [[ "${add_yn,,}" == "y" ]] ;then
        addRemote
    else
        echo "Add a remote server with -add-remote or -make-remote"
    fi
}
# - - - Create PGW Config - - - #
createConfig() {
    echo "KEYID=${KEYID}" >> "${WAL}/.pgw.conf"
    echo "CIPHER=${CIPHER}" >> "${WAL}/.pgw.conf"
    echo "DIGEST=${DIGEST}" >> "${WAL}/.pgw.conf"
    echo "NO_COLOR=${NO_COLOR}" >> "${WAL}/.pgw.conf"
    echo '.pgw.conf' >> "${WAL}/.gitignore"
}
# - - - Configure Runtime Environment - - - #
config_env() {
    # [[ -z ${NO_COLOR} ]] Then tree and list output will have colors
    [[ -z ${KEYID} ]] && KEYID=""
    [[ -z ${CIPHER} ]] && CIPHER="TWOFISH"
    [[ -z ${DIGEST} ]] && DIGEST="SHA512"
    [[ -z ${PAGER} ]] && \
    PAGER=$(whereis -b less |cut -d ' ' -f 2)
    SSH=$(whereis -b ssh |cut -d ' ' -f 2)
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
    config_env ${@}
    read_config ${@}
    parse_args ${@}
    validate ${@}
    run_cmd ${@}
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
            -h)
                cmd+='help'
            ;;
            --help)
                cmd+='manlyhelp'
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
            -tree)
                cmd+='tree'
            ;;
            -list)
                cmd+='list'
            ;;
             -update)
                cmd+='update'
            ;;
            -version)
                cmd+=':version:' ; treeish="${value}"
            ;;
            -revert)
                cmd+='revert' ; treeish="${value}"
            ;;
            -clone-remote)
                cmd+='clone-remote' ; URI="${value}"
            ;;
            -add-remote)
                cmd+='add-remote' ; URI="${value}"
            ;;
            -make-remote)
                cmd+='make-remote' ; URI="${value}"
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
        manlyhelp)
            echo "${MANLY_HELP}"
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
        list|list:version:|:version:list)
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
        clone-remote)
            local ok=true
        ;;
        add-remote)
            local ok=true
        ;;
        make-remote)
            local ok=true
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
        list)
            itemIndex
        ;;
        :version:list|list:version:)
            versionIndex
        ;;
        update)
            gitPull
        ;;
        revert)
            gitRevert
            gitSync
        ;;
        clone-remote)
            cloneRemote
        ;;
        add-remote)
            addRemote
        ;;
        make-remote)
            makeRemote
        ;;
        *:accnt:*)
            accnt_action
        ;;
        *:version:*)
            gitRevert
            decryptValue
            gitClean
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
# - - - Decrypt value - - - #
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
    cd ${WAL}
    ${GIT_EXE} init
}
# - - - Git add - - - #
gitAdd() {
    ${GIT} add --all
}
# - - - Git pull - - - #
gitPull() {
    ${GIT} pull origin master
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
# - - - Git Revert - - - #
gitRevert() {
    ${GIT} show ${treeish}:${dom}/${typ}/${obj} > "${WAL}/${dom}/${typ}/${obj}"
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
# - - - Add Remote - - - #
addRemote() {
    if [[ -z ${URI} ]] ;then
        echo
        echo "Enter the SSH URI for the remote repository"
        echo "i.e. user@git.ssh.example.com:git/${WAL}.git"
        read -p "URI: " URI
    fi
    if [[ ${URI} ]]
        then ${GIT} remote add origin "${URI}"
        gitPush
    else
        echo "Abort... No URI"
    fi
}
# - - - Clone Remote Wallet - - - #
cloneRemote() {
    if [[ -z ${URI} ]] ;then
        echo
        echo "Enter the SSH URI for the remote repository"
        echo "i.e. user@git.ssh.example.com:git/${WAL}.git"
        read -p "URI: " URI
    fi
    if [[ ${URI} ]] ;then
        [[ -d ${WAL} ]] && mv ${WAL} ${WAL}-preclone
        mkdir -p ${WAL}
        ${GIT} clone "${URI}"
        [[ -f ${WAL}-preclone/.pgw.conf ]] && \
            cp ${WAL}-preclone/.pgw.conf ${WAL}/.pgw.conf
        [[ -f ${WAL}-preclone/.gitignore ]] && \
            cp ${WAL}-preclone/.gitignore ${WAL}/.gitignore
        #
        [[ -f ${WAL}/.pgw.conf ]] && createConfig
        gitSync
    else
        echo "Abort... No URI"
    fi
}
# - - - Create Remote - - - #
makeRemote() {
    echo
    echo " - - - To create a Remote Sync Server - - -"
    echo
    if [[ -z ${URI} ]] ;then
        echo "Enter the SSH login URI for server to create repository on"
        echo "i.e. user@ssh.example.com"
        read -p "URI: " URI
    fi
    if [[ ${URI} ]] ;then
        ${SSH} ${URI} "mkdir -p ~/git/${WAL}.git"
        ${SSH} ${URI} "cd ~/git/${WAL}.git ;git init --bare"
        URI+="git/${WAL}.git"
        addRemote
        echo
        echo "This wallet can be used on and synchronized with other computers"
        echo "To do so run the following command on the other computers"
        echo
        echo "${SELF} -clone-remote ${URI}"
        echo
    else
        echo "Abort... No URI"
    fi
}
# - - - Version Select - - - #
versionSelect() {
    echo
    echo "                    :: Select Version ::"
    echo
    index=$(versionIndex |sed -e 's/ /#/g')
    numberedList "version"
    echo
    read -p "$(echo -ne ${WHT}) Enter choice #$(echo -ne ${clr}) " choice
    local line=$(echo "${index}" |sed -n "${choice}p")
    treeish="$(echo ${line} |cut -d '#' -f 1)"
    index=''
}
# - - - Select from list - - - #
objectSelect() {
    echo
    echo "                     :: Select Item ::"
    echo
    index=$(itemIndex)
    numberedList "item"
    echo
    read -p "$(echo -ne ${WHT}) Enter choice #$(echo -ne ${clr}) " choice
    dom=$(echo "${index}" |sed -n "${choice}p" |cut -d '/' -f 1)
    typ=$(echo "${index}" |sed -n "${choice}p" |cut -d '/' -f 2)
    obj=$(echo -n "${index}" |sed -n "${choice}p" |cut -d '/' -f 3)
    index=''
}
# - - - tree command view - - - #
treeUI() {
    local tree_lines=${1}
    local term_lines=${2}
    cd ${WAL}
    local tree_cmd="${TREE} --noreport --prune"
    local search=""
    if [[ ${typ} =~ ":accnt:" ]]
        then local search+="keyring:"
        else local search+="${typ}:"
    fi
    [[ ${tree_lines} -gt ${term_lines} ]] && search+="pager:"
    [[ ${NO_COLOR} ]] && search+="nocolor:"
    case ${search} in
        vault:)
            ${tree_cmd} -P "*.asc" ${dom}
        ;;
        vault:pager:)
            ${tree_cmd} -C -P "*.asc" ${dom} | ${PAGER}
        ;;
        vault:pager:nocolor:)
            ${tree_cmd} -n -P "*.asc" ${dom} | ${PAGER}
        ;;
        vault:nocolor:)
            ${tree_cmd} -n -P "*.asc" ${dom}
        ;;
        keyring:)
            ${tree_cmd} -I "*.asc" ${dom}
        ;;
        keyring:pager:)
            ${tree_cmd} -C -I "*.asc" ${dom} | ${PAGER}
        ;;
        keyring:pager:nocolor:)
            ${tree_cmd} -n -I "*.asc" ${dom} | ${PAGER}
        ;;
        keyring:nocolor:)
            ${tree_cmd} -n -I "*.asc" ${dom}
        ;;
        pager:)
            ${tree_cmd} -C ${dom} | ${PAGER}
        ;;
        pager:nocolor:)
            ${tree_cmd} -n ${dom} | ${PAGER}
        ;;
        nocolor:)
            ${tree_cmd} -n ${dom}
        ;;
        *)
            ${tree_cmd} ${dom}
    esac
}
# - - - Version Index - - - #
versionIndex() {
    cd ${WAL}
    [[ ${typ} =~ ":accnt:" ]] && local KorF="keyring" || local KorF="${typ}"
    ${GIT} --no-pager log --oneline *${dom}*/*${KorV}*/*${obj}*
}
# - - - Item Index - - - #
itemIndex() {
    cd ${WAL}
    local domains="ls --color=never"
    local find_cmd="find $(${domains}) -type f"
    local search=""
    [[ ${dom} ]] && local search+="dom:"
    [[ ${typ} ]] && local search+="typ:"
    [[ ${obj} ]] && local search+="obj:"
    case ${search} in
        dom:)
            ${find_cmd} |grep -E "${dom}//*"
        ;;
        dom:typ:)
            ${find_cmd} |grep -E "${dom}//*" |grep -E "${typ}//*"
        ;;
        dom:typ:obj:)
            ${find_cmd} |grep -E "${dom}//*" |grep -E "${typ}//*" |grep "${obj}"
        ;;
        dom:obj:)
            ${find_cmd} |grep -E "${dom}//*" |grep -E "${obj}//*"
        ;;
        typ:obj:)
            ${find_cmd} |grep -e "${typ}//*" |grep "${obj}"
        ;;
        obj:)
            ${find_cmd} |grep "${obj}"
        ;;
        typ:)
            ${find_cmd} |grep -e "${typ}//*"
        ;;
        *)
            ${find_cmd}
    esac
}
# - - - Numbered list - - - #
numberedList() {
    local index_type=${1}
    local ln=1
    if [[ -z ${NO_COLOR} ]]
        then evalColors ;color_one=${blu} ;color_two=${wht}
        else color_one='' ;color_two=''
    fi
    case ${index_type} in
        version)
            local color=${color_one}
            for line in ${index} ;do
                echo -ne "${color}"
                echo -ne "-> ${ln} - ${line}" |sed -e 's/#/ /g'
                echo -e "${clr}"
                if [[ ${color} == ${color_one} ]]
                    then local color=${color_two}
                    else local color=${color_one}
                fi
                local ln=$(expr $ln + 1)
            done
        ;;
        item)
            local color=${color_one}
            for line in ${index} ;do
                echo -ne "${color}"
                dom="$(echo ${line} |cut -d '/' -f 1)"
                typ="$(echo ${line} |cut -d '/' -f 2)"
                obj="$(echo ${line} |cut -d '/' -f 3)"
                n=$(expr 26 - $(echo -n ${dom} |wc -c))
                while [[ $n -gt 0 ]] ;do n=$(expr $n - 1) ;dom+=" " ;done
                n=$(expr 10 - $(echo -n ${typ} |wc -c))
                while [[ $n -gt 0 ]] ;do n=$(expr $n - 1) ;typ+=" " ;done
                echo -ne "-> ${dom}- ${typ}${ln} - ${obj}"
                echo -e "${clr}"
                if [[ ${color} == ${color_one} ]]
                    then local color=${color_two}
                    else local color=${color_one}
                fi
                local ln=$(expr $ln + 1)
            done
    esac
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
