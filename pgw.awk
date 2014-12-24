#!/usr/bin/awk -f
#
###############################################################################
#                                                                             #
# Copyright (c) 2014 Thomas Dwyer. All rights reserved.                       #
#                                                                             #
# Redistribution and use in source and binary forms, with or without          #
# modification, are permitted provided that the following conditions          #
# are met:                                                                    #
# 1. Redistributions of source code must retain the above copyright           #
#    notice, this list of conditions and the following disclaimer.            #
# 2. Redistributions in binary form must reproduce the above copyright        #
#    notice, this list of conditions and the following disclaimer in the      #
#    documentation and/or other materials provided with the distribution.     #
#                                                                             #
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR        #
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES   #
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.     #
# IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,            #
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT    #
# NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,   #
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY       #
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT         #
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF    #
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.           #
#                                                                             #
###############################################################################
#
# All my computers run OpenBSD
# However, I bend over backwards to make it as OS agnostic as possible.
#
#
BEGIN {
  #
  # Set all global vars
  #
  # Time in seconds until X11 Clipboard selection is cleared
  CLIPBOARD_TIMEOUT=30
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
  RM_BIN="/bin/rm"
  SHA256_BIN="/bin/sha256"
  XCLIP_BIN="/usr/local/bin/xclip"
  XDO_BIN="/usr/local/bin/xdotool"
  # Composite commands
  GIT=(GIT_BIN" -C "WALLET" ")
  GPG=(GPG_BIN" --yes --batch --quiet")
  XCLIP=(XCLIP_BIN" -selection clipboard")
  # Relative vars
  if ( ! length(ARGV1) )
    {
      ARGV1="help"
    }
  else if (index(ARGV2,":"))
    {
      split(ARGV2,COMMIT_ARGV2,":")
      COMMIT=COMMIT_ARGV2[1]
      OBJ=(COMMIT_ARGV2[2]".gpg")
    }
  else
    {
      OBJ=(ARGV2".gpg")
    }
  #
  # Clear the ARGVs so AWK dose not think they are files it should read
  #
  ARGV[1]=""
  ARGV[2]=""
  _main()
}

function _main(  cmd,rv) {
  #
  # If a commit is specified
  # Revert file to that commit before doing anything
  #
  if (length(COMMIT) )
    {
      rv=_gitRevert()
    }

  #
  # if else is cleaner and more reliable then switch case
  #
  if ( ARGV1 == "add" )
    {
      _add()
    }
  else if ( ARGV1 == "clean" )
    {
      rv=_gitClean()
    }
  else if ( ARGV1 == "find" )
    {
      _search()
    }
  else if ( ARGV1 == "help" )
    {
      _help()
    }
  else if ( ARGV1 == "log" )
    {
      rv=_gitLog()
    }
  else if ( ARGV1 == "update" )
    {
      _gitSync()
    }
  else if ( _validate() )
    {
      _search()
    }
  else if ( ARGV1 == "auto" )
    {
      _auto()
    }
  else if ( ARGV1 == "clip" )
    {
      _clip()
    }
  else if ( ARGV1 == "crypt" )
    {
      _crypt()
    }
  else if ( ARGV1 == "revert" )
    {
      _gitSync()
    }
  else if ( ARGV1 == "remove" )
    {
      _gitRm()
    }
  else if ( ARGV1 == "stdout" )
    {
      _stdout()
    }
  
  #
  # If a commit is specified and not reverting
  # Reset HEAD
  # Sure could check for things like: pgw add aoisur3:domain.com/1/u
  # However I have found then when you try to account for every crazy thing
  # a user can type in. The code end up being crazy as shit and therefor
  # unstable
  #
  if (length(COMMIT) )
    {
      rv=_gitClean()
    }
  exit
}

function _help( usage) {
  #
  # Print the help message
  #
  usage=("Usage: pgw (help|update|list|find|add|crypt|clip|auto) domain.com/1/pass")
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
  # Return > 0 if file not found
  #
  cmd=(GREP_BIN" -sq '' "WALLET"/"OBJ)
  rv=system(cmd); close(cmd)
  return rv
}

function _search(  cmd,line) {
  #
  # List all files tracked by Git in the wallet
  # If ARGV2; match it using egrep style regex
  #
  sub(/(.gpg)$/,"",OBJ)
  if (length(OBJ) )
    {
      cmd=(GIT" ls-files -- |grep -E "OBJ" ")
    }
  else
    {
      cmd=(GIT" ls-files -- ")
    }

  #
  # Print the wallet location
  # Print found files
  #
  printf "%s%s%s", "\n", WALLET, "\n"
  while ( (cmd | getline line) > 0)
    {
      gsub(/(.gpg)$/,"",line)
      printf "%s%s%s", "    ", line, "\n"
    }; close(cmd)
  return ""
}

