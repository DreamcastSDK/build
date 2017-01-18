#!/bin/sh

# The script returns 1 on failure and 0 on success. Failure to delete a
# pre-existing version when specifying --clean is not considered a failure.


################################################################################
#                                                                              #
#                               Shell functions                                #
#                                                                              #
################################################################################

# Function to print to stdout and log
# @param[in] $1 message
announce () {
  echo ${1} | tee -a ${log}
}

# Function to record error to log
# @param[in] $1 message
log_error () {
  announce "ERROR: ${1}"
}

# Function to record warning to log
# @param[in] $1 message
log_warning () {
  announce "WARNING: ${1}"
}

# Function to extract value from argument
# @param[in] $1 input string e.g. --flagname=value
arg_value () {
  echo "${1}" | sed -e "s/--[a-z]*=\(.*\)/\1/"
}

# Function that faults if a directory doesn't exist
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
    echo false
  fi
  echo true
}


# Function to download a file

# @param[in] $1 url
# @param[in] $2 output file
# @param[in] $3 options (optional)

# @return the result of the underlying call or 1 if no utility is found
has_wget=$(detect "wget")
has_curl=$(detect "curl")
has_fetch=$(detect "fetch")
has_aria2c=$(detect "aria2c")
download ()
{
  url=$1
  outfile=$2
  options=$3

  if ${has_wget}
  then
    case ${options} in
      silent)
        wget -q -c -O "${outfile}" "${url}"
      ;;
      *)
        wget --show-progress --progress=bar:force:noscroll -q -c -O "${outfile}" "${url}"
      ;;
    esac
  elif ${has_curl}
  then
    case ${options} in
      silent)
        curl -s -C - -o "${outfile}" "${url}"
      ;;
      *)
        curl -# -C - -o "${outfile}" "${url}"
      ;;
    esac
  elif ${has_fetch}
    then
    case ${options} in
      silent)
        fetch -q -m -a -o "${outfile}" "${url}"
      ;;
      *)
        fetch -m -a -o "${outfile}" "${url}"
      ;;
    esac
  elif ${has_aria2c}
    then
    case ${options} in
      silent)
        aria2c -q -c -o "${outfile}" "${url}"
      ;;
      *)
        aria2c -c -o "${outfile}" "${url}"
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
  echo -n "Unpacking ${filename}... "
  if ! eval "tar xf ${filename}" >> ${log} 2>&1
  then
    echo "FAILED."
    log_error "Unable to unpack ${filename}"
    return 1
  else
    echo "done."
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

# Function to test a file's SHA256 checksum

# @param[in] $1 filename
# @param[in] $2 expected SH256 checksum

# @return 0 on success, 1 on failure.
has_sha512sum=$(detect "sha512sum")
has_shasum=$(detect "shasum")
has_sha512=$(detect "sha512")
validate_file () {
  filename=${1}
  sha512sum=${2}

  echo -n "Validating ${filename}... "
  if ${has_sha512sum}
  then
    checksum=`sha512sum ${filename} | cut -d ' ' -f 1`
  elif ${has_shasum}
  then
    checksum=`shasum -a 512 ${filename} | cut -d ' ' -f 1`
  elif ${has_sha512}
  then
    checksum=`sha512 ${filename} | cut -d ' ' -f 1`
  else
    echo "No checksum tool found. Skipping check."
    return 0
  fi

  if [ "${checksum}" != "${sha512sum}" ]
  then
    echo "INVALID!"
    log_error "checksum failure: expected ${sha512sum} but got ${checksum}"
    return 1
  else
    echo "valid."
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

  # If --clean is in action and old source exists, attempt delete
  # If old source exists, delete
  if ${clean}
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

  if [ "x${urlbase}" = "x" ]
  then
    urlbase=${gnu_url}
  fi

  filename=""
  sha512sum=""

# If --clean is in action and old source exists, attempt delete
  if ${clean}
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
  else
    if [ -e "${target}.sum" ]
    then
      echo "${target} archive already downloaded."
      filename=`ls ${target}.tar.*`
      if ${validate} && ! validate_file "${filename}" `cat ${target}.sum`
      then
        log_error "download for ${target} does not match checksum in checksums.txt"
        return 1
      fi

      if ! unpack "${filename}"
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
          if [ "x${output}" != "x" ]
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
            if [ "x${filename}" = "x" ] && ${has_gzip}
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

      announce "Downloading ${target}..."
      if ! download "${directory}/${filename}" "${filename}"
      then
        log_error "Unable to download ${tool}"
        return 1
      fi

      if ${validate} && ! validate_file "${filename}" "${sha512sum}"
      then
        log_error "download for ${target} does not match checksum in checksums.txt"
        return 1
      elif ${validate}
      then
        echo ${checksum} > ${target}.sum
      fi

      rm -f checksums.txt

      if ! unpack "${filename}"
      then
        log_error "Unable to unpack ${tool}"
        return 1
      fi
    fi

    if ${patch}
    then
      announce "Applying patches..."
      for patchfile in `ls -1 ${basedir}/patches/*.diff | grep "${target}"`
      do
        patch --batch --forward --directory=${target} --strip=1 < ${patchfile} >> ${log} 2>&1
      done
    fi
  fi
  [ true ]
}


