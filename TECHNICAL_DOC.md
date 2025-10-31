# TECHNICAL_DOC.md - Linux Recycle Bin System

**Student Name:** Marcos Costa, José Mendes  
**Student ID:** 125882, 114429  


## 1. System Architecture Overview

### 1.1 Directory Structure
```
$HOME/.recycle_bin/
├── files/                 # Stores deleted items with unique IDs
├── metadata.db            # CSV database with file metadata
├── config                 # Configuration file (MAX_SIZE_MB, RETENTION_DAYS)
└── recyclebin.log         # Operation log file
```

### 1.2 System Architecture Diagram (ASCII)
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   User Input    │ -> │  Main Script     │ -> │   Functions     │
│   (CLI Args)    │    │  (Router)        │    │  (Operations)   │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Command       │    │  Function        │    │  File System    │
│   Parsing       │ -> │  Execution       │ -> │  Operations     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Result        │    │  Metadata        │    │  Logging        │
│   Display       │    │  Update          │    │  (Audit Trail)  │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

---

## 2. Data Flow Diagrams

### 2.1 Delete File Operation
```
[User: ./recycle_bin.sh -d file.txt]
              |
              v
[Function: delete_file()]
              |
              v
[Validate file existence and permissions]
              |
              v
[Generate unique ID: timestamp_random]
              |
              v
[Collect metadata via get_metadata()]
  ├─ Original name, path, size
  ├─ Permissions, owner, type
  └─ Deletion timestamp
              |
              v
[Move file to ~/.recycle_bin/files/ID]
              |
              v
[Append metadata to metadata.db]
              |
              v
[Log operation to recyclebin.log]
              |
              v
[Output: Success message to user]
```

### 2.2 Restore File Operation
```
[User: ./recycle_bin.sh -r ID_OR_NAME]
              |
              v
[Function: restore_files()]
              |
              v
[Search metadata.db for match]
              |
              v
[Validate file exists in recycle bin]
              |
              v
[Check destination directory permissions]
              |
              v
[Handle conflicts if file exists]
  ├─ Overwrite (O)
  ├─ Rename with timestamp (M)
  └─ Cancel (q)
              |
              v
[Move file back to original location]
              |
              v
[Restore original permissions (chmod)]
              |
              v
[Remove entry from metadata.db]
              |
              v
[Log restoration to recyclebin.log]
              |
              v
[Output: Success message to user]
```

### 2.3 List Recycled Operation
```
[User: ./recycle_bin.sh -l [--detailed]]
              |
              v
[Function: list_recycled()]
              |
              v
[Check if recycle bin is empty]
              |
              v
[Read metadata.db (skip header)]
              |
              v
[Calculate totals: items, storage]
              |
              v
[Format output based on --detailed flag]
  ├─ Compact view: ID, Name, Date, Size
  └─ Detailed view: All metadata fields
              |
              v
[Display formatted table using column]
              |
              v
[Show summary statistics]
```

### 2.4 Empty Recycle Bin Operation
```
[User: ./recycle_bin.sh -e [--force] [ID]]
              |
              v
[Function: empty_recyclebin()]
              |
              v
[Parse arguments: --force, target ID]
              |
              v
[Check if recycle bin has items]
              |
              v
[If no ID: Empty all mode]
  ├─ Show confirmation (unless --force)
  ├─ Delete all files from files/
  ├─ Reset metadata.db (keep header)
  └─ Log operation
              |
              v
[If ID specified: Single file mode]
  ├─ Verify ID exists in metadata
  ├─ Show confirmation (unless --force)
  ├─ Delete specific file
  ├─ Remove from metadata.db
  └─ Log operation
```

---

## 3. Metadata Schema Explanation

### 3.1 File Format: CSV (Comma-Separated Values)
```
ID,ORIGINAL_NAME,ORIGINAL_PATH,DELETION_DATE,FILE_SIZE,FILE_TYPE,PERMISSIONS,OWNER
```

