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
    if [ ! -f $METADATA_FILE ]; then
        printf "ID,ORIGINAL_NAME,ORIGINAL_PATH,DELETION_DATE,FILE_SIZE,FILE_TYPE,PERMISSIONS,OWNER\n" > $METADATA_FILE    
    fi 
    echo "MAX_SIZE_MB=1024" > "$RECYCLE_BIN_DIR/config"
    touch "$RECYCLE_BIN_DIR/recyclebin.log"
    return 0
}

