#!/bin/sh

# To modify versions and repos, edit components.conf,  NOT this script

# To see options, run this script with the "--help" argument

# The script returns 1 on failure and 0 on success. Failure to delete a
# pre-existing version when specifying --clean is not considered a failure.


################################################################################
#                                                                              #
#                               Shell functions                                #
#                                                                              #
################################################################################

# Function to print to stdout and log
# @param[in] $@ message
announce () {
  echo "${@}" | tee -a ${log}
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

# Function concatonate strings into a single string
# @param[in] $@ input strings
concat () {
  until [ "x${1}" = "x" ]
  do
    echo -n "${1}"
    shift
  done
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
    echo "false"
  fi
  echo "true"
}

has_git=$(detect "git")
has_gzip=$(detect "gzip")
has_bzip2=$(detect "bzip2")
has_xz=$(detect "xz")

# identify and create command strings to download silently and with a progress output
if $(detect "wget")
then
  exec_download_silent="wget -q -c -O"
  exec_download_progress="wget --show-progress --progress=bar:force:noscroll -q -c -O"
elif $(detect "curl")
then
  exec_download_silent="curl -s -C - -o"
  exec_download_progress="curl -# -C - -o"
elif $(detect "fetch")
then
  exec_download_silent="fetch -q -m -a -o"
  exec_download_progress="fetch -m -a -o"
elif $(detect "aria2c")
then
  exec_download_silent="aria2c -q -c -o"
  exec_download_progress="aria2c -c -o"
else
  log_error "No download utility found!"
  return 1
fi

if $(detect "sha512sum")
then
  exec_sha_checksum="sha512sum"
elif $(detect "shasum")
then
  exec_sha_checksum="shasum -a 512"
elif $(detect "sha512")
then
  exec_sha_checksum="sha512"
else
  exec_sha_checksum="false"
fi



# Function to download a file

# @param[in] $1 url
# @param[in] $2 output file
# @param[in] $3 options (optional)

# @return the result of the underlying call or 1 if no utility is found

download ()
{
  url=$1
  outfile=$2
  options=$3

  case ${options} in
    silent)
      eval "${exec_download_silent} \"${outfile}\" \"${url}\""
    ;;
    *)
      eval "${exec_download_progress} \"${outfile}\" \"${url}\""
    ;;
  esac
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
    if ! mv $(echo "${filename}" | sed -e "s/\(.*\).tar.[a-z]\{2,3\}/\1/") ${destination} >> ${log} 2>&1
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
validate_file () {
  filename=${1}
  sha512sum=${2}

  if [ "${exec_sha_checksum}" = "false" ]
  then
    echo "No checksum tool found. Skipping check."
    return 0
  fi

  echo -n "Validating ${filename}..."
  checksum=$(${exec_sha_checksum} ${filename} | cut -d ' ' -f 1)

  if [ "${checksum}" != "${sha512sum}" ]
  then
    echo "INVALID!"
    log_error "Checksum failure: expected ${sha512sum} but got ${checksum}"
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
  name=$1
  branch=$2
  organization=$3
  eval "`echo "${name}" | sed -e "s/[^0-9a-zA-Z]/_/g"`_dir=${name}"

  # If --clean is in action and old source exists, attempt delete
  # If old source exists, delete
  if ${clean}
  then
    if ! rm -Rf ${name} >> ${log} 2>&1
    then
      log_warning "Unable to delete old ${name}"
    fi
  fi

  if [ -e "${name}" ]
  then
    echo "${name} already downloaded."
  elif ${clone} && ${has_git}
  then
    echo "Cloning ${name}..."
    if ! git clone -q -b ${branch} ${git_transport_prefix}/${organization}/${name}.git >> ${log} 2>&1
    then
      log_error "Unable to clone ${name}"
      return 1
    fi
  else
    echo "Downloading repository: \"${name}\" - branch: \"${branch}\""
    if ! download "${git_transport_prefix}/${organization}/${name}/archive/${branch}.tar.gz" "${name}-${branch}.tar.gz"
    then
      log_error "Unable to download ${name}"
      return 1
    fi

    if ! unpack "${name}-${branch}.tar.gz" "${name}"
    then
      log_error "Unable to unpack ${name}"
      return 1
    fi
  fi
}


# Function to either download a tool or clone a git repository

# @param[in] $1 destination directory
# @param[in] $2 source URL