function _stdout(  cmd,rv) {
  #
  # Allow GnuPG send plaintext to stdout
  #
  cmd=("echo -n \"$("GPG" -d "WALLET"/"OBJ" )\" ")
  rv=system(cmd); close(cmd)
  if (rv)
    {
      MESSAGE=(MESSAGE"Failed allow GnuPG to send plaintext to stdout")
    }
  return ""
}

function _clip(  cmd,rv) {
  #
  # Stuff the plaintext of file into X11 Clipboard selection
  # Spawn sleeper to clear X11 Clipboard selection after CLIPBOARD_TIMEOUT sec
  #
  cmd=("echo -n \"$("GPG" -d "WALLET"/"OBJ" )\" |"XCLIP" -i")
  cmd=(cmd" ;sleep "CLIPBOARD_TIMEOUT" && echo -n '' |"XCLIP" -i  & ")
  rv=system(cmd); close(cmd)
  if (rv)
    {
      MESSAGE=(MESSAGE"Failed to stuff plaintext into X11 Clipboard selection")
    }
  return ""
}

function _crypt(  cmd,rv) {
  #
  # Stuff the ciphertext of file into X11 Clipboard selection
  #
  cmd=("cat "WALLET"/"OBJ" |"XCLIP" -i")
  rv=system(cmd); close(cmd)
  if (rv)
    {
      MESSAGE=(MESSAGE"Failed to stuff ciphertext into X11 Clipboard selection")
    }
  return ""
}

function _auto(  cmd,rv,xwindow) {
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
  if (ERRNO)
    {
      MESSAGE=(MESSAGE"Failed to get X11 Window selection")
      exit
    }

  cmd=(XDO_BIN" windowraise "xwindow)
  cmd=(cmd" ;"XDO_BIN" type \"$("GPG" -d "WALLET"/"OBJ")\"")
  rv=system(cmd); close(cmd)
  if (rv)
    {
      MESSAGE=(MESSAGE"Failed to autotype plaintext")
    }
  return ""
}

function _add(  cmd,rv,hashOne,hashTwo) {
  #
  # Use pinentry via pish wrapper script
  # Encrypt string to file and have user verify
  #

  if (_makeDirs())
    {
      MESSAGE=(MESSAGE"Failed to make directory path to add new file")
      exit
    }

  #
  # Get string with pinentry
  # Encrypt pinentry stdout to file
  # 
  # Cant catch the exit status of pinentry reliably
  # because I know of now universal way to check PIPESTATUS in ALL shells
  # In Bash you can check $PIPESTATUS[1]
  # However AWK will run system commands in whatever is the users default shell
  #
  # BUT as long as the user Cancels the second pinentry prompt or
  # enters different plaintext no changes will be committed
  #
  cmd=(PISH_BIN" |"GPG" -a --default-recipient-self -o "WALLET"/"OBJ" -e ")
  rv=system(cmd); close(cmd)
  if (rv)
    {
      MESSAGE=(MESSAGE"Failed encrypt file")
      rv=_gitClean()
      exit
    }

  #
  # Get sha256 hash of the plaintext version of newly saved file
  #
  cmd=(GPG" -d "WALLET"/"OBJ" | "SHA256_BIN)
  cmd | getline hashOne; close(cmd)
  if (ERRNO)
    {
      MESSAGE=(MESSAGE"Failed to get sha256 hash of newly added file")
      rv=_gitClean()
      exit
    }

  #
  # Have user re-enter string and get the sha256 hash
  #
  cmd=(PISH_BIN" | "SHA256_BIN)
  cmd | getline hashTwo; close(cmd)
  if (ERRNO)
    {
      MESSAGE=(MESSAGE"Pinentry failled when validating newly added file")
      rv=_gitClean()
      exit
    }

  #
  # If the hash of the plaintext in newly saved file
  # dose not equal the hash of the second string entered
  # _gitClean()
  # Else
  # _gitSync()
  #
  if (hashOne == hashTwo)
    {
      _gitSync()
    }
  else
    {
      rv=_gitClean()
    }

  return ""
}

function _makeDirs(  cmd,rv,parts,dirs,i) {
  #
  # Create directory path for new file
  #
  split(OBJ,parts,"/")
  dirs=parts[1]
  for (i=2; i<length(parts); i++)
    {
      dirs=(dirs"/"parts[i])
    }
  cmd=(MKDIR_BIN" -p "WALLET"/"dirs)
  rv=system(cmd); close(cmd)
  if (rv)
    {
      MESSAGE=(MESSAGE"Failed to create directory path for new file")
    }
  return ""
}

