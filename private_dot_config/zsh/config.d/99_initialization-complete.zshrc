# print a cow!

if [[ -n $ZSH_EXECUTE_ON_STARTUP ]] then
    $ZSH_EXECUTE_ON_STARTUP
else 
    CURRENT_COW=$(fortune | cowsay)
    echo $CURRENT_COW
fi

: