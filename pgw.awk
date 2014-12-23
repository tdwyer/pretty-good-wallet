#!/usr/bin/awk -f
#
# BEGIN
#   Setup Environment
#   Set global vars
# 
# _functions
#   Only run system commands here as a last resort
#   Try to only return exit status or system command as a string
#
# END
#   Print any final messages
#   Execute system commands
#
#
BEGIN {
  #
  # Set all global vars
  #
  ARGV1=ARGV[1]
  ARGV2=ARGV[2]
  # ENV
  DISPLAY=ENVIRON["DISPLAY"]
  HOME=ENVIRON["HOME"]
  GPG_AGENT_INFO=ENVIRON["GPG_AGENT_INFO"]
  GPG_TTY=ENVIRON["GPG_TTY"]
  STY=ENVIRON["STY"]
  TMUX=ENVIRON["TMUX"]
  TMUX_PANE=ENVIRON["TMUX_PANE"]
  USER=ENVIRON["USER"]
  # Composite vars
  WALLET=(HOME"/.gwallet")
  # Bins
  CRYPTBOARD_BIN="/usr/local/bin/cryptboard"
  DATE_BIN="/bin/date"
  GIT_BIN="/usr/local/bin/git"
  GPG_BIN="/usr/local/bin/gpg2"
  GREP_BIN="/usr/bin/grep"
  HOSTNAME_BIN="/bin/hostname"
  MKDIR_BIN="/bin/mkdir"
  PISH_BIN="/usr/site/bin/pish"
  SHA256_BIN="/bin/sha256"
  XCLIP_BIN="/usr/local/bin/xclip"
  XDO_BIN="/usr/local/bin/xdotool"
  # Composite commands
  OBJ=(SELECTION"/"WALLET)
  GIT=(GIT_BIN" -C "WALLET" ")
  GPG=(GPG_BIN" --yes --batch --quiet")
  XCLIP=(XCLIP_BIN" -selection clipboard")
  # Relative vars
  if ( ! length(ARGV1) )
    {
      ARGV1="help"
    }
  else if ( ARGV1 == "revert" )
    {
      split(ARGV2,REVERT_ARGV2,":")
      COMMIT=REVERT_ARGV2
      OBJ=(WALLET"/"REVERT_ARGV2".gpg")
    }
  else
    {
      OBJ=(WALLET"/"ARGV2".gpg")
    }
  #
  # Clear the ARGVs so AWK dose not think they are files it should read
  #
  ARGV[1]=""
  ARGV[2]=""
  _main()
}

function _main() {
  if ( ARGV1 == "help" )
    {
      _help()
    }
  else if ( ARGV1 == "update" )
    {
      CMD=_gitSync()
    }
  else if ( ARGV1 == "add" )
    {
      CMD=_add()
    }
  else if ( ARGV1 == "log" )
    {
      CMD=_gitLog()
    }
  else if ( _validate() )
    {
      _search()
    }
  else if ( ARGV1 == "crypt" )
    {
      CMD=_crypt()
    }
  else if ( ARGV1 == "clip" )
    {
      CMD=_clip()
    }
  else if ( ARGV1 == "auto" )
    {
      CMD=_auto()
    }
  else if ( ARGV1 == "revert" )
    {
      CMD=_gitRevert()
    }
  exit
}

function _help( usage) {
  #
  # Print the help message
  #
  usage=("Usage: pgw (help|update|add|crypt|clip|auto) domain.com/1/pass")
  _message(usage)
  return ""
}

function _message(msg) {
  #
  # Print the msg string cleanly
  #
  printf "%s%s%s",
         "\n", msg, "\n"
  return ""
}

function _validate(  cmd,rv) {
  #
  # Check if the file exists
  #
  cmd=(GREP_BIN" -sq '' "OBJ)
  rv=system(cmd); close(cmd)
  return rv
}

function _search(  cmd) {
  #
  # List all files tracked by Git in the wallet
  #
  cmd=(GIT" ls-files -- |grep -E \""RAW"\" ")
  printf "%s%s%s", "\n", WALLET, "\n"
  while ( (cmd | getline _line) > 0)
    {
      gsub(/(.gpg)$/,"",_line)
      printf "%s%s%s", "    ", _line, "\n"
    }
  return ""
}

function _clip(  cmd) {
  #
  # Stuff the plaintext of file into X11 Clipboard selection
  # Spawn sleeper to clear X11 Clipboard selection after 30 seconds
  #
  cmd=("echo -n \"$("GPG" -d "OBJ" )\" |"XCLIP" -i")
  cmd=(cmd" ;sleep 30 && echo -n '' |"XCLIP" -i  & ")
  return cmd
}

function _crypt(  cmd) {
  #
  # Stuff the ciphertext of file into X11 Clipboard selection
  #
  cmd=("cat "WALLET"/"RAW".gpg |"XCLIP" -i")
  return cmd
}

function _auto(  cmd,xwindow) {
  #
  # Have user select the window to act upon
  # Type the plaintext of the file
  # to current cursor position inside selected window
  #
  cmd=(XDO_BIN" selectwindow 2>/dev/null")
  while((cmd | getline xwindow) > 0)
    {
      continue
    }; close(cmd)

  cmd=(XDO_BIN" windowraise "xwindow)
  cmd=(cmd" ;"XDO_BIN" type \"$("GPG" -d "OBJ")\"")
  cmd=(cmd" ;"XDO_BIN" key --window "xwindow" Return")
  return cmd
}

