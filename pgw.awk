#!/usr/local/bin/gawk -f
# NOTE: Development will be focused on OpenBSD support from now on
BEGIN {
  OFS="\n"
  URI=ARGV[1]
  HOME=ENVIRON["HOME"]
  PGWALLET=ENVIRON["PGWALLET"] # arg for now
  if (! PGWALLET){PGWALLET=(HOME"/.gnupg/wallet")}
  USER=ENVIRON["USER"]
  PWD=ENVIRON["PWD"]
  DISPLAY=ENVIRON["DISPLAY"]
  STY=ENVIRON["STY"]
  GPG_AGENT_INFO=ENVIRON["GPG_AGENT_INFO"]
  GPG_TTY=ENVIRON["GPG_TTY"]
  KEYIDS=""
  DIGEST="SHA512"
  CIPHER="TWOFISH"
  HOSTNAMECMD="/usr/bin/hostname"
  READLINK="/usr/bin/readlink -f "
  SCREEN="/usr/local/bin/screen"
  XCLIP="/usr/local/bin/xclip"
  rv=(XCLIP" -selection primary:")
  rv=(rv XCLIP" -selection secondary:"XCLIP" -selection clipboard")
  split(rv,xclip,":") #rv strage but save mem
  if (length(pager) == 0) {pager="/usr/bin/less"}
  CRYPTBOARD="/usr/local/bin/cryptboard"
  MKDIR="/usr/local/bin/mkdir"
  PAGER="/usr/local/bin/less"
  SSH="/usr/bin/ssh"
  XDO="/usr/local/bin/xdotool"
  XDGO="/usr/bin/xdg-open"
  PISH="/usr/local/bin/pish"
  GPG="/usr/local/bin/gpg2"
  gpg=(GPG" --armor --quiet --batch --yes ")
  GIT="/usr/bin/git"
  git=("cd "PGWALLET" ;"GIT" -C "PGWALLET)
  #
  rv=0
  main()
}
# -----------------------------------------------------------------------------
function main(  i,n,a,uri,parts) {
  sub("pgw:","",URI); sub("(^//)|(^/)",":",URI) # Convert
  part="keyinfo hostname commit filename action argument"
  char="@ / : , ="; split(char,chars," "); uri=URI; hostname=uri
  for(n in chars)
  {
    split(uri,a,chars[n])
    if(2 in a){
      if(3 in a){ exit n }
      else{
        printUriParse(uri,n,a)
        if(n == 1){keyinfo=a[1]; hostname=a[2]}
        else if(n == 2){hostname=a[1]; commit=a[2]}
        else if(n == 3){
          if (commit){commit=a[1]}
          else{hostname=a[1]}
          filename=a[2]
        }
        else if(n == 4){
          if (filename){filename=a[1]}
          else if (commit){commit=a[1]}
          else {hostname=a[1]}
          action=a[2]
        }
        else if(n == 5){action=a[1]; argument=a[2]}
        uri=a[2]
      }
    }
  }
  if(! action){
    if(filename && ! keyinfo){action="out"}
    else{
      if(keyinfo){
        if(DISPLAY){action="clip"; argument=1}
        else if(STY){action="screen"}
        else{rv+=1}
      }else{action="xdgopen"}
    }
  }
  if(rv){exit rv} # Return all errors, not just first
  # . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .
  actionList="gpg out auto clip screen xdgopen list vlist help update"
  actionList=(actionList" clone addremote mkremote")
  split(actionList,actions," ")
  for(i=1; i <= length(actions); i++){if(action == actions[i]){break}}
  if((i < 7 || i > 10) && ! hostname){rv+=2}
  if(actions[i] == "gpg"){
    if(argument && argument !~ "^/"){
      cmd=(READLINK argument)
      cmd | getline argument
      close(cmd)
    }
    if(argument && ! keyinfo && ! filename){
      split(argument,parts,"/")
      for (n in parts) {filename=parts[n]}
    }
  }
  else if (actions[i] == "out"){
    if(argument && argument !~ "^/"){argument=(PWD"/"argument)}
  }
  else if (actions[i] == "clip"){
    if(CRYPTBOARD){argument=3}
    else if(! argument || argument < 0 || argument > 3){argument=1}
  }
  if(i < 7){
    if(! keyinfo && ! filename){keyinfo="url"}
    if(keyinfo && filename){rv+=4}
    if(keyinfo ~ "^:" ? 3 in lines : 2 in lines){action="list"}
  }
  if(i > 1 && i < 8){complete()}
  if(i < 7){if(filename && filename !~ ".asc$"){filename=(filename".asc")}}
  else if(i < 13 && i > 10 && (! keyinfo || ! filename)){rv+=8}
  else if(i == 13 && ! keyinfo){rv+=16}
  if(i == 1){
    if(keyinfo){fpto=(hostname"/keyring/"keyinfo)}
    else{fpto=(hostname"/vault/"filename)}
  }
  if(rv){exit rv+=100}
    printValues(i)
  run()
  return ""
}
# -----------------------------------------------------------------------------
function run() {
  if (action == "help") {print "help"}
  else if (action == "list") {printLines()}
  else if (action == "vlist") {versions(); printLines()}
  else if (action == "update") {update()}
  else if (action == "clone") {clone()}
  else if (action == "addremote") {addremote()}
  else if (action == "makeremote") {makeremote()}
  else if (action == "revert") {revert()}
  else if (keyinfo ~ "^:"){keyinfo="" ;account()}
  else if (action == "out") {out()}
  else if (action == "screen") {screen()}
  else if (action == "gpg") {encrypt()}
  else if (action == "auto") {auto()}
  else if (action == "clip") {clip()}
  else if (action == "xdgopen") {xdgopen()}
  else {
    printf "%s %s %s", "No function for action: (", action, ")\n"
    exit 254
  }
  return ""
}
# -----------------------------------------------------------------------------
function account() {
  object=lines[2][3]; fpto=(PGWALLET"/"hostname"/"type"/"object)
  run()
  if(action != "auto"){
    print "The username has been decrypted."
    print "Enter Y to decrypt password, or N to quit."
    cmd="read -p 'Enter (y/n): ' x ;echo -n ${x}"
    cmd | getline rv;                                               close(cmd)
    tolower(rv); if(rv != "y"){exit 0}
  }
  object=lines[1][3]; fpto=(PGWALLET"/"hostname"/"type"/"object)
  run()
  return ""
}
# -----------------------------------------------------------------------------
function complete(  cmd,v,line,a,i,e,y) {
  # Need to check for exact match and not search if so
  if (keyinfo){type="keyring"; object=keyinfo}
  else if (filename){type="vault"; object=filename}
  fpto=(PGWALLET"/"hostname"/"type"/"object)
  if(object ~ "^:"){sub(":","",object); a=1}
  cmd=(git" ls-files"); i=0
  while ( (cmd | getline v) > 0){
    split(v,line,"/")
    if(line[1] ~ hostname && line[1] !~ "(.gitignore)|(.pgw.conf)"){
      if(line[2] ~ type){
        if(a){
          if(line[3] ~ "(^user:)|(^pass:)"){split(line[3],y,":")
            if(y[2] ~ object){(++i); for(e in line){lines[i][e] = line[e]}}
          }
        }
        else{
          if(line[3] ~ object){(++i); for(e in line){lines[i][e] = line[e]}}
        }
      }
    }
  }
  hostname=lines[1][1]
  if (keyinfo){type="keyring"; object=lines[1][3]}
  else if (filename){type="vault"; object=lines[1][3]}
  fpto=(PGWALLET"/"hostname"/"type"/"object)
  return ""
}
# -----------------------------------------------------------------------------
function versions(  s,i,e) {
  if (hostname){s=("*"hostname"*")}
  if (keyinfo){s=(s"/keyring/*"keyinfo"*")}
  else if (filename){s=(s"/vault/*"filename"*")}
  cmd=(git" --no-pager log --oneline "s)
  while ( (cmd | getline v) > 0){split(v,line," "); (++i)
    for(e in line){lines[i][e] = line[e]}
  }
  return ""
}
# -----------------------------------------------------------------------------
function printLines(  f,i,e,line) {
  if(action == "vlist"){
    f=("  %-9s %-16s %-8s %-12s")
    for (i in lines){
      printf ""
      printf f, lines[i][1], lines[i][2], lines[i][3], lines[i][4]
      for(e=5; e<=length(lines[i]); e++){printf "%s %s", " ", lines[i][e]}
      printf "\n"
    }
  }
  else{
    f="  %-16s %-8s %-12s %s"
    for (i in lines){
      printf "  %-24s %-8s %-12s %s", lines[i][1], lines[i][2], lines[i][3],"\n"
    }
  }
  return ""
}
# -----------------------------------------------------------------------------
function encrypt(  cmd,gpgenc,X,x,H) {
  gpgenc=(gpgBase" --sign")
  if (KEYIDS) {
    split(KEYIDS,keyids," ")
    for (key in keyids) {gpgenc=(gpgenc" -r "key)} 
  }
  else {gpgEjnc=(gpgenc" --default-recipient-self ")}
  cmd=(MKDIR" -p "fpto)
  rv=system(cmd);                                                   close(cmd)
  #
  if (length(filename) != 0) {
    #
    cmd=(gpgenc" -o "fpto" -e "argument)
    rv=system(cmd);                                                 close(cmd)
  }
  else if (length(argument) != 0) {
    cmd=("echo -n '"argument"' | "gpgenc" -o "fpto" -e ")
    rv=system(cmd);                                                 close(cmd)
  }
  else if (keyinfo == "url" || keyinfo ~ "user:*") {
    #
    cmd=("read -p 'Enter value for key ["keyinfo"]: ' x ;echo -n $x")
    cmd | getline argument;                                         close(cmd)
    cmd=("read -p 'Save ["keyinfo"]<"argument"> (y/n): ' x ;echo -n $x")
    cmd | getline X; x=tolower(X);                                  close(cmd)
    cmd=("echo -n '"argument"' | "gpgenc" -o "fpto" -e ")
    if (x == "y")
    {rv=system(cmd)} else {print "Abort . . ."};                    close(cmd)
  }
  else{
    #
    realrv=";if [[ $PIPESTATUS -gt 0 ]] ;then grep -qs '' /XRz6euQoi9 ;fi"
    cmd=(PISH" | "gpgenc" -o "fpto" -e "realrv)
    rv=system(cmd);                                                 close(cmd)
    if (rv == 0) {
      cmd=(gpg"  --gen-random 1 24")
      cmd | getline S;                                              close(cmd)
      H=(gpg" --print-md "DIGEST)
      cmd=("[[ $(echo -n \""S"$("gpg" -d "fpto" )\" | "H") == ")
      cmd=(cmd"$(echo -n \""S"$("PISH" ;(($? != 0)) && echo -n '"S"')\" | "H")")
      cmd=(cmd" ]]")
      rv=system(cmd);                                               close(cmd)
    }
  }
  return ""
}
# -----------------------------------------------------------------------------
function out(  cmd) {
  if (argument){cmd=(gpg" -o "argument" -d "fpto)}
  else {cmd=(gpg" -d "fpto)}
  rv=system(cmd);                                                   close(cmd)
  return ""
}
# -----------------------------------------------------------------------------
function auto(  cmd) {
  # FWI xdg-open url
  if(! xwindow){
    cmd=(XDO" selectwindow 2>/dev/null")
    while((cmd | getline xwindow) > 0){continue};                   close(cmd)
  }
  cmd=(XDO" windowraise "xwindow)
  cmd=(cmd" ;"XDO" type \"$("gpg" -d "fpto")\"")
  cmd=(cmd" ;"XDO" key --window "xwindow)
  print object
  if(object ~ "^user"){cmd=(cmd" Tab")}else{cmd=(cmd" Return")}
  rv=system(cmd);                                                   close(cmd)
  return ""
}
# -----------------------------------------------------------------------------
function xdgopen(  cmd) {
  cmd=(XDGO" \"$("gpg" -d "fpto")\"")
  rv=system(cmd);                                                   close(cmd)
  if(rv){rv=0; action="clip"; argument=1; run()}
  return ""
}
# -----------------------------------------------------------------------------
function clip(  cmd) {
  if (CRYPTBOARD){cmd=("cat "fpto" | "xclip[3]" -in")}
  else {cmd=(gpg" -d "fpto" | "xclip[argument]" -in")}
  rv=system(cmd);                                                   close(cmd)
  return ""
}
# -----------------------------------------------------------------------------
# Need to write tmux function Will be super easy compared to screen
function screen(  cmd) {
  if(argument){cmd=(SCREEN" -S "STY" -p "argument" -X stuff \"$("gpg" -d "fpto")\"")}
  else{cmd=(SCREEN" -S "STY" -X register . \"$("gpg" -d "fpto")\"")}
  rv=system(cmd);                                                   close(cmd)
  return ""
}
# -----------------------------------------------------------------------------
function update() {
  rv=system(gitPull);                                           close(gitPull)
  return ""
}
# -----------------------------------------------------------------------------
function clone() {
  print "Function clone"
  return ""
}
# -----------------------------------------------------------------------------
function addremote() {
  print "Function addremote"
  return ""
}
# -----------------------------------------------------------------------------
function gitClean(  cmd,i,a,v,untracked) {
  cmd=("grep -qs '' "PGWALLET"/.git/config")
  rv=system(cmd);                                                   close(cmd)
  if (rv == 0){
    cmd=(git" status --porcelain")
    while ( (cmd | getline v) > 0){
      if (v ~ "^??"){
        sub("?? ","",v)
        if (length(v) != 0){a[++i] = v}
      }
    }
    close(cmd)
    cmd=("cd "PGWALLET" ;/usr/bin/rm -rf")
    for (untracked in a){cmd=(cmd" "untracked)}
    rv=system(cmd);                                                 close(cmd)
    cmd=(git" checkout -- .")
    rv=system(cmd);                                                 close(cmd)
  }
  return ""
}
# -----------------------------------------------------------------------------
function gitCommit(  cmd,LOCALHOST) {
  if (commit){commit=(":"commit)}
  HOSTNAMECMD | getline LOCALHOST;                          close(HOSTNAMECMD)
  cmd=(GIT" commit -m "hostname" "type" "object)
  cmd=(cmd" "action commit" "strftime("%F %T")" "USER"@"LOCALHOST"'")
  rv=system(cmd);                                                   close(cmd)
  if (commit){sub(":","",commit)}
  return ""
}
# -----------------------------------------------------------------------------
function gitSync(  cmd,r) {
  cmd=("grep -qs 'remote' "PGWALLET"/.git/config")
  rv=system(cmd);                                                   close(cmd)
  cmd=(git" init")
  if (rv == 2){rv=system(cmd);                                      close(cmd)}
  cmd=(git" add --all")
  rv=system(cmd);                                                   close(cmd)
  cmd=(git" pull origin master")
  if (! r){rv=system(cmd);                                          close(cmd)}
  gitCommit()
  cmd=(git" push orgin master")
  if (! r){rv=system(cmd);                                          close(cmd)}
  return ""
}
# -----------------------------------------------------------------------------
function gitRevert(  cmd) {
  cmd=(git" show "commit":"fpto" > "fpto)
  rv=system(cmd);                                                   close(cmd)
  if(rv){gitClean()}
  return ""
}
# -----------------------------------------------------------------------------
# * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
# -----------------------------------------------------------------------------
function printValues(i) {
  printf "%s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s",
         "  filename: ", filename, "\n",
         " hostname: ", hostname, "\n",
         "   commit: ", commit, "\n",
         "   action: ", action, "\n",
         " argument: ", argument, "\n",
         "  keyinfo: ", keyinfo, "\n",
         "        i: ", i, "\n"
  return ""
}
# -----------------------------------------------------------------------------
function printUriParse(uri,n,a) {
    printf "%s %s %s %s %s %s %s %s %s",
            "uri: ", uri, "| n: ", n,
            "| a[1]: ", a[1], "| a[2]: ", a[2], "\n"
  return ""
}
# vim: set ts=2 sw=2 tw=80 et :