function _gitLog(  cmd,rv) {
  #
  # Show git log
  #
  cmd=(GIT" --no-pager log --oneline --reverse ")
  rv=system(cmd); close(cmd)
  if (rv)
    {
      MESSAGE=(MESSAGE"Failed to list the git log")
    }
  return ""
}

function _gitSync(  cmd,rv) {
  #
  # Sync local Git repository with remote 'correctly'
  #
  # git add --all
  # git pull origin master
  # git commit "useful message"
  # git push origin master
  #
  rv=_gitAdd()
  if (rv)
    {
      rv=_gitClean()
      exit
    }
  rv=_gitPull()
  rv=_gitCommit()
  if (rv)
    {
      rv=_gitClean()
      exit
    }
  rv=_gitPush()
  if (rv)
    {
      exit
    }
  return ""
}

function _gitAdd(  cmd,rv) {
  #
  # Add all changes to HEAD
  #
  cmd=(GIT" add --all")
  rv=system(cmd); close(cmd)
  if (rv)
    {
      MESSAGE=(MESSAGE"Failed to add changes to git repository")
    }
  return rv
}

function _gitPull(  cmd,rv) {
  #
  # Pull in all changes from remote to local
  #
  cmd=(GIT" push origin master ")
  rv=system(cmd); close(cmd)
  if (rv)
    {
      MESSAGE=(MESSAGE"Failed to pull origin master")
    }
  return rv
}

function _gitCommit(  cmd,rv,hostname) {
  #
  # Commit all changes to local
  #
  sub(/(.gpg)$/,"",OBJ)
  cmd=(HOSTNAME_BIN)
  cmd | getline hostname; close(cmd)
  if (ERRNO)
    {
      MESSAGE=(MESSAGE"Failed to get hostname")
    }
  cmd=(GIT" commit -m")
  if (length(COMMIT) )
    {
      cmd=(cmd" \""COMMIT":"OBJ)
    }
  else
    {
      cmd=(cmd" \""OBJ)
    }
  cmd=(cmd" "ARGV1" $("DATE_BIN" \"+%x %T\") "USER"@"hostname"\" ")
  rv=system(cmd); close(cmd)
  if (rv)
    {
      MESSAGE=(MESSAGE"Failed to commit changes to git repository")
    }
  return rv
}

function _gitPush(  cmd,rv) {
  #
  # Push committed changes from local to remote
  #
  cmd=(GIT" push origin master")
  rv=system(cmd); close(cmd)
  if (rv)
    {
      MESSAGE=(MESSAGE"Failed to push origin master")
    }
  return rv
}

function _gitRm(  cmd,rv) {
  #
  # Push committed changes from local to remote
  #
  cmd=(GIT" rm "OBJ)
  rv=system(cmd); close(cmd)
  if (rv)
    {
      MESSAGE=(MESSAGE"Failed to remove file")
    }
  _gitSync()
  return rv
}

function _gitRevert(  cmd,rv) {
  #
  # Revert local file to COMMIT
  #
  cmd=(GIT" show "COMMIT":"OBJ" > "WALLET"/"OBJ)
  rv=system(cmd); close(cmd)
  if (rv)
    {
      MESSAGE=(MESSAGE"Failed to revert")
      rv=_gitClean()
    }
  return rv
}

function _gitClean(  cmd,rv,line,i,untracked,testString) {
  #
  # Clean local repository
  #

  #
  # Remove all files not tracked by Git
  #
  cmd=(GIT" status --porcelain")
  while ( (cmd | getline line) > 0 )
    {
      if (match(line,"^\\?\\? ") )
        {
          sub("\\?\\? ","",line)
          if (length(line) )
            {
              untracked[i++] = line
              if (cmd_)
                {
                  cmd_=(cmd_" ;"RM_BIN" -ri "WALLET"/"line)
                }
              else
                {
                  cmd_=(RM_BIN" -rf "WALLET"/"line)
                }
            }
        }
    }; close(cmd)
  if (ERRNO)
    {
      MESSAGE=(MESSAGE"Failed to git status --porcelain ")
    }

  #
  # Reset HEAD
  #
  if (cmd_)
    {
      cmd=(cmd_" ;"GIT" checkout -- . ")
    }
  else
    {
      cmd=(GIT" checkout -- . ")
    }
  rv=system(cmd); close(cmd)
  if (rv)
    {
      MESSAGE=(MESSAGE"Failed to clean git repository")
    }
  return rv
}

END {
  #
  # Run system commands
  # Print messages
  #
  if (length(MESSAGE))
    {
      _message(MESSAGE)
    }
}
