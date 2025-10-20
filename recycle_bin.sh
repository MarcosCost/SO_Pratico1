#!/bin/bash
set -e

#################################################
# Script Header Comment
# Author: Your Name
# Date: YYYY-MM-DD
# Description: Brief description
# Version: 1.0
#################################################


# Global Variables (ALL CAPS)
RECYCLE_BIN_DIR="$HOME/recycle_bin"    #FIXME: DONT FORGET TO CHANCE DIR NAME TO .recycle_bin BACK, TEMP recycle_bin FOR EASIER BROWSER/TESTING
METADATA_FILE="$RECYCLE_BIN_DIR/metadata.db"



#################################################
# Function: initialize_recyclebin
# Description: Inicia a Recycle_bin e todos os seus componentes caso não existam ainda. 
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
        printf "MAX_SIZE_MB=1024\n0\n" > "$RECYCLE_BIN_DIR/config"  
    fi 
    touch "$RECYCLE_BIN_DIR/recyclebin.log"
    return 0
}

#################################################
# Function: log
# Description: Log the parameter with a costum timestamp
# Parameters: 1
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
# Function: get_id
# Description: Ler a linha 2 do ficheiro config que contem the last issued ID
# Parameters: None
# Returns: 0 on success
#################################################
get_id(){
    echo $(head -n 2 "$RECYCLE_BIN_DIR/config" | tail -n 1)
    return 0
}
#################################################
# Function: update_id
# Description: Sobe o numero do ultimo Id por q
# Parameters: None
# Returns: 0 on success
#################################################
update_id(){
    local new_id_counter=$(($(get_id) + 1))
    sed -i "2c $new_id_counter" $RECYCLE_BIN_DIR/config
    return 0
}

#################################################
# Function: get_metadata
# Description: Obter a metadata de um ficheiro
# Parameters: Apenas 1
# Returns: 0 on success
#################################################
get_metadata(){
    if [ $# -ne 1 ]; then
        echo "Erro: get_metadata takes 1 argument only"
        echo "$(date +"[%d/%m/%Y %H:%M:%S]"): ERROR: get_metadata takes 1 argument only" >> $RECYCLE_BIN_DIR/recyclebin.log
        return 1
    fi
    local file="$1"

    #Values we need to get:
    local og_filename="$file"
    local og_abspath="$(realpath "$file")"
    local del_time="$(date +"[%Y/%m/%d %H:%M:%S]")"
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

#################################################TODO: No recursive thing yet
# Function: delete_file
# Description: Apagar ficheiros
# Parameters: Pelo menos 1
# Returns: 0 on success
#################################################
delete_file(){
    #Para cada um dos argumentos fazer o seguinte
    for var in "$@"
    do 
        #Skip invalid input
        if [ ! -e "$var" ]; then 
            echo "\"$var\" isn't a filename or directory"
            log "Failed to delete $(pwd)/$var - There is no such File/Dir"
            continue
        #FIXME: better checking
        elif [[ "$var" == "recycle_bin.sh" ]] || [[ "$var" == "README.md" ]] || [[ "$var" == "TECHNICAL_DOC.md" ]] || [[ "$var" == "TESTING.md" ]] || [[ "$var" == "test_suite.sh" ]] || [[ "$var" == ".gitignore" ]]; then
            echo "Cannot delete Project Structure items"
            log "Error: Cannot delete Project Structure items"
            continue
        fi

        update_id
        echo "$(get_id),$(get_metadata $var)" >> $METADATA_FILE
        mv "$var" "$RECYCLE_BIN_DIR/files/$(get_id)"
        
        echo "$(realpath "$var") was deleted"
        log "$(realpath "$var") Was deleted; ID:$id_counter"

    done
    return 0
}

#################################################
# Function: list_recycled
# Description: Lsta de todos os elementos da Bin
# Parameters: 1 or 0
# Returns: 0 on success
#################################################

list_recycled(){

    if [ "$#" -eq 0 ]; then
        awk -F',' '{print "| " $1 , "+| "$2 , "+| " $4 , "+| " $5 , "+|"}' $METADATA_FILE | column -t -s+
    elif [ "$#" -eq 1 ] && [ "$1" == "--detailed" ]; then
        awk -F, '{print "| " $1 , "+| " $2 , "+| " $3 , "+| " $4 , "+| " $5 , "+| " $6 , "+| " $7 , "+| " $8 , "+|"}' $METADATA_FILE | column -t -s+
    elif [ "$#" -eq 1 ] && [ "$1" != "--detailed" ]; then
        echo "\"$1\" is not recognized as a flag"
    else
        echo "list_recycled can only take one argument"
    fi
    echo
}




#################################################
# Function: main
# Description: Função principal que seleciona qual função é para correr
# Parameters: multiple
# Returns: 0 on success
#################################################
main(){

    first_arg=$1
    shift

    case $first_arg in
    
        initialize_recyclebin | 0)
        initialize_recyclebin
        ;;

        delete_file | 1)
        delete_file "$@"
        ;;

        list_recycled | 2)
        list_recycled "$@"
        ;;



        *)
        echo "Commands unkown"
        ;;

    esac

}

main $@