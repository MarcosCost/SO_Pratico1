#!/bin/bash
# Enhanced Automated Test Suite for Recycle Bin System
# Author: Marcos Costa (125882), José Mendes (114429)

SCRIPT="./recycle_bin.sh"
TEST_DIR="test_data"
PASS=0
FAIL=0
TEST_COUNT=0

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test Helper Functions
print_header() {
    echo -e "\n${YELLOW}=== $1 ===${NC}"
}

print_result() {
    ((TEST_COUNT++))
    if [ $1 -eq 0 ]; then
        echo -e "  ${GREEN}✓ PASS${NC}: $2"
        ((PASS++))
    else
        echo -e "  ${RED}✗ FAIL${NC}: $2"
        ((FAIL++))
    fi
}

setup() {
    echo "Setting up test environment..."
    mkdir -p "$TEST_DIR"
    rm -rf ~/.recycle_bin
    $SCRIPT -i > /dev/null 2>&1
}

cleanup() {
    echo "Cleaning up test files..."
    rm -rf "$TEST_DIR"
}

# ==================== BASIC FUNCTIONALITY TESTS ====================

test_initialization() {
    print_header "Test 1: System Initialization"
    
    $SCRIPT -i > /dev/null 2>&1
    print_result $? "Initialize recycle bin command"
    
    [ -d ~/.recycle_bin ] && [ -d ~/.recycle_bin/files ]
    print_result $? "Directory structure created"
    
    [ -f ~/.recycle_bin/metadata.db ]
    print_result $? "Metadata file created"
    
    [ -f ~/.recycle_bin/config ]
    print_result $? "Config file created"
}

test_delete_single_file() {
    print_header "Test 2: Delete Single File"
    
    echo "Test content" > "$TEST_DIR/single_test.txt"
    $SCRIPT -d "$TEST_DIR/single_test.txt" > /dev/null 2>&1
    print_result $? "Delete single file command"
    
    [ ! -f "$TEST_DIR/single_test.txt" ]
    print_result $? "File removed from original location"
    
    grep -q "single_test.txt" ~/.recycle_bin/metadata.db
    print_result $? "File metadata recorded"
}

test_delete_multiple_files() {
    print_header "Test 3: Delete Multiple Files"
    
    echo "File 1" > "$TEST_DIR/multi1.txt"
    echo "File 2" > "$TEST_DIR/multi2.txt"
    echo "File 3" > "$TEST_DIR/multi3.txt"
    
    $SCRIPT -d "$TEST_DIR/multi1.txt" "$TEST_DIR/multi2.txt" "$TEST_DIR/multi3.txt" > /dev/null 2>&1
    print_result $? "Delete multiple files command"
    
    [ ! -f "$TEST_DIR/multi1.txt" ] && [ ! -f "$TEST_DIR/multi2.txt" ] && [ ! -f "$TEST_DIR/multi3.txt" ]
    print_result $? "All files removed from original locations"
}

test_delete_empty_directory() {
    print_header "Test 4: Delete Empty Directory"
    
    mkdir -p "$TEST_DIR/empty_dir_test"
    
    $SCRIPT -d "$TEST_DIR/empty_dir_test" > /dev/null 2>&1
    print_result $? "Delete empty directory command"
    
    [ ! -d "$TEST_DIR/empty_dir_test" ]
    print_result $? "Empty directory removed"
}

test_delete_directory_with_contents() {
    print_header "Test 5: Delete Directory with Contents"
    
    mkdir -p "$TEST_DIR/test_dir"
    echo "File in dir" > "$TEST_DIR/test_dir/file1.txt"
    echo "Another file" > "$TEST_DIR/test_dir/file2.txt"
    mkdir -p "$TEST_DIR/test_dir/subdir"
    echo "Nested file" > "$TEST_DIR/test_dir/subdir/file3.txt"
    
    $SCRIPT -d "$TEST_DIR/test_dir" > /dev/null 2>&1
    print_result $? "Delete directory command"
    
    [ ! -d "$TEST_DIR/test_dir" ]
    print_result $? "Directory removed from original location"
}

