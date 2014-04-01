#!/bin/bash
#
#   GpgWallet       GPLv3              v10.10.2
#   Thomas Dwyer    <devel@tomd.tel>   http://tomd.tel/
#
SELF="$(echo "${0}" | rev | cut -d '/' -f 1 | rev | cut -d ':' -f 1)"
WALLET="$(echo "${0}" | rev | cut -d '/' -f 1 | rev | cut -d ':' -f 2)"
if [[ "${SELF}" == "${WALLET}" ]]
    then WALLET="main"
fi
if [[ ! -d ${PGWHOME} ]] ;then
    [[ ! -d ${GNUPGHOME} ]] && GNUPGHOME="${HOME}/.gnupg"
    PGWHOME="${GNUPGHOME}/wallet"
fi
PGW="${PGWHOME}/${WALLET}"
CONFIG="${PGW}/.pgw.conf"
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
#
# - - - Main - - - #
main() {
    readConfig
    validateWallet
    parseArgs ${@}
    run
}
# - - - Validate Wallet - - - #
validateWallet() {
    if [[ -d ${PGW} && -z $(ls ${PGW}) ]] ;then
            rm -r "${PGW}"
    fi
    if [[ ! -d ${PGW} ]] ;then
        makeWallet
    fi
}
# - - - Wallet Setup - - - #
makeWallet() {
    echo
    echo "Wallet ( ${PGW} ) not found"
    mkdir -p "${PGW}" ;chmod 0700 "${PGW}"
    echo
    echo "Would you like to . . ."
    echo
    read -p "  - Clone your wallet a sync server (y/n): " ansr
    if [[ "${ansr,,}" == "y" ]] ;then
        cloneRemote
    else
        gitInit
        createConfig
        createGitignore
        syncWallet
        read -p "Would you like to add a Remote Server? (y/n): " add_yn
        if [[ "${add_yn,,}" == "y" ]] ;then
            addRemote
        else
            echo "Add a remote server with -add-remote or -make-remote"
        fi
    fi
}
# - - - Create PGW Config - - - #
createConfig() {
    echo "KEYID=${KEYID}" >> "${PGW}/.pgw.conf"
    echo "CIPHER=${CIPHER}" >> "${PGW}/.pgw.conf"
    echo "DIGEST=${DIGEST}" >> "${PGW}/.pgw.conf"
    echo "NO_COLOR=${NO_COLOR}" >> "${PGW}/.pgw.conf"
}
# - - - Create gitignore - - - #
createGitignore() {
    echo '.gitignore' >> "${PGW}/.gitignore"
    echo '.pgw.conf' >> "${PGW}/.gitignore"
}
# - - - Configure Runtime Environment - - - #
readConfig() {
    . $CONFIG 2>/dev/null # Source Wallet Configuration File
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
    if [[ ! -x ${PAGER} ]] ;then echo "less Not found" ;exit 2 ;fi
    if [[ ! -x ${GIT_EXE} ]] ;then echo "git Not found" ;exit 2 ;fi
    if [[ ! -x ${XCLIP_EXE} ]] ;then echo "xclip Not found" ;exit 2 ;fi
    if [[ ! -x ${XDO} ]] ;then echo "xdotool Not found" ;exit 2 ;fi
#    if [[ ! -x ${SCREEN} ]] ;then ;fi
    if [[ ! -x ${TREE} ]] ;then echo "tree Not found" ;exit 2 ;fi
#    if [[ ! -x ${XCRYPTB} ]] ;then ;exit 2 ;fi
    if [[ ! -x ${PINENTRY} ]] ;then echo "pinentry Not found" ;exit 2 ;fi
    if [[ ! -x ${GPG} ]] ;then echo "gpg Not found" ;exit 2 ;fi
    [[ ${PAGER} == "less" ]] && LESS="--RAW-CONTROL-CHARS"
    GIT="${GIT_EXE} -C ${PGW}"
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
# - - - Parse the arguments - - - #
parseArgs() {
    cmd='' ;dom='' ;typ='' ;obj='' ;val='' ;dst='' ;sel='' commit='' ;URI=''
    for (( i=1; i<=${#}; i++ )); do
        flag=$(echo ${@:${i}:1} | grep -G '^-')
        value=$(echo ${@:$(expr ${i} + 1):1} | grep -vG '^-')
        [[ ${value} ]] && i=$(expr $i + 1)
        #
        case ${flag} in
            -h)
                echo "${HELP}"
                exit 0
            ;;
            --help)
                echo "${MANLY_HELP}"
                exit 0
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
                cmd+=':value:' ; val="${value}"
            ;;
            -f)
                typ+='vault' ; val="$(readlink -f ${value} 2>/dev/null)"
                obj="$(echo ${value} |rev |cut -d '/' -f 1 |rev)"
                if [[ $(echo $obj |rev |cut -d '.' -f 1 |rev) != 'asc' ]]
                    then obj+=".asc"
                fi
            ;;
            -accnt)
                cmd+=':accnt:' ; typ+='keyring' ; obj="${value}"
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
                cmd+=':version:' ; commit="${value}"
            ;;
            -revert)
                cmd+='revert' ; commit="${value}"
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
# - - - If no errors run - - - #
run() {
    case ${typ} in
        keyring)
            local ok=true
        ;;
        vault)
            local ok=true
        ;;
        '')
            local ok=true
        ;;
        *)
            echo "Can no specify -k -f at the same time"
            exit 10
    esac
    case "${cmd}" in
        help)
            echo "${HELP}"
            exit 0
        ;;
        manlyhelp)
            echo "${MANLY_HELP}"
            exit 0
        ;;
        update)
            gitPull
        ;;
        revert)
            [[ -z ${dom} || -z ${typ} || -z ${obj} ]] && objectSelect
            [[ -z ${commit} ]] && versionSelect
            gitRevert
            syncWallet
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
        *tree*)
            case "${cmd}" in
                *:vlaue:*)
                    echo "-v can not be used with -list"
                    exit
                ;;
                *:version:*)
                    echo "-version can not be used with -list"
                    exit 20
                ;;
                *)
                    local tree_lines=$(expr 4 + $(treeUI | wc -l))
                    local term_lines=$(tput lines)
                    treeUI ${tree_lines} ${term_lines}
            esac
        ;;
        *list*)
            case "${cmd}" in
                *:vlaue:*)
                    echo "-v can not be used with -list"
                    exit 20
                ;;
                *:version:*)
                    versionIndex
                ;;
                *)
                    itemIndex
            esac
        ;;
        *encrypt*)
            case "${cmd}" in
                *:version:*)
                    echo "-version can not be used with -enc"
                    exit 30
                ;;
                *:accnt:*)
                    case "${typ}" in
                        vault)
                            echo "-accnt can not be used with -enc -f"
                            exit 32
                        ;;
                        keyring)
                            validateEncrypt
                            accntAction
                    esac
                ;;
                *:vlaue:*)
                    case "${typ}" in
                        vault)
                            echo "-v can not be used with -enc -f"
                            exit 34
                        ;;
                        keyring)
                            validateEncrypt
                            encryptValue
                    esac
                ;;
                *)
                    validateEncrypt
                    encryptValue
            esac
        ;;
        *decrypt*)
            case "${cmd}" in
                *:value:*)
                    echo "-v can not be used when decrypting"
                    exit 40
                ;;
                *:accnt:*)
                    case "${cmd}" in
                        *:version:*)
                            echo "Can not use -accnt when viewing old versions"
                            echo "${HELP}"
                            exit 42
                        ;;
                        *)
                            validateDecrypt
                            accntAction
                    esac
                ;;
                *:version:*)
                    validateDecrypt
                    [[ -z ${commit} ]] && versionSelect
                    gitRevert
                    decryptValue
                    gitClean
            esac
            validateDecrypt
            decryptValue
        ;;
        *)
            echo " - -> Command Not Supported: [ ${SELF} ${@} ]"
            echo "${HELP}"
            exit 250
    esac
}
# - - - Verify Encrypt - - - #
validateEncrypt() {
    if [[ -z ${dom} ]] ;then
        echo "You must provide a -d domain with encrypt command"
        exit 130
    fi
    wdir="${PGW}/${dom}/${typ}" # Shorten this validated path
    case ${typ} in
        keyring)
            if [[ -z ${obj} ]] ;then echo "${HELP}" ;exit 132 ;fi
        ;;
        vault)
            if [[ -z ${val} ]] ;then echo "${HELP}" ;exit 134 ;fi
        ;;
        *)
            echo "${HELP}"
            exit 136
    esac
}
# - - - Verify Decrypt - - - #
validateDecrypt() {
    local line=$(itemIndex |tail -n1)
    if [[ ! $(echo "${line}" |awk -F ' ' '{print 1}') -eq 1 ]] ;then
        objectSelect
    else
        dom=$(echo ${line} |awk -F ' ' '{print $1}')
        typ=$(echo ${line} |awk -F ' ' '{print $2}')
        obj=$(echo ${line} |awk -F ' ' '{print $6}')
    fi
    wdir=${PGW}/${dom}/${typ} # Shorten this validated path
    case ${dst} in
        auto)
            local ok=true
        ;;
        stdout)
            local ok=true #Can select filename. GPG prompts to overwrite
        ;;
        clip)
            [[ -z ${XCD[${sel}]} ]] && sel=1
        ;;
        screen)
            if [[ -z $STY ]] ;then
                echo ' - No $STY for GNU Screen found -'
                exit
            fi
        ;;
        window)
            $(expr ${sel} + 1 1>/dev/null 2>&1)
            if [[ ! ${?} -eq 0 ]] ;then
                echo "Destination Window number: ${sel} :is invalid"
                echo "${HELP}"
                exit 140
            fi
        ;;
        *)
            echo "${HELP}"
            exit 142
    esac
}
# - - - Account Action - - - #
accntAction() {
    [[ ${val} ]] && local keys="pass user" || local keys="user pass"
    local accnt_name="${obj}"
    case ${cmd} in
        *encrypt*)
            for key in ${keys} ;do
                obj="${key}:${accnt_name}"
                 [[ -z ${invalid} ]] && encryptValue
            done
        ;;
        *decrypt*)
            for key in ${keys} ;do
                obj="${key}:${accnt_name}"
                decryptValue
            done
    esac
    val=''
}
# - - - Encrypt value - - - #
encryptValue() {
    case "${typ}" in
        vault)
            ${GPGen} -o ${wdir}/${obj} -e ${val}
        ;;
        keyring)
            case "${cmd}" in
                *:vlaue:*)
                    echo -n "${val}" | ${GPGen} -o ${wdir}/${obj} -e
                ;;
                *)
                    local obj_typ=$(echo ${obj} |cut -d ':' -f 1)
                    if [[ "${obj_typ}" == "user" || "${obj_typ}" == "url" ]]
                        then prompt
                        echo -n "${val}" | ${GPGen} -o ${wdir}/${obj} -e
                    else
                        pinentryKeyValue
                    fi
            esac
    esac
    val=""
    [[ ${invalid} ]] && gitClean || syncWallet
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
            echo "HAY: ${?}"
            echo "Key values did not match"
            invalid=true
        fi
    else
        echo "User Aborted . . ."
        invalid=true
    fi
    echo "HAY: ${?}"
}
# - - - Decrypt value - - - #
decryptValue() {
    case "${dst}" in
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
        stdout)
            if [[ -z ${sel} ]] ;then
                ${GPGde} -d ${wdir}/${obj}
            else
                ${GPGde} -o ${sel} -d ${wdir}/${obj}
            fi
        ;;
        clip)
            if [[ -z ${XCRYPTB} ]] ;then
                ${GPGde} -d ${wdir}/${obj} | ${XCLIP} ${XCD[${sel}]} -in
            else
                cat "${wdir}/${obj}" | ${XCLIP} ${XCD[3]} -i
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
# - - - tree command view - - - #
treeUI() {
    local index=$(itemIndex)
    local raw_d=$(echo "${index}" | awk '{print $1}')
    local raw_o=$(echo "${index}" | awk '{print $6}')
    local d=$(echo -n $(echo -n "${raw_d}" |sort -u) |sed 's/ / /g')
    local o=$(echo -n $(echo -n "${raw_o}" |sort -u) |sed 's/ /|/g')

    cd ${PGW} ;local tree_cmd="${TREE} --noreport"
    local output=""
    [[ ${NO_COLOR} ]] && local output+="nocolor:"
    [[ ${tree_lines} -gt ${term_lines} ]] && local output+="pager:"
    case ${output} in
        nocolor:)
            ${tree_cmd} -n -P "${o}" ${d}
        ;;
        nocolor:pager)
            ${tree_cmd} -n -P "${o}" ${d} | ${PAGER}
        ;;
        pager:)
            ${tree_cmd} -C -P "${o}" ${d} | ${PAGER}
        ;;
        *)
            ${tree_cmd} -P "${o}" ${d}
    esac
}
# - - - Version Select - - - #
versionSelect() {
    echo
    echo "        :: Select Version ::"
    echo
    versionIndex
    echo
    read -p "$(echo -ne ${WHT}) Enter choice #$(echo -ne ${clr}) " choice
    local line=$(versionIndex ${choice})
    dom=$(echo "${line}" |awk -F ' ' '{print $7}' |awk -F '/' '{print $1}')
    typ=$(echo "${line}" |awk -F ' ' '{print $7}' |awk -F '/' '{print $2}')
    obj=$(echo "${line}" |awk -F ' ' '{print $7}' |awk -F '/' '{print $3}')
    commit="$(echo "${line}" |awk -F ' ' '{print $4}')"
}
# - - - Select from list - - - #
objectSelect() {
    echo
    echo "                         :: Select Item ::"
    echo
    itemIndex
    echo
    read -p "$(echo -ne ${WHT}) Enter choice #$(echo -ne ${clr}) " choice
    local line=$(itemIndex ${choice})
    dom=$(echo "${line}" |awk -F ' ' '{print $1}')
    typ=$(echo "${line}" |awk -F ' ' '{print $2}')
    obj=$(echo "${line}" |awk -F ' ' '{print $6}')
}
# - - - Version Index - - - #
versionIndex() {
    [[ ${NO_COLOR} || ! "${cmd}" =~ "list" ]] && local f="" || local f="c"
    [[ ${1} ]] && local s=${1} || local s=
    local yellow=$(tput setaf 3)
    local white=$(tput setaf 7)
    local nocolor=$(tput sgr0)
    cd ${PGW}
    [[ ${cmd} =~ ":accnt:" ]] && obj=":*${obj}"
    [[ ${typ} =~ "vault" ]] && obj=$(echo ${obj} |sed 's/.asc/*.asc/')
    printf " " # Hum, well this aligns it, Easy enough
    ${GIT} --no-pager log --oneline *${dom}*/*${typ}*/*${obj}* | \
    awk \
      -v i=1 \
      -v cmd=${cmd} \
      -v f=${f} \
      -v s=${s} \
      -v y=${yellow} \
      -v w=${white} \
      -v n=${nocolor} \
      -F ' ' 'ORS=" "{
      if(length(s) == 0 || s == i){
        if(f == "c"){
          if(i % 2 == 0){
            printf y
          }else{
            printf w
          }
        }
        printf "%s %3s %s %-8s", ".", i, ".", $1
        $1=""
        if(f == "c"){
          printf n
        }
        printf "%3s %-17s", $2, $3
        $2=$3=""
        print $0, "\n"
      }
      (i++)
    }'
}
# - - - Item Index - - - # Should be fast as fuck
itemIndex() {
    [[ ${NO_COLOR} || ! "${cmd}" =~ "list" ]] && local f="" || local f="c"
    [[ ${1} ]] && local s=${1} || local s=
    local blue=$(tput setaf 4)
    local white=$(tput setaf 7)
    local nocolor=$(tput sgr0)
    
    ${GIT} ls-files | \
    awk \
      -v i=1 \
      -v cmd=${cmd} \
      -v f=${f} \
      -v s=${s} \
      -v b=${blue} \
      -v w=${white} \
      -v n=${nocolor} \
      -v c=${cmd} \
      -v d=${dom} \
      -v t=${typ} \
      -v o=${obj} \
      -F '/' '{
      if($1 ~ d && $1 != ".gitignore" && $1 != ".pgw.conf"){
        if($2 ~ t){
          if($3 ~ o){
            if(c ~ ":accnt:"){
              if($3 ~ ":"){
                if(length(s) == 0 || s == i){
                  if(f == "c"){
                    if(i % 2 == 0){
                      printf b
                    }else{
                      printf w
                    }
                  }
                  printf "%24s %8s %s %3s %s %s", $1, $2, ".", i, ".", $3
                  if(f == "c"){
                    printf n
                  }
                  print " "
                }
                (i++)
              }
            }else{
              if(length(s) == 0 || s == i){
                if(f == "c"){
                  if(i % 2 == 0){
                    printf b
                  }else{
                    printf w
                  }
                }
                printf "%24s %8s %s %3s %s %s", $1, $2, ".", i, ".", $3
                if(f == "c"){
                  printf n
                }
                print " "
              }
              (i++)
            }
          }
        }
      }
    }'
}
# - - - Sync repos - - - #
syncWallet() {
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
        echo "The Wallet Git repository must be located at"
        echo "example.com:git/${WALLET}.git"
        echo
        echo "Enter the SSH URI for the remote repository"
        echo "i.e. user@git.ssh.example.com"
        read -p "URI: " URI
    fi
    URI="${URI}"
    if [[ ${URI} ]]
        then ${GIT} remote add origin "${URI}:git/${WALLET}.git"
        gitPush
    else
        echo "Abort... No URI"
    fi
}
# - - - Clone Remote Wallet - - - #
cloneRemote() {
    if [[ -z ${URI} ]] ;then
        echo
        echo "The Wallet Git repository must be located at"
        echo "example.com:git/${WALLET}.git"
        echo
        echo "Enter the SSH URI for the remote repository"
        echo "i.e. user@git.ssh.example.com"
        read -p "URI: " URI
    fi
    URI="${URI}"
    if [[ ${URI} ]] ;then
        [[ -d ${PGW} ]] && mv ${PGW} ${PGW}-preclone
        mkdir -p ${PGW}
        ${GIT} clone "${URI}:git/${WALLET}.git"
        [[ -f ${PGW}-preclone/.pgw.conf ]] && \
            cp ${PGW}-preclone/.pgw.conf ${PGW}/.pgw.conf
        [[ -f ${PGW}-preclone/.gitignore ]] && \
            cp ${PGW}-preclone/.gitignore ${PGW}/.gitignore
        #
        [[ -f ${PGW}/.pgw.conf ]] && createConfig
        syncWallet
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
    URI="${URI}"
    if [[ ${URI} ]] ;then
        ${SSH} ${URI} "mkdir -p ~/git/${WALLET}.git"
        ${SSH} ${URI} "cd ~/git/${WALLET}.git ;git init --bare"
        addRemote
        echo
        echo "This wallet can be used on and synchronized with other computers"
        echo "To do so run the following command on the other computers"
        echo
        echo "${SELF} -clone-remote ${URI}:/git/${WALLET}.git"
        echo
    else
        echo "Abort... No URI"
    fi
}
# - - - Git init - - - #
gitInit() {
    cd ${PGW}
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
    [[ ! -z ${commit} ]] && local msg+="<${commit}>"
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
    ${GIT} show ${commit}:${dom}/${typ}/${obj} > "${PGW}/${dom}/${typ}/${obj}"
}
# - - - Git clean working directory - - - #
gitClean() {
    for new_file in $(${GIT} status --porcelain |grep -G '^.?' |sed 's/^...//g')
        do rm ${PGW}/${new_file}
    done
    ${GIT} checkout -- .
}
#
# - - - RUN - - - #
main ${@}
exit 0
# vim: set ts=2 sw=2 tw=80 et :