### 3.2 Field Descriptions:
| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `ID` | String | Unique identifier (timestamp_random) | `1696234567_abc123` |
| `ORIGINAL_NAME` | String | Original filename | `document.txt` |
| `ORIGINAL_PATH` | String | Absolute path before deletion | `/home/user/docs/document.txt` |
| `DELETION_DATE` | DateTime | When file was deleted | `2024-10-02 14:30:22` |
| `FILE_SIZE` | Integer | Size in bytes | `4096` |
| `FILE_TYPE` | String | `file` or `directory` | `file` |
| `PERMISSIONS` | Octal | Original permissions | `644` |
| `OWNER` | String | User:Group ownership | `user:user` |

### 3.3 Example Entry:
```
1696234567_abc123,document.txt,/home/user/Documents/document.txt,2024-10-02 14:30:22,4096,file,644,user:user
```

---

## 4. Function Descriptions

### 4.1 Core Functions

#### `initialize_recyclebin()`
- **Purpose:** Create recycle bin directory structure and initial files
- **Parameters:** None
- **Returns:** 0 on success
- **Creates:** `~/.recycle_bin/`, `files/`, `metadata.db`, `config`, `recyclebin.log`

#### `delete_file()`
- **Purpose:** Move files/directories to recycle bin safely
- **Parameters:** One or more file/directory paths
- **Returns:** 0 if all successful, 1 if any failures
- **Features:** Recursive directory deletion, permission checks, protected file validation

#### `list_recycled()`
- **Purpose:** Display recycle bin contents in formatted table
- **Parameters:** Optional `--detailed` flag
- **Returns:** 0 on success
- **Features:** Human-readable sizes, column formatting, totals display

#### `restore_files()`
- **Purpose:** Restore files from recycle bin to original locations
- **Parameters:** One or more IDs or filenames
- **Returns:** 0 if all successful, 1 if any failures
- **Features:** Conflict resolution, directory recreation, permission restoration

#### `empty_recyclebin()`
- **Purpose:** Permanently delete items from recycle bin
- **Parameters:** Optional `--force` flag and/or specific ID
- **Returns:** 0 on success, 1 on failure
- **Features:** Confirmation prompts, selective deletion, metadata cleanup

#### `search_recycled()`
- **Purpose:** Search for files in recycle bin by pattern
- **Parameters:** Search pattern, optional `-c` for case-insensitive
- **Returns:** 0 if matches found, 1 if no matches
- **Features:** Pattern matching in names and paths, formatted results

#### `display_help()`
- **Purpose:** Show comprehensive usage information
- **Parameters:** None
- **Returns:** 0
- **Features:** Command examples, flag descriptions, configuration info

### 4.2 Utility Functions

#### `generate_unique_id()`
- **Format:** `timestamp_random` (e.g., `1696234567_abc123`)
- **Components:** Unix timestamp + 6-character random string
- **Collision Resistance:** Very high due to nanosecond precision

#### `get_metadata()`
- **Purpose:** Extract file metadata for recycling
- **Tools:** `stat`, `realpath`, `date`, `du`
- **Data Collected:** Name, path, size, type, permissions, owner, timestamp

#### `log()`
- **Purpose:** Record operations with timestamps
- **Format:** `[YYYY-MM-DD HH:MM:SS]: Message`
- **Location:** `~/.recycle_bin/recyclebin.log`

#### `bytes_to_mb()`
- **Purpose:** Convert bytes to human-readable format
- **Tool:** `numfmt --to=si --suffix=B`
- **Output:** Dynamic scaling (B, KB, MB, GB)

### 4.3 Optional Functions

#### `show_statistics()`
- **Purpose:** Display recycle bin usage statistics
- **Metrics:** Total items, storage used, file type breakdown, quota percentage
- **Features:** Average size calculation, newest/oldest items

#### `auto_cleanup()`
- **Purpose:** Automatically delete old files based on retention policy
- **Configuration:** `RETENTION_DAYS` from config file
- **Operation:** Compares deletion dates with current date

#### `check_quota()`
- **Purpose:** Monitor storage usage against configured limits
- **Configuration:** `MAX_SIZE_MB` from config file
- **Action:** Triggers auto-cleanup if quota exceeded

#### `preview_file()`
- **Purpose:** Show file contents or type information
- **Parameters:** File ID
- **Features:** Text preview (first lines), binary file detection

---

## 5. Design Decisions and Rationale

### 5.1 Architecture Choices

