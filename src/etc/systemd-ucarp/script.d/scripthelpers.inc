
BIN_IP="/usr/sbin/ip"
BIN_GREP="/usr/bin/grep"
BIN_MAWK="/usr/bin/mawk"
BIN_ARPING="/usr/bin/arping"

check_binaries () {

	[ -x $BIN_IP ] || { echo "ERROR: Binary "$BIN_IP" not executable. Aborting!" ; exit 10; }
	[ -x "$BIN_GREP" ] || { echo "ERROR: Binary "$BIN_GREP" not executable. Aborting!" ; exit 11; }
	[ -x "$BIN_MAWK" ] || { echo "ERROR: Binary "$BIN_MAWK" not executable. Aborting!" ; exit 12; }
	[ -x "$BIN_ARPING" ] || { echo "ERROR: Binary "$BIN_" not executable. Aborting!" ; exit 13; }

	return 0
}

getnetmask () {

	ip address show $1  | grep -E "^[[:space:]]+inet" | grep -v secondary | head -n 1 | mawk '{ print $2 }' | mawk -F / '{ print $2}'	

}

check_binaries ||  { echo "Error: necessary binaries not found. Aborting!"; exit 1;  }


