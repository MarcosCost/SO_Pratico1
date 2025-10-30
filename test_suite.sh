#!/bin/bash
# Automated Test Suite for Recycle Bin System
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
    # Clean any existing recycle bin
    rm -rf ~/.recycle_bin
    # Initialize fresh recycle bin
    $SCRIPT -i > /dev/null 2>&1
}

cleanup() {
    echo "Cleaning up test files..."
    rm -rf "$TEST_DIR"
    # Don't remove recycle bin to preserve test results
}

# Test Cases

test_initialization() {
    print_header "Test 1: System Initialization"
    
    # Test initialization
    $SCRIPT -i > /dev/null 2>&1
    print_result $? "Initialize recycle bin command"
    
    # Check directory structure
    [ -d ~/.recycle_bin ] && [ -d ~/.recycle_bin/files ]
    print_result $? "Directory structure created"
    
    # Check metadata file
    [ -f ~/.recycle_bin/metadata.db ]
    print_result $? "Metadata file created"
    
    # Check config file
    [ -f ~/.recycle_bin/config ]
    print_result $? "Config file created"
}

test_delete_single_file() {
    print_header "Test 2: Delete Single File"
    
    # Create test file
    echo "Test content for single file" > "$TEST_DIR/single_test.txt"
    
    # Delete file
    $SCRIPT -d "$TEST_DIR/single_test.txt" > /dev/null 2>&1
    print_result $? "Delete single file command"
    
    # Check file removed from original location
    [ ! -f "$TEST_DIR/single_test.txt" ]
    print_result $? "File removed from original location"
    
    # Check file exists in recycle bin (by checking metadata)
    grep -q "single_test.txt" ~/.recycle_bin/metadata.db
    print_result $? "File metadata recorded"
}

test_delete_multiple_files() {
    print_header "Test 3: Delete Multiple Files"
    
    # Create multiple test files
    echo "File 1" > "$TEST_DIR/multi1.txt"
    echo "File 2" > "$TEST_DIR/multi2.txt"
    echo "File 3" > "$TEST_DIR/multi3.txt"
    
    # Delete multiple files
    $SCRIPT -d "$TEST_DIR/multi1.txt" "$TEST_DIR/multi2.txt" "$TEST_DIR/multi3.txt" > /dev/null 2>&1
    print_result $? "Delete multiple files command"
    
    # Verify all files removed
    [ ! -f "$TEST_DIR/multi1.txt" ] && [ ! -f "$TEST_DIR/multi2.txt" ] && [ ! -f "$TEST_DIR/multi3.txt" ]
    print_result $? "All files removed from original locations"
}

test_delete_directory() {
    print_header "Test 4: Delete Directory"
    
    # Create directory with files
    mkdir -p "$TEST_DIR/test_dir"
    echo "File in dir" > "$TEST_DIR/test_dir/file1.txt"
    echo "Another file" > "$TEST_DIR/test_dir/file2.txt"
    mkdir -p "$TEST_DIR/test_dir/subdir"
    echo "Nested file" > "$TEST_DIR/test_dir/subdir/file3.txt"
    
    # Delete directory
    $SCRIPT -d "$TEST_DIR/test_dir" > /dev/null 2>&1
    print_result $? "Delete directory command"
    
    # Check directory removed
    [ ! -d "$TEST_DIR/test_dir" ]
    print_result $? "Directory removed from original location"
}