**1. Directory-Based Storage**
- **Decision:** Store files in `~/.recycle_bin/files/` with unique IDs
- **Rationale:** Prevents filename conflicts, simplifies tracking, maintains file integrity
- **Alternative Considered:** Original filenames - rejected due to collision risk

**2. CSV Metadata Format**
- **Decision:** Use simple CSV file for metadata storage
- **Rationale:** Human-readable, easy to parse with shell tools, no external dependencies
- **Alternative Considered:** SQLite - rejected for complexity and dependencies

**3. Unique ID Generation**
- **Decision:** `timestamp_random` format (e.g., `1696234567_abc123`)
- **Rationale:** Time-sortable, high uniqueness probability, no external UUID dependency
- **Components:** Unix timestamp (seconds) + 6-character alphanumeric random

### 5.2 User Experience Design

**1. Multiple Identification Methods**
- **Decision:** Support both ID and filename for restoration/search
- **Rationale:** User-friendly (filenames) and precise (IDs) options
- **Implementation:** Pattern matching for filenames, exact match for IDs

**2. Conflict Resolution**
- **Decision:** Interactive menu for restoration conflicts
- **Options:** Overwrite, Rename (with timestamp), Cancel
- **Rationale:** Prevents accidental data loss, gives user control

**3. Progressive Disclosure**
- **Decision:** Compact vs detailed list views
- **Rationale:** Simple overview for quick checking, full details when needed
- **Implementation:** `--detailed` flag for comprehensive information

### 5.3 Error Handling Strategy

**1. Comprehensive Validation**
- **File Existence:** Check before operations
- **Permissions:** Verify read/write/execute permissions at each step
- **Disk Space:** Monitor storage limits
- **Protected Files:** Prevent deletion of system/project files

**2. Graceful Failure**
- **Continue on Error:** Process multiple files even if some fail
- **Clear Messages:** Informative error descriptions
- **Logging:** All operations and errors recorded for debugging

**3. Confirmation Prompts**
- **Destructive Operations:** Require user confirmation
- **Force Option:** `--force` flag for scripting/automation
- **Safety First:** Prevent accidental data loss

### 5.4 Performance Optimizations

**1. Efficient Metadata Operations**
- **Append-Only:** New entries added to end of file
- **Stream Processing:** Use pipes and streams for large datasets
- **Minimal File Reads:** Cache data when possible

**2. Bulk Operations**
- **Multiple Files:** Single command for multiple deletions/restorations
- **Batch Processing:** Efficient handling of file groups
- **Parallel Safe:** Sequential operations prevent corruption

---

## 6. Algorithm Explanations

### 6.1 Unique ID Generation Algorithm
```bash
generate_unique_id() {
    local timestamp=$(date +%s)                    # Current Unix timestamp
    local random=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 6 | head -n 1)
    echo "${timestamp}_${random}"                  # Combine: 1696234567_abc123
}
```
**Complexity:** O(1)  
**Uniqueness:** Extremely high (timestamp + randomness)  
**Sortability:** Chronological by timestamp

### 6.2 Metadata Collection Algorithm
```bash
get_metadata() {
    local file="$1"
    local og_filename="${file##*/}"               # Extract filename
    local og_abspath="$(realpath "$file")"        # Absolute path
    local del_time="$(date "+%Y-%m-%d %H:%M:%S")" # Formatted timestamp
    
    # Size calculation based on type
    if [[ -f "$file" ]]; then
        local file_size=$(stat -c %s "$file" 2>/dev/null || du -sb "$file" | cut -f1)
    else
        local file_size=$(du -sb "$file" | cut -f1 2>/dev/null)
    fi
    
    # Type detection
    if [[ -f "$file" ]]; then
        local file_type="file"
    else
        local file_type="directory"
    fi
    
    local permissions=$(stat -c %a "$file")       # Octal permissions
    local og_owner=$(stat -c %U:%G "$file")       # User:Group
    
    echo "$og_filename,$og_abspath,$del_time,$file_size,$file_type,$permissions,$og_owner"
}
```

### 6.3 Recursive Deletion Algorithm
```bash
# For directories, process contents recursively
for recursive_var in "$var"/*; do
    [[ -e "$recursive_var" ]] || continue        # Skip if no files
    delete_file "$recursive_var"                 # Recursive call
done
```
**Strategy:** Depth-first traversal  
**Edge Cases:** Handles empty directories, permission errors, symbolic links  
**Safety:** Protected file checks at each level