# Function that loops over all component versions and downloads them

# @return 0 on success, anything else indicates failure
download_components()
{
  OLD_IFS=${IFS}
  IFS="
" # We only want the newline character

  announce "\nUpdating configuration defaults..."
  if ! download "http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=HEAD" "${builddir}/config.guess" "silent"
  then
    log_error "Unable to download config.guess"
  fi
  if ! download "http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=HEAD"   "${builddir}/config.sub"   "silent"
  then
    log_error "Unable to download config.sub"
  fi

  for line in `cat ${basedir}/components.conf | grep -v '^#' | grep -v '^$'`
  do
    echo ""
    case ${line} in
      toolchain:*)
        name=`      echo ${line} | cut -d ':' -f 2`
        version=`   echo ${line} | cut -d ':' -f 3`
        forced_url=`echo ${line} | cut -d ':' -f 4`

        if ! gnu_download_tool "${name}" "${version}" "${forced_url}"
        then
          return 1
        fi

        if [ -e ${builddir}/config.guess ]
        then
          cp ${builddir}/config.guess ${builddir}/${name}-${version}
          cp ${builddir}/config.sub ${builddir}/${name}-${version}
        fi
      ;;

      dreamcast:*)
        repo=`  echo ${line} | cut -d ':' -f 2`
        branch=`echo ${line} | cut -d ':' -f 3`
        organization=`  echo ${line} | cut -d ':' -f 4`
        if [ "x${branch}" = "x" ]
        then
          branch="master"
        fi
        if [ "x${organization}" = "x" ]
        then
          organization="GravisZro"
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
#                               Parse arguments                                #
#                                                                              #
################################################################################
# Defaults
uninstall=false
clean=false
clone=false
patch=true
build=true
git_transport_prefix="https://github.com"
gnu_url="ftp://gcc.gnu.org/pub"

basedir=$(absolutedir `dirname $0`)
builddir=$(absolutedir "${basedir}/builds")
installdir="/usr/local"

until
  opt=$1
  case ${opt} in
    --uninstall)
      uninstall=true
    ;;

    --no-patch)
      patch=false
    ;;

    --no-build)
      build=false
    ;;

    --clean)
      clean=true
    ;;

    --clone)
      clone=true
    ;;

    --download)
      clone=false
    ;;

    --builddir=*)
      builddir=$(absolutedir $(arg_value ${opt}))
    ;;

    --installdir=*)
      installdir=$(absolutedir $(arg_value ${opt}))
    ;;

    --makejobs=*)
      makejobs=$(arg_value ${opt})
    ;;


    ?*)
      echo "Usage: ./setup.sh [--uninstall]"
      echo "                  [--installdir=<dir>]"
      echo "                  [--builddir=<dir>]"
      echo "                  [--clean]"
      echo "                  [--no-patch]"
      echo "                  [--no-build]"
      echo "                  [--clone | --download]"
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

if ${uninstall}
then
  echo -n "\nUninstalling..."
  sudo rm -rf ${installdir}/dreamcast
  echo -n "."
  sudo rm -f ${installdir}/bin/sh-dreamcast-*
  echo -n "."
  sudo rm -f ${installdir}/bin/sh-elf-${gcc_dir}
  echo -n "."
  sudo rm -f ${installdir}/bin/arm-eabi-${gcc_dir}
  echo "."
  echo "\n======= [ Uninstall complete! ] ======="
  exit 0
fi

