PGW - Pretty Good Wallet
========================
*A password manager you can work with*


Why?
----


* Have you ever been concerned about *How* your password manager is encrypting information?
* Have you ever wanted to use a cipher that is unsupported by your password manager?
* Have you ever wanted to easily run *Your own*  password sync server?


I've had all these problems and more but never found any password manager that could solve all them. What has bothered me the most is that each individual function a password manager preforms has already been mastered by another program. So, I have decided to create a password manager/agent by using the best tools available for each specific task. The maximum level of *Compatibility* and *Reliability* is achieved by using standard tools in standard ways.


Essentially, PGW ties together commonly trusted software projects into a Password Manager and Session Agent

The projects used by PGW include:

* [GnuPG The GNU Privacy Guard](https://www.gnupg.org "GnuPG The GNU Privacy Guard")
* [Git --distributed-is-the-new-centralized](http://git-scm.com "Git --distributed-is-the-new-centralized")
* [OpenSSH Keeping Your Communiqués Secret](http://www.openssh.com "OpenSSH Keeping Your Communiqués Secret")
* [xclip commandline interface to the X11 clipboard](http://sourceforge.net/projects/xclip "xclip commandline interface to the X11 clipboard")


Project Status
--------------


Stable

After changing the binary paths at the top of the script, it should run on anything.

Testing on:
* OpenBSD 5.5 -stable
* OpenBSD 5.6 -current


Dependencies
------------


* [AWK](http://www.openbsd.org/cgi-bin/man.cgi?query=awk&sektion=1 "AWK")
* [pish: pinentry wrapper script writting in OpenBSD's ksh](https://github.com/tdwyer/pish "pish: pinentry wrapper script writting in OpenBSD's ksh")
* [GnuPG The GNU Privacy Guard](https://www.gnupg.org "GnuPG The GNU Privacy Guard")
* [Git --distributed-is-the-new-centralized](http://git-scm.com "Git --distributed-is-the-new-centralized")
* [OpenSSH Keeping Your Communiqués Secret](http://www.openssh.com "OpenSSH Keeping Your Communiqués Secret")
* [xclip commandline interface to the X11 clipboard](http://sourceforge.net/projects/xclip "xclip commandline interface to the X11 clipboard")
* [xdotool: Command-line X11 automation tool](http://www.semicomplete.com/projects/xdotool/ "xdotool: Command-line X11 automation tool")


Interoperability with Other Managers and Programs
-------------------------------------------------


- **Mutt**
  - Its super easy to keep your plaintext passwords out of muttrc
- **Python Keyring**
  - Removed from the project at the moment: reworking
  - Python 2.7 Keyring backend is available


### Mutt Config


    set my_pw_example = `pgw stdout example.com/password`
    set imap_pass = $my_pw_example
    set smtp_pass = $my_pw_example
    account-hook $folder "set imap_user=$my_username imap_pass=$my_pw_example"


### Python Keyring Config

**Python Keyring backend is currently no in the repo**

Enable Python Keyring for your user by adding the following to
`$HOME/.local/share/python_keyring/keyringrc.cfg`


    [backend]
    default-keyring=pgw.Wallet
    keyring-path=/usr/lib/python2.7/site-packages/PyPGW/keyring/backends


### OfflineIMAP Configuration for Python Keyring


In the `[Repository mail.example.com-Remote]` section add a line like this.


    remotepasseval = keyring.get_password("mail.example.com", "alice")


Where `mail.example.com` is the *Domain* name you used in PGW and `alice` is the name of the *Key* which contains your password.


User Interface
--------------


If a functionality is not found here, it may very well be available. The beauty of using all standard tool in standard ways is that they work with all the other standard tools. So, if you want to store your GPG key on a *Trusted Platform Module (TPM)* or *SmartCard*, you can do it.


Examples
========


Create bare repository on your server.


    ssh user@my.server.com
    user@my.server.com $ mkdir main
    user@my.server.com $ cd main
    user@my.server.com $ git init --bare
    user@my.server.com $ exit


Clone your wallet from your server.


    git clone user@my.server.com:main $HOME/.gwallet


Add some new stuff. You will be prompted to enter a string with pinentry-curses or pinentry-gtk two times. This is done to verify you have entered the string you think you did, because the string will be 'stared' out. If you mess up. Just make sure to enter a different string the second time your prompted with Pinentry.


    pgw add google.com/url # url
    pgw add google.com/1/u # username for first account
    pgw add google.com/1/p # password for first account


If you end up committing an entry, but don't like the name of the file or directory path. You can remove it.


    pgw add google.com/111/borked
    pgw remove google.com/111/borked


There are a number of ways to receive the plaintext.


    pgw auto google.com/url
    pgw clip google.com/url
    pgw stdout google.com/url


Pretty Good Wallet (pgw) is also fully compatible with my other project
[Cryptboard - An Encrypted X11 Clipboard manager](https://github.com/tdwyer/cryptboard "Cryptboard - An Encrypted X11 Clipboard manager")
With this option the ASCII Armor ciphertext will be stuffed into the X11 Clipbard selection. This is very useful if, say your RDP client is synchronizing your Clipboard.


    pgw crypt google.com/1/p


You can view the Git log.


    pgw log


This is useful, because Pretty Good Wallet (pgw) allows you to get the version of any file from any point in time. Perhaps, this feature could be used to provide some obscurity by keeping your real password a few commits back


    pgw auto 9163494:google.com/url
    pgw clip 9163494:google.com/url
    pgw crypt 9163494:google.com/url
    pgw stdout 9163494:google.com/url


You can also revert the object back to the point before you fracked it up.


    pgw revert 9163494:google.com/1/p


Finding things is also easy, provided you have some idea of what your looking for. This find function is compatible with egrep regex syntax. Make sure to use single quotes around a regex.


    pgw find
    pgw find goo
    pgw find google.com
    pgw find '^g'
    pgw find '\\.net'


You only need these command in fringe cases, because every time you make a change Pretty Good Wallet (pgw) will git-add,git-pull,git-commit,git-push. However, if you made a change while your computer could not contact to the remote repository you should manually update the wallet.


    pgw update


Maybe somehow some junk is in your wallet. This should not happen, because Pretty Good Wallet (pgw) should have caught the error and cleaned itself up. However, if it dose happen, you can just run the clean manually.


    pgw clean


Confidentiality, Integrity, and Availability (CIA)
--------------------------------------------------


**Confidentiality**
  - **Transmission**
    - OpenSSH provides encrypted access to Git server
  - **Storage**
    - GnuPG can encrypt data with strong ciphers
      - Supported Symmetrical Ciphers Include: TWOFISH, CAMELLIA256, BLOWFISH
  - **Processing**
    - GnuPG is given the path and name of file to encrypt not the contents
    - Pinentry stdout is piped directly to GnuPG stdin

**Integrity**
  - **Transmission**
    - Git validates the integrity of all data stored in the wallet with SHA1
      - Enabling GPG Key Signing of Commits is planed
    - OpenSSH uses TCP to insure all packets are received
  - **Storage**
    - GnuPG validates data with *digital signatures*
      - Supported Public Key algorithms Include: RSA, ELG, DSA, ECC
  - **Processing**
    - GnuPG output is piped directly to it's destination
      - Handling of plaintext by PGW is avoided whenever possible

**Availability**
  - **Transmission**
    - Git Server can be Accessed from HTTP, HTTPS, or OpenSSH
  - **Storage**
    - Git Maintains a Local Repository of the Complete Wallet and all Changes
  - **Processing**
    - Git manages changes submitted by multiple sources
    - Git provides change rollback functionality for *password recovery*
    - GPG-Agent provides *session management*

