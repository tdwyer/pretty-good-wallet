PGW - Pretty Good Wallet
========================
*A password manager you can work with*


Have you ever lost ALL your passwords because your password manager broke?

Have you ever wanted change password managers but can't do to incompatibilities?

Have you ever been concerned about *How* your password manager is encrypting your *Bank Account* information?

Have you ever wanted to change ciphers... *Snowden.. cough. cough. AES* but been unable to?

Have you ever wanted to easily run *Your own*  password sync server?


I've had all these problems and more but never found any password manager that could solve them. What has bothered me the most is that each individual function a password manager preforms has already been mastered by another program. So, coming from a Unix like perspective I have decided to make my own password manager. My intention is to use the best tool available for each specific task instead of reinventing the wheel badly. I will also _avoid doing anything out of the ordinary_ with them. This way the password manager will be extremely versatile, reliable, and easy to work with, even if this project dies.


Confidentiality, Integrity, and Availability (CIA)
--------------------------------------------------
If a functionality is not found here, it may very well be available. The beauty of using all standard tool in standard ways is that they work with all the other standard tools. So, if you want to store your GPG key on a *Trusted Platform Module (TPM)*, you can do it. If you want to unlock our GPG keyring with a SmartCard, no problem.


**Confidentiality**
  - **Transmission**
    - OpenSSH and GnuPG
      - Encrypted transmission provided by OpenSSH to Git Server
      - Contents Encrypted Locally with GnuPG
  - **Storage**
    - GnuPG Encrypts Data With Strong Ciphers
      - Supported Symmetrical Ciphers Include: TWOFISH, CAMELLIA256, BLOWFISH, AES256
    - GnuPG encrypts each password, username, file, and url into a separate file
    - OS File-System permissions mitigate risk of unauthorized access to encrypted files
  - **Processing**
    - GnuPG is given the path and name of file to encrypt NOT the contents
    - GnuPG is piped password. Work is ongoing to utilize `pinentry` instead

**Integrity**
  - **Transmission**
    - GnuPG validation with Digital Signatures and Public Key Cryptography
      - Supported Public Key algorithms RSA, ELG, DSA, ECC
    - Git validates the integrity of all data stored in the wallet with SHA1
    - OpenSSH uses TCP to insure all packets are received
  - **Storage**
    - GnuPG validation with Digital Signatures and Public Key Cryptography
      - Supported Public Key algorithms RSA, ELG, DSA, ECC
  - **Processing**
    - GnuPG output is piped directly to it's destination
      - Handling of plaintext is avoided whenever possible

**Availability**
  - **Transmission**
    - GnuPG Multi-Account Access by Encrypting to Multiple Public Keys
    - Git Server can be Accessed from HTTPS or OpenSSH which can run on Any Port
  - **Storage**
    - GnuPG Encrypt to Main Key and a Backup Key in case the Main Key is Lost
    - Git Maintains a Local Repository of the Complete Wallet and all Changes
  - **Processing**
    - Git is Trusted with the Managing Changes Submitted by Multiple Sources
    - Git is Trusted with the Ability to Rollback Changes and Recover Passwords
    - GPG-Agent provides Secure Session Management


Interoperability with Other Password Managers and Keychain Agents
-----------------------------------------------------------------


Python 2.7 Keyring Backend is fully operational and I currently use it for OfflineIMAP. Work is ongoing to provide fully native and automatic KeePass v1 Database synchronization. Currently, only export to KDBv1 but fully auto two-way sync is merely a mater of typing it in on the keyboard. Next, planed action is to replicate the *KDE Wallet* DBUS interface. This would automatically enable hundreds of programs to utilize PGW, including ThunderBird and FireFox.


**Supported Alien Password Mangers and Keychain Agents**
- **Python Keyring**
  - Python 2.7 Keyring backend is available
  - Python 3 Keyring backend should be trivial to crate
- **KeePass KeePassX**
  - Export PGW to KeePass v1 database is Fully Functional
    - The could be flipped for Auto One-Way Sync to a KDBv1 with a few lines of code
    - Two-Way Sync is merely a time management issue. There are no road bocks
    - KeePass DBv1 Python interface provided by `kppy`
- **Python 2.7 API**
  - Import PGW into a Python Object
    - Containing Vault Objects and Keychain Objects
      - Containing File Objects and Key Objects
        - With value() methods to obtain plaintext
  - Inter-Object Relations are all local Dictionary variables
    - This allows for quick and easy development of translation classes
  - Interface() Class provides a command abstraction layer
    - Guards against changes in PGW proper from braking Python programs


User Interface
--------------


Hum, come to think of it there is no GUI. I always have a shell open, where other password managers suck unbelievable bad, PGW is a nice cold beer. I suppose KeePass could be used for a GUI, after I, or someone hit hit, finishes Two-Way sync.

