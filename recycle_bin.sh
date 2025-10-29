#!/bin/bash
#set -e

#################################################
# Linux Recycle Bin Simulation
# Author: Your Name
# Date: YYYY-MM-DD
# Description: Shell-based recycle bin system
# Version: 1.0
#################################################

# Global Variables (ALL CAPS)
RECYCLE_BIN_DIR="$HOME/recycle_bin"
METADATA_FILE="$RECYCLE_BIN_DIR/metadata.db"


#################################################
# Function: initialize_recyclebin
# Description: Initialize recycle bin directory structure and files
# Parameters: None
# Returns: 0 on success
#################################################
initialize_recyclebin(){
    #A flag -p faz com que mkdir não dê erro caso o dir ja exista, cria qualquer parent dir nessesario, e não apaga conteudo caso ja existam
    mkdir -p "$RECYCLE_BIN_DIR/files"
    #verificar se os ficheiros que precisam de ser inicializados com dados pre-existentes ja existem para evitar sobescrever dados no caso de dupla chamada da função
    if [ ! -f $METADATA_FILE ]; then
        printf "ID,ORIGINAL_NAME,ORIGINAL_PATH,DELETION_DATE,FILE_SIZE,FILE_TYPE,PERMISSIONS,OWNER\n" > $METADATA_FILE    
    fi
    if [ ! -f "$RECYCLE_BIN_DIR/config" ]; then
        printf "MAX_SIZE_MB=1024\nRETENTION_DAYS=30\n" > "$RECYCLE_BIN_DIR/config"
    fi 
    touch "$RECYCLE_BIN_DIR/recyclebin.log"
    echo "Recycle Bin initialized sucessfully"
    return 0
}

#################################################
# Function: log
# Description: Log message with timestamp to log file
# Parameters: 1 (message to log)
# Returns: 0 on success
#################################################
log(){
    local log="$1"
    if [ $# -ne 1 ]; then
        echo "Erro: log takes 1 argument only"
        echo "$(date +"[%d/%m/%Y %H:%M:%S]"): ERROR: log takes 1 argument only" >> $RECYCLE_BIN_DIR/recyclebin.log
        return 1
    fi
    echo "$(date +"[%d/%m/%Y %H:%M:%S]"): $log" >> $RECYCLE_BIN_DIR/recyclebin.log
    return 0
}

#################################################
# Function: generate_unique_id
# Description: Generate unique ID with timestamp and random string
# Parameters: None
# Returns: Unique ID string
#################################################
generate_unique_id() {
    local timestamp=$(date +%s)
    local random=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 6 | head -n 1 2>/dev/null || echo "fallback")
    echo "${timestamp}_${random}"
}

