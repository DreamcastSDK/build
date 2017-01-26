#!/bin/sh

# Function to extract value from argument
# @param[in] $1 input string e.g. --flagname=value
arg_value () {
  echo "${1}" | sed -e "s/--[a-z]*=\(.*\)/\1/"
}

until
  opt=$1
  case ${opt} in

    -i)
      shift
      infile=$1
    ;;

    -o)
      shift
      outfile=$1
    ;;

    -n)
      shift
      name=$1
    ;;

    --input=*)
      infile=$(arg_value $1)
    ;;

    --output=*)
      outfile=$(arg_value $1)
    ;;

    --name=*)
      name=$(arg_value $1)
    ;;
    ?*)
      echo "Usage: bin2c.sh <infile> <outfile> <array_name>"
      echo "       bin2c.sh -i file -o file -n name"
      echo "       bin2c.sh --input=<file> --output=<file> --name=<array name>"
      exit 1
    ;;

    *)
    ;;
  esac
  [ "x${opt}" = "x" ]
do
  shift
done

size=`stat -c %s ${infile}`
header=`echo ${outfile} | sed -e "s/\([a-z]\)/\U\1/g" -e "s/[^0-9a-zA-Z]/_/g"`
echo "#ifndef _${header}_" >> ${outfile}
echo "#define _${header}_" >> ${outfile}
echo "" >> ${outfile}
echo "const int ${name}_size = ${size}" >> ${outfile}
echo "const unsigned char ${name}_data[${size}] = {" >> ${outfile}
od -t x1 ${infile} | sed -e "s/[0-9a-fA-F]\{7,9\}//" -e "s/ \([0-9a-fA-F][0-9a-fA-F]\)/0x\1, /g" >> ${outfile}
echo "};" >> ${outfile}
echo "" >> ${outfile}
echo "#endif" >> ${outfile}