function _add(  cmd,hashOne,hashTwo) {
  #
  # Use pinentry via pish wrapper script
  # Encrypt string to file and have user verify
  #

  if (_makeDirs())
    {
      MESSAGE="Failed to make directory path to add new file"
      exit
    }

  #
  # Get string with pinentry
  #
  cmd=(PISH_BIN)
  cmd | getline line; close(cmd)
  if (ERRNO)
    {
      MESSAGE="Pinentry failled"
      cmd=_gitClean()
      exit
    }

  #
  # Encrypt pinentry stdout to file
  #
  cmd=("echo -n "line" |"GPG" -a --default-recipient-self -o "OBJ" -e ")
  rv=system(cmd); close(cmd)
  if (rv)
    {
      MESSAGE="Failed to add"
      cmd=_gitClean()
      exit
    }

  #
  # Get sha256 hash of the plaintext version of newly saved file
  #
  cmd=(GPG" -d "OBJ" | "SHA256_BIN)
  cmd | getline hashOne; close(cmd)
  if (ERRNO)
    {
      MESSAGE="Failed to get sha256 hash of newly added file"
      cmd=_gitClean()
      exit
    }

  #
  # Have user re-enter string and get the sha256 hash
  #
  cmd=(PISH_BIN" | "SHA256_BIN)
  cmd | getline hashTwo; close(cmd)
  if (ERRNO)
    {
      MESSAGE="Pinentry failled when validating newly added file"
      cmd=_gitClean()
      exit
    }

  #
  # If the hash of the plaintext in newly saved file
  # dose not equal the hash of the second string entered
  # _gitClean()
  # Else
  # _gitSync()
  #
  if (hashOne != hashTwo)
    {
      cmd=_gitClean()
    }
  else
    {
      cmd=_gitSync()
    }

  return cmd
}

function _makeDirs(  cmd,parts,dirs,i,rv) {
  #
  # Create directory path for new file
  #
  split(OBJ,parts,"/")
  dirs=parts[1]
  for (i=2; i<length(parts); i++)
    {
      dirs=(dirs"/"parts[i])
    }
  cmd=(MKDIR_BIN" -p "dirs)
  rv=system(cmd); close(cmd)
  return rv
}

function _gitLog(  cmd) {
  #
  # Show git log
  #
  cmd=(GIT" log --oneline ")
  return cmd
}

function _gitSync(  cmd) {
  #
  # Sync local Git repository with remote 'correctly'
  #
  # Unlike that shitty ZX2C4 pass
  # http://www.passwordstore.org/
  # or its shitty android version zeapo Android-Password-Store
  # https://github.com/zeapo/Android-Password-Store
  #
  # git add --all
  # git pull origin master
  # git commit "useful message"
  # git push origin master
  #
  cmd=_gitAdd()
  rv=system(cmd); close(cmd)
  if (rv)
    {
      MESSAGE="Git add failed"
      exit
    }
  cmd=_gitPull()
  rv=system(cmd); close(cmd)
  if (rv)
    {
      MESSAGE="Git pull failed"
      exit
    }
  cmd=_gitCommit()
  rv=system(cmd); close(cmd)
  if (rv)
    {
      MESSAGE="Git commit failed"
      exit
    }
  cmd=_gitPush()
  rv=system(cmd); close(cmd)
  if (rv)
    {
      MESSAGE="Git push failed"
      exit
    }
  return cmd
}

function _gitAdd(  cmd) {
  #
  # Add all changes to HEAD
  #
  cmd=(GIT" add --all")
  return cmd
}

function _gitPull(  cmd) {
  #
  # Pull in all changes from remote to local
  #
  cmd=(GIT" pull origin master")
  return cmd
}

function _gitCommit(  cmd,hostname) {
  #
  # Commit all changes to local
  #
  cmd=(HOSTNAME_BIN)
  cmd | getline hostname; close(cmd)
  if (ERRNO)
    {
      MESSAGE="Failed to get hostname"
    }
  cmd=(GIT" commit -m")
  cmd=(cmd" \""OBJ" "ARGV1" $("DATE_BIN" \"+%x %T\") "USER"@"hostname"\" ")
  return cmd
}

function _gitPush(  cmd) {
  #
  # Push committed changes from local to remote
  #
  cmd=(GIT" push origin master")
  return cmd
}

function _gitRevert(  cmd,rv) {
  #
  # Revert local file to COMMIT
  #
  cmd=(GIT" show "COMMIT":"OBJ" > "OBJ)
  rv=system(cmd); close(cmd)
  if (rv)
    {
      MESSAGE="Failed to revert"
      cmd=_gitClean()
    }
  else
    {
      cmd=""
    }
  return cmd
}

function _gitClean(  cmd,line,i,untracked) {
  #
  # Clean local repository
  #

  #
  # Remove all files not tracked by Git
  #
  cmd=(GIT" status --porcelain")
  while ( (cmd | getline line) > 0 )
    {
      if (line ~ "^??")
        {
          sub(/"?? "/,"",line)
          if (length(line) != 0)
            {
              untracked[i++] = line
              if (cmd_)
                {
                  cmd_=(cmd_" ;"RM_BIN" -rf "WALLET"/"file)
                }
              else
                {
                  cmd_=(RM_BIN" -rf "WALLET"/"file)
                }
            }
        }
    }; close(cmd)

  #
  # Reset HEAD
  #
  cmd=(cmd_" ;"GIT" checkout -- . ")
  return cmd
}

END {
  #
  # Run system commands
  # Print messages
  #
  if (length(CMD))
    {
      rv=system(CMD); close(CMD)
    }
  if (length(MESSAGE))
    {
      _message(MESSAGE)
    }
  exit rv
}
