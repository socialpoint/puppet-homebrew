class homebrew::compiler {

  if ! str2bool($::has_compiler) {
    notice('Installing Command Line Tools.')

    $install_command = '/tmp/install_command_line_tools.sh'
    file { $install_command :
      ensure => file,
      source => 'puppet:///modules/homebrew/install_command_line_tools.sh',
      owner  => 'root',
      mode   => '0744',
    }

    -> exec { 'Install command line tools':
      command => $install_command,
      creates => '/Library/Developer/CommandLineTools/usr/bin',
      user => 'root',
      timeout => 60 * 10
    }
  }
}