################################################################################
#                                                                              #
#                               Initialize setup                               #
#                                                                              #
################################################################################

echo "\n======= [ Initializing ] =======\n"

# Determine the number of processes to use for building
makejobs=`nproc --all`
if [ $? -ne 0 ]
then
  makejobs=`sysctl hw.ncpu | cut -f2 -d' '`
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
  log_error "No known \"make\" program could be found!"
  exit 1
fi

# GCC compiles fine with clang, but only if we use libstdc++ instead of libc++.
if $(detect "g++")
then
  export CXX="g++"
elif $(detect "clang++")
then
  export CXX="clang++ -stdlib=libstdc++"
else
  log_error "No known C++ compiler could be found!"
  exit 1
fi

# Create and then move into builddir location

if [ ! -e "${builddir}" ]
then
  if ! mkdir "${builddir}"
  then
    log_error "Unable to create directory for downloads/clones!"
    exit 1
  fi
fi

if ! cd "${builddir}"
then
  log_error "Unable to change to directory for downloads/clones!"
  exit 1
fi

# Set up a log file
#log="${builddir}/build-$(date +%F-%H%M).log"
log="${builddir}/build.log"
rm -f "${log}"

echo "build   dir: ${builddir}"
echo "install dir: ${installdir}"
echo "C++ compiler: ${CXX}"
echo "Logging to: ${log}"


if ! $(detect "tar")
then
  log_error "Unable to proceed without the \"tar\" archive tool."
  exit 1
fi

################################################################################
#                                                                              #
#                             Download everything                              #
#                                                                              #
################################################################################
echo "\n======= [ Downloading components ] ======="

# Download all components defined in 'components.conf'
if ! download_components
then
  log_error "Failed to download some components"
  echo "Downloads incomplete - see ${log} for details"
  exit 1
fi

echo "\n======= [ Downloads complete! ] ======="

################################################################################
#                                                                              #
#                          Configure, build, install                           #
#                                                                              #
################################################################################
echo "\n======= [ Configuring, building, installing ] ======="

assert_dir "Binutils" "${binutils_dir}"
assert_dir "GCC"      "${gcc_dir}"
assert_dir "Newlib"   "${newlib_dir}"
assert_dir "GMP"      "${gmp_dir}"
assert_dir "MPFR"     "${mpfr_dir}"
assert_dir "MPC"      "${mpc_dir}"

# make symlinks for GCC... at least until I figure out the flags to specify their locations
if [ ! -e ${builddir}/${gcc_dir}/gmp ]
then
  ln -srf ${builddir}/${gmp_dir}  ${builddir}/${gcc_dir}/gmp
  ln -srf ${builddir}/${mpfr_dir} ${builddir}/${gcc_dir}/mpfr
  ln -srf ${builddir}/${mpc_dir}  ${builddir}/${gcc_dir}/mpc
fi

if ! ${build}
then
  log_error "Not building.  Finished!"
  exit 0
fi


target_name () {
  echo `echo ${1} | cut -d '-' -f 1`-dreamcast
}

configure_and_make () {
  wd_dir=${1}
  target=${2}
  new_target=$(target_name ${target})
  conf_flags="--prefix=${installdir}
              --exec-prefix=${installdir}/dreamcast
              --with-gxx-include-dir=${installdir}/dreamcast/${target}/include
              --bindir=${installdir}/bin
              --disable-werror
              --target=${target}
              --program-prefix=${new_target}-
              ${3}"
  targetdir=${builddir}/${new_target}-${wd_dir}

  announce "\n[ ${new_target}-${wd_dir} ]"
  announce "Configuring..."
  rm -rf ${targetdir} > /dev/null 2>&1
  mkdir -p ${targetdir}
  cd ${targetdir}
  if ! sh ${builddir}/${wd_dir}/configure ${conf_flags} > config.log 2>&1
  then
    announce "FAILED!\nSee ${targetdir}/config.log for details."
    exit 1
  fi
  announce "Building..."
  if ! eval      "${make_tool} -j${makejobs} > build.log 2>&1"
  then
    announce "FAILED!\nSee ${targetdir}/build.log for details."
    exit 1
  fi
  announce "Installing..."
  if ! eval "sudo ${make_tool} install > install.log 2>&1"
  then
    announce "FAILED!\nSee ${targetdir}/install.log for details."
    exit 1
  fi
  cd ${builddir}
  rm -rf ${targetdir} > /dev/null 2>&1
}

