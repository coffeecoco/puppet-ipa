# FreeIPA templating module by James
# Copyright (C) 2012-2013+ James Shubin
# Written by James Shubin <james@shubin.ca>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# NOTE: this has to be a singleton (eg: class) because we can only install one!
# NOTE: topology connections and peering information can be non-singleton types TODO
class ipa::server::replica::install(
	$peers = {}
) {

	include ipa::server::replica::install::base
	include ipa::vardir
	#$vardir = $::ipa::vardir::module_vardir	# with trailing slash
	$vardir = regsubst($::ipa::vardir::module_vardir, '\/$', '')

	# process possible replica masters that are available...
	$replica_fqdns_fact = "${::ipa_replica_prepared_fqdns}"	# fact!
	$replica_fqdns = split($replica_fqdns_fact, ',')	# list!

	# peering is always bidirectional for now :)
	# $peers is a hash of fqdn1 => fqdn2 pairs...

	#if has_key($peers, "${::fqdn}") and member($replica_fqdns, $peers["${::fqdn}"]) {
	#	$valid_fqdn = $peers["${::fqdn}"]
	if has_key($peers, "${::fqdn}") {
		$intersection = intersection($replica_fqdns, $peers["${::fqdn}"])
		# NOTE use empty() because 'if []' returns true!
		if empty($intersection) {
			$valid_fqdn = ''
		} else {
			# pick the first in the list if there is more than one!
			$valid_fqdn = pick($intersection, '')	# first
		}
	} else {
		$valid_fqdn = ''
	}

	if "${valid_fqdn}" == '' {
		warning("The requested peer: '${valid_fqdn}', isn't ready yet.")
	}

	$filename = "replica-info-${valid_fqdn}.gpg"
	$valid_file = "${vardir}/replica/install/${filename}"

	# send to all prepared hosts, so the keys don't flip flop if vip moves!
	ssh::send { $replica_fqdns:	# fqdn of where i got this from...

	}

	# TODO: tag can be used as grouping
	# NOTE: this could pull down multiple files...
	Ssh::File::Pull <<| tag == 'ipa-replica-prepare' |>> {
		path => "${vardir}/replica/install/",
		# tag this file so it doesn't get purged
		ensure => present,
		owner => root,
		group => nobody,
		mode => 600,			# u=rw
		backup => false,		# don't backup to filebucket
		before => Exec['ipa-install'],
		require => File["${vardir}/replica/install/"],
	}

	# this exec is purposefully very similar to the ipa-server-install exec
	exec { "/usr/sbin/ipa-replica-install --password=`/bin/cat '${vardir}/dm.password'` --unattended ${valid_file}":
		logoutput => on_failure,
		onlyif => [
			"/usr/bin/test '${valid_fqdn}' != ''",	# bonus safety!
			"/usr/bin/test -s ${valid_file}",
		],
		unless => "${::ipa::common::ipa_installed}",	# can't install if installed...
		timeout => 3600,	# hope it doesn't take more than 1 hour
		require => [
			File["${vardir}/"],
			Package['ipa-server'],
		],
		alias => 'ipa-install',	# same alias as server to prevent both!
	}
}

# vim: ts=8