# @return  The result of the underlying call to clone or download a tool.
generic_download_tool ()
{
  name=$1
  url=$2
  eval "`echo \"${name}\" | sed -e \"s/[^0-9a-zA-Z]/_/g\"`_dir=\"${name}\""

  filename=$(echo "${url}" | sed -e "s/.\+\/\([^/]*.tar.[a-z]\{2,3\}\)/\1/")
  if [ "${filename}" = "${url}" ]
  then
    is_git="true"
  else
    is_git="false"
  fi

  # If --clean is in action and old source exists, attempt delete
  # If old source exists, delete
  if ${clean}
  then
    if ! rm -Rf ${name} >> ${log} 2>&1
    then
      log_warning "Unable to delete old ${name}"
    fi
  fi

  if [ -e "${name}" ]
  then
    echo "${name} already downloaded."
  elif ${is_git}
  then
    if ! ${has_git}
    then
      log_error "Unable to clone ${name}"
      return 1;
    fi
    echo "Cloning ${name}..."
    if ! git clone -q ${url} ${name} >> ${log} 2>&1
    then
      log_error "Unable to clone ${name}"
      return 1
    fi
  else
    echo "Downloading ${filename}..."

    if ! download ${url} ${filename}
    then
      log_error "Unable to download ${name}"
      return 1
    fi

    if ! unpack "${filename}" "${name}"
    then
      log_error "Unable to unpack ${name}"
      return 1
    fi
  fi
}


# Function to download a toolchain component

# @param[in] $1 Component name
# @param[in] $2 version
# @param[in] $3 gnu mirror URL (optional)

