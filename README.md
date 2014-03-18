PGW - Pretty Good Wallet
========================
*A password manager you can work with*


* Have you ever been concerned about *How* your password manager is encrypting information?
* Have you ever wanted to use a cipher that is unsupported by your password manager?
* Have you ever wanted to easily run *Your own*  password sync server?


I've had all these problems and more but never found any password manager that could solve them. What has bothered me the most is that each individual function a password manager preforms has already been mastered by another program. So, I have decided to create a password manager/agent by using the best tool available for each specific task instead of reinventing the wheel badly. The maximum level of *Compatibility* and *Reliability* by using standard tool in standard ways.


Essentially, PGW ties together commonly trusted tools into a Password Manager and Session Agent

The projects used by PGW include:

[GnuPG The GNU Privacy Guard](https://www.gnupg.org "GnuPG The GNU Privacy Guard")
[Git --distributed-is-the-new-centralized](http://git-scm.com "Git --distributed-is-the-new-centralized")
[OpenSSH Keeping Your Communiqués Secret](http://www.openssh.com "OpenSSH Keeping Your Communiqués Secret")
[kppy Python API  to KeePass 1.x files](http://raymontag.github.io/kppy "kppy Python API  to KeePass 1.x files")
[xclip commandline interface to the X11 clipboard](http://sourceforge.net/projects/xclip "xclip commandline interface to the X11 clipboard")


Project Status
--------------


PGW is currently usable from the shell and as a Python Keyring backend, but there is still a lot of work to be done. However, even at it's current stage PGW provides many useful features which make it something to consider.


PGW Wallet Structure
--------------------


* **Wallet**
The wallet is a directory located at $GNUPGHOME/wallet by default. Found in the root of this directory is the file `.KEYID` which contains a space separated list of GPG UID's or key fingerprint to encrypt to. Also found here are directories for each **Domain**.


* **Domain**
A *Domain* directory contains a **Keyring** directory and a **Vault** directory.


* **Keyring**
Inside a *Keyring* directory is where you will find all of the **Keys** saved for that *Domain*


* **Key**
In PGW *Keys* are used to store *Clipboardable Strings*, such as *Passwords*, and *Usernames*. If the Username is not confidential, then it is advantages to create a key with the name of your accounts username and have it contain your encrypted password. Doing this improves search ability. However, it is not required nor are *Key* limited to only storing passwords.


* **Vault**
Inside a *Vault* is where you can store encrypted files. There are many more things on a computer which need to be protected and these *Vaults* provide an easy way to do that. Given that each *Domain* has it's own *Vault*, keeping these files organized is also made much easier. Encrypted files in the vault are also *backed up* to remote location and *synchronized* across all your computers with Git, so you will never lose them.

  * NOTE: If you store a file named `url` in the vault it will be imported into KeePass during PGW export-to-keepass.
  * NOTE: If you store a file named `comment` in the vault it will be imported into KeePass durring PGW export-to-keepass.
    * NOTE: :P export-to-keepass is not integrated just yet, but can be preformed from a Python shell


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
    - GnuPG is piped passwords to be encrypted.
      - Work is ongoing to utilize `pinentry` instead

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


Interoperability with Other Managers and Program
------------------------------------------------


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


#### Install the Python Keyring Backend


    cp ./PGW/Python2.7/keyring/backends/pgw.py /usr/lib/python2.7/site-packages/keyring/backends


#### Configure Python Keyring


Enable Python Keyring for your user by adding the following to
**$HOME/.local/share/python_keyring/keyringrc.cfg**


    [backend]
    default-keyring=pgw.Wallet
    keyring-path=/usr/lib/python2.7/site-packages/keyring/backends


### OfflineIMAP Configuration for Python Keyring


In the `[Repository mail.example.com-Remote]` section add a line like this.


    remotepasseval = keyring.get_password("mail.example.com", "alice")


Where `mail.example.com` is the *Domain* name you used in PGW and `alice` is the name of the *Key* which contains your password.


User Interface
--------------


The user interface is command line based and has no GUI at the moment.


- **Gnu Screen**
  - **Send to Copy Buffer**
    - `pgw -d example.com -screen`
      - Okay, key *alice* is item 1, `1` and `Enter`
    - Now just use the your configured keybinding to output the Copy Buffer
      - Default Screen Keybinding is `Ctrl-A` `]`
  - **Send to Window**
      - In Window 3 enter `pgw -d example.com -window 2 -k alice`
        - The password for alice@example.com is sent to the last cursor position in Window 2
- **Direct Comman Line Invocation**
  - Retrieved Keys and Files with a single command
  - Currently the only way to add Keys and Files to your Vault.
    - However, PGW provides intuitive -flags and a helpful `--help`
- **Search Wallet in Tree View**
  - The `tree` command is used for Fancy and Readable View of the wallet
    - If the Tree will not fit in the terminal, `less` is opened automatically
  - Search Wallet for Files and Keys
    - Simply add the string your looking for after the `-t`
    - Limit search to one Domain by adding `-d example.com`
    - View Only Keys or Files by adding `-k` or `-f`
    - Combined any, all, or none of these search options
- **Select from Numbered List**
  - Don't know exactly what your looking for? Heres a list, Enter the number...
    - Just type `pgw -clip 3`
      - Then enter the number of the item you want sent to the Clipboard.
    - If you know the Domain you can shorten the list `pgw -clip 3 -d example.com`
      - Now only options for *example.com* are shown in the list

### Encrypting Keys/Passwords and Files


**Encrypting Password and Files **
  - Adding password, or *Key Value Pairs*, could not be easier
    - Enter Password with Interactive Prompt
      - `pgw -d example.com -k alice -e` And Enter and Re-Enter the password
        - Get username Confidentiality
          - `pgw -d example.com -k username -e`
          - `pgw -d example.com -k password -e`
        - Get URL Confidentiality
          - `pgw -d favorateWebsite -k username -e`
          - Save the url to a file named *url* and add it to the domain's Vault
            - `pgw -d favorateWebsite -v url -e`
    - Enter Password as Parameter
      - `-v $Value` can added for scripted addition of passwords/key values


**Encrypt Any File to a Vault**
  - PGW makes it easy to store related documents 
    - `pgw -d exampletaxservice.com -v EZ1040-2013.pdf -e`
