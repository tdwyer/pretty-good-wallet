#!/usr/local/bin/gawk -f
#
# Short script to re-encyrpt the whole wallet with new GPG Key
#
BEGIN {
  # If new key has same UID, i.e. bob@jackson.com, use the new Key's ID here
  NEW_UID="B79E7681"
  GPG_BIN="/usr/local/bin/gpg2"
  WALLET_DIR="/home/thomas/.gnupg/wallet"
  WALLET_OLD=(WALLET_DIR"/old")
  WALLET_NEW=(WALLET_DIR"/new")
  main()
}

function main() {
  lines=genWorkArray()
  rv=recrypt(lines)
  if (rv > 0) {
    printf "%s %s", "Fail: return value from encrypt operation: ", rv
  } else {
    printf "%s %s", "Success: return value from encrypt operation: ", rv
  }
}

function genWorkArray(  cmd, lines, line) {
  lines=""
  # Append Keys to lines
  cmd=("cd "WALLET_OLD" ;/usr/local/bin/gfind -type f ! -name \"*\.asc\"")
  while ( (cmd | getline line) > 0) {
    lines=(lines" "line)
  }
  # Append Files to lines
  cmd=("cd "WALLET_OLD" ;/usr/local/bin/gfind -type f ! -name \"*\.asc\"")
  while ( (cmd | getline line) > 0) {
    lines=(lines" "line)
  }
  return lines
}

function recrypt(lines,  line, parts, cmd, rv, old_obj, new_obj) {
  # Split lines into WORK_ARRAY
  split(lines,WORK_ARRAY," ")
  #
  # This is the work horse loop
  for(i=1; i <= length(WORK_ARRAY); i++) {
    # Split lines into WORK_ARRAY
    split(lines,WORK_ARRAY," ")
    line=WORK_ARRAY[i]
    # Split line into parts
    split(line,parts,"/")
    # Create directory tree
    cmd=("mkdir -p "WALLET_NEW"/"parts[2]"/"parts[3])
    rv=system(cmd);                                                 close(cmd)
    if (rv > 0) {
      break
    }
    # Build GPG Decyrpt to GPG Enclrypt PIPE Command
    old_obj=(WALLET_OLD"/"parts[2]"/"parts[3]"/"parts[4])
    new_obj=(WALLET_NEW"/"parts[2]"/"parts[3]"/"parts[4])
    cmd=(GPG_BIN" --quiet --batch -d "old_obj)
    cmd=(cmd" |"GPG_BIN" --quiet --batch --armor ")
    cmd=(cmd"-r "NEW_UID" -o "new_obj" -e ")
    # Decrypt old file and Encrypt to new file with New GPG Key
    rv=system(cmd);                                                 close(cmd)
    if (rv > 0) {
      break
    }
  }
  return rv
}