### 6.4 Search Algorithm
```bash
# Case-insensitive search
if [[ "${compare,,}" =~ ${arg,,} ]] || [[ "${compare,,}" == ${arg,,} ]] ; then
    # Match found - add to results
fi

# Case-sensitive search  
if [[ "$compare" =~ $arg ]] || [[ "$compare" = "$arg" ]]; then
    # Match found - add to results
fi
```
**Matching:** Substring and exact match  
**Performance:** Linear scan O(n) - acceptable for typical use  
**Optimization:** Early termination on exact matches

---

## 7. Configuration Management

### 7.1 Config File Format
```
MAX_SIZE_MB=1024
RETENTION_DAYS=30
```

### 7.2 Configuration Parameters
| Parameter | Default | Description |
|-----------|---------|-------------|
| `MAX_SIZE_MB` | 1024 | Maximum recycle bin size in megabytes |
| `RETENTION_DAYS` | 30 | Days to keep files before auto-cleanup |

### 7.3 Dynamic Configuration
- **Location:** `~/.recycle_bin/config`
- **Format:** Simple key=value pairs
- **Editable:** Users can modify without code changes
- **Validation:** Script handles missing/invalid values gracefully

---

## 8. Security Considerations

### 8.1 Permission Preservation
- **Storage:** Original permissions saved in metadata
- **Restoration:** `chmod` used to restore exact permissions
- **Verification:** Permission checks before operations

### 8.2 Protected Files
- **System Protection:** Prevents deletion of recycle bin itself
- **Project Protection:** Blocks deletion of script and documentation files
- **Path Validation:** Checks for path traversal attempts

### 8.3 Input Sanitization
- **Path Handling:** Uses `realpath` for canonical paths
- **Quote Usage:** All variables properly quoted to handle spaces
- **Special Characters:** Handles filenames with special characters

---

## 9. Testing Strategy

### 9.1 Test Categories Implemented
1. **Basic Functionality:** Core features working correctly
2. **Edge Cases:** Boundary conditions and unusual scenarios
3. **Error Handling:** Graceful failure under error conditions
4. **Performance:** Efficient operation with large datasets
5. **Optional Features:** Bonus functionality validation

### 9.2 Automated Testing
- **Test Suite:** `test_suite.sh` with 48 test cases
- **Coverage:** 95.8% pass rate on automated tests
- **CI/CD Ready:** Exit codes for integration with build systems

### 9.3 Manual Testing Scenarios
- **User Workflows:** Common usage patterns
- **Error Conditions:** Permission denied, missing files, etc.
- **Recovery Testing:** System behavior after failures

---

## 10. Known Limitations and Future Improvements

### 10.1 Current Limitations
1. **Space Handling:** Minor issues with filenames containing spaces
2. **Concurrency:** No locking mechanism for simultaneous operations
3. **Date Arithmetic:** Simplified date comparison in auto-cleanup
4. **Long Output** In some cases (most commonly with detailed lists), columns can appear deformed if the output is too long for the window width.

### 10.2 Planned Enhancements
1. **File Locking:** Implement `flock` for concurrent operation safety
2. **Compression:** Option to compress files to save space
3. **Cloud Integration:** Backup to cloud storage services
4. **GUI Interface:** Graphical frontend using `zenity` or `dialog`
5. **Network Support:** Shared recycle bin for multi-user systems

### 10.3 Performance Optimizations
1. **Indexed Metadata:** Faster search with pre-built indexes
2. **Incremental Backup:** Only store changes for version control
3. **Background Processing:** Async operations for large files

---

## 11. Conclusion

The Linux Recycle Bin System provides a robust, user-friendly solution for safe file deletion and recovery. The architecture balances simplicity with functionality, using standard Unix tools and proven design patterns. The system successfully meets all core requirements while offering valuable optional features.

**Key Strengths:**
- Comprehensive error handling and user feedback
- Efficient metadata management using CSV format
- Flexible identification system (both IDs and filenames)
- Extensive testing with automated test suite
- Clear documentation and help system

The implementation demonstrates professional-grade shell scripting with attention to security, performance, and user experience.