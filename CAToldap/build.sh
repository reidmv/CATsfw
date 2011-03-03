#!/bin/sh
# Script to generate CATdb package
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

PKGNAME='CAToldap'
PKGVERS='2.4.24'

PREFIX=/opt/sfw
STARTDIR="`pwd`"
PKGSRC="${STARTDIR}/openldap-${PKGVERS}.tar.gz"
SRCDIR="${STARTDIR}/openldap-${PKGVERS}"
PKGDIR="${STARTDIR}/pkg"
STAGINGDIR="${PKGDIR}/staging"
PKGBLDDIR="${PKGDIR}/build"

USER=$USER
GROUP=`id | sed 's/.*gid=[0-9]*(\([^)]*\))/\1/'`

AR=/opt/csw/bin/gar
CC=/opt/csw/gcc4/bin/gcc
CFLAGS="-I${SRCDIR}/include -I/opt/sfw/include -I/opt/csw/include -I/usr/include -I/usr/include/kerberosv5"
CPPFLAGS="-I${SRCDIR}/include -I/opt/sfw/include -D_GNU_SOURCE -I/opt/sfw/include"
CXXFLAGS="$CFLAGS"
LD=/opt/csw/gcc4/bin/ld
LDFLAGS="-L/opt/sfw/lib -R/opt/sfw/lib -R/opt/csw/lib -R/usr/lib -R/lib"
PATH='/bin:/sbin:/opt/csw/gcc4/bin:/opt/csw/bin:/usr/local/bin:/usr/ccs/bin'
LD_LIBRARY_PATH="/opt/sfw/lib:/lib:/usr/lib:/opt/csw/lib:/opt/csw/gcc4/lib"
LIBS="-ldb -lgcc_s"

export AR
export CC
export CFLAGS
export CPPFLAGS
export CXXFLAGS
export LD
export LDFLAGS
export PATH
export LD_LIBRARY_PATH
export LIBS

#=== FUNCTION ================================================================
#        NAME:  file_depends
# DESCRIPTION:  Prints the depends file for the solaris package
#=============================================================================
file_depend ()
{
	cat <<-EOF
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
	umask 0022
	cd "${STARTDIR}"

	echo "Unzipping package source..."
	if [ -d ${SRCDIR} ] ; then
	 rm -rf ${SRCDIR} && gtar xzf ${PKGSRC} || exit 1
	else
	 gtar xzf ${PKGSRC} || exit 1
	fi

	cd ${SRCDIR} || exit 1

	if [ -f Makefile ] ; then
	  echo "Making clean in ${SRCDIR}..."
	  /opt/csw/bin/gmake clean >/dev/null || exit 1
	fi
}

#=== FUNCTION ================================================================
#        NAME:  configure
# DESCRIPTION:  Gets stuff ready
#=============================================================================
configure ()
{
	echo "Running configure script..."
	./configure \
		--prefix="${PREFIX}" \
		--without-gnu-ld

	if [ $? -ne 0 ] ; then
	  [ ! -f "${SRCDIR}/config.log" ] && exit 1
	  for i in "${VISUAL}" "${EDITOR}" /bin/ed /bin/less /bin/more ; do
	    if [ -x "$i" ] ; then
	      $i "${SRCDIR}/config.log"
	      exit 1
	    fi
	  done
	  echo "Cannot exec editor or viewer for config.log" >&2
	  exit 1
	fi
}

#=== FUNCTION ================================================================
#        NAME:  compile
# DESCRIPTION:  Gets stuff ready
#=============================================================================
compile ()
{
	echo "Building package..."
	/opt/csw/bin/gmake -j 9 || exit 1
}

#=== FUNCTION ================================================================
#        NAME:  package
# DESCRIPTION:  Gets stuff ready
#=============================================================================
package ()
{
	if [ -d ${STAGINGDIR} ] ; then
	  rm -rf "${STAGINGDIR}" && \
	  mkdir -p "${STAGINGDIR}" || \
	  exit 1
	fi

	echo "Installing (fake) to ${STAGINGDIR}..."
	/opt/csw/bin/gmake DESTDIR="${STAGINGDIR}" install || exit 1
	mv ${STAGINGDIR}/${PREFIX}/* ${STAGINGDIR} && rmdir ${STAGINGDIR}/${PREFIX}

	echo "Calculating prototype..."
	if [ ! -d ${PKGDIR} ]; then
	 mkdir ${PKGDIR}
	fi
	if [ ! -d ${STAGINGDIR} ]; then
	 mkdir ${STAGINGDIR}
	fi
	if [ ! -d ${PKGBLDDIR} ]; then
	 mkdir ${PKGBLDDIR}
	fi

	cd "${PKGDIR}"

	cat > ${PKGDIR}/pkginfo <<-EOF
	PKG=CAToldap
	NAME=cat_openldap - OpenLDAP
	ARCH=`uname -p`
	VERSION=${PKGVERS},REV=`date +%Y-%m-%d`
	CATEGORY=application
	VENDOR=OpenLdap
	EMAIL=support@cat.pdx.edu
	PSTAMP=Reid Vandewiele
	BASEDIR=${PREFIX}
	CLASSES=none
	EOF

	touch ${PKGDIR}/copyright
	echo "i pkginfo" >"${PKGDIR}/prototype"
	echo "i copyright" >>"${PKGDIR}/prototype"
	echo "i depend" >>"${PKGDIR}/prototype"
	file_depend > ${PKGDIR}/depend
	pkgproto "${STAGINGDIR}=${PREFIX}" >> "${PKGDIR}/prototype"
	/opt/csw/bin/gsed -i "s/$USER $GROUP/root bin/" "${PKGDIR}/prototype"

	PKGNAME="${PKGDIR}/${PKGNAME}-${PKGVERS}-`uname -s``uname -r`-`uname -p`-CAT.pkg"

	echo "Building to ${PKGNAME}.gz"
	pkgmk -d "${PKGBLDDIR}"

	pkgtrans "${PKGBLDDIR}" "${PKGNAME}" <<-EOF
	all
	EOF
	gzip "${PKGNAME}"
}

#-----------------------------------------------------------------------------
# Call main to start things rolling.
#-----------------------------------------------------------------------------
main "$@"