# @return 0 on success, anything else indicates failure
gnu_download_tool ()
{
  name=$1
  version=$2
  target=${name}-${version}
  urlbase=$3
  eval "`echo \"${name}\" | sed -e \"s/[^0-9a-zA-Z]/_/g\"`_dir=\"${target}\""

  if [ "x${urlbase}" = "x" ]
  then
    urlbase=${gnu_url}
  fi

  filename=""
  sha512sum=""

# If --clean is in action and old source exists, attempt delete
  if ${clean}
  then
    if ! rm -Rf ${target} >> ${log} 2>&1
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
      filename=$(ls ${target}.tar.*)
      if ${validate} && ! validate_file "${filename}" $(cat ${target}.sum)
      then
        log_error "Download for ${target} does not match checksum in checksums.txt"
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
          "${urlbase}/${name}" \
          "${urlbase}/${name}/releases" \
          "${urlbase}/${name}/releases/${target}" \
          "${urlbase}/${name}/${version}" \
          "${urlbase}/${name}/snapshots" \
          "${urlbase}/${name}/snapshots/${target}" \
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
          output=$(grep "${target}.tar" checksums.txt)
          if [ "x${output}" != "x" ]
          then
            echo " found."
            break
          fi
        fi
      done

      for line in $(grep "${target}.tar" checksums.txt | sed -e "s/\([0-9a-f]\{128\}\)  .*.tar.\([a-z]\{2,3\}\)/\1:\2/")
      do
        this_sha512sum=$(echo "${line}" | cut -d ':' -f 1)

        case $(echo "${line}" | cut -d ':' -f 2) in
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
            log_error "Parsing checksums.txt for ${target} from ${directory}"
            return 1
          ;;
        esac
      done

      announce "Downloading ${target}..."
      if ! download "${directory}/${filename}" "${filename}"
      then
        log_error "Unable to download ${name}"
        return 1
      fi

      if ${validate} && ! validate_file "${filename}" "${sha512sum}"
      then
        log_error "Download for ${target} does not match checksum in checksums.txt"
        return 1
      elif ${validate}
      then
        echo "${checksum}" > ${target}.sum
      fi

      rm -f checksums.txt

      if ! unpack "${filename}"
      then
        log_error "Unable to unpack ${name}"
        return 1
      fi
    fi

    if ${patch}
    then
      for patchfile in $(ls -1 ${basedir}/patches/*.diff | grep "${target}")
      do
        announce "Applying patch ${patchfile}..."
        patch -p1 -N -d ${target} -i ${patchfile} >> ${log} 2>&1
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

  if [ ! -f ${builddir}/config.guess ] || [ ! -f ${builddir}/config.sub ]
  then
    announce "\nUpdating configuration defaults..."
    if ! download "http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=HEAD" "${builddir}/config.guess" "silent"
    then
      log_error "Unable to download config.guess"
    fi
    if ! download "http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=HEAD"   "${builddir}/config.sub"   "silent"
    then
      log_error "Unable to download config.sub"
    fi
  fi

  for line in $(cat ${basedir}/components.conf | grep -v '^#' | grep -v '^$')
  do
    echo ""
    case ${line} in
      toolchain:*)
        name=$(      echo "${line}" | cut -d ':' -f 2)
        version=$(   echo "${line}" | cut -d ':' -f 3)
        forced_url=$(echo "${line}" | cut -d ':' -f 4)

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

      ${platform}:*)
        name=$(        echo "${line}" | cut -d ':' -f 2)
        branch=$(      echo "${line}" | cut -d ':' -f 3)
        organization=$(echo "${line}" | cut -d ':' -f 4)
        if [ "x${branch}" = "x" ]
        then
          branch="master"
        fi
        if [ "x${organization}" = "x" ]
        then
          organization="GravisZro"
        fi

        if ! git_tool "${name}" "${branch}" "${organization}"
        then
          return 1
        fi
      ;;

      library:*)
        name=$(echo "${line}" | cut -d ':' -f 2)
        url=$( echo "${line}" | sed -e "s/[^:]\+:[^:]\+:\(.\+\)/\1/")

        if ! generic_download_tool "${name}" "${url}"
        then
          return 1
        fi
        name_dir=$(echo "${name}" | sed -e "s/[^0-9a-zA-Z]/_/g")
        libraries="${libraries}${name_dir}:"
      ;;

      *)
        echo "Unrecognized prefix!"
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
install=false
uninstall=false
clean=false
clone=false
patch=true
build=true
build_arm_c_toolchain=true
build_sh4_c_toolchain=true
build_sh4_libc=true
build_sh4_cpp_compiler=true
build_libraries=true

platform="dreamcast"
git_transport_prefix="https://github.com"
gnu_url="ftp://gcc.gnu.org/pub"

basedir=$(absolutedir $(dirname $0))
builddir=$(absolutedir "${basedir}/builds")
installdir="/usr/local"
libraries=""

usage=$(concat \
      "\nUsage: ./setup.sh [--install]" \
      "\n                  [--uninstall]" \
      "\n                  [--installdir=<dir>]" \
      "\n                  [--builddir=<dir>]" \
      "\n                  [--clean]" \
      "\n                  [--clone | --download]" \
      "\n                  [--makejobs=<number>]" \
      "\n                  [--no-patch]" \
      "\n                  [--no-build]" \
      "\n                  [--no-arm-toolchain]" \
      "\n                  [--no-sh4-toolchain]" \
      "\n                  [--no-sh4-libc]" \
      "\n                  [--no-sh4-c++]" \
      "\n                  [--no-libraries]" \
      "\n                  [--help | -h]" \
      )
help=$(concat \
      "\n TODO: make help string" \
      )

until [ "x$1" = "x" ]
do
  option=$1
  case ${option} in
    --install)
      install=true
    ;;

    --uninstall)
      uninstall=true
    ;;

    --installdir=*)
      installdir=$(absolutedir $(arg_value ${option}))
    ;;

    --builddir=*)
      builddir=$(absolutedir $(arg_value ${option}))
    ;;

    --clean)
      clean=true
    ;;

    --clone)
      if ${has_git}
      then
        clone=true
      else
        echo "You must install \"git\" to use the clone option";
        exit 1
      fi
    ;;

    --download)
      clone=false
    ;;

    --makejobs=*)
      makejobs=$(arg_value ${option})
    ;;


    --no-patch)
      patch=false
    ;;

    --no-build)
      build_arm_c_toolchain=false
      build_sh4_c_toolchain=false
      build_sh4_libc=false
      build_sh4_cpp_compiler=false
      build_libraries=false
    ;;

    --no-arm-toolchain)
      build_arm_c_toolchain=false
    ;;

    --no-sh4-toolchain)
      build_sh4_c_toolchain=false
      build_sh4_libc=false
      build_sh4_cpp_compiler=false
    ;;

    --no-sh4-libc)
      build_sh4_libc=false
      build_sh4_cpp_compiler=false
    ;;

    --no-sh4-c++)
      build_sh4_cpp_compiler=false
    ;;

    --no-libraries)
      build_libraries=false
    ;;

    -h|--help)
      echo "${usage}"
      echo "${help}"
      exit 0
    ;;
    ?*)
      option=$(echo ${option} | sed -e "s/\(--[a-z]*\)=.*/\1/")
      echo "\nunrecognized option: ${option}"
      echo "${usage}"
      exit 1
    ;;

    *)
    ;;
  esac
  shift
done

if ${uninstall}
then
  echo -n "\nUninstalling..."
  sudo rm -Rf ${installdir}/${platform}
  echo -n "."
  sudo rm -f ${installdir}/bin/sh-${platform}-*
  echo -n "."
  sudo rm -f ${installdir}/bin/arm-${platform}-*
  echo -n "."
  sudo rm -f ${installdir}/bin/sh-elf-${gcc_dir}
  echo -n "."
  sudo rm -f ${installdir}/bin/arm-eabi-${gcc_dir}
  echo "."
  echo "\n======= [ Uninstall complete! ] ======="
  if ! ${install}
  then
    exit 0
  fi
fi

if ! ${install}
then
  echo -n "Download, build and install SDK? [y/N] "
  read doinstall
  case ${doinstall} in
    [yY]);;
    [yY][eE][sS]);;
    *)
      echo "\nAborting installation\n"
      eval "sh ${0} --help"
      echo ""
      exit 1
    ;;
  esac
