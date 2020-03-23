#!/bin/bash
# This script converts all graphics files located in all subfolders to pdf.
# Order of pages depends on names of folders and files. To change it, rename those.

# Don't run this script as root
if [ $USER = root ]
then
    echo "Please don't run this script as superuser. Exiting. (to prevent this check use --allow-superuser)."
    exit 1
fi

function log {
    echo $(date) $1 >> log.txt
}

# list of directories
declare -a book_list
book_list=$(ls -d */)

if [ $? -gt 0 ]
then
    echo "No folders to process, or other error. Exiting."
    exit 0
fi

#debug
log "Processing following ${#book_list[*]} folders:"
for i in ${book_list[@]}
do
    echo $i
done

#do your job
for book in ${book_list[@]}
do
    mkdir tmp
    book=$(echo $book | sed 's/\///g')
    log "processing book: $book"
    unset dir_list
    unset file_list
    declare -a dir_list
    declare -a file_list
    dir_list=$(ls -d $book/*/)
    if [ $? -gt 0 ]
    then
        #no subfolders
        for file in $book/*.png;
        do
            log "debug: add to array: $file"
            file_list+=($file)
        done
    else
        #subfolders
        for dir in ${dir_list[*]}
        do
            log "process book: $book, folder: $dir"
            for file in $dir*.png
            do
                log "debug: add to array: $file"
                file_list+=($file)
            done
        done
    fi

    log "zero: ${file_list[0]}"
    log "first: ${file_list[1]}"
    log "all: ${file_list[*]}"

    total=${#file_list[*]}
    rounds=$(($total/10))
    rest=$(($total%10))

    log "total=$total"
    log "rounds=$rounds"
    log "rest=$rest"

    function norm {
        log "normalizing $1 --> $2"
        convert $1 -normalize $2;
        if [ $? -gt 0 ]; then log "error (normalizing), exiting"; exit 1; fi
    }

    function tojpeg {
        log "compressing $1 --> $2"
        convert $1 -compress jpeg -quality 50 $2;
        if [ $? -gt 0 ]; then log "error (compressing), exiting"; exit 1; fi
    }

    #rounds
    for (( j=0; j<$(( $rounds )); j++))
    do
        for (( i=0; i<$(( 10 )); i++ ))
        do
            norm ${file_list[$(( $j*10+$i ))]} tmp/$(( $j*10+$i )).png
            tojpeg tmp/$(( $j*10+$i )).png tmp/$(( $j*10+$i )).jpeg
        done
        #generate pdf
        log "create tmp/$j.pdf (for book $book)"
        convert $(for (( i=0; i<$(( 10 )); i++ )); do echo -n "tmp/$(( $j*10+$i )).jpeg "; done) tmp/$j.pdf
        if [ $? -gt 0 ]; then log "error (convert pdf rounds), exiting"; exit 1; fi
    done

    #rest
    for (( i=0; i<$(( $rest )); i++ ))
    do
        norm ${file_list[$(( $rounds*10+$i ))]} tmp/$(( $rounds*10+$i )).png
        tojpeg tmp/$(( $rounds*10+$i )).png tmp/$(( $rounds*10+$i )).jpeg
    done

    #generate pdf
    if [ $rest -gt 0 ]
    then
        log "create tmp/$rounds.pdf (for book $book)"
        convert $(for (( i=0; i<$(( $rest )); i++ )); do echo -n "tmp/$(( $rounds*10+$i )).jpeg "; done) tmp/$rounds.pdf
        if [ $? -gt 0 ]; then log "error (convert pdf rest), exiting"; exit 1; fi
    fi

    #join pdfs
    pdftk $(for i in tmp/*pdf; do echo -n "$i "; done) cat output $book.pdf
    if [ $? -gt 0 ]; then log "error (pdftk), exiting"; exit 1; fi

    #remove trash
    #for (( i=0; i<$total; i++ )); do rm tmp/$i.jpeg tmp/$i.png; done
    log "removing tmp folder"
    rm tmp/*
    rmdir tmp
done

exit 0