test_list_empty_bin() {
    print_header "Test 6: List Empty Recycle Bin"
    
    rm -rf ~/.recycle_bin/files/*
    echo "ID,ORIGINAL_NAME,ORIGINAL_PATH,DELETION_DATE,FILE_SIZE,FILE_TYPE,PERMISSIONS,OWNER" > ~/.recycle_bin/metadata.db
    
    $SCRIPT -l | grep -q "Empty" > /dev/null 2>&1
    print_result $? "List shows empty bin message"
}

test_list_with_items() {
    print_header "Test 7: List with Items"
    
    echo "test" > "$TEST_DIR/list_test.txt"
    $SCRIPT -d "$TEST_DIR/list_test.txt" > /dev/null 2>&1
    
    $SCRIPT -l > /dev/null 2>&1
    print_result $? "List command with items"
    
    $SCRIPT -l --detailed > /dev/null 2>&1
    print_result $? "Detailed list command"
}

test_restore_file_by_id() {
    print_header "Test 8: Restore File by ID"
    
    echo "Restore test content" > "$TEST_DIR/restore_test.txt"
    $SCRIPT -d "$TEST_DIR/restore_test.txt" > /dev/null 2>&1
    
    local file_id=$(grep "restore_test.txt" ~/.recycle_bin/metadata.db | cut -d',' -f1)
    
    if [ -n "$file_id" ]; then
        echo "y" | $SCRIPT -r "$file_id" > /dev/null 2>&1
        print_result $? "Restore file by ID command"
        
        [ -f "$TEST_DIR/restore_test.txt" ]
        print_result $? "File restored to original location"
    else
        print_result 1 "Could not find file ID for restoration"
    fi
}

test_restore_to_nonexistent_path() {
    print_header "Test 9: Restore to Non-Existent Path"
    
    echo "restore path test" > "$TEST_DIR/restore_path_test.txt"
    $SCRIPT -d "$TEST_DIR/restore_path_test.txt" > /dev/null 2>&1
    
    rm -rf "$TEST_DIR"
    
    local file_id=$(grep "restore_path_test.txt" ~/.recycle_bin/metadata.db | cut -d',' -f1)
    if [ -n "$file_id" ]; then
        echo "y" | $SCRIPT -r "$file_id" > /dev/null 2>&1
        print_result $? "Restore to non-existent path command"
        
        mkdir -p "$TEST_DIR"
    else
        print_result 1 "Could not find file ID for restoration test"
    fi
}

test_empty_entire_bin() {
    print_header "Test 10: Empty Entire Recycle Bin"
    
    echo "test" > "$TEST_DIR/empty_test1.txt"
    echo "test" > "$TEST_DIR/empty_test2.txt"
    $SCRIPT -d "$TEST_DIR/empty_test1.txt" "$TEST_DIR/empty_test2.txt" > /dev/null 2>&1
    
    echo "y" | $SCRIPT -e > /dev/null 2>&1
    print_result $? "Empty recycle bin command"
    
    local item_count=$(ls ~/.recycle_bin/files/ 2>/dev/null | wc -l)
    [ "$item_count" -eq 0 ]
    print_result $? "Recycle bin is empty after operation"
}

test_search_existing_file() {
    print_header "Test 11: Search for Existing File"
    
    echo "test" > "$TEST_DIR/search_pattern.txt"
    echo "test" > "$TEST_DIR/pattern_file.doc"
    $SCRIPT -d "$TEST_DIR/search_pattern.txt" "$TEST_DIR/pattern_file.doc" > /dev/null 2>&1
    
    $SCRIPT -s "pattern" > /dev/null 2>&1
    print_result $? "Search command"
    
    $SCRIPT -s -c "PATTERN" > /dev/null 2>&1
    print_result $? "Case insensitive search"
}

test_search_nonexistent_file() {
    print_header "Test 12: Search for Non-Existent File"
    
    $SCRIPT -s "nonexistent_pattern_12345" > /dev/null 2>&1
    local exit_code=$?
    [ $exit_code -eq 1 ]
    print_result $? "Search for non-existent file returns error"
}

test_help_system() {
    print_header "Test 13: Help System"
    
    $SCRIPT -h > /dev/null 2>&1
    print_result $? "Help command"
    
    $SCRIPT --help > /dev/null 2>&1
    print_result $? "Help command (long form)"
    
    $SCRIPT help > /dev/null 2>&1
    print_result $? "Help command (word form)"
}

# ==================== EDGE CASE TESTS ====================

test_delete_nonexistent_file() {
    print_header "Test 14: Delete Non-Existent File"
    
    $SCRIPT -d "non_existent_file_12345.txt" 2>/dev/null
    local exit_code=$?
    [ $exit_code -eq 1 ]
    print_result $? "Error on non-existent file deletion"
}

test_delete_file_without_permissions() {
    print_header "Test 15: Delete File Without Permissions"
    
    echo "protected content" > "$TEST_DIR/protected_file.txt"
    chmod 000 "$TEST_DIR/protected_file.txt"
    
    $SCRIPT -d "$TEST_DIR/protected_file.txt" 2>/dev/null
    local exit_code=$?
    
    chmod 644 "$TEST_DIR/protected_file.txt"
    
    [ $exit_code -ne 0 ]
    print_result $? "Permission denied handled gracefully"
}

test_restore_nonexistent_id() {
    print_header "Test 16: Restore Non-Existent ID"
    
    $SCRIPT -r "0000000000_xxxxxx" 2>/dev/null
    local exit_code=$?
    [ $exit_code -eq 1 ]
    print_result $? "Error on non-existent ID restoration"
}

test_filenames_with_spaces() {
    print_header "Test 17: Filenames with Spaces"
    
    touch "$TEST_DIR/file with spaces.txt"
    
    $SCRIPT -d "$TEST_DIR/file with spaces.txt" > /dev/null 2>&1
    print_result $? "Delete file with spaces"
    
    local file_id=$(grep "file with spaces.txt" ~/.recycle_bin/metadata.db | cut -d',' -f1)
    
    if [ -n "$file_id" ]; then
        echo "y" | $SCRIPT -r "$file_id" > /dev/null 2>&1
        [ -f "$TEST_DIR/file with spaces.txt" ]
        print_result $? "File with spaces restored correctly"
    else
        print_result 1 "Could not find file with spaces for restoration"
    fi
}

test_special_characters_filenames() {
    print_header "Test 18: Special Characters in Filenames"
    
    touch "$TEST_DIR/file!@test.txt"
    touch "$TEST_DIR/file\$(test).txt"
    
    $SCRIPT -d "$TEST_DIR/file!@test.txt" "$TEST_DIR/file\$(test).txt" > /dev/null 2>&1
    print_result $? "Delete files with special characters"
    
    local file_id1=$(grep "file!@test.txt" ~/.recycle_bin/metadata.db | cut -d',' -f1)
    local file_id2=$(grep "file\$(test).txt" ~/.recycle_bin/metadata.db | cut -d',' -f1)
    
    if [ -n "$file_id1" ] && [ -n "$file_id2" ]; then
        echo "y" | $SCRIPT -r "$file_id1" > /dev/null 2>&1
        echo "y" | $SCRIPT -r "$file_id2" > /dev/null 2>&1
        [ -f "$TEST_DIR/file!@test.txt" ] && [ -f "$TEST_DIR/file\$(test).txt" ]
        print_result $? "Files with special characters restored correctly"
    else
        print_result 1 "Could not find files with special characters for restoration"
    fi
}

test_hidden_files() {
    print_header "Test 19: Hidden Files"
    
    echo "hidden content" > "$TEST_DIR/.hidden_file"
    
    $SCRIPT -d "$TEST_DIR/.hidden_file" > /dev/null 2>&1
    print_result $? "Delete hidden file command"
    
    grep -q "\.hidden_file" ~/.recycle_bin/metadata.db
    print_result $? "Hidden file metadata recorded"
}

test_files_different_directories() {
    print_header "Test 20: Files from Different Directories"
    
    mkdir -p "$TEST_DIR/dir1" "$TEST_DIR/dir2"
    echo "file1" > "$TEST_DIR/dir1/file1.txt"
    echo "file2" > "$TEST_DIR/dir2/file2.txt"
    
    $SCRIPT -d "$TEST_DIR/dir1/file1.txt" "$TEST_DIR/dir2/file2.txt" > /dev/null 2>&1
    print_result $? "Delete files from different directories"
    
    [ ! -f "$TEST_DIR/dir1/file1.txt" ] && [ ! -f "$TEST_DIR/dir2/file2.txt" ]
    print_result $? "Files from different directories removed"
}

# ==================== ERROR HANDLING TESTS ====================

test_invalid_arguments() {
    print_header "Test 21: Invalid Command Line Arguments"
    
    $SCRIPT invalid_command 2>/dev/null
    local exit_code=$?
    [ $exit_code -ne 0 ]
    print_result $? "Invalid command handled"
    
    $SCRIPT -x 2>/dev/null
    exit_code=$?
    [ $exit_code -ne 0 ]
    print_result $? "Invalid option handled"
}

test_missing_parameters() {
    print_header "Test 22: Missing Required Parameters"
    
    $SCRIPT -d 2>/dev/null
    local exit_code=$?
    [ $exit_code -ne 0 ]
    print_result $? "Missing file parameter handled"
    
    $SCRIPT -r 2>/dev/null
    exit_code=$?
    [ $exit_code -ne 0 ]
    print_result $? "Missing ID parameter handled"
}

# ==================== PERFORMANCE TESTS ====================

test_performance_mass_deletion() {
    print_header "Test 23: Performance - Mass Deletion"
    
    for i in {1..100}; do
        echo "content $i" > "$TEST_DIR/performance_file_$i.txt"
    done
    
    local start_time=$(date +%s)
    $SCRIPT -d "$TEST_DIR"/performance_file_*.txt > /dev/null 2>&1
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    print_result $? "Mass deletion of 100 files"
    [ $duration -lt 10 ]
    print_result $? "Mass deletion completed in reasonable time ($duration seconds)"
}

test_performance_large_list() {
    print_header "Test 24: Performance - Large List"
    
    local start_time=$(date +%s)
    $SCRIPT -l > /dev/null 2>&1
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    [ $duration -lt 5 ]
    print_result $? "List with many items completed in reasonable time ($duration seconds)"
}

# ==================== OPTIONAL FEATURES TESTS ====================

test_optional_features() {
    print_header "Test 25: Optional Features"
    
    echo "stats test" > "$TEST_DIR/stats_test.txt"
    $SCRIPT -d "$TEST_DIR/stats_test.txt" > /dev/null 2>&1
    
    $SCRIPT -S > /dev/null 2>&1
    print_result $? "Statistics command"
    
    $SCRIPT -Q > /dev/null 2>&1
    print_result $? "Quota check command"
    
    local file_id=$(grep "stats_test.txt" ~/.recycle_bin/metadata.db | cut -d',' -f1)
    if [ -n "$file_id" ]; then
        $SCRIPT -P "$file_id" > /dev/null 2>&1
        print_result $? "File preview command"
    fi
}

# ==================== MAIN EXECUTION ====================

main() {
    echo -e "${YELLOW}=================================${NC}"
    echo -e "${YELLOW}  Enhanced Recycle Bin Test Suite${NC}"
    echo -e "${YELLOW}=================================${NC}"
    
    setup
    
    # Basic Functionality Tests
    test_initialization
    test_delete_single_file
    test_delete_multiple_files
    test_delete_empty_directory
    test_delete_directory_with_contents
    test_list_empty_bin
    test_list_with_items
    test_restore_file_by_id
    test_restore_to_nonexistent_path
    test_empty_entire_bin
    test_search_existing_file
    test_search_nonexistent_file
    test_help_system
    
    # Edge Case Tests
    test_delete_nonexistent_file
    test_delete_file_without_permissions
    test_restore_nonexistent_id
    test_filenames_with_spaces
    test_special_characters_filenames
    test_hidden_files
    test_files_different_directories
    
    # Error Handling Tests
    test_invalid_arguments
    test_missing_parameters
    
    # Performance Tests
    test_performance_mass_deletion
    test_performance_large_list
    
    # Optional Features Tests
    test_optional_features
    
    cleanup
    
    echo -e "\n${YELLOW}=================================${NC}"
    echo -e "${YELLOW}           TEST RESULTS${NC}"
    echo -e "${YELLOW}=================================${NC}"
    echo -e "Total Tests: $TEST_COUNT"
    echo -e "${GREEN}Passed: $PASS${NC}"
    echo -e "${RED}Failed: $FAIL${NC}"
    
    if [ $FAIL -eq 0 ]; then
        echo -e "\n${GREEN}🎉 All tests passed!${NC}"
        exit 0
    else
        echo -e "\n${RED}❌ Some tests failed. Check implementation.${NC}"
        exit 1
    fi
}

main "$@"