fi


################################################################################
#                                                                              #
#                               Initialize setup                               #
#                                                                              #
################################################################################

echo "\n======= [ Initializing ] =======\n"

# Determine the number of processes to use for building
makejobs=$(nproc --all)
if [ $? -ne 0 ]
then
  makejobs=$(sysctl hw.ncpu | cut -f2 -d' ')
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
elif ! $(detect "sed")
then
  log_error "Unable to proceed without the \"sed\" stream editing tool."
  exit 1
elif ! $(detect "tee")
then
  log_error "Unable to proceed without the \"tee\" tool."
  exit 1
elif ! $(detect "patch") && ${patch}
then
  log_error "Unable to proceed without the \"patch\" tool."
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

if ${build_arm_c_toolchain} || ${build_sh4_c_toolchain}
then
  assert_dir "Binutils"   "${binutils_dir}"
  assert_dir "GCC"        "${gcc_dir}"
  assert_dir "Newlib"     "${newlib_dir}"
  assert_dir "GMP"        "${gmp_dir}"
  assert_dir "MPFR"       "${mpfr_dir}"
  assert_dir "MPC"        "${mpc_dir}"

  # make symlinks for GCC... at least until I figure out the flags to specify their locations
  if [ ! -e ${builddir}/${gcc_dir}/gmp ]
  then
    ln -sf ${builddir}/${gmp_dir}  ${builddir}/${gcc_dir}/gmp
    ln -sf ${builddir}/${mpfr_dir} ${builddir}/${gcc_dir}/mpfr
    ln -sf ${builddir}/${mpc_dir}  ${builddir}/${gcc_dir}/mpc
  fi
fi

target_name () {
  echo "`echo \"${1}\" | cut -d '-' -f 1`-${platform}"
}

step_template() {
  dir=${1}
  message=${2}
  command=${3}
  logfile=${4}
  olddir=$(pwd)

  announce "${message}"
  cd ${dir}
  if ! eval "${command} > ${logfile} 2>&1"
  then
    announce "FAILED!\nSee ${dir}/${logfile} for details."
    exit 1
  fi
  cd ${olddir}
}

configure_and_make () {
  wd_dir=${1}
  target=${2}
  new_target=$(target_name ${target})
  conf_flags="--prefix=${installdir} \
              --exec-prefix=${installdir}/${platform} \
              --with-gxx-include-dir=${installdir}/${platform}/${target}/include/c++ \
              --bindir=${installdir}/bin \
              --disable-werror \
              --target=${target} \
              --program-prefix=${new_target}- \
              ${3}"
  compilation_dir=${builddir}/${new_target}-${wd_dir}

  announce "\n[ ${new_target}-${wd_dir} ]"

  announce "Initializing..."
  rm -Rf ${compilation_dir} > /dev/null 2>&1
  mkdir -p ${compilation_dir}

  step_template ${compilation_dir} "Configuring..." "sh ${builddir}/${wd_dir}/configure ${conf_flags}" "config.log"
  step_template ${compilation_dir} "Building..."    "${make_tool} -j${makejobs}"                       "build.log"
  step_template ${compilation_dir} "Installing..."  "sudo ${make_tool} install"                        "install.log"

  announce "Cleaning up..."
  rm -Rf ${compilation_dir} > /dev/null 2>&1
}

# === FOR ALL TARGETS ===
library_options="--with-newlib --disable-libssp --disable-tls"

# === ARM TARGET ===
target="arm-eabi"
target_dir=${installdir}/${platform}/${target}
cpu_options="--with-arch=armv4"

# <=== BUILD ARM C TOOLCHAIN ===>
if ${build_arm_c_toolchain}
then
  configure_and_make "${binutils_dir}" "${target}"
  if [ -e "${gdb_dir}" ]
  then
    configure_and_make "${gdb_dir}" "${target}"
  fi
  configure_and_make "${gcc_dir}" "${target}" "${cpu_options} ${library_options} --enable-languages=c --without-headers"

  sudo cp ${basedir}/scripts/$(target_name ${target}).specs ${target_dir}/lib/specs
fi
# </=== BUILD ARM C TOOLCHAIN ===>