#################################################
# Function: get_metadata
# Description: Get file metadata for recycling
# Parameters: 1 (file path)
# Returns: 0 on success
#################################################
get_metadata(){
    if [ $# -ne 1 ]; then
        echo "Erro: get_metadata takes 1 argument only"
        log "ERROR: get_metadata takes 1 argument only"
        return 1
    fi
    local file="$1"

    #Values we need to get:
    local og_filename="${file##*/}"
    local og_abspath="$(realpath "$file")"
    local del_time="$(date "+%Y-%m-%d %H:%M:%S")"
    if [[ -f "$file" ]]; then
        local file_size=$(stat -c %s "$file" 2>/dev/null || du -sb "$file" | cut -f1)
    else
        local file_size=$(du -sb "$file" | cut -f1 2>/dev/null)
    fi

    if [[ -f "$file" ]]; then
        local file_type="file"
    else
        local file_type="directory"
    fi
    local permissions=$(stat -c %a "$file")
    local og_owner=$(stat -c %U:%G "$file")

    echo "$og_filename,$og_abspath,$del_time,$file_size,$file_type,$permissions,$og_owner"
    return 0
}

#################################################
# Function: delete_file
# Description: Move files/directories to recycle bin
# Parameters: At least 1 (file/directory paths)
# Returns: 0 on success
#################################################               TODO: no read write permissions, Insufficient disk space
delete_file(){

    #ficheiros protegidos (não podem ser apagados)
    local protected_files=(
        "recycle_bin.sh" "README.md" "TECHNICAL_DOC.md"
        "TESTING.md" "test_suite.sh" ".gitignore"
    )

    #Para cada um dos argumentos fazer o seguinte
    for varr in "$@"; do
        
        local var="$varr"

        #Skip invalid input
        if [ ! -e "$var" ]; then
            echo "\"$var\" isn't a filename or directory"
            log "Failed to delete $(pwd)/$var - There is no such File/Dir"
            continue
        fi
        local abs_path=$(realpath "$var" 2>/dev/null)
        #Não deletar a recycle bin itself
        if [[ "$abs_path" == "$(realpath "$RECYCLE_BIN_DIR" 2>/dev/null)"* ]] ||
           [[ "$abs_path" == "$HOME/.recycle_bin"* ]]; then
            echo "Cannot delete recycle bin itself or its contents"
            log "Attempted to delete recycle bin: $abs_path"
            continue
        fi
        #Não deletar ficheiros protegidos
        local is_protected=0
        for protected in "${protected_files[@]}"; do
            if [[ "$(basename "$var")" == "$protected" ]] ||
               [[ "$abs_path" == "$(realpath "$protected" 2>/dev/null)" ]]; then
                echo "Cannot delete Project Structure items"
                log "Error: Cannot delete Project Structure items"
                is_protected=1
                break
            fi
        done
        if [ $is_protected -eq 1 ]; then
            continue
        fi



        if [[ -f $var ]];then
            
            local current_id=$(generate_unique_id)
            echo "$current_id,$(get_metadata $var)" >> $METADATA_FILE
            mv "$var" "$RECYCLE_BIN_DIR/files/$current_id"
            echo "$(realpath "$var") was deleted"
            log "$(realpath "$var") Was deleted; ID:$current_id"

        elif [[ -d $var ]];then

            for recursive_var in "$var"/*; do
                [[ -e "$recursive_var" ]] || continue
                delete_file "$recursive_var"
            done

            local current_id=$(generate_unique_id)
            echo "$current_id,$(get_metadata $var)" >> $METADATA_FILE
            mv "$var" "$RECYCLE_BIN_DIR/files/$current_id"
            echo "$(realpath "$var") was deleted"
            log "$(realpath "$var") Was deleted; ID:$current_id"

        fi

    done
    return 0
}

#################################################
# Function: bytes_to_mb
# Description: returns the value in B, KB, MB, GB
# Parameters: 1
# Returns: 0 on success
#################################################
bytes_to_mb() {
    local result=$(numfmt --to=si --suffix=B "$1")    
    echo "$result"
    return 0
}

#################################################
# Function: list_recycled
# Description: List all items in recycle bin
# Parameters: 0 or 1 (--detailed flag)
# Returns: 0 on success
#################################################
list_recycled(){

    echo
    local total_item=$(ls "$RECYCLE_BIN_DIR/files" -1 | wc -l)
    local total_storage=$(
        local total=0
        while IFS= read -r line; do

            IFS=',' read -ra fields <<< "$line"
            total=$((total + ${fields[4]}))

        done < <(tail -n +2 "$METADATA_FILE")
        echo $total
    )

    if [[ "$total_item" -eq 0 ]];then
        printf "Recycle Bin is Currently Empty\n\n"
        return 0
    fi

    if [ "$#" -eq 0 ]; then
        
        local result="|ID+|ORIGINAL_NAME+|DELETION_DATE+|FILE_SIZE+|\n"        
        {
        read
        while read -r line;do

            IFS="," read -ra arr <<< $line
            result+="|${arr[0]}+|${arr[1]}+|${arr[3]}+|$(bytes_to_mb ${arr[4]})+|\n"

        done 
        }< "$METADATA_FILE"

        printf "$result" | column -t -s+

    elif [ "$#" -eq 1 ] && [ "$1" == "--detailed" ]; then
        
        local result="|ID+|ORIGINAL_NAME+|ORIGINAL_PATH+|DELETION_DATE+|FILE_SIZE+|FILE_TYPE+|PERMISSION+|OWNER+|\n"        
        {
        read
        while read -r line;do

            IFS="," read -ra arr <<< $line
            result+="|${arr[0]}+|${arr[1]}+|${arr[2]}+|${arr[3]}+|$(bytes_to_mb ${arr[4]})+|${arr[5]}+|${arr[6]}+|${arr[7]}+|\n"

        done 
        }< "$METADATA_FILE"

        printf "$result" | column -t -s+  | cut -c1-$(tput cols)

    elif [ "$#" -eq 1 ] && [ "$1" != "--detailed" ]; then
        echo "\"$1\" is not recognized as a flag"
    else
        echo "list_recycled can only take one argument"
    fi

    printf "\nTotal files: $total_item\n"
    printf "Total size: $(bytes_to_mb $total_storage) \n"

    echo

    return 0

}

#################################################
# Function: empty_recyclebin
# Description: Empty recycle bin (all items or specific ID)
# Parameters: 0,1 or 2 (--force, specific ID)
# Returns: 0 on success
#################################################              TODO: Display summary of deleted items
empty_recyclebin(){
    # Verificar se há itens na recycle bin
    if [ ! -s "$METADATA_FILE" ] || [ $(wc -l < "$METADATA_FILE") -le 1 ]; then
        echo "Recycle bin is already empty"
        log "Attempted to empty recycle bin - already empty"
        return 0
    fi

    local force=0
    local target_id=""

    # Parse arguments
    if [ $# -eq 1 ] && [[ "$1" == "--force" ]]; then
        force=1
    elif [ $# -eq 1 ] && [[ "$1" != "--force" ]]; then
        target_id="$1"
    elif [ $# -eq 2 ] && [[ "$1" == "--force" ]]; then
        force=1
        target_id="$2"
    elif [ $# -gt 0 ]; then
        echo "Error: Invalid arguments"
        echo "Usage: empty_recyclebin [--force] [ID]"
        return 1
    fi

    # Modo: Empty all
    if [[ "$target_id" == "" ]]; then
        
        if [[ $force == 1 ]];then
            confirmation="yes"
        else
            echo "WARNING: This will permanently delete ALL items from recycle bin"
            echo "Are you sure? This cannot be undone (y/n): "
            read -r confirmation
        fi

        case "$confirmation" in
            y|Y|yes|YES)
                # Apagar todos os ficheiros
                rm -rf "$RECYCLE_BIN_DIR/files/"*

                # Reset do metadata file (mantém apenas o header)
                head -n 1 "$METADATA_FILE" > "$METADATA_FILE.tmp"
                mv "$METADATA_FILE.tmp" "$METADATA_FILE"

                echo "Recycle bin emptied successfully"
                log "Recycle bin emptied - all items permanently deleted"
                ;;
            *)
                echo "Operation cancelled"
                log "Empty recycle bin operation cancelled by user"
                return 0
                ;;
        esac

    # Modo: Empty específico por ID
    else
        # Verificar se o ID existe no metadata
        if ! grep -q "^$target_id," "$METADATA_FILE"; then
            echo "Error: ID '$target_id' not found in recycle bin"
            log "Failed to delete item with ID '$target_id' - ID not found"
            return 1
        fi

        if [[ $force == 1 ]];then
            confirmation="yes"
        else
            echo "WARNING: This will permanently delete item by id $target_id from recycle bin"
            echo "Are you sure? This cannot be undone (y/n): "
            read -r confirmation
        fi

        case "$confirmation" in
            y|Y|yes|YES)
                # Apagar o ficheiro físico
                rm -rf "$RECYCLE_BIN_DIR/files/$target_id"

                # Remover do metadata
                grep -v "^$target_id," "$METADATA_FILE" > "$METADATA_FILE.tmp"
                mv "$METADATA_FILE.tmp" "$METADATA_FILE"

                echo "Item with ID '$target_id' permanently deleted"
                log "Item with ID '$target_id' permanently deleted from recycle bin"
                ;;
            *)
                echo "Operation cancelled"
                log "Delete item operation cancelled by user (ID: $target_id)"
                return 0
                ;;
        esac

    fi

    return 0
}

#################################################
# Function: restore_files
# Description: Restore files by id
# Parameters: At least 1 (ID)
# Returns: 0 on success
#################################################           TODO:Permission denied at destination;   Disk space issues
restore_files(){

    if [[ "$#" -lt 1 ]]; then
        echo "Restore Files needs ate least 1 argument"
        return 1
    fi

    for var in "$@"; do

        #Modo ID
        if [[ $var =~ ^[0-9]{10}_[a-zA-Z0-9]{6}$ ]]; then

            # Verificar se o ID existe no metadata
            if ! grep -q "^$var," "$METADATA_FILE"; then
                echo "Error: ID '$var' not found in recycle bin"
                log "Failed to delete item with ID '$var' - ID not found"
                return 1
            fi

            #Split metadata into array
            IFS=',' read -ra arr <<< "$(grep "^$var," "$METADATA_FILE")"

            #Caso ja exista
            if [[ -e "${arr[2]}" ]];then

                echo "WARNING: There is a ${arr[5]} by the same name (${arr[1]}) in the target location already"
                echo "Do you wish to Override (O), Restore with Modified Name (M), or Cancel (q) "
                read -r confirmation

                case "$confirmation" in
                    O)
                        #Fix for placing directories inside directories instead of replacing
                        [[ -d "${arr[2]}" ]] && mv "${arr[2]}" "${arr[2]}_old"

                        mv "$RECYCLE_BIN_DIR/files/${arr[0]}" "${arr[2]}"

                        [[ -d "${arr[2]}_old" ]] && rm -rf "${arr[2]}_old"
                        
                        grep -v "^${arr[0]}," "$METADATA_FILE" > "$METADATA_FILE.tmp"
                        mv "$METADATA_FILE.tmp" "$METADATA_FILE"
                        chmod "${arr[6]}" "${arr[2]}" 

                        echo "Sucessfully Overwrote \"${arr[1]}\""
                        log "Sucessfully Overwrote \"${arr[2]}\" with \"${arr[0]}\""
                        continue
                        ;;
                    M)
                        local timestamp=$(date +%s)
                        mv "$RECYCLE_BIN_DIR/files/${arr[0]}" "${arr[2]}_$timestamp"
                        grep -v "^${arr[0]}," "$METADATA_FILE" > "$METADATA_FILE.tmp"
                        mv "$METADATA_FILE.tmp" "$METADATA_FILE"
                        chmod "${arr[6]}" "${arr[2]}_$timestamp" 

                        echo "Sucessfully restored \"${arr[1]}\" with name \"${arr[1]}_$timestamp\""
                        log "Sucessfully restored \"${arr[0]}\" at \"${arr[2]}_$timestamp\""
                        continue
                        ;;
                    *)
                        echo "Restore operation for \"${arr[1]}\" was canceled"
                        log "Restore operation for \"${arr[0]}\" was canceled"
                        continue
                        ;;

                esac
            fi

            #Caso não exista
            
            #Criar any parent dirs necessarios to avoid errors
            mkdir -p "$(dirname "${arr[2]}")"
            
            mv "$RECYCLE_BIN_DIR/files/${arr[0]}" "${arr[2]}"
            grep -v "^${arr[0]}," "$METADATA_FILE" > "$METADATA_FILE.tmp"
            mv "$METADATA_FILE.tmp" "$METADATA_FILE"
            chmod "${arr[6]}" "${arr[2]}"

            echo "\"${arr[1]}\" restored sucessfully"
            log "\"${arr[0]}\" restored sucessfully"
            return 0
        else #Mode Filename

            # Verificar se o Filename existe no metadata
            if ! grep -q "^[0-9]\{10\}_[a-zA-Z0-9]\{6\},$var," "$METADATA_FILE"; then
                echo "Error: Filename '$var' not found in recycle bin"
                log "Failed to delete item with Filename '$var' - Filename not found"
                return 1
            fi
            
            #Split metadata into array
            IFS=',' read -ra arr <<< "$(grep "^[0-9]\{10\}_[a-zA-Z0-9]\{6\},$var," "$METADATA_FILE")"

            #Caso ja exista
            if [[ -e "${arr[2]}" ]];then

                echo "WARNING: There is a ${arr[5]} by the same name (${arr[1]}) in the target location already"
                echo "Do you wish to Override (O), Restore with Modified Name (M), or Cancel (q) "
                read -r confirmation

                case "$confirmation" in
                    O)
                        #Fix for placing directories inside directories instead of replacing
                        [[ -d "${arr[2]}" ]] && mv "${arr[2]}" "${arr[2]}_old"

                        mv "$RECYCLE_BIN_DIR/files/${arr[0]}" "${arr[2]}"

                        [[ -d "${arr[2]}_old" ]] && rm -rf "${arr[2]}_old"

                        grep -v "^${arr[0]}," "$METADATA_FILE" > "$METADATA_FILE.tmp"
                        mv "$METADATA_FILE.tmp" "$METADATA_FILE"
                        chmod "${arr[6]}" "${arr[2]}" 

                        echo "Sucessfully Overwrote \"${arr[1]}\""
                        log "Sucessfully Overwrote \"${arr[2]}\" with \"${arr[0]}\""
                        continue
                        ;;
                    M)
                        local timestamp=$(date +%s)
                        mv "$RECYCLE_BIN_DIR/files/${arr[0]}" "${arr[2]}_$timestamp"
                        grep -v "^${arr[0]}," "$METADATA_FILE" > "$METADATA_FILE.tmp"
                        mv "$METADATA_FILE.tmp" "$METADATA_FILE"
                        chmod "${arr[6]}" "${arr[2]}_$timestamp" 

                        echo "Sucessfully restored \"${arr[1]}\" with name \"${arr[1]}_$timestamp\""
                        log "Sucessfully restored \"${arr[0]}\" at \"${arr[2]}_$timestamp\""
                        continue
                        ;;
                    *)
                        echo "Restore operation for \"${arr[1]}\" was canceled"
                        log "Restore operation for \"${arr[0]}\" was canceled"
                        continue
                        ;;

                esac
            fi

            #Caso não exista
            
            #Criar any parent dirs necessarios to avoid errors
            mkdir -p "$(dirname "${arr[2]}")"
            
            mv "$RECYCLE_BIN_DIR/files/${arr[0]}" "${arr[2]}"
            grep -v "^${arr[0]}," "$METADATA_FILE" > "$METADATA_FILE.tmp"
            mv "$METADATA_FILE.tmp" "$METADATA_FILE"
            chmod "${arr[6]}" "${arr[2]}"

            echo "\"${arr[1]}\" restored sucessfully"
            log "\"${arr[0]}\" restored sucessfully"
            return 0

        fi

    done

}

#################################################
# Function: search_recycled
# Description: Restore files by id
# Parameters: Min 1 Max 2 ( -c and pattern)
# Returns: 0 on success
#################################################
search_recycled(){

    #validate arguments
    if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
        echo "Error: Expected 1 or 2 arguments, but got $#"
        echo "Usage: search_recycled [-c] <argument>"
        return 1
    fi
    if [ "$#" -eq 2 ] && [ "$1" != "-c" ]; then
        echo "$1 isn't an acceptable flag"
        echo "Usage: search_recycled [-c] <argument>"
        return 1
    fi

    local results=""
    local found=0

    #Case insensitive
    if [[ "$1" = "-c" ]];then
        local arg="$2"
        results+=$(printf "\nSearch Results:\n\n│%-17s│%-25s│%-60s│\n" "ID" "NAME" "PATH")
        {
        read
        while read -r line;do
            
            IFS="," read -ra arr <<< "$line" 
            local comparables=("${arr[1]}" "${arr[2]}")
            for compare in "${comparables[@]}"; do
                
                #Reference 1
                if [[ "${compare,,}" =~ ${arg,,} ]] || [[ "${compare,,}" == ${arg,,} ]] ; then
                    results+=$(printf "│%-17s│%-25s│%-60s│\n" "${arr[0]}" "${arr[1]}" "${arr[2]}")
                    found=1
                    break
                fi
            
            done

        done } < "$METADATA_FILE"
        return 0
    fi

    #Case sensitive
    local arg="$1"
    results+=$(printf "\nSearch Results:\n\n│%-17s│%-25s│%-60s│\n" "ID" "NAME" "PATH")
    {
    read
    while read -r line;do
        
        IFS="," read -ra arr <<< "$line" 
        local comparables=("${arr[1]}" "${arr[2]}")
        for compare in "${comparables[@]}"; do
            
            if [[ "$compare" =~ $arg ]] || [[ "$compare" = "$arg" ]]; then
                results+=$(printf "\n│%-17s│%-25s│%-60s│\n" "${arr[0]}" "${arr[1]}" "${arr[2]}")
                found=1
                break
            fi
        
        done

    done }< "$METADATA_FILE"
    
    if [ $found -eq 0 ]; then
        echo "No matches found for '$arg'"
    else
        echo "$results"
    fi

    return 0
}

#################################################
# Function: display_help
# Description: Displays help
# Parameters: 1 
# Returns: 0 on success
#################################################
display_help(){
    printf "\n Config file located at $RECYCLE_BIN_DIR/config can be used for setting MAX_SIZE_MB and RETENTION_DAYS\n"

    printf "\n\tinitialize_recyclebin, -i         ./recycle_bin.sh -i\n\t\tCreates the folder and all components of the recycle bin, If folder exists but some components are missing re-creates them\n"
    printf "\n\tdelete_file, -d                   ./recycle_bin.sh -d [FILES]\n\t\tDeletes all files or directories (and their contents) specified in the arguments saving them to the recycle bin.\n"
    printf "\n\tlist_recycled, -l                 ./recycle_bin.sh -l [FLAG]\n\t\tPrints a list of all files in the bin.\n\t\tTakes one flag '--detailed' for a more detailed list\n"
    printf "\n\tempty_recyclebin, -e              ./recycle_bin.sh -e [FLAG] [FILE_ID]\n\t\tIf an Id is provided, searches for ID in the recycle bin and permanently deletes it, if no Id it provided empties recycle bin of all contents.\n\t\tTakes one flag '--force' to skip user confirmation.\n"
    printf "\n\trestore_file, -r                  ./recycle_bin.sh -r [FILES_OR_IDS]\n\t\tRestores all files or directoried specified in the arguments if they exist in the recycle bin\n"
    printf "\n\tsearch_recycled, -s               ./recycle_bin.sh -s [FLAG] [Pattern]\n\t\tSearches the Recyclebin for any file whose name or path mathes the pattern argument.\n\t\tTakes one flag '-c' to make a Case insensitive search\n"
    
    echo
    return 0
}

#################################################
# Function: show_statistics
# Description: displays statistics
# Parameters: 0
# Returns: 0 on success
#################################################
show_statistics(){

    local total_storage=$(
        local total=0
        while IFS= read -r line; do

            IFS=',' read -ra fields <<< "$line"
            total=$((total + ${fields[4]}))

        done < <(tail -n +2 "$METADATA_FILE")
        echo $total
    )

    local file_storage=$(
        local total=0
        while IFS= read -r line; do

            IFS=',' read -ra fields <<< "$line"
            if [[ "${fields[5]}" == "file" ]]; then
                total=$((total + ${fields[4]}))
            fi
        done < <(tail -n +2 "$METADATA_FILE")
        echo $total
    )

    local dir_storage=$(
        local total=0
        while IFS= read -r line; do

            IFS=',' read -ra fields <<< "$line"
            if [[ "${fields[5]}" == "directory" ]]; then
                total=$((total + ${fields[4]}))
            fi
        done < <(tail -n +2 "$METADATA_FILE")
        echo $total
    )

    local total_count=$(ls "$RECYCLE_BIN_DIR/files" -1 -p | wc -l)
    local file_count=$(ls "$RECYCLE_BIN_DIR/files" -1 -p | grep -v / | wc -l)
    local dir_count=$(ls "$RECYCLE_BIN_DIR/files" -1 -p | grep  / | wc -l)

    local quota_bytes=$(( $(head -n 1 "$RECYCLE_BIN_DIR/config" | cut -d '=' -f2) * 1000000 ))

    local result="| +|Total+|Files+|Dir+|\n"

    result+="|Number of:+|$total_count+|$file_count+|$dir_count+|\n"
    result+="|Storage used:+|$(bytes_to_mb $total_storage)+|$(bytes_to_mb $file_storage)+|$(bytes_to_mb $dir_storage)+|\n"
    result+="|Quota+|%.10f%% +|%.10f%% +|%.10f%% +|\n"
    result+="|Average size+|$(bytes_to_mb $(echo "$total_storage/$total_count" | bc)) +|$(bytes_to_mb $(echo "$file_storage/$file_count" | bc)) +|$(bytes_to_mb $(echo "$dir_storage/$dir_count" | bc)) +|\n"

    printf "$result" "$(echo "scale=10; $total_storage*100/$quota_bytes" | bc)" "$(echo "scale=10; $file_storage*100/$quota_bytes" | bc)" "$(echo "scale=10; $dir_storage*100/$quota_bytes" | bc)" | column -t -s+
    echo ""
    echo "Newest entry: $(tail -n 1 "$METADATA_FILE" | cut -d ',' -f2 )"
    echo "Newest entry: $(head -n 2 "$METADATA_FILE" | tail -n 1 | cut -d ',' -f2 )"
    return 0
}

#################################################
# Function: auto_cleanup
# Description: apagar automaticamente files cuja deletion date seja ha mais de RETENCION_DAYS dias
# Parameters: 0
# Returns: 0 on success
#################################################
auto_cleanup(){

    local curr_date=0
    local delete_date=0
    local retention_days=$(head -n 2 "$RECYCLE_BIN_DIR/config" | tail -n 1 | cut -d '=' -f2)

    {
    read
    while read -ra line; do
        
        IFS=- read -r f1 f2 f3 <<< "$(date +%Y-%m-%d)" 
        curr_date=$(( f1*365 + f2*30 + f3 ))
        
        IFS=- read -r f1 f2 f3 <<< "$(cut -d ',' -f4 <<< "$line")"
        delete_date=$(( f1*365 + f2*30 + f3 ))

        local id=$(cut -d ',' -f1 <<< "$line" )

        if [[ $(( $curr_date - $delete_date )) -ge $retention_days ]];then
            empty_recyclebin --force "$id"
        fi

    done 
    }< "$METADATA_FILE"

    echo "All items older than $retention_days deleted"

}


#################################################
# Function: check_quotaa
# Description: Vẽ se o tamanho da bin excede o tamanho defenido nsa configs, caso positivo automaticamente corre auto cleanup
# Parameters: 0
# Returns: 0 on success
#################################################
check_quota(){

    local total_storage=$(
        local total=0
        while IFS= read -r line; do

            IFS=',' read -ra fields <<< "$line"
            total=$((total + ${fields[4]}))

        done < <(tail -n +2 "$METADATA_FILE")
        echo $total
    )

    local quota_bytes=$(($(head -n 1 "$RECYCLE_BIN_DIR/config" | cut -d '=' -f2)*1000000))
    
    local percentage=$(echo "scale=10; $total_storage*100/$quota_bytes" | bc)
    echo "Quota used: $percentage%"

    if [[ ${percentage%.*} -ge 100 ]];then
        echo "Quota execeded running auto cleanup"
        auto_cleanup
    fi
    return 0
}

#################################################
# Function: main
# Description: Main function that routes to appropriate functions
# Parameters: multiple (command line arguments)
# Returns: 0 on success
#################################################
main(){

    local first_arg=$1
    shift

    case $first_arg in
    
        initialize_recyclebin | -i)
        initialize_recyclebin
        ;;

        delete_file | -d)
        delete_file "$@"
        ;;

        list_recycled | -l)
        list_recycled "$@"
        ;;

        empty_recyclebin | -e)
        empty_recyclebin "$@"
        ;;

        restore_file | -r)
        restore_files "$@"
        ;;

        search_recycled | -s)
        search_recycled "$@"
        ;;

        display_help | help | -h | --help)
        display_help "$@"
        ;;

        show_statistics | -S )
        show_statistics
        ;;

        auto_cleanup | -A )
        auto_cleanup
        ;;

        check_quota | -Q )
        check_quota
        ;;

        *)
        echo "Unknown command"
        ;;

    esac
    return 0
}

main $@