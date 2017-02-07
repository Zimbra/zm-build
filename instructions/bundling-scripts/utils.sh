#!/bin/bash

Copy()
{
   if [ $# -ne 2 ]
   then
      echo "Usage: Copy <file1> <file2>" 1>&2
      exit 1;
   fi

   local src_file="$1"; shift;
   local dest_file="$1"; shift;

   mkdir -p "$(dirname "$dest_file")"

   cp -f "$src_file" "$dest_file"
}

Cpy2()
{
   if [ $# -ne 2 ]
   then
      echo "Usage: Cpy2 <file1> <dir>" 1>&2
      exit 1;
   fi

   local src_file="$1"; shift;
   local dest_dir="$1"; shift;

   mkdir -p "$dest_dir"

   cp -f "$src_file" "$dest_dir"
}


CreatePackage()
{
    if [ $# -ne 1 ]
    then
      echo "Usage: CreatePackage <os-name>" 1>&2
      exit 1
    fi

    if [[ $1 == UBUNTU* ]]
    then
        CreateDebianPackage
    elif [[ $1 == RHEL* ]]
    then
        CreateRhelPackage
    else
        echo "OS not supported. Run using UBUNTU or RHEL system. "
        exit 1
    fi

    if [ $? -ne 0 ]; then
        echo -e "\t### ${currentPackage} package building failed ###" >> ${buildLogFile}
    else
        echo -e "\t*** ${currentPackage} package successfully created ***" >> ${buildLogFile}
    fi

}