- **Direct Comman Line Invocation**
  - PGW provides easy to understand -flags
  - Help is actually helpful
  - Fall back to Numbered list and Prompt user for selection
- **Search Wallet in Tree View**
  - Utalizes the `tree` command or Fancy and Readable View
    - If the Tree will not fit in the terminal open in `less` or configure $PAGER
  - Search Wallet for Files and Keys
    - Simply put the string your looking for after the `-t`
    - View Only Keys and Files for one Domain by adding `-d example.com`
    - View Only Keys or View Only Files by adding just the `-k` or `-v` flag
    - Combined Any, All, or None of these search options
      - No straining your eyes reading through a crazy long list
      - The whole point of a password manager is to be EASY to use
- **Select from Numbered List**
  - Don't know exactly what your looking for? Heres a list, Enter the number...
    - Just type `pgw -clip`
      - Full List is show and you Simply enter the number of they Key you want.
    - Awe, you used the *Tree* view so you know the Domain `pgw -clip -d example.com`
      - Now only options for *example.com* are shown in the list


Common Usage Patterns
---------------------


**Input**
- **Add/Update Password**
  - Adding password, or *Key Value Pairs*, could not be easier
    - Enter Password with Interactive Prompt
      - `pgw -d example.com -k alice -e` And Enter and Re-Enter the password
        - Get username Confidentiality
          - `pgw -d example.com -k username -e`
          - `pgw -d example.com -k password -e`
        - Get URL Confidentiality
          - `pgw -d favorateWebsite -k username -e`
          - Now just save to file *url* and add it to the domain's Vault
            - `pgw -d favorateWebsite -v url -e`
    - Enter Password as Parameter
      - The limit of possibilities equals the limits of your imagination.
        - `pgw -d example.com -u alice -e -v "$(scp user@NotMyjurisdiction.con/CryptDir | openssl aes-256-xts -a -salt -d | gpg -a -r alice@example.com -d >Crypt.img ;cryptsetup luksOpen .Crypt.img CrazyComplicatedCryptImage ;mount CrazyComplicatedCryptImage /home/alice/mypassword ;cat /home/alice/mypassword/password)"`
      - Nuf' Said
- **Encrypt Any File to a Vault**
  - If you want to save a copy of your Taxes along with HnB-Rock.con
    - `pgw -d hNr-rock.con -v EZ1040-2013.pdf -e` GPG is easy but that is Dan EZ

**Output**
- **Standard Out**
  - **Get Decrypted File from a Vault**
    - Frack!, I'm getting Audited!?!
      - `pgw -d hNb-rock.con -v EZ1040-2013.pdf -stdout EZ1040-2013.pdf`
  - **Scripting**
    - This functionality is what makes interfacing with other programs so easy
      - Really...? Come on. Read the code for an example.
  - **Pipeing**
    - This is what you would use to send a password back to user@NotMyjurisdiction.con
      - `pgw -d example.com -u alice -stdout > /home/alice/mypassword/password ;bla |bla`
- **Gnu Screen**
  - Send to Copy / Scrollback Buffer
    - `pgw -d example.com -screen`
      - Okay, key *alice* is item 1, `1` and `Enter`
    - Now just use the your configured keybinding to output the Copy Buffer
      - Default Keybinding
        - `Ctrl-A` `]`
  - Send to Standard Input of program Inside a Window
    - Shoot, I'm visiting Iran but I need to log into HnB Rock's website
      - `screen` In window two `ssh user@server.us` .. `w3m ...`
      - In window one `pgw -d example.com -window 2 -v url`
      - `enter.arrow..arrow.enter.alice.enter.`
      - Back in window one `pgw -d example.com -window 2 -k alice`
      - `enter`
- **X11 Clipboard**
  - All X11 Clipboard functionality is provided by the handy `xclip` program
  - Send to Primary Selection
    - Primary Selection is pasted to the cursor location with middle click
    - `pgw -d example.com -u alice -clip 3`
  - Send to Secondary Selection
    - I have no idea what Secondary Selection is or how to access it
      - But I know how to put data into it
    - `pgw -d example.com -u alice -clip 3`
  - Send to X11 Clipboard
    - Handy, Clipboard carries across Remote Desktop, VNC, and so on
      - Clipboard is as dangerous as it is handy for the same reasons
    - `pgw -d example.com -u alice -clip 3`


Mutt Config
-----------


    set my_pw_lavabit = `pgw -d lavabit.com -k tdwyer -stdout`
    set imap_pass = $my_pw_lavabit
    set smtp_pass = $my_pw_lavabit
    account-hook $folder "set imap_user=$my_username imap_pass=$my_pw_lavabit"