library_options="--with-newlib --disable-libssp --disable-tls"

target="sh-elf"
cpu_options="--with-endian=little --with-cpu=m4-single-only --with-multilib-list=m4-single-only,m4-nofpu,m4"
configure_and_make ${binutils_dir} ${target}
if [ -e "${gdb_dir}" ]
then
  configure_and_make ${gdb_dir} ${target}
fi
configure_and_make ${gcc_dir} ${target} "${cpu_options} ${library_options} --enable-languages=c --without-headers"

export CC_FOR_TARGET=${installdir}/bin/sh-dreamcast-gcc
export CXX_FOR_TARGET=${installdir}/bin/sh-dreamcast-c++
export GCC_FOR_TARGET=${installdir}/bin/sh-dreamcast-gcc
export AR_FOR_TARGET=${installdir}/bin/sh-dreamcast-ar
export AS_FOR_TARGET=${installdir}/bin/sh-dreamcast-as
export LD_FOR_TARGET=${installdir}/bin/sh-dreamcast-ld
export NM_FOR_TARGET=${installdir}/bin/sh-dreamcast-nm
export OBJDUMP_FOR_TARGET=${installdir}/bin/sh-dreamcast-objdump
export RANLIB_FOR_TARGET=${installdir}/bin/sh-dreamcast-ranlib
export READELF_FOR_TARGET=${installdir}/bin/sh-dreamcast-readelf
export STRIP_FOR_TARGET=${installdir}/bin/sh-dreamcast-strip

configure_and_make ${newlib_dir} ${target} "${cpu_options}"

unset CC_FOR_TARGET
unset CXX_FOR_TARGET
unset GCC_FOR_TARGET
unset AR_FOR_TARGET
unset AS_FOR_TARGET
unset LD_FOR_TARGET
unset NM_FOR_TARGET
unset OBJDUMP_FOR_TARGET
unset RANLIB_FOR_TARGET
unset READELF_FOR_TARGET
unset STRIP_FOR_TARGET

sudo cp    ${builddir}/kos/common/include/pthread.h      ${installdir}/dreamcast/${target}/include
sudo cp    ${builddir}/kos/common/include/sys/_pthread.h ${installdir}/dreamcast/${target}/include/sys
sudo cp    ${builddir}/kos/common/include/sys/sched.h    ${installdir}/dreamcast/${target}/include/sys
sudo cp -r ${builddir}/kos/common/include/kos            ${installdir}/dreamcast/${target}/include
sudo cp -r ${builddir}/kos/dreamcast/include/arch        ${installdir}/dreamcast/${target}/include
sudo cp -r ${builddir}/kos/dreamcast/include/dc          ${installdir}/dreamcast/${target}/include

configure_and_make ${gcc_dir} ${target} "${cpu_options} ${library_options} --enable-languages=c,c++ --enable-threads=kos"

sudo cp ${basedir}/scripts/$(target_name ${target}).specs ${installdir}/dreamcast/${target}/lib/specs
sudo rm ${installdir}/dreamcast/${target}/lib/ldscripts/shlelf.*
sudo cp ${basedir}/scripts/shlelf.x ${installdir}/dreamcast/${target}/lib/ldscripts/


target="arm-eabi"
cpu_options="--with-arch=armv4"
configure_and_make ${binutils_dir} ${target}
if [ -e "${gdb_dir}" ]
then
  configure_and_make ${gdb_dir} ${target}
fi
configure_and_make ${gcc_dir} ${target} "${cpu_options} ${library_options} --enable-languages=c --without-headers"

sudo cp ${basedir}/scripts/$(target_name ${target}).specs ${installdir}/dreamcast/${target}/lib/specs

echo "\n======= [ Installation complete! ] ======="

exit 0

=== GCC options ===
#optimizations
-ffunction-sections
-fdata-sections

# for non-specialized toolchains
# SH toolchains
CFLAGS= -ml -m4-single-only
AFLAGS= -little
LDFLAGS= -ml -m4-single-only -Wl,-Ttext=0x8c010000 -Wl,--gc-sections

# ARM toolchains
CFLAGS= -mcpu=arm7di -fno-strict-aliasing -Wl,--fix-v4bx -Wa,--fix-v4bx
AFLAGS= -mcpu=arm7di --fix-v4bx