test_list_empty_bin() {
    print_header "Test 5: List Empty Recycle Bin"
    
    # Empty the bin first
    rm -rf ~/.recycle_bin/files/*
    echo "ID,ORIGINAL_NAME,ORIGINAL_PATH,DELETION_DATE,FILE_SIZE,FILE_TYPE,PERMISSIONS,OWNER" > ~/.recycle_bin/metadata.db
    
    # Test list command on empty bin
    $SCRIPT -l | grep -q "Empty" > /dev/null 2>&1
    print_result $? "List shows empty bin message"
}

test_list_with_items() {
    print_header "Test 6: List with Items"
    
    # Add some test files to bin
    echo "test" > "$TEST_DIR/list_test.txt"
    $SCRIPT -d "$TEST_DIR/list_test.txt" > /dev/null 2>&1
    
    # Test list command
    $SCRIPT -l > /dev/null 2>&1
    print_result $? "List command with items"
    
    # Test detailed list
    $SCRIPT -l --detailed > /dev/null 2>&1
    print_result $? "Detailed list command"
}

test_restore_by_id() {
    print_header "Test 7: Restore File by ID"
    
    # Create and delete a file
    echo "Restore test content" > "$TEST_DIR/restore_test.txt"
    $SCRIPT -d "$TEST_DIR/restore_test.txt" > /dev/null 2>&1
    
    # Get the file ID from metadata
    local file_id=$(grep "restore_test.txt" ~/.recycle_bin/metadata.db | cut -d',' -f1)
    
    if [ -n "$file_id" ]; then
        # Restore by ID
        echo "y" | $SCRIPT -r "$file_id" > /dev/null 2>&1
        print_result $? "Restore file by ID command"
        
        # Check file restored
        [ -f "$TEST_DIR/restore_test.txt" ]
        print_result $? "File restored to original location"
    else
        print_result 1 "Could not find file ID for restoration"
    fi
}

test_search_functionality() {
    print_header "Test 8: Search Functionality"
    
    # Create test files with specific names
    echo "test" > "$TEST_DIR/search_pattern.txt"
    echo "test" > "$TEST_DIR/pattern_file.doc"
    $SCRIPT -d "$TEST_DIR/search_pattern.txt" "$TEST_DIR/pattern_file.doc" > /dev/null 2>&1
    
    # Test search
    $SCRIPT -s "pattern" > /dev/null 2>&1
    print_result $? "Search command"
    
    # Test case insensitive search
    $SCRIPT -s -c "PATTERN" > /dev/null 2>&1
    print_result $? "Case insensitive search"
}

test_empty_bin() {
    print_header "Test 9: Empty Recycle Bin"
    
    # Add some files to bin first
    echo "test" > "$TEST_DIR/empty_test1.txt"
    echo "test" > "$TEST_DIR/empty_test2.txt"
    $SCRIPT -d "$TEST_DIR/empty_test1.txt" "$TEST_DIR/empty_test2.txt" > /dev/null 2>&1
    
    # Test empty with confirmation (auto-confirm with echo)
    echo "y" | $SCRIPT -e > /dev/null 2>&1
    print_result $? "Empty recycle bin command"
    
    # Check if bin is empty
    local item_count=$(ls ~/.recycle_bin/files/ 2>/dev/null | wc -l)
    [ "$item_count" -eq 0 ]
    print_result $? "Recycle bin is empty after operation"
}

test_help_command() {
    print_header "Test 10: Help System"
    
    # Test help command
    $SCRIPT -h > /dev/null 2>&1
    print_result $? "Help command"
    
    $SCRIPT --help > /dev/null 2>&1
    print_result $? "Help command (long form)"
    
    $SCRIPT help > /dev/null 2>&1
    print_result $? "Help command (word form)"
}

test_error_handling() {
    print_header "Test 11: Error Handling"
    
    # Test deleting non-existent file
    $SCRIPT -d "non_existent_file_12345.txt" 2>/dev/null
    local exit_code=$?
    [ $exit_code -eq 1 ]  # ← CORREÇÃO: Verificar se retorna 1 (erro)
    print_result $? "Error on non-existent file deletion"
    
    # Test restoring non-existent ID
    $SCRIPT -r "0000000000_xxxxxx" 2>/dev/null
    exit_code=$?
    [ $exit_code -eq 1 ]  # ← CORREÇÃO: Verificar se retorna 1 (erro)
    print_result $? "Error on non-existent ID restoration"
}

test_optional_features() {
    print_header "Test 12: Optional Features"
    
    # Add a file for statistics
    echo "stats test" > "$TEST_DIR/stats_test.txt"
    $SCRIPT -d "$TEST_DIR/stats_test.txt" > /dev/null 2>&1
    
    # Test statistics
    $SCRIPT -S > /dev/null 2>&1
    print_result $? "Statistics command"
    
    # Test quota check
    $SCRIPT -Q > /dev/null 2>&1
    print_result $? "Quota check command"
    
    # Get file ID for preview test
    local file_id=$(grep "stats_test.txt" ~/.recycle_bin/metadata.db | cut -d',' -f1)
    if [ -n "$file_id" ]; then
        $SCRIPT -P "$file_id" > /dev/null 2>&1
        print_result $? "File preview command"
    fi
}

# Main test execution
main() {
    echo -e "${YELLOW}=================================${NC}"
    echo -e "${YELLOW}  Recycle Bin Test Suite${NC}"
    echo -e "${YELLOW}=================================${NC}"
    
    # Setup test environment
    setup
    
    # Run all test functions
    test_initialization
    test_delete_single_file
    test_delete_multiple_files
    test_delete_directory
    test_list_empty_bin
    test_list_with_items
    test_restore_by_id
    test_search_functionality
    test_empty_bin
    test_help_command
    test_error_handling
    test_optional_features
    
    # Cleanup
    cleanup
    
    # Print final results
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

# Run main function
main "$@"