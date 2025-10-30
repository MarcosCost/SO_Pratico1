# Linux Recycle Bin System
## Author

Marcos Costa 125882 <br> [Your Name] [Your Student ID]
## Description
This is a recycle bin system for linux based systems. It includes, among other features, file deletion/restauration, and recycle bin's content listing/searching/emptying.
## Installation
To setup the recycle bin system run "./recycle_bin.sh -i" or "./recycle_bin.sh initialize_recyclebin" in your terminal to setup the recycle bin in your current user's home directory.
## Usage
If no parameters are provided to recycle_bin the script will simply inform the user that it didn't recognize the operation requested.<br>

### Deleting files:
<div style="border: 2px solid #5e685fff; padding: 10px; border-radius: 5px;">
./recycle_bin.sh -d [FILES]
<br>**-example:**<br>./recycle_bin.sh -d file.txt<br>./recycle_bin.sh -d file.txt file2.txt<br>./recycle_bin.sh -d directory_to_delete<br>
</div>

### Listing Bin:
<div style="border: 2px solid #5e685fff; padding: 10px; border-radius: 5px;">
./recycle_bin.sh -l [--FLAG]<br>
**-example:**<br>./recycle_bin.sh -l<br>./recycle_bin.sh -l --detailed<br>
</div>
<br>For a lot of the following features you might need to use the file's ID which can be consulted with the feature above.<br>

### Restoring files:
<div style="border: 2px solid #5e685fff; padding: 10px; border-radius: 5px;">
./recycle_bin.sh -r [ID]|[FILENAME]<br>
**-example:**<br>./recycle_bin.sh -r 1234567890_abcdef<br>./recycle_bin.sh -r file_to_restore.txt<br>./recycle_bin.sh -r 1234567890_abcdef file_in_bin.txt<br>
</div>

### Searching Bin:
<div style="border: 2px solid #5e685fff; padding: 10px; border-radius: 5px;">
./recycle_bin.sh -s [-FLAG] [PATTERN]<br>
**-example:**<br>./recycle_bin.sh -s ^[a-z]{4}<br>./recycle_bin.sh -s string_to_match<br>./recycle_bin.sh -s -c string_case_insensitive<br>
</div>

### Clear Bin:
<div style="border: 2px solid #5e685fff; padding: 10px; border-radius: 5px;">
./recycle_bin.sh -e [--FLAG] [ID]<br>
**-example:**<br>./recycle_bin.sh -e<br>./recycle_bin.sh -e --force<br>./recycle_bin.sh -e 1234567890_abcdef<br>./recycle_bin.sh -e --force 1234567890_abcdef<br>
</div>

### Help:
<div style="border: 2px solid #5e685fff; padding: 10px; border-radius: 5px;">
./recycle_bin.sh [-flag]<br>
**-example:**<br>./recycle_bin.sh -h<br>./recycle_bin.sh --help<br>./recycle_bin.sh help
</div>

## Features
### Mandatory features
<div style="border: 2px solid #5e685fff; padding: 10px; border-radius: 5px;">
    • initialize_recyclebin<br>
    • delete_file<br>
    • list_recycled<br>
    • empty_recyclebin<br>
    • restore_file<br>
    • search_recycled<br> 
    • display_help
</div>
<br>

### Optional features
<div style="border: 2px solid #5e685fff; padding: 10px; border-radius: 5px;">
    • show_statistics<br>
    • auto_cleanup<br>
    • check_quota<br>
    • preview_file
</div>

## Configuration
To configure settings such as maximum mb size of bin or the retention days for auto cleanup, access "$HOME/.recycle_bin/config" and alter said fields.
## Examples
[Detailed usage examples with screenshots]s
## Known Issues
[Any limitations or bugs]
## References
[\[How to output neat columns regardless of variable size\]](https://stackoverflow.com/questions/6462894/how-can-i-format-the-output-of-a-bash-command-in-neat-columns) <br>
[\[Custom field separator for command column\]](https://stackoverflow.com/questions/14218470/specific-a-delimiter-to-separate-data-into-columns) <br>
[\[numfmt for byte conversion\]](https://askubuntu.com/questions/1463041/convert-byte-value-to-mb-in-bash-script)<br>
[\[Split line into array using read and custom IFS\]](https://stackoverflow.com/questions/10586153/how-to-split-a-string-into-an-array-in-bash)<br>
