#!/bin/bash
#set -e

#################################################
# Linux Recycle Bin Simulation
# Author: Marcos Costa (125882), José Mendes (114429)
# Date: YYYY-MM-DD
# Description: Shell-based recycle bin system
# Version: 1.0
#################################################

# Global Variables (ALL CAPS)
RECYCLE_BIN_DIR="$HOME/.recycle_bin"
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

    local any_failed=0

    #Para cada um dos argumentos fazer o seguinte
    for varr in "$@"; do

        local var="$varr"

        #Skip invalid input
        if [ ! -e "$var" ]; then
            echo "\"$var\" isn't a filename or directory"
            log "Failed to delete $(pwd)/$var - There is no such File/Dir"
            any_failed=1
            continue
        fi

        # Check if we have read permission
        if [ ! -r "$var" ]; then
            echo "Error: No read permission for '$var'"
            log "Failed to delete $var - No read permission"
            any_failed=1
            continue
        fi

        # Check if we have write permission to the directory containing the file
        local parent_dir=$(dirname "$var")
        if [ ! -w "$parent_dir" ]; then
            echo "Error: No write permission in directory for '$var'"
            log "Failed to delete $var - No write permission in parent directory"
            any_failed=1
            continue
        fi

        # Check if we have write permission to the file itself (for files)
        if [ -f "$var" ] && [ ! -w "$var" ]; then
            echo "Error: No write permission for file '$var'"
            log "Failed to delete $var - No write permission for file"
            any_failed=1
            continue
        fi

        # Check if we have execute permission for directories
        if [ -d "$var" ] && [ ! -x "$var" ]; then
            echo "Error: No execute permission for directory '$var'"
            log "Failed to delete $var - No execute permission for directory"
            any_failed=1
            continue
        fi

        local abs_path=$(realpath "$var" 2>/dev/null)
        #Não deletar a recycle bin itself
        if [[ "$abs_path" == "$(realpath "$RECYCLE_BIN_DIR" 2>/dev/null)"* ]] ||
           [[ "$abs_path" == "$HOME/.recycle_bin"* ]]; then
            echo "Cannot delete recycle bin itself or its contents"
            log "Attempted to delete recycle bin: $abs_path"
            any_failed=1
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
                any_failed=1
                break
            fi
        done
        if [ $is_protected -eq 1 ]; then
            continue
        fi



        if [[ -f $var ]];then

            local current_id=$(generate_unique_id)
            echo "$current_id,$(get_metadata "$var")" >> $METADATA_FILE
            mv "$var" "$RECYCLE_BIN_DIR/files/$current_id"
            echo "$(realpath "$var") was deleted"
            log "$(realpath "$var") Was deleted; ID:$current_id"

        elif [[ -d $var ]];then

            for recursive_var in "$var"/*; do
                [[ -e "$recursive_var" ]] || continue
                delete_file "$recursive_var"
            done

            local current_id=$(generate_unique_id)
            echo "$current_id,$(get_metadata "$var")" >> $METADATA_FILE
            mv "$var" "$RECYCLE_BIN_DIR/files/$current_id"
            echo "$(realpath "$var") was deleted"
            log "$(realpath "$var") Was deleted; ID:$current_id"

        fi

    done

    if [ $any_failed -eq 1 ]; then
        return 1
    else
        return 0
    fi
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
# Returns: 0 on success, 1 on failure
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
    if [[ -z "$target_id" ]]; then

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
# Parameters: At least 1 (ID or Filename)
# Returns: 0 on success, 1 on failure
#################################################           TODO:Permission denied at destination;   Disk space issues

restore_files(){

    if [[ "$#" -lt 1 ]]; then
        echo "Error: Restore Files needs at least 1 argument"
        echo "Usage: ./recycle_bin.sh -r [ID_OR_FILENAME]"
        return 1
    fi

    local any_failed=0

    for var in "$@"; do

        #Modo ID
        if [[ $var =~ ^[0-9]{10}_[a-zA-Z0-9]{6}$ ]]; then

            # Verificar se o ID existe no metadata
            if ! grep -q "^$var," "$METADATA_FILE"; then
                echo "Error: ID '$var' not found in recycle bin"
                log "Failed to restore item with ID '$var' - ID not found"
                any_failed=1
                continue
            fi

            #Split metadata into array
            IFS=',' read -ra arr <<< "$(grep "^$var," "$METADATA_FILE")"

            # Check if we have write permission to restore location
            local restore_dir=$(dirname "${arr[2]}")
            if [ ! -w "$restore_dir" ] && [ ! -w "$(dirname "$restore_dir")" ]; then
                echo "Error: No write permission to restore to '${arr[2]}'"
                log "Failed to restore ${arr[0]} - No write permission to destination"
                any_failed=1
                continue
            fi

            #Caso ja exista
            if [[ -e "${arr[2]}" ]];then

                echo "WARNING: There is a ${arr[5]} by the same name (${arr[1]}) in the target location already"
                echo "Do you wish to Override (O), Restore with Modified Name (M), or Cancel (q) "
                read -r confirmation

                case "$confirmation" in
                    O|o)
                        # Check write permission for overwrite
                        if [ -f "${arr[2]}" ] && [ ! -w "${arr[2]}" ]; then
                            echo "Error: No write permission to overwrite '${arr[2]}'"
                            any_failed=1
                            continue
                        fi

                        #Fix for placing directories inside directories instead of replacing
                        [[ -d "${arr[2]}" ]] && mv "${arr[2]}" "${arr[2]}_old"

                        mv "$RECYCLE_BIN_DIR/files/${arr[0]}" "${arr[2]}"

                        [[ -d "${arr[2]}_old" ]] && rm -rf "${arr[2]}_old"

                        grep -v "^${arr[0]}," "$METADATA_FILE" > "$METADATA_FILE.tmp"
                        mv "$METADATA_FILE.tmp" "$METADATA_FILE"
                        chmod "${arr[6]}" "${arr[2]}"

                        echo "Sucessfully Overwrote \"${arr[1]}\""
                        log "Sucessfully Overwrote \"${arr[2]}\" with \"${arr[0]}\""
                        ;;
                    M|m)
                        local timestamp=$(date +%s)
                        mv "$RECYCLE_BIN_DIR/files/${arr[0]}" "${arr[2]}_$timestamp"
                        grep -v "^${arr[0]}," "$METADATA_FILE" > "$METADATA_FILE.tmp"
                        mv "$METADATA_FILE.tmp" "$METADATA_FILE"
                        chmod "${arr[6]}" "${arr[2]}_$timestamp"

                        echo "Sucessfully restored \"${arr[1]}\" with name \"${arr[1]}_$timestamp\""
                        log "Sucessfully restored \"${arr[0]}\" at \"${arr[2]}_$timestamp\""
                        ;;
                    *)
                        echo "Restore operation for \"${arr[1]}\" was canceled"
                        log "Restore operation for \"${arr[0]}\" was canceled"
                        any_failed=1
                        continue
                        ;;

                esac
            else
                #Caso não exista

                #Criar any parent dirs necessarios to avoid errors
                mkdir -p "$(dirname "${arr[2]}")"

                mv "$RECYCLE_BIN_DIR/files/${arr[0]}" "${arr[2]}"
                grep -v "^${arr[0]}," "$METADATA_FILE" > "$METADATA_FILE.tmp"
                mv "$METADATA_FILE.tmp" "$METADATA_FILE"
                chmod "${arr[6]}" "${arr[2]}"

                echo "\"${arr[1]}\" restored sucessfully"
                log "\"${arr[0]}\" restored sucessfully"
            fi

        else #Mode Filename

            # Verificar se o Filename existe no metadata
            if ! grep -q ",$var," "$METADATA_FILE"; then
                echo "Error: Filename '$var' not found in recycle bin"
                log "Failed to restore item with Filename '$var' - Filename not found"
                any_failed=1
                continue
            fi

            #Split metadata into array
            IFS=',' read -ra arr <<< "$(grep ",$var," "$METADATA_FILE")"

            # Check if we have write permission to restore location
            local restore_dir=$(dirname "${arr[2]}")
            if [ ! -w "$restore_dir" ] && [ ! -w "$(dirname "$restore_dir")" ]; then
                echo "Error: No write permission to restore to '${arr[2]}'"
                log "Failed to restore ${arr[0]} - No write permission to destination"
                any_failed=1
                continue
            fi

            #Caso ja exista
            if [[ -e "${arr[2]}" ]];then

                echo "WARNING: There is a ${arr[5]} by the same name (${arr[1]}) in the target location already"
                echo "Do you wish to Override (O), Restore with Modified Name (M), or Cancel (q) "
                read -r confirmation

                case "$confirmation" in
                    O|o)
                        # Check write permission for overwrite
                        if [ -f "${arr[2]}" ] && [ ! -w "${arr[2]}" ]; then
                            echo "Error: No write permission to overwrite '${arr[2]}'"
                            any_failed=1
                            continue
                        fi
                        #Fix for placing directories inside directories instead of replacing
                        [[ -d "${arr[2]}" ]] && mv "${arr[2]}" "${arr[2]}_old"

                        mv "$RECYCLE_BIN_DIR/files/${arr[0]}" "${arr[2]}"

                        [[ -d "${arr[2]}_old" ]] && rm -rf "${arr[2]}_old"

                        grep -v "^${arr[0]}," "$METADATA_FILE" > "$METADATA_FILE.tmp"
                        mv "$METADATA_FILE.tmp" "$METADATA_FILE"
                        chmod "${arr[6]}" "${arr[2]}"

                        echo "Sucessfully Overwrote \"${arr[1]}\""
                        log "Sucessfully Overwrote \"${arr[2]}\" with \"${arr[0]}\""
                        ;;
                    M)
                        local timestamp=$(date +%s)
                        mv "$RECYCLE_BIN_DIR/files/${arr[0]}" "${arr[2]}_$timestamp"
                        grep -v "^${arr[0]}," "$METADATA_FILE" > "$METADATA_FILE.tmp"
                        mv "$METADATA_FILE.tmp" "$METADATA_FILE"
                        chmod "${arr[6]}" "${arr[2]}_$timestamp"

                        echo "Sucessfully restored \"${arr[1]}\" with name \"${arr[1]}_$timestamp\""
                        log "Sucessfully restored \"${arr[0]}\" at \"${arr[2]}_$timestamp\""
                        ;;
                    *)
                        echo "Restore operation for \"${arr[1]}\" was canceled"
                        log "Restore operation for \"${arr[0]}\" was canceled"
                        any_failed=1
                        continue
                        ;;

                esac
            else
                #Caso não exista

                #Criar any parent dirs necessarios to avoid errors
                mkdir -p "$(dirname "${arr[2]}")"

                mv "$RECYCLE_BIN_DIR/files/${arr[0]}" "${arr[2]}"
                grep -v "^${arr[0]}," "$METADATA_FILE" > "$METADATA_FILE.tmp"
                mv "$METADATA_FILE.tmp" "$METADATA_FILE"
                chmod "${arr[6]}" "${arr[2]}"

                echo "\"${arr[1]}\" restored sucessfully"
                log "\"${arr[0]}\" restored sucessfully"
            fi

        fi

    done

    # Retornar código de erro apropriado
    if [ $any_failed -eq 1 ]; then
        return 1
    else
        return 0
    fi
}

#################################################
# Function: search_recycled
# Description: Search files in recycle bin
# Parameters: Min 1 Max 2 ( -c and pattern)
# Returns: 0 on success, 1 on failure
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

        if [ $found -eq 0 ]; then
            echo "No matches found for '$arg'"
            return 1  # ← CORREÇÃO: Retornar 1 quando não encontra resultados
        else
            echo "$results"
            return 0
        fi

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
        return 1  # ← CORREÇÃO: Retornar 1 quando não encontra resultados
    else
        echo "$results"
        return 0
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

    local total_storage=0
    local file_storage=0
    local dir_storage=0
    local file_count=0
    local dir_count=0

    # Processar metadata apenas se houver entradas
    if [ -s "$METADATA_FILE" ] && [ $(wc -l < "$METADATA_FILE") -gt 1 ]; then
        {
        read  # Pular cabeçalho
        while IFS= read -r line; do
            IFS=',' read -ra fields <<< "$line"

            local size=${fields[4]}
            local type=${fields[5]}

            total_storage=$((total_storage + size))

            if [[ "$type" == "file" ]]; then
                file_storage=$((file_storage + size))
                file_count=$((file_count + 1))
            elif [[ "$type" == "directory" ]]; then
                dir_storage=$((dir_storage + size))
                dir_count=$((dir_count + 1))
            fi
        done
        } < "$METADATA_FILE"
    fi

    local total_count=$((file_count + dir_count))

    # Obter quota das configurações
    local max_size_mb=$(grep "^MAX_SIZE_MB=" "$RECYCLE_BIN_DIR/config" | cut -d '=' -f2)
    local quota_bytes=$((max_size_mb * 1000000))

    # Calcular percentagens com verificação
    local total_percent="0.0000000000"
    local file_percent="0.0000000000"
    local dir_percent="0.0000000000"

    if [ $quota_bytes -gt 0 ]; then
        total_percent=$(echo "scale=10; $total_storage * 100 / $quota_bytes" 2>/dev/null | bc 2>/dev/null || echo "0.0000000000")
        file_percent=$(echo "scale=10; $file_storage * 100 / $quota_bytes" 2>/dev/null | bc 2>/dev/null || echo "0.0000000000")
        dir_percent=$(echo "scale=10; $dir_storage * 100 / $quota_bytes" 2>/dev/null | bc 2>/dev/null || echo "0.0000000000")
    fi

    # Calcular tamanhos médios com verificação de divisão por zero
    local avg_total="0B"
    local avg_files="0B"
    local avg_dirs="0B"

    if [ $total_count -gt 0 ]; then
        avg_total=$(bytes_to_mb $((total_storage / total_count)) 2>/dev/null || echo "0B")
    fi

    if [ $file_count -gt 0 ]; then
        avg_files=$(bytes_to_mb $((file_storage / file_count)) 2>/dev/null || echo "0B")
    fi

    if [ $dir_count -gt 0 ]; then
        avg_dirs=$(bytes_to_mb $((dir_storage / dir_count)) 2>/dev/null || echo "0B")
    fi

    # Obter entradas mais recentes e mais antigas
    local newest_entry="N/A"
    local oldest_entry="N/A"

    if [ -s "$METADATA_FILE" ] && [ $(wc -l < "$METADATA_FILE") -gt 1 ]; then
        newest_entry=$(tail -n 1 "$METADATA_FILE" | cut -d ',' -f2)
        oldest_entry=$(head -n 2 "$METADATA_FILE" | tail -n 1 | cut -d ',' -f2)
    fi

    {
        echo "| +|Total+|Files+|Dir+|"
        echo "|Number of:+|$total_count+|$file_count+|$dir_count+|"
        echo "|Storage used:+|$(bytes_to_mb $total_storage)+|$(bytes_to_mb $file_storage)+|$(bytes_to_mb $dir_storage)+|"
        echo "|Quota+|${total_percent}% +|${file_percent}% +|${dir_percent}% +|"
        echo "|Average size+|$avg_total +|$avg_files +|$avg_dirs +|"
    } | column -t -s+

    echo ""
    echo "Newest entry: $newest_entry"
    echo "Oldest entry: $oldest_entry"

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
# Function: check_quota
# Description: Vê se o tamanho da bin excede o tamanho definido nas configs, caso positivo automaticamente corre auto cleanup
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

    local max_size_mb=$(grep "^MAX_SIZE_MB=" "$RECYCLE_BIN_DIR/config" | cut -d '=' -f2)
    local quota_bytes=$((max_size_mb * 1000000))

    # Calcular porcentagem sem bc - usando cálculo inteiro
    local percentage=0
    if [ $quota_bytes -gt 0 ]; then
        percentage=$((total_storage * 100 / quota_bytes))
    fi

    echo "Quota used: ${percentage}%"

    if [ $percentage -ge 100 ]; then
        echo "Quota exceeded running auto cleanup"
        auto_cleanup
    fi
    return 0
}

#################################################
# Function: preview_file
# Description: preview the file
# Parameters: 1
# Returns: 0 on success
#################################################
preview_file(){

    if [[ ! $1 =~ ^[0-9]{10}_[a-zA-Z0-9]{6}$ ]] || [[ "$#" -ne 1 ]]; then
        echo "preview_file only takes one ID as argument"
        log "ERROR: preview_files took invalid parameters"
        return 1
    fi

    if [[ "$(file "$RECYCLE_BIN_DIR/files/$1")" != "$RECYCLE_BIN_DIR/files/$1: ASCII text" ]];then
        echo "$(file "$RECYCLE_BIN_DIR/files/$1")"
    else
        echo "$(head "$RECYCLE_BIN_DIR/files/$1")"
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

    # If no arguments provided, show error
    if [ $# -eq 0 ]; then
        echo "Error: No command provided"
        echo "Use './recycle_bin.sh -h' for help"
        return 1
    fi

    local first_arg=$1
    shift

    case $first_arg in

        initialize_recyclebin | -i)
        initialize_recyclebin
        ;;

        delete_file | -d)
        if [ $# -eq 0 ]; then
            echo "Error: No files specified for deletion"
            echo "Usage: ./recycle_bin.sh -d [FILES]"
            return 1
        fi
        delete_file "$@"
        exit $?
        ;;

        list_recycled | -l)
        list_recycled "$@"
        ;;

        empty_recyclebin | -e)
        empty_recyclebin "$@"
        exit $?
        ;;

        restore_file | -r)
        if [ $# -eq 0 ]; then
            echo "Error: No files or IDs specified for restoration"
            echo "Usage: ./recycle_bin.sh -r [FILES_OR_IDS]"
            return 1
        fi
        restore_files "$@"
        exit $?
        ;;

        search_recycled | -s)
        if [ $# -eq 0 ]; then
            echo "Error: No search pattern specified"
            echo "Usage: ./recycle_bin.sh -s [PATTERN]"
            return 1
        fi
        search_recycled "$@"
        exit $?
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

        preview_file | -P )
        if [ $# -eq 0 ]; then
            echo "Error: No file ID specified for preview"
            echo "Usage: ./recycle_bin.sh -P [FILE_ID]"
            return 1
        fi
        preview_file "$@"
        ;;

        *)
        echo "Error: Unknown command '$first_arg'"
        echo "Use './recycle_bin.sh -h' for available commands"
        return 1
        ;;


    esac
    return 0
}

main $@
