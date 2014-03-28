PGW - Pretty Good Wallet
========================
*A password manager you can work with*


* Have you ever been concerned about *How* your password manager is encrypting information?
* Have you ever wanted to use a cipher that is unsupported by your password manager?
* Have you ever wanted to easily run *Your own*  password sync server?


I've had all these problems and more but never found any password manager that could solve all them. What has bothered me the most is that each individual function a password manager preforms has already been mastered by another program. So, I have decided to create a password manager/agent by using the best tools available for each specific task. The maximum level of *Compatibility* and *Reliability* is achieved by using standard tools in standard ways.


Essentially, PGW ties together commonly trusted software projects into a Password Manager and Session Agent

The projects used by PGW include:

* [GnuPG The GNU Privacy Guard](https://www.gnupg.org "GnuPG The GNU Privacy Guard")
* [Git --distributed-is-the-new-centralized](http://git-scm.com "Git --distributed-is-the-new-centralized")
* [OpenSSH Keeping Your Communiqués Secret](http://www.openssh.com "OpenSSH Keeping Your Communiqués Secret")
* [kppy Python API  to KeePass 1.x files](http://raymontag.github.io/kppy "kppy Python API  to KeePass 1.x files")
* [xclip commandline interface to the X11 clipboard](http://sourceforge.net/projects/xclip "xclip commandline interface to the X11 clipboard")


Project Status
--------------


PGW is currently fully usable from the command line and as a Python Keyring backend. There is more work to be done, but at it's current stage PGW provides many useful features which make it a solution to consider.


PGW Wallet Structure
--------------------


* **Wallet**
  The wallet is a directory located at $GNUPGHOME/wallet by default. Found in the root of this directory is the file `.KEYID` which contains a space separated list of GPG UID's or key fingerprint to encrypt to. Also found here are directories for each **Domain**.


* **Domain**
  A *Domain* directory contains a **Keyring** directory and a **Vault** directory.


* **Keyring**
Inside a *Keyring* directory is where you will find all of the **Keys** saved for that *Domain*


* **Key**
  In PGW *Keys* are used to store *Clipboardable Strings*, such as *Passwords*, and *Usernames*. If the Username is not confidential, then it is advantages to use your username as the *Key* name and encrypt your password. Doing this improves search ability. However, it is not required, nor are *Keys* limited to password storage.


* **Vault**
  Inside a *Vault* is where you can store encrypted files. There are many more things on a computer which need to be protected and these *Vaults* provide an easy way to do that. Given that each *Domain* has it's own *Vault*, keeping these files organized is made much easier. Encrypted files are also *backed up* to your remote server and *synchronized* across all your computers with Git along with the Keys.

  * NOTE: If you store a file named `url` in the vault it will be imported into KeePass during PGW export-to-keepass.
  * NOTE: If you store a file named `comment` in the vault it will be imported into KeePass durring PGW export-to-keepass.
    * NOTE: `export-to-keepass` is not integrated just yet :p, but it is just around the corner


Interoperability with Other Managers and Programs
-------------------------------------------------


- **Python Keyring**
  - Python 2.7 Keyring backend is available
- **KeePass KeePassX**
  - Export PGW to KeePass v1 database is available
    - Automatic One-Way Sync to a KDBv1 is close to completion
    - Two-Way Sync is coming
- **Python 2.7 API**
  - An Interface class is being developed and currently provides core functionality.


### Mutt Config


    set my_pw_example = `pgw -d example.com -k alice -stdout`
    set imap_pass = $my_pw_example
    set smtp_pass = $my_pw_example
    account-hook $folder "set imap_user=$my_username imap_pass=$my_pw_example"


### Python Keyring Config


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


The user interface is command line based. With it you can encrypt keys and files. Then you can access them in a few ways, such as send to the **GNU Screen** copy buffer `-screen`, *GNU Screen* window `-window #`, cursor position `-stdout`, or wire to a file `-stdout file.txt`. The X11 *Clipboard* is also destination and it selected with `-clip 1`, `2`, or `3` where `1` is Primary selection, `2` Secondary, and `3` is the Clipboard.


PGW provides a couple options to improve locating items and accessing them.

- **Search the Wallet in Tree View**
  - The `tree` command is used for Fancy and Readable View of the wallet
    - If the Tree will not fit in the terminal, `less` is opened automatically
  - Search Wallet for Files and Keys
    - Simply add the string your looking for after the `-t`
    - Limit search to one Domain by adding `-d example.com`
    - View Only Keys or Files by adding `-k` or `-f`
    - Combined any, all, or none of these search options
- **Select from Numbered List**
  - Don't know exactly what your looking for? Heres a list, Enter the number...
    - Just type `pgw -screen`
      - Then enter the number of the item you want sent to the Clipboard.
    - If you know the Domain you can shorten the list `pgw -screen -d example.com`
      - Now only options for *example.com* are shown in the list


### NEW Features


* **Auto-Type** with `-auto`
* **Add Account** in one go with `-accnt`
  * This option is ideal with `-auto` to log into websites
* **View Old Revisions** `-chrono`
* **Recover Old Revisions** `-revert`
* **Cryptboard Support** if [Cryptboard](http://github.com/tdwyer/cryptboard "Cryptboard") is installed `-clip` will put *encrypted* messages in the clipboard
* **Auto-Gen Wallet** the *Wallet* will be created
  * `git init` will run
  * `pgw.conf` will be created
* **Multi-Wallet Support** Simply by creating symbolic links
  * Have a *Work Wallet* `ln -s /usr/bin/pgw pgw:work`
    * Now run `pgw:work` to create and use the wallet `$HOME/.gnupg/work`
* **Per-Wallet Configuration** `wallet/.pgw.conf`


### Examples


**Adding website account**
  - Enter password with the interactive prompt
    - Enter `pgw -d example.com -accnt main -e`
        - Then enter your username and your password with `pinentry`
    - For url confidentiality use false or abstract *Domain* name
      - Then save the url as a key *url* which is useful with Auto-Type anyway
        - `pgw -d website01 -k url -e`
  - Enter Password as Parameter
    - Password can be added as a param or from stdout of other app like `passgen`
      - `pgw -d website01 -accnt troll -v "$(passgen 48)" -e`
  - At example.com login page use Auto-Type to log you in
    - `pgw -d website01 -accnt main -auto`
    - Then click back on the web browser


**Adding a file to the vault**
  - PGW makes it easy to store related documents 
    - `pgw -d tax.example.com -v EZ1040-2013.pdf -e`
**Get a file from a vault**
  - Just redirect `-stdout` to a file name. Like all other Unix commands
    - `pgw -d tax.examplecom -stdout >taxes.pdf`
  - You could just select from the list and specify the full path to output file
    - `pgw -stdout ~/taxes.pdf`


Confidentiality, Integrity, and Availability (CIA)
--------------------------------------------------


If a functionality is not found here, it may very well be available. The beauty of using all standard tool in standard ways is that they work with all the other standard tools. So, if you want to store your GPG key on a *Trusted Platform Module (TPM)* or *SmartCard*, you can do it.


**Confidentiality**
  - **Transmission**
    - OpenSSH provides encrypted access to Git server
  - **Storage**
    - GnuPG can encrypt data with strong ciphers
      - Supported Symmetrical Ciphers Include: TWOFISH, CAMELLIA256, BLOWFISH, AES256
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
    - GnuPG can encrypt to *multiple keys* in case the main key is lost
    - Git Maintains a Local Repository of the Complete Wallet and all Changes
  - **Processing**
    - GnuPG *multi-account access* by encrypting to all team members keys
    - Git manages changes submitted by multiple sources
    - Git provides change rollback functionality for *password recovery*
    - GPG-Agent provides *session management*

