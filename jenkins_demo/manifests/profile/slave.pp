class jenkins_demo::profile::slave {
  include ::lsststack

  if $::operatingsystemmajrelease == '7' {
    include ::docker

    $docker = 'docker'
    $dockergc = '/usr/local/bin/docker-gc'

    archive { 'docker-gc':
      source  => 'https://raw.githubusercontent.com/spotify/docker-gc/master/docker-gc',
      path    => $dockergc,
      cleanup => false,
      extract => false,
    } ->
    # this isn't nessicary with puppet/archive 1.x
    file { $dockergc:
      mode => '0555',
    }

    cron { 'docker-gc':
      command => $dockergc,
      minute  => '0',
      hour    => '4',
    }
  } else {
    $docker = undef
  }

  $platform = downcase("${::operatingsystem}-${::operatingsystemmajrelease}")
  class { 'jenkins::slave':
    masterurl    => 'http://jenkins-master:8080',
    slave_name   => $::hostname,
    slave_groups => $docker,
    executors    => 1,
    labels       => "${::hostname} ${platform} ${docker}",
    # don't start slave before lsstsw build env is ready
    require      => [
      Class['lsststack'],
      Host['jenkins-master'],
    ],
  }

  # provides killall on el6 & el7
  ensure_packages(['psmisc'])
  ensure_packages(['lsof'])

  # virtualenv is needed by validate_drp
  class { 'python':
    version    => 'system',
    pip        => 'present',
    dev        => 'present',
    virtualenv => 'present',
  }
}
