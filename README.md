# PoSh Provisioning
A collection of handy PowerShell cmdlets for aiding in the provisioning of a freshly built machine, particularly tailored towards those who maintain IT infrastructure.

Hard Requirements:
    * Administrator rights
    * A valid configuration file
    * A brain

Soft Requirements:
    * Cloud storage provider (for creating AppData/PowerShell profile sync)

## What's all this about then?
This collection of cmdlets picks up where configuration management leaves off - they allow you to take a generalised Windows build and truly make it your own.
As the script was designed to make my PC set-up process as painless as possible it's very much tailored to suit my needs, but it's generic enough that I'm sure others can find some benefit in it too.

## What's next?
For now, the main list of "todo's" is being tracked in the individual cmdlets, eventually these will be moved out into the `issues` on GitHub.
Development is likely to be slow on this and I imagine the bulk of work will come as and when I rebuild my machines and put this module through it's paces.
In terms of new features, again as this module is tailored towards making my life easier the features I add will likely follow suit, but I am more than happy to take PR's for new features (see below).

This is also my first public repository and I don't really have any idea on what I'm doing...

## Contributing
I am more than happy to take pull requests on this project and I am not so proud as to take offence to refactoring or bug fixes. 
I'm not perfect and my code is most certainly not either 😛

Priority will of course be given to bug fixes as new features require time to test.

## Getting Started

### Creating a configuration file
As it stand if you want to use this repo you'll need to pass in a valid configuration file, this takes the form of a `JSON` file, but don't worry if you've never used JSON before there's an `template_configuration.json` file in the repo that contains a rough template and I'll guide you through how to edit it and create your own file here.

tl;dr: Keys are on the left, values on the right. Any key starting with a `*` can be renamed, any key starting with a `-` means the pair can be deleted and anything with `*/-` means it can be renamed **or** deleted.

- `Builds` this denotes the start of the **builds** section   
    - `Buildname` the name of the build (eg `work`) this is what you'll pass to the `-BuildType` parameter in the `Intialize-NewBuild` cmdlet  
    - `admin_account` if specifed then the cmdlet will ensure that this account has a home directory on the system and copy a PowerShell profile  
    - `domain` if `admin_account` is specified this is the domain to use.  
    - `CloudStorage` the path to the local cloud storage path. (accepts PowerShell environment variables such as `$env:OneDrive`)  
    - `GitSSHMethod` the type of SSH method to use for GitHub (either `OpenSSH` or `PuTTY`)  
    - `GitName` the name to use in your global gitconfig  
    - `GitEmail` the email address registered to your GitHub account (must match for GPG to work)  
    - `ppks` the names of any PuTTY keys you'd like to be created  
    - `GitRepos` this where you'll specify the git repos you want to clone, along with the folder you'd like to clone them into  
        - `FolderName` the name of the folder to clone the suceeding git repos into  
            - `git_repo_ssh_address` the ssh address of the git repo to clone  
    - `ChocoPackages` this is where you'll define the applications you want to install  
        - `package_name` the name of the packages as per chocolatey  
            - `version` the version of the package to install (use `latest` for the latest version)  
    - `VSCodeExts` this where you'll specify any VSCode extensions you want to install  
        - `vs_code_extension_id` the VSCode extension ID as per the marketplace  
    - `OneDriveJunctions` this where you'll specify the SyncData (see below)  
        - `file\folder_name_in_cloud_storage` the path to the where the file/folder is in your cloud storage (see below)  
            - `Local file\folder destination` the path you want to be linked locally (accepts PowerShell environment variables such as `$env:OneDrive`)  
- `CommonPackages` Any common packages to be installed (same format as `ChocoPackages` above)  
- `CommonRepos` Any common repos to be cloned (same format as `GitRepos` above)  
- `CommonVSCodeExts` Any common VSCode extension to be installed (same format as `VSCodeExts` above)  


### Setting up cloud storage
If you want to maintain AppData and PowerShell profile consistency between machines then you'll need to setup some cloud storage.
The cloud storage can be whatever platform you want as long as it presents itself as a standard local folder in Windows, you then pass this folder in to the `foo` field in the configuration file (see above).

You need to ensure there's a `.provisioning` folder in whatever path you provided for `foo`, for example if you provided `C:\Users\JoeBloggs\OneDrive\` as the path for `foo` then you'd need to ensure that you create the `.provisioning` folder in `C:\Users\JoeBloggs\OneDrive\` (`C:\Users\JoeBloggs\OneDrive\.provisioning`).
Withing the `.provisioning` folder you'd need to create another folder called `SyncData` - this where all of your AppData will end up.

Currently the `SyncData` folder will need to contain all the data you wish to keep synchronised already to avoid errors, in the future I hope to remove this rquirement.
For each file/folder you want to sync you'll need a key/value pair in your configuration file (see above).

**Wait, why cloud storage?**  
By my calculations cloud storage is the most senible place to perform these kinds of syncs, it's fairly resilient and reasonably secure (providing the permissions aren't changed) but the big advantage is that it allows for consistency by contantly syncing.
Take VSCode for example, I sync the `settings.json` for my work machine, which means that anytime I rebuild, all of my preferences are pulled right back in and I don't have to spend hours getting things just the way I like all over again.

**Ok, but why symlinks?**  
Symlinks have the advantage of keeping the file/folder in it's original location and simply placing a kind-of shortcut to it in a secondary location, typically cloud storage is dumb to this and just treats the symlink as a regular file, ensuring whatever changes you or your application make to the original get sync'd across to the cloud.
I am under no illusions that there are problem some applications or cloud providers that this probably won't work with, but for everything I've tried it's worked so far! 😁

**But why not simply point the application to the cloud?**  
Not all applications allow you to change their default configuration paths (especially those that write to `APPDATA`), and those that do sometimes don't take kindly to having their storage pulled out from under them.
In the past I tried to use my OneDrive for Business account for everything that would allow me to use it this way, however an Office365 update caused the OneDrive client to break and when it was removed it deleted the local storage folder, this resulted in one or two apps getting extremely confused for a time.

Occasionally path lenght can be an issue too, most cloud sync apps pop their local sync folder in your users home directory, which adds bloat to the file path. Given that Windows has a 260 haracter limit for file paths this can quickly become a problem. (for example my OneDrive for business path looks like this: `C:\Users\Steve.Brown\OneDrive - CompanyName\`)
Symlinks ignore this limit.

### Tips, Tricks & Troubleshooting
If you're using a work provided cloud storage option remember to keep a backup of your configuration file somewhere so that if you ever loose access to your cloud storage you've not lost your configuration! 
In my case I keep the configuration file sync'd between both my personal and corporate OneDrive accounts, ensuring consistency as well. :) 

If you're getting errors while running the cmdlet, try running it with the `-verbose` paramter, this logs a lot more output and makes it easier to diagnose bugs.