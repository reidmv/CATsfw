#!/bin/sh
# Script to generate package
# Any similarity to aur PKGBUILDs is strictly coincidental.

#  This file is part of CATsfw.
#
#  CATsfw is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  CATsfw is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with CATsfw.  If not, see <http://www.gnu.org/licenses/>.

PKGNAME='CATkrb5'
PKGVERS='1.9'

PREFIX=/opt/sfw
STARTDIR="`pwd`"
PKGSRC="${STARTDIR}/krb5-${PKGVERS}.tar.gz"
SRCDIR="${STARTDIR}/krb5-${PKGVERS}/src"
PKGDIR="${STARTDIR}/pkg"
STAGINGDIR="${PKGDIR}/staging"
PKGBLDDIR="${PKGDIR}/build"

AR=/opt/csw/bin/gar
CC=/opt/csw/gcc4/bin/gcc
CFLAGS="-I/opt/sfw/include -I/opt/csw/include -I/usr/include"
CPPFLAGS="-I/opt/sfw/include -I/opt/csw/include -I/usr/include"
CXXFLAGS="$CFLAGS"
LD=/opt/csw/gcc4/bin/ld
LDFLAGS="-L/opt/sfw/lib -L/opt/csw/lib -L/usr/lib -L/lib -R/opt/sfw/lib:/opt/csw/lib:/usr/lib:/lib -lsasl2 -lintl -lgss"
PATH='/bin:/sbin:/opt/csw/gcc4/bin:/opt/csw/bin'
LD_LIBRARY_PATH="/opt/sfw/lib:/opt/csw/lib:/lib:/usr/lib:/opt/csw/gcc4/lib"

export AR
export CC
export CFLAGS
export CPPFLAGS
export CXXFLAGS
export LD
export LDFLAGS
export PATH
export LD_LIBRARY_PATH

#=== FUNCTION ================================================================
#        NAME:  file_depends
# DESCRIPTION:  Prints the depends file for the solaris package
#=============================================================================
file_depend ()
{
	cat <<-EOF
		P CATbdb
	EOF
}

#=== FUNCTION ================================================================
#        NAME:  file_pkginfo
# DESCRIPTION:  Prints the pkginfo file for the solaris package
#=============================================================================
file_pkginfo ()
{
	cat <<-EOF
		PKG=CATkrb5
		NAME=cat_krb5
		ARCH=`uname -p`
		VERSION=${PKGVERS},REV=`date +%Y-%m-%d`
		CATEGORY=application
		VENDOR=MIT
		EMAIL=support@cat.pdx.edu
		PSTAMP=Reid Vandewiele
		BASEDIR=${PREFIX}
		CLASSES=none
	EOF
}

#=== FUNCTION ================================================================
#        NAME:  main
# DESCRIPTION:  Does everything
#=============================================================================
main ()
{
	setup
	configure
	compile
	package	
}

#=== FUNCTION ================================================================
#        NAME:  setup
# DESCRIPTION:  Gets stuff ready
#=============================================================================
setup ()
{
	# Extract the source package
	cd "${STARTDIR}"
	echo "Unzipping package source..."
	if [ -d ${SRCDIR} ] ; then
	 rm -rf ${SRCDIR} && \
	 gtar xzf ${PKGSRC} || \
	 exit 1
	else
	 gtar xzf ${PKGSRC} || \
	 exit 1
	fi

	# Get the build and staging dir stuff ready
	if [ -d ${STAGINGDIR} ] ; then
	  rm -rf "${STAGINGDIR}" && \
	  mkdir -p "${STAGINGDIR}" || \
	  exit 1
	fi
	if [ ! -d ${PKGDIR} ]; then
	 mkdir ${PKGDIR}
	fi
	if [ ! -d ${STAGINGDIR} ]; then
	 mkdir ${STAGINGDIR}
	fi
	if [ ! -d ${PKGBLDDIR} ]; then
	 mkdir ${PKGBLDDIR}
	fi
}

#=== FUNCTION ================================================================
#        NAME:  configure
# DESCRIPTION:  Configures the software for compilation
#=============================================================================
configure ()
{
	echo "Configuring Package..."

	cd ${SRCDIR} || exit 1

	if [ -f Makefile ] ; then
	  echo "Making clean in ${SRCDIR}..."
	  /opt/csw/bin/gmake clean >/dev/null || exit 1
	fi

	./configure --prefix="${PREFIX}" \
		--enable-dns-for-realms

	[ $? -eq 0 ] || exit 1
}

#=== FUNCTION ================================================================
#        NAME:  compile
# DESCRIPTION:  Compiles the software
#=============================================================================
compile ()
{
	cd ${SRCDIR} || exit 1

	echo "Compiling package..."
	/opt/csw/bin/gmake DESTDIR="${STAGINGDIR}" || exit 1
}

#=== FUNCTION ================================================================
#        NAME:  package
# DESCRIPTION:  Creates a package for the software
#=============================================================================
package ()
{
	echo "Building package..."
	cd ${SRCDIR} || exit 1
	/opt/csw/bin/gmake -j 9 || exit 1

	echo "Installing (fake) to ${STAGINGDIR}..."
	/opt/csw/bin/gmake DESTDIR="${STAGINGDIR}" install || exit 1
	mv ${STAGINGDIR}/${PREFIX}/* ${STAGINGDIR} && rmdir ${STAGINGDIR}/${PREFIX}

	echo "Calculating prototype..."

	cd "${PKGDIR}"

	file_pkginfo     > ${PKGDIR}/pkginfo
	file_copyright   > ${PKGDIR}/copyright
	file_depend      > ${PKGDIR}/depend
	file_prototype   > ${PKGDIR}/prototype

	PKGNAME="${PKGDIR}/${PKGNAME}-${PKGVERS}-`uname -s``uname -r`-`uname -p`-CAT.pkg"

	echo "Building to ${PKGNAME}.gz"
	pkgmk -o -d "${PKGBLDDIR}"

	pkgtrans "${PKGBLDDIR}" "${PKGNAME}" <<-EOF
	all
	EOF
	gzip -f "${PKGNAME}"

}

#=== FUNCTION ================================================================
#        NAME:  file_copyright
# DESCRIPTION:  Prints the copyright file for the solaris package
#=============================================================================
file_copyright ()
{
	cat <<-EOF
	EOF
}

#=== FUNCTION ================================================================
#        NAME:  file_prototype
# DESCRIPTION:  Prints the prototype file for the solaris package
#=============================================================================
file_prototype ()
{
	USER=`id | sed 's/.*uid=[0-9]*(\([^)]*\)).*/\1/'`
	GROUP=`id | sed 's/.*gid=[0-9]*(\([^)]*\))/\1/'`
	TEMP=`mktemp`

	echo "i pkginfo"
	echo "i depend"
	echo "i copyright"
	(
		cd ${STAGINGDIR};
		pkgproto "${STAGINGDIR}=${PREFIX}" > $TEMP
                sed  "s/${USER} ${GROUP}/root bin/" $TEMP
	)
	rm $TEMP
}

#-----------------------------------------------------------------------------
# Call main to start things rolling.
#-----------------------------------------------------------------------------
main "$@"
