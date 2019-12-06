#!/bin/bash

# installr.sh
# A script to (optionally) erase a volume and install macos and
# additional packagesfound in a packages folder in the same directory
# as this script

if [[ $UID -ne 0 ]]; then
    echo "$0 must be run as root, or via sudo. Please enter your password:"
    exec sudo bash "$0" "$@"
fi

until [[ $(/usr/bin/pmset -g ps) == *"AC Power"* ]]; do
    echo "Please connect a Power Adapter to continue.."
    sleep 5
done

INDEX=0
OLDIFS=$IFS
IFS=$'\n'

# dirname and basename not available in Recovery boot
# so we get to use Bash pattern matching
BASENAME=${0##*/}
THISDIR=${0%$BASENAME}
PACKAGESDIR="${THISDIR}packages"

prompt="Please select the install:"
options=( $(find "${THISDIR%/1}" -maxdepth 1 -iname "install macos*" | while read LINE; do echo "${LINE##*/}" ; done ) )

PS3="$prompt "
select opt in "${options[@]}" "Quit" ; do 
    if (( REPLY == 1 + "${#options[@]}" )) ; then
        exit

    elif (( REPLY > 0 && REPLY <= "${#options[@]}" )) ; then
        echo  "You picked $opt which is $REPLY"

    else
        echo "Invalid option. Try another one."
    fi
done    


INSTALLMACOSAPP=$(echo "${THISDIR%/1}$opt")
STARTOSINSTALL=$(echo "${THISDIR%/1}$opt/Contents/Resources/startosinstall")

if [ ! -e "$STARTOSINSTALL" ]; then
    echo "Can't find an Install macOS app containing startosinstall in this script's directory!"
    exit -1
fi

echo "****** Welcome to installr! ******"
echo "macOS will be installed from:"
echo "    ${INSTALLMACOSAPP}"
echo "these additional packages will also be installed:"
for PKG in $(/bin/ls -1 "${PACKAGESDIR}"/*.pkg); do
    echo "    ${PKG}"
done
echo
echo "Available volumes:"
for VOL in $(/bin/ls -1 /Volumes) ; do
    if [[ "${VOL}" != "OS X Base System" ]] ; then
        let INDEX=${INDEX}+1
        VOLUMES[${INDEX}]=${VOL}
        echo "    ${INDEX}  ${VOL}"
    fi
done
read -p "Install to volume # (1-${INDEX}): " SELECTEDINDEX

SELECTEDVOLUME=${VOLUMES[${SELECTEDINDEX}]}

if [[ "${SELECTEDVOLUME}" == "" ]]; then
    exit 0
fi

read -p "Erase target volume before install (y/N)? " ERASETARGET

case ${ERASETARGET:0:1} in
    [yY] ) /usr/sbin/diskutil reformat "/Volumes/${SELECTEDVOLUME}" ;;
    * ) echo ;;
esac

echo
echo "Installing macOS to /Volumes/${SELECTEDVOLUME}..."

# build our startosinstall command
CMD="\"${STARTOSINSTALL}\" --agreetolicense --volume \"/Volumes/${SELECTEDVOLUME}\"" 

for ITEM in "${PACKAGESDIR}"/* ; do
    FILENAME="${ITEM##*/}"
    EXTENSION="${FILENAME##*.}"
    if [[ -e ${ITEM} ]]; then
        case ${EXTENSION} in
            pkg ) CMD="${CMD} --installpackage \"${ITEM}\"" ;;
            * ) echo "    ignoring non-package ${ITEM}..." ;;
        esac
    fi
done

# kick off the OS install
eval $CMD

