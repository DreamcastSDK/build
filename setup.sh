#!/bin/sh

# The script returns 1 on failure and 0 on success. Failure to delete a
# pre-existing version when specifying --force is not considered a failure.


################################################################################
#                                                                              #
#                               Shell functions                                #
#                                                                              #
################################################################################

# Function to print an error to stdout
# @param[in] $1 message
echo_error () {
  echo "ERROR: $1"
}


# Function to print an error to stdout
# @param[in] $1 message
echo_warning () {
  echo "WARNING: $1"
}


# Function to record error to log
# @param[in] $1 message
log_error () {
  echo_error "$1" | tee -a ${log}
}


# Function to record warning to log
# @param[in] $1 message
log_warning () {
  echo_warning "$1" | tee -a ${log}
}


# Function to detect if a program is usable
# @param[in] $1 input string e.g. --flagname=value
# @return "value"
getvalue () {
  echo "${1}" | sed -e "s/--[a-z]*=\(.*\)/\1/"
}


# Function to detect if a program is usable
# @param[in] $1 program name
# @param[in] $2 program directory
assert_dir () {
  if [ ! -e "${2}" ]
  then
    log_error "Directory for ${1} is missing! Expected: ${2}"
    exit 1
  fi
}


# Function to check for relative directory and makes it absolute
# @param[in] $1  The directory to make absolute if necessary.
absolutedir()
{
  case ${1} in
    /*)
      echo "${1}"
    ;;

    *)
      echo "${PWD}/${1}"
    ;;
  esac
}


# Function to detect if a program is usable
# @param[in] $1 program
# @return the result of the underlying call or 1 if no utility is found
detect () {
  eval "${1} --version >> /dev/null 2>&1"
  if [ $? -ne 0 ]
  then
    echo "false"
  fi
  echo "true"
}


# Function to download a file

# @param[in] $1 url
# @param[in] $2 output file
# @param[in] $3 options (optional)

# @return the result of the underlying call or 1 if no utility is found
has_wget=$(detect "wget")
has_curl=$(detect "curl")
download ()
{
  url=$1
  outfile=$2
  options=$3

  if ${has_wget}
  then
    case ${options} in
      silent)
        wget --quiet --continue --output-document="${outfile}" ${url}
      ;;
      *)
        wget --quiet --show-progress --progress=bar:force:noscroll --continue --output-document="${outfile}" ${url}
      ;;
    esac
  elif ${has_curl}
  then
    case ${options} in
      silent)
        curl -C - --silent --url "${url}" --output "${outfile}"
      ;;
      *)
        curl -C - --progress-bar --url "${url}" --output "${outfile}"
      ;;
    esac
  else
    log_error "no download utility found"
    return 1
  fi
  return $?
}


# Function to extract an archive

# @param[in] $1 filename
# @param[in] $2 destination (optional)

# @return 0 on success, 1 on failure.
unpack ()
{
  filename=$1
  destination=$2
  if ! eval "tar xf ${filename}" >> ${log} 2>&1
  then
    log_error "Unable to unpack ${filename}"
    return 1
  fi

  if [ "x$destination" != "x" ]
  then
    if ! mv `echo ${filename} | sed -e "s/\(.*\).tar.[a-z]\{2,3\}/\1/"` ${destination} >> ${log} 2>&1
    then
      log_error "Unable to move unpacked dir to ${destination}"
      return 1
    fi
  fi
}

# Function to either download a tool or clone a git repository from GitHub,
# checking out the relevant branch.

# @param[in] $1 The repo to clone/download.
# @param[in] $2 The branch to checkout/download.
# @param[in] $3 The user/organization.

# @return  The result of the underlying call to clone or download a tool.
git_tool ()
{
  repo=$1
  branch=$2
  organization=$3

  # If --force is in action and old source exists, attempt delete
  # If old source exists, delete
  if ${force}
  then
    if ! rm -rf ${repo} >> ${log} 2>&1
    then
      log_warning "Unable to delete old ${tool}"
    fi
  fi

  if [ -e "${repo}" ]
  then
    echo "${repo} already downloaded."
  elif ${clone}
  then
    echo "Cloning ${repo}..."
    if ! git clone -q -b ${branch} ${git_transport_prefix}/${organization}/${repo}.git >> ${log} 2>&1
    then
      log_error "Unable to clone ${tool}"
      return 1
    fi
  else
    echo "Downloading repository: \"${repo}\" - branch: \"${branch}\""
    if ! download "${git_transport_prefix}/${organization}/${repo}/archive/${branch}.tar.gz" "${repo}-${branch}.tar.gz"
    then
      log_error "Unable to download ${tool}"
      return 1
    fi

    echo "Unpacking ${repo}..."
    if ! unpack "${repo}-${branch}.tar.gz" "${repo}"
    then
      log_error "Unable to unpack ${repo}"
      return 1
    fi
  fi
}

# Function to download a toolchain component

# @param[in] $1 Component name
# @param[in] $2 version
# @param[in] $3 gnu mirror URL (optional)

# @return 0 on success, anything else indicates failure
has_gzip=$(detect "gzip")
has_bzip2=$(detect "bzip2")
has_xz=$(detect "xz")
gnu_download_tool ()
{
  tool=$1
  version=$2
  target=${tool}-${version}
  urlbase=$3
  eval "${tool}_dir=${target}"

  if [ "${urlbase}" = "" ]
  then
    urlbase=${gnu_url}
  fi

  filename=""
  sha512sum=""

# If --force is in action and old source exists, attempt delete
  if ${force}
  then
    if ! rm -rf ${target} >> ${log} 2>&1
    then
      log_warning "Unable to delete old ${target}"
    fi
  fi

# Download and unpack source if it does not already exist
  if [ -e "${target}" ]
  then
    echo "${target} already downloaded."
  elif [ -e `ls ${target}.tar.*` ]
  then
    echo "${target} archive already downloaded."
    echo "Unpacking ${target}..."
    if ! unpack `ls ${target}.tar.*`
    then
      log_error "Unable to unpack ${target}"
      return 1
    fi
  else
    echo -n "Locating ${target}.."
# check the locations it /might/ be
    for directory in \
        "${urlbase}/${tool}" \
        "${urlbase}/${tool}/releases" \
        "${urlbase}/${tool}/releases/${target}" \
        "${urlbase}/${tool}/${version}" \
        "${urlbase}/${tool}/snapshots" \
        "${urlbase}/${tool}/snapshots/${target}" \
        "${urlbase}/gcc/infrastructure" \
        "error"
    do
      echo -n "."
      if [ ${directory} = "error" ]
      then
        echo ""
        log_error "Unable to locate ${target} on server"
        return 1
      fi
      rm -f checksums.txt
      touch checksums.txt
      if download "${directory}/sha512.sum" "checksums.txt" "silent"
      then
        output=`grep "${target}.tar" checksums.txt`
        if [ "${output}" != "" ]
        then
          echo " found."
          break
        fi
      fi
    done

    for line in `grep "${target}.tar" checksums.txt | sed -e "s/\([0-9a-f]\{128\}\)  .*.tar.\([a-z]\{2,3\}\)/\1:\2/"`
    do
      this_sha512sum=`echo ${line} | cut -d ':' -f 1`

      case `echo ${line} | cut -d ':' -f 2` in
        gz)
          if [ "${filename}" = "" ] && ${has_gzip}
          then
            sha512sum=${this_sha512sum}
            filename=${target}.tar.gz
          fi
        ;;
        bz2)
        if ${has_bzip2}
        then
          sha512sum=${this_sha512sum}
          filename=${target}.tar.bz2
          fi
        ;;
        xz)
          if ${has_xz}
          then
            sha512sum=${this_sha512sum}
            filename=${target}.tar.xz
            break
          fi
        ;;
        *)
          log_error "parsing checksums.txt for ${target} from ${directory}"
          return 1
        ;;
      esac
    done

    echo "Downloading ${target}..."
    if ! download "${directory}/${filename}" "${filename}"
    then
      log_error "Unable to download ${tool}"
      return 1
    fi

    if ${validate}
    then
      echo "Validating ${target}..."
      checksum=`sha512sum ${filename} | cut -d ' ' -f 1`

      if [ "${checksum}" != "${sha512sum}" ]
      then
        print_error "checksum failure: expected ${sha512sum} but got ${checksum}"
        log_error "download for ${target} does not match checksum in checksums.txt"
        return 1
      else
        echo "Download validated."
      fi
    fi

    rm -f checksums.txt

    echo "Unpacking ${target}..."
    if ! unpack "${filename}"
    then
      log_error "Unable to unpack ${tool}"
      return 1
    fi
  fi
}


# Function that loops over all component versions and downloads them

# @return 0 on success, anything else indicates failure
download_components()
{
  OLD_IFS=${IFS}
  IFS="
" # We only want the newline character

  for line in `cat ${basedir}/components.conf | grep -v '^#' | grep -v '^$'`
  do
    case ${line} in
      toolchain:*)
        name=`      echo ${line} | cut -d ':' -f 2`
        version=`   echo ${line} | cut -d ':' -f 3`
        forced_url=`echo ${line} | cut -d ':' -f 4`

        if ! gnu_download_tool "${name}" "${version}" "${forced_url}"
        then
          return 1
        fi
      ;;

      dreamcast:*)
        repo=`  echo ${line} | cut -d ':' -f 2`
        branch=`echo ${line} | cut -d ':' -f 3`
        organization=`  echo ${line} | cut -d ':' -f 4`
        if [ "${branch}" = "" ]
        then
          branch="master"
        fi
        if [ "${organization}" = "" ]
        then
          organization="KallistiOS"
        fi

        if ! git_tool "${repo}" "${branch}" "${organization}"
        then
          return 1
        fi
      ;;

      lib:*)
        name=`echo ${line} | cut -d ':' -f 2`
        url=` echo ${line} | cut -d ':' -f 3`

        if ! lib_tool "${name}" "${url}"
        then
          return 1
        fi
      ;;

      *)
        echo Unrecognized prefix!
      ;;
    esac
  done


  # Restore IFS before returning
  IFS=${OLD_IFS}
}


################################################################################
#                                                                              #
#                              Detect programs                                 #
#                                                                              #
################################################################################

# Determine the number of processes to use for building
makejobs=`nproc --all`
if [ $? -ne 0 ]
then
  makejobs=`sysctl hw.ncpu | awk '{print $2}'`
  if [ $? -ne 0 ]
  then
    makejobs="1"
  fi
fi

has_make=$(detect "make")
has_gmake=$(detect "gmake")
if ${has_make}
then
  make_tool="make"
elif ${has_gmake}
then
  make_tool="gmake"
else
  print_error "no make system installed?!"
  exit 1
fi

################################################################################
#                                                                              #
#                              Parse arguments                                 #
#                                                                              #
################################################################################
# Defaults
force="false"
clone="false"
git_transport_prefix="https://github.com"
gnu_url="ftp://gcc.gnu.org/pub"

basedir=$(absolutedir `dirname $0`)
builddir=$(absolutedir "${basedir}/builds")
installdir="/usr"

until
  opt=$1
  case ${opt} in

    --force)
      force="true"
    ;;

    --clone)
      clone="true"
    ;;

    --download)
      clone="false"
    ;;

    --builddir=*)
      builddir=$(absolutedir $(getvalue ${opt}))
    ;;

    --installdir=*)
      installdir=$(absolutedir $(getvalue ${opt}))
    ;;

    --makejobs=*)
      makejobs=$(getvalue ${opt})
    ;;


    ?*)
      echo "Usage: ./setup.sh [--force]"
      echo "                  [--clone | --download]"
      echo "                  [--builddir=<dir>]"
      echo "                  [--installdir=<dir>]"
      echo "                  [--makejobs=<number>]"
      echo "                  [--help | -h]"
      exit 1
    ;;

    *)
    ;;
  esac
  [ "x${opt}" = "x" ]
do
  shift
done


################################################################################
#                                                                              #
#                              Initialize setup                                #
#                                                                              #
################################################################################

# Create and then move to builddir location

if [ ! -e "${builddir}" ]
then
  if ! mkdir "${builddir}"
  then
    print_error "Unable to create directory for downloads/clones"
    exit 1
  fi
fi

if ! cd "${builddir}"
then
  print_error "Unable to change to directory for downloads/clones"
  exit 1
fi

# Set up a log file
log="${builddir}/build-$(date +%F-%H%M).log"
rm -f "${log}"

echo "Logging to ${log}"

################################################################################
#                                                                              #
#                            Download everything                               #
#                                                                              #
################################################################################

# Download all components defined in 'components.conf'
if ! download_components
then
  log_error "Failed to download some components"
  echo "Downloads incomplete - see log for details"
  exit 1
fi

echo "Downloads complete"


################################################################################
#                                                                              #
#                              Patch and Build                                 #
#                                                                              #
################################################################################
assert_dir "Binutils" "${binutils_dir}"
assert_dir "GCC"      "${gcc_dir}"
assert_dir "GDB"      "${gdb_dir}"
assert_dir "Newlib"   "${newlib_dir}"
assert_dir "GMP"      "${gmp_dir}"
assert_dir "MPFR"     "${mpfr_dir}"
assert_dir "MPC"      "${mpc_dir}"

ln -s "../${gmp_dir}"  "${gcc_dir}/gmp"  >> ${log} 2>&1
ln -s "../${mpfr_dir}" "${gcc_dir}/mpfr" >> ${log} 2>&1
ln -s "../${mpc_dir}"  "${gcc_dir}/mpc"  >> ${log} 2>&1


configure_and_make () {
  wd_dir=${1}
  conf_flags=${2}
  cd ${basedir}

echo "Patching ${wd_dir}..."
  for patch in `ls -1 patches/*.diff | grep "${wd_dir}"`
  do
    patch --forward -d ${builddir}/${wd_dir} -p1 < ${patch}
  done
  cd ${builddir}/${wd_dir}
  echo "Configuring ${wd_dir}..."
  sh configure ${conf_flags} >> ${log} 2>&1
  echo "Building ${wd_dir}..."
  eval "${make_tool} -j${makejobs} DESTDIR=\"${basedir}/output/${wd_dir}\" >> ${log} 2>&1"
  eval "${make_tool} install DESTDIR=\"${basedir}/output/${wd_dir}\" >> ${log} 2>&1"
}

target_arch="sh-elf"
configure_and_make "${binutils_dir}"  "--prefix=${installdir}/${target_arch} --target=${target_arch}"
configure_and_make "${gdb_dir}"       "--prefix=${installdir}/${target_arch} --target=${target_arch}"
configure_and_make "${gcc_dir}"       "--prefix=${installdir}/${target_arch} --target=${target_arch} --without-headers --with-newlib --enable-languages=c --disable-libssp --disable-tls --with-multilib-list=m4-single-only,m4-nofpu,m4 --with-endian=little --with-cpu=m4-single-only"
configure_and_make "${newlib_dir}"    "--prefix=${installdir}/${target_arch} --target=${target_arch} --with-multilib-list=m4-single-only,m4-nofpu,m4 --with-endian=little --with-cpu=m4-single-only"
configure_and_make "${gcc_dir}"       "--prefix=${installdir}/${target_arch} --target=${target_arch} --with-newlib --enable-languages=c,c++,objc,obj-c++ --disable-libssp --disable-tls --with-multilib-list=m4-single-only,m4-nofpu,m4 --with-endian=little --with-cpu=m4-single-only --enable-threads=kos"

target_arch="arm-eabi"
configure_and_make "${binutils_dir}"  "--prefix=${installdir}/${target_arch} --target=${target_arch}"
configure_and_make "${gdb_dir}"       "--prefix=${installdir}/${target_arch} --target=${target_arch}"
configure_and_make "${gcc_dir}"       "--prefix=${installdir}/${target_arch} --target=${target_arch} --without-headers --with-newlib --enable-languages=c --disable-tls --disable-libssp --with-arch=armv4"