# === SH4 TARGET ===
target="sh-elf"
target_dir=${installdir}/${platform}/${target}
cpu_options="--with-endian=little --with-cpu=m4-single-only --with-multilib-list=m4-single-only,m4-nofpu,m4"

# <=== BUILD SH4 C TOOLCHAIN ===>
if ${build_sh4_c_toolchain}
then
  configure_and_make "${binutils_dir}" "${target}"
  if [ -e "${gdb_dir}" ]
  then
    configure_and_make "${gdb_dir}" "${target}"
  fi
  configure_and_make "${gcc_dir}" "${target}" "${cpu_options} ${library_options} --enable-languages=c --without-headers"

  sudo cp ${basedir}/scripts/$(target_name ${target}).specs ${target_dir}/lib/specs
  sudo rm ${target_dir}/lib/ldscripts/shlelf.*
  sudo cp ${basedir}/scripts/shlelf.x ${target_dir}/lib/ldscripts/
fi
# </=== BUILD SH4 C COMPILER ===>

# <=== BUILD SH4 LIB C ===>
if ${build_sh4_libc}
then
  target_prefix=${installdir}/bin/$(target_name ${target})
  export CC_FOR_TARGET=${target_prefix}-gcc
  export CXX_FOR_TARGET=${target_prefix}-c++
  export GCC_FOR_TARGET=${target_prefix}-gcc
  export AR_FOR_TARGET=${target_prefix}-ar
  export AS_FOR_TARGET=${target_prefix}-as
  export LD_FOR_TARGET=${target_prefix}-ld
  export NM_FOR_TARGET=${target_prefix}-nm
  export OBJDUMP_FOR_TARGET=${target_prefix}-objdump
  export RANLIB_FOR_TARGET=${target_prefix}-ranlib
  export READELF_FOR_TARGET=${target_prefix}-readelf
  export STRIP_FOR_TARGET=${target_prefix}-strip
  configure_and_make "${newlib_dir}" "${target}" "${cpu_options}"
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
fi
# </=== BUILD SH4 LIB C ===>

environment="-e PLATFORM=${platform} -e ARCH=${target} -e INSTALL_PATH=${installdir} -e DEBUG=true"

# <=== BUILD SH4 C++ COMPILER ===>
if ${build_sh4_cpp_compiler}
then
  assert_dir "KOS" "${kos_dir}"
  step_template "${builddir}/${kos_dir}" "Installing headers to build SH4 C++ compiler." "sudo ${make_tool} ${environment} install_headers"  "install_headers.log"

  configure_and_make "${gcc_dir}" "${target}" "${cpu_options} ${library_options} --enable-languages=c,c++ --enable-threads=kos"

  sudo cp ${basedir}/scripts/$(target_name ${target}).specs ${target_dir}/lib/specs
  sudo rm ${target_dir}/lib/ldscripts/shlelf.*
  sudo cp ${basedir}/scripts/shlelf.x ${target_dir}/lib/ldscripts/
fi
# </=== BUILD SH4 C++ COMPILER ===>

# <=== BUILD LIBRARIES ===>
if ${build_libraries}
then
  until [ "x${name_dir}:" = "x${libraries}" ]
  do
    name_dir=$(echo "${libraries}" | cut -d ':' -f 1)
    libraries=$(echo "${libraries}" | sed -e "s/[^:]*:\(.\+\)/\1/")

    assert_dir "${name_dir}" "${name_dir}"

    announce "\n[ ${name_dir} ]"
    if [ -e "${basedir}/makefiles/${name_dir}" ]
    then
      announce "Replacing Makefile..."
      cp -f ${basedir}/makefiles/${name_dir} ${builddir}/${name_dir}/Makefile
    fi
    step_template "${builddir}/${name_dir}" "Building..."   "${make_tool} -j${makejobs} ${environment}" "build.log"
    step_template "${builddir}/${name_dir}" "Installing..." "sudo ${make_tool} ${environment} install"  "install.log"
  done
fi
# </=== BUILD LIBRARIES ===>

echo "\n======= [ Installation complete! ] ======="

exit 0

=== GCC options ===
#optimizations
-ffunction-sections
-fdata-sections

# for non-specialized toolchains
# SH toolchains
CFLAGS=-ml -m4-single-only
AFLAGS=-little
LDFLAGS=-ml -m4-single-only -Wl,-Ttext=0x8c010000 -Wl,--gc-sections

# ARM toolchains
CFLAGS= -mcpu=arm7di -fno-strict-aliasing -Wl,--fix-v4bx -Wa,--fix-v4bx
AFLAGS= -mcpu=arm7di --fix-v4bx
