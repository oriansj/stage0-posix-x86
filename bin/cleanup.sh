#!/usr/bin/env bash
# Mes --- Maxwell Equations of Software
# Copyright © 2020 Jeremiah Orians
#
# This file is part of Mes.
#
# Mes is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or (at
# your option) any later version.
#
# Mes is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Mes.  If not, see <http://www.gnu.org/licenses/>.

# For keeping the bin directory, despite wanting to ignore it's contents
# and cleaning it up after

set -eux
rm -vf x86/bin/M1
rm -vf x86/bin/M2-Mesoplanet
rm -vf x86/bin/M2-Planet
rm -vf x86/bin/blood-elf
rm -vf x86/bin/catm
rm -vf x86/bin/chmod
rm -vf x86/bin/cp
rm -vf x86/bin/get_machine
rm -vf x86/bin/hex2
rm -vf x86/bin/kaem
rm -vf x86/bin/match
rm -vf x86/bin/mkdir
rm -vf x86/bin/sha256sum
rm -vf x86/bin/ungz
rm -vf x86/bin/untar
