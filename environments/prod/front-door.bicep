param profiles_fd_sportdeets_name string
param vaults_sportsdataweb_externalid string

resource profiles_fd_sportdeets_name_resource 'Microsoft.Cdn/profiles@2025-04-15' = {
  name: profiles_fd_sportdeets_name
  location: 'Global'
  sku: {
    name: 'Standard_AzureFrontDoor'
  }
  kind: 'frontdoor'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    originResponseTimeoutSeconds: 60
  }
}

resource profiles_fd_sportdeets_name_default 'Microsoft.Cdn/profiles/afdendpoints@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_resource
  name: 'default'
  location: 'Global'
  properties: {
    enabledState: 'Enabled'
  }
}

resource profiles_fd_sportdeets_name_www 'Microsoft.Cdn/profiles/afdendpoints@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_resource
  name: 'www'
  location: 'Global'
  properties: {
    enabledState: 'Disabled'
  }
}

resource profiles_fd_sportdeets_name_about_origin_group 'Microsoft.Cdn/profiles/origingroups@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_resource
  name: 'about-origin-group'
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
      additionalLatencyInMilliseconds: 50
    }
    healthProbeSettings: {
      probePath: '/'
      probeRequestType: 'HEAD'
      probeProtocol: 'Https'
      probeIntervalInSeconds: 100
    }
    sessionAffinityState: 'Disabled'
  }
}

resource profiles_fd_sportdeets_name_apim_origin_group 'Microsoft.Cdn/profiles/origingroups@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_resource
  name: 'apim-origin-group'
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
      additionalLatencyInMilliseconds: 50
    }
    healthProbeSettings: {
      probePath: '/swagger/index.html'
      probeRequestType: 'GET'
      probeProtocol: 'Https'
      probeIntervalInSeconds: 100
    }
    sessionAffinityState: 'Disabled'
  }
}

resource profiles_fd_sportdeets_name_defaultorigingroup 'Microsoft.Cdn/profiles/origingroups@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_resource
  name: 'defaultorigingroup'
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
      additionalLatencyInMilliseconds: 50
    }
    healthProbeSettings: {
      probePath: '/'
      probeRequestType: 'HEAD'
      probeProtocol: 'Https'
      probeIntervalInSeconds: 100
    }
    sessionAffinityState: 'Disabled'
  }
}

resource profiles_fd_sportdeets_name_dev 'Microsoft.Cdn/profiles/origingroups@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_resource
  name: 'dev'
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
      additionalLatencyInMilliseconds: 50
    }
    healthProbeSettings: {
      probePath: '/'
      probeRequestType: 'HEAD'
      probeProtocol: 'Https'
      probeIntervalInSeconds: 100
    }
    sessionAffinityState: 'Disabled'
  }
}

resource profiles_fd_sportdeets_name_dev_api_origin 'Microsoft.Cdn/profiles/origingroups@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_resource
  name: 'dev-api-origin'
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
      additionalLatencyInMilliseconds: 50
    }
    healthProbeSettings: {
      probePath: '/api/health'
      probeRequestType: 'HEAD'
      probeProtocol: 'Https'
      probeIntervalInSeconds: 100
    }
    sessionAffinityState: 'Disabled'
  }
}

resource profiles_fd_sportdeets_name_dev_contest_origin 'Microsoft.Cdn/profiles/origingroups@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_resource
  name: 'dev-contest-origin'
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
      additionalLatencyInMilliseconds: 50
    }
    healthProbeSettings: {
      probePath: '/'
      probeRequestType: 'HEAD'
      probeProtocol: 'Https'
      probeIntervalInSeconds: 100
    }
    sessionAffinityState: 'Disabled'
  }
}

resource profiles_fd_sportdeets_name_dev_franchise_origin 'Microsoft.Cdn/profiles/origingroups@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_resource
  name: 'dev-franchise-origin'
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
      additionalLatencyInMilliseconds: 50
    }
    healthProbeSettings: {
      probePath: '/'
      probeRequestType: 'HEAD'
      probeProtocol: 'Https'
      probeIntervalInSeconds: 100
    }
    sessionAffinityState: 'Disabled'
  }
}

resource profiles_fd_sportdeets_name_dev_logging_origin 'Microsoft.Cdn/profiles/origingroups@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_resource
  name: 'dev-logging-origin'
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
      additionalLatencyInMilliseconds: 50
    }
    sessionAffinityState: 'Disabled'
  }
}

resource profiles_fd_sportdeets_name_dev_notification_origin 'Microsoft.Cdn/profiles/origingroups@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_resource
  name: 'dev-notification-origin'
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
      additionalLatencyInMilliseconds: 50
    }
    healthProbeSettings: {
      probePath: '/'
      probeRequestType: 'HEAD'
      probeProtocol: 'Https'
      probeIntervalInSeconds: 100
    }
    sessionAffinityState: 'Disabled'
  }
}

resource profiles_fd_sportdeets_name_dev_player_origin 'Microsoft.Cdn/profiles/origingroups@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_resource
  name: 'dev-player-origin'
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
      additionalLatencyInMilliseconds: 50
    }
    healthProbeSettings: {
      probePath: '/'
      probeRequestType: 'HEAD'
      probeProtocol: 'Https'
      probeIntervalInSeconds: 100
    }
    sessionAffinityState: 'Disabled'
  }
}

resource profiles_fd_sportdeets_name_dev_producer_football_ncaa_origin 'Microsoft.Cdn/profiles/origingroups@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_resource
  name: 'dev-producer-football-ncaa-origin'
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
      additionalLatencyInMilliseconds: 50
    }
    sessionAffinityState: 'Disabled'
  }
}

resource profiles_fd_sportdeets_name_dev_provider_football_ncaa_origin 'Microsoft.Cdn/profiles/origingroups@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_resource
  name: 'dev-provider-football-ncaa-origin'
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
      additionalLatencyInMilliseconds: 50
    }
    healthProbeSettings: {
      probePath: '/'
      probeRequestType: 'HEAD'
      probeProtocol: 'Https'
      probeIntervalInSeconds: 100
    }
    sessionAffinityState: 'Disabled'
  }
}

resource profiles_fd_sportdeets_name_dev_season_origin 'Microsoft.Cdn/profiles/origingroups@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_resource
  name: 'dev-season-origin'
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
      additionalLatencyInMilliseconds: 50
    }
    healthProbeSettings: {
      probePath: '/'
      probeRequestType: 'HEAD'
      probeProtocol: 'Https'
      probeIntervalInSeconds: 100
    }
    sessionAffinityState: 'Disabled'
  }
}

resource profiles_fd_sportdeets_name_homelab_cluster 'Microsoft.Cdn/profiles/origingroups@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_resource
  name: 'homelab-cluster'
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
      additionalLatencyInMilliseconds: 50
    }
    healthProbeSettings: {
      probePath: '/api/health'
      probeRequestType: 'GET'
      probeProtocol: 'Http'
      probeIntervalInSeconds: 100
    }
    sessionAffinityState: 'Disabled'
  }
}

resource profiles_fd_sportdeets_name_prod_ui_origin_group 'Microsoft.Cdn/profiles/origingroups@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_resource
  name: 'prod-ui-origin-group'
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
      additionalLatencyInMilliseconds: 50
    }
    healthProbeSettings: {
      probePath: '/'
      probeRequestType: 'GET'
      probeProtocol: 'Https'
      probeIntervalInSeconds: 100
    }
    sessionAffinityState: 'Disabled'
  }
}

resource profiles_fd_sportdeets_name_0_b26bc027_7d40_4a8e_80b6_be5c9dc5bd3d_about_sportdeets_com 'Microsoft.Cdn/profiles/secrets@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_resource
  name: '0--b26bc027-7d40-4a8e-80b6-be5c9dc5bd3d-about-sportdeets-com'
  properties: {
    parameters: {
      type: 'ManagedCertificate'
    }
  }
}

resource profiles_fd_sportdeets_name_0_f34783e3_9819_480d_953e_ffeced4505ac_api_sportdeets_com 'Microsoft.Cdn/profiles/secrets@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_resource
  name: '0--f34783e3-9819-480d-953e-ffeced4505ac-api-sportdeets-com'
  properties: {
    parameters: {
      type: 'ManagedCertificate'
    }
  }
}

resource profiles_fd_sportdeets_name_sportsdataweb_sportdeetssslissued_latest 'Microsoft.Cdn/profiles/secrets@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_resource
  name: 'sportsdataweb-sportdeetssslissued-latest'
  properties: {
    parameters: {
      type: 'CustomerCertificate'
      secretSource: {
        id: '${vaults_sportsdataweb_externalid}/secrets/sportdeetssslissued'
      }
      secretVersion: '3fcf8497f2c2425eaf92661cc2495f8d'
      useLatestVersion: true
      subjectAlternativeNames: [
        '*.sportdeets.com'
        'sportdeets.com'
      ]
    }
  }
}

resource profiles_fd_sportdeets_name_about_sportdeets_com 'Microsoft.Cdn/profiles/customdomains@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_resource
  name: 'about-sportdeets-com'
  properties: {
    hostName: 'about.sportdeets.com'
    tlsSettings: {
      certificateType: 'ManagedCertificate'
      minimumTlsVersion: 'TLS12'
      cipherSuiteSetType: 'TLS12_2022'
      secret: {
        id: profiles_fd_sportdeets_name_0_b26bc027_7d40_4a8e_80b6_be5c9dc5bd3d_about_sportdeets_com.id
      }
    }
  }
}

resource profiles_fd_sportdeets_name_admin_sportdeets_com 'Microsoft.Cdn/profiles/customdomains@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_resource
  name: 'admin-sportdeets-com'
  properties: {
    hostName: 'admin.sportdeets.com'
    tlsSettings: {
      certificateType: 'CustomerCertificate'
      minimumTlsVersion: 'TLS12'
      cipherSuiteSetType: 'TLS12_2023'
      secret: {
        id: profiles_fd_sportdeets_name_sportsdataweb_sportdeetssslissued_latest.id
      }
    }
  }
}

resource profiles_fd_sportdeets_name_analytics_sportdeets_com 'Microsoft.Cdn/profiles/customdomains@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_resource
  name: 'analytics-sportdeets-com'
  properties: {
    hostName: 'analytics.sportdeets.com'
    tlsSettings: {
      certificateType: 'CustomerCertificate'
      minimumTlsVersion: 'TLS12'
      cipherSuiteSetType: 'TLS12_2022'
      secret: {
        id: profiles_fd_sportdeets_name_sportsdataweb_sportdeetssslissued_latest.id
      }
    }
  }
}

resource profiles_fd_sportdeets_name_api_dev_sportdeets_com_6dee 'Microsoft.Cdn/profiles/customdomains@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_resource
  name: 'api-dev-sportdeets-com-6dee'
  properties: {
    hostName: 'api-dev.sportdeets.com'
    tlsSettings: {
      certificateType: 'CustomerCertificate'
      minimumTlsVersion: 'TLS12'
      cipherSuiteSetType: 'TLS12_2023'
      secret: {
        id: profiles_fd_sportdeets_name_sportsdataweb_sportdeetssslissued_latest.id
      }
    }
  }
}

resource profiles_fd_sportdeets_name_api_int_sportdeets_com 'Microsoft.Cdn/profiles/customdomains@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_resource
  name: 'api-int-sportdeets-com'
  properties: {
    hostName: 'api-int.sportdeets.com'
    tlsSettings: {
      certificateType: 'CustomerCertificate'
      minimumTlsVersion: 'TLS12'
      cipherSuiteSetType: 'TLS12_2022'
      secret: {
        id: profiles_fd_sportdeets_name_sportsdataweb_sportdeetssslissued_latest.id
      }
    }
  }
}

resource profiles_fd_sportdeets_name_api_sportdeets_com 'Microsoft.Cdn/profiles/customdomains@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_resource
  name: 'api-sportdeets-com'
  properties: {
    hostName: 'api.sportdeets.com'
    tlsSettings: {
      certificateType: 'ManagedCertificate'
      minimumTlsVersion: 'TLS12'
      cipherSuiteSetType: 'TLS12_2022'
      secret: {
        id: profiles_fd_sportdeets_name_0_f34783e3_9819_480d_953e_ffeced4505ac_api_sportdeets_com.id
      }
    }
  }
}

resource profiles_fd_sportdeets_name_contest_dev_sportdeets_com_895c 'Microsoft.Cdn/profiles/customdomains@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_resource
  name: 'contest-dev-sportdeets-com-895c'
  properties: {
    hostName: 'contest-dev.sportdeets.com'
    tlsSettings: {
      certificateType: 'CustomerCertificate'
      minimumTlsVersion: 'TLS12'
      cipherSuiteSetType: 'TLS12_2023'
      secret: {
        id: profiles_fd_sportdeets_name_sportsdataweb_sportdeetssslissued_latest.id
      }
    }
  }
}

resource profiles_fd_sportdeets_name_dev_sportdeets_com_c2ce 'Microsoft.Cdn/profiles/customdomains@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_resource
  name: 'dev-sportdeets-com-c2ce'
  properties: {
    hostName: 'dev.sportdeets.com'
    tlsSettings: {
      certificateType: 'CustomerCertificate'
      minimumTlsVersion: 'TLS12'
      cipherSuiteSetType: 'TLS12_2022'
      secret: {
        id: profiles_fd_sportdeets_name_sportsdataweb_sportdeetssslissued_latest.id
      }
    }
  }
}

resource profiles_fd_sportdeets_name_franchise_dev_sportdeets_com_fdfd 'Microsoft.Cdn/profiles/customdomains@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_resource
  name: 'franchise-dev-sportdeets-com-fdfd'
  properties: {
    hostName: 'franchise-dev.sportdeets.com'
    tlsSettings: {
      certificateType: 'CustomerCertificate'
      minimumTlsVersion: 'TLS12'
      cipherSuiteSetType: 'TLS12_2023'
      secret: {
        id: profiles_fd_sportdeets_name_sportsdataweb_sportdeetssslissued_latest.id
      }
    }
  }
}

resource profiles_fd_sportdeets_name_grafana_sportdeets_com 'Microsoft.Cdn/profiles/customdomains@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_resource
  name: 'grafana-sportdeets-com'
  properties: {
    hostName: 'grafana.sportdeets.com'
    tlsSettings: {
      certificateType: 'CustomerCertificate'
      minimumTlsVersion: 'TLS12'
      cipherSuiteSetType: 'TLS12_2023'
      secret: {
        id: profiles_fd_sportdeets_name_sportsdataweb_sportdeetssslissued_latest.id
      }
    }
  }
}

resource profiles_fd_sportdeets_name_logging_dev_sportdeets_com_a407 'Microsoft.Cdn/profiles/customdomains@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_resource
  name: 'logging-dev-sportdeets-com-a407'
  properties: {
    hostName: 'logging-dev.sportdeets.com'
    tlsSettings: {
      certificateType: 'CustomerCertificate'
      minimumTlsVersion: 'TLS12'
      cipherSuiteSetType: 'TLS12_2023'
      secret: {
        id: profiles_fd_sportdeets_name_sportsdataweb_sportdeetssslissued_latest.id
      }
    }
  }
}

resource profiles_fd_sportdeets_name_logging_sportdeets_com 'Microsoft.Cdn/profiles/customdomains@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_resource
  name: 'logging-sportdeets-com'
  properties: {
    hostName: 'logging.sportdeets.com'
    tlsSettings: {
      certificateType: 'CustomerCertificate'
      minimumTlsVersion: 'TLS12'
      cipherSuiteSetType: 'TLS12_2022'
      secret: {
        id: profiles_fd_sportdeets_name_sportsdataweb_sportdeetssslissued_latest.id
      }
    }
  }
}

resource profiles_fd_sportdeets_name_notification_dev_sportdeets_com_c047 'Microsoft.Cdn/profiles/customdomains@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_resource
  name: 'notification-dev-sportdeets-com-c047'
  properties: {
    hostName: 'notification-dev.sportdeets.com'
    tlsSettings: {
      certificateType: 'CustomerCertificate'
      minimumTlsVersion: 'TLS12'
      cipherSuiteSetType: 'TLS12_2023'
      secret: {
        id: profiles_fd_sportdeets_name_sportsdataweb_sportdeetssslissued_latest.id
      }
    }
  }
}

resource profiles_fd_sportdeets_name_player_dev_sportdeets_com_1091 'Microsoft.Cdn/profiles/customdomains@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_resource
  name: 'player-dev-sportdeets-com-1091'
  properties: {
    hostName: 'player-dev.sportdeets.com'
    tlsSettings: {
      certificateType: 'CustomerCertificate'
      minimumTlsVersion: 'TLS12'
      cipherSuiteSetType: 'TLS12_2023'
      secret: {
        id: profiles_fd_sportdeets_name_sportsdataweb_sportdeetssslissued_latest.id
      }
    }
  }
}

resource profiles_fd_sportdeets_name_producer_football_ncaa_dev_sportdeets_com_8e1c 'Microsoft.Cdn/profiles/customdomains@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_resource
  name: 'producer-football-ncaa-dev-sportdeets-com-8e1c'
  properties: {
    hostName: 'producer-football-ncaa-dev.sportdeets.com'
    tlsSettings: {
      certificateType: 'CustomerCertificate'
      minimumTlsVersion: 'TLS12'
      cipherSuiteSetType: 'TLS12_2023'
      secret: {
        id: profiles_fd_sportdeets_name_sportsdataweb_sportdeetssslissued_latest.id
      }
    }
  }
}

resource profiles_fd_sportdeets_name_provider_football_ncaa_dev_sportdeets_com_84c5 'Microsoft.Cdn/profiles/customdomains@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_resource
  name: 'provider-football-ncaa-dev-sportdeets-com-84c5'
  properties: {
    hostName: 'provider-football-ncaa-dev.sportdeets.com'
    tlsSettings: {
      certificateType: 'CustomerCertificate'
      minimumTlsVersion: 'TLS12'
      cipherSuiteSetType: 'TLS12_2023'
      secret: {
        id: profiles_fd_sportdeets_name_sportsdataweb_sportdeetssslissued_latest.id
      }
    }
  }
}

resource profiles_fd_sportdeets_name_qa_sportdeets_com_9a7f 'Microsoft.Cdn/profiles/customdomains@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_resource
  name: 'qa-sportdeets-com-9a7f'
  properties: {
    hostName: 'qa.sportdeets.com'
    tlsSettings: {
      certificateType: 'CustomerCertificate'
      minimumTlsVersion: 'TLS12'
      cipherSuiteSetType: 'TLS12_2022'
      secret: {
        id: profiles_fd_sportdeets_name_sportsdataweb_sportdeetssslissued_latest.id
      }
    }
  }
}

resource profiles_fd_sportdeets_name_season_dev_sportdeets_com_7e55 'Microsoft.Cdn/profiles/customdomains@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_resource
  name: 'season-dev-sportdeets-com-7e55'
  properties: {
    hostName: 'season-dev.sportdeets.com'
    tlsSettings: {
      certificateType: 'CustomerCertificate'
      minimumTlsVersion: 'TLS12'
      cipherSuiteSetType: 'TLS12_2023'
      secret: {
        id: profiles_fd_sportdeets_name_sportsdataweb_sportdeetssslissued_latest.id
      }
    }
  }
}

resource profiles_fd_sportdeets_name_sportdeets_com_eb4e 'Microsoft.Cdn/profiles/customdomains@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_resource
  name: 'sportdeets-com-eb4e'
  properties: {
    hostName: 'sportdeets.com'
    tlsSettings: {
      certificateType: 'CustomerCertificate'
      minimumTlsVersion: 'TLS12'
      cipherSuiteSetType: 'TLS12_2022'
      secret: {
        id: profiles_fd_sportdeets_name_sportsdataweb_sportdeetssslissued_latest.id
      }
    }
  }
}

resource profiles_fd_sportdeets_name_www_sportdeets_com_a381 'Microsoft.Cdn/profiles/customdomains@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_resource
  name: 'www-sportdeets-com-a381'
  properties: {
    hostName: 'www.sportdeets.com'
    tlsSettings: {
      certificateType: 'CustomerCertificate'
      minimumTlsVersion: 'TLS12'
      cipherSuiteSetType: 'TLS12_2022'
      secret: {
        id: profiles_fd_sportdeets_name_sportsdataweb_sportdeetssslissued_latest.id
      }
    }
  }
}

resource profiles_fd_sportdeets_name_about_origin_group_about_origin 'Microsoft.Cdn/profiles/origingroups/origins@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_about_origin_group
  name: 'about-origin'
  properties: {
    hostName: 'mango-bay-03c81c30f.3.azurestaticapps.net'
    httpPort: 80
    httpsPort: 443
    originHostHeader: 'mango-bay-03c81c30f.3.azurestaticapps.net'
    priority: 1
    weight: 1000
    enabledState: 'Enabled'
    enforceCertificateNameCheck: true
  }
  dependsOn: [
    profiles_fd_sportdeets_name_resource
  ]
}

resource profiles_fd_sportdeets_name_apim_origin_group_apim_origin 'Microsoft.Cdn/profiles/origingroups/origins@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_apim_origin_group
  name: 'apim-origin'
  properties: {
    hostName: 'sportdeets-apim.azure-api.net'
    httpPort: 80
    httpsPort: 443
    originHostHeader: 'sportdeets-apim.azure-api.net'
    priority: 1
    weight: 1000
    enabledState: 'Enabled'
    enforceCertificateNameCheck: true
  }
  dependsOn: [
    profiles_fd_sportdeets_name_resource
  ]
}

resource profiles_fd_sportdeets_name_dev_api_origin_api_public_dev_sporteets 'Microsoft.Cdn/profiles/origingroups/origins@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_dev_api_origin
  name: 'api-public-dev-sporteets'
  properties: {
    hostName: 'api-public-dev-f9ashfbeavh0czbh.eastus2-01.azurewebsites.net'
    httpPort: 80
    httpsPort: 443
    originHostHeader: 'api-public-dev-f9ashfbeavh0czbh.eastus2-01.azurewebsites.net'
    priority: 1
    weight: 1000
    enabledState: 'Enabled'
    enforceCertificateNameCheck: true
  }
  dependsOn: [
    profiles_fd_sportdeets_name_resource
  ]
}

resource profiles_fd_sportdeets_name_dev_contest_origin_contest_dev 'Microsoft.Cdn/profiles/origingroups/origins@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_dev_contest_origin
  name: 'contest-dev'
  properties: {
    hostName: 'sportdeets-contest-dev-ezg4hshpava5gmdr.eastus2-01.azurewebsites.net'
    httpPort: 80
    httpsPort: 443
    originHostHeader: 'sportdeets-contest-dev-ezg4hshpava5gmdr.eastus2-01.azurewebsites.net'
    priority: 1
    weight: 1000
    enabledState: 'Enabled'
    enforceCertificateNameCheck: true
  }
  dependsOn: [
    profiles_fd_sportdeets_name_resource
  ]
}

resource profiles_fd_sportdeets_name_dev_devsportdeets 'Microsoft.Cdn/profiles/origingroups/origins@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_dev
  name: 'devsportdeets'
  properties: {
    hostName: 'lively-coast-0020b840f.6.azurestaticapps.net'
    httpPort: 80
    httpsPort: 443
    originHostHeader: 'lively-coast-0020b840f.6.azurestaticapps.net'
    priority: 1
    weight: 1000
    enabledState: 'Enabled'
    enforceCertificateNameCheck: true
  }
  dependsOn: [
    profiles_fd_sportdeets_name_resource
  ]
}

resource profiles_fd_sportdeets_name_dev_franchise_origin_franchise_dev_sportdeets 'Microsoft.Cdn/profiles/origingroups/origins@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_dev_franchise_origin
  name: 'franchise-dev-sportdeets'
  properties: {
    hostName: 'sportdeets-franchise-dev-fvcxh3drevafd7g4.eastus2-01.azurewebsites.net'
    httpPort: 80
    httpsPort: 443
    originHostHeader: 'sportdeets-franchise-dev-fvcxh3drevafd7g4.eastus2-01.azurewebsites.net'
    priority: 1
    weight: 1000
    enabledState: 'Enabled'
    enforceCertificateNameCheck: true
  }
  dependsOn: [
    profiles_fd_sportdeets_name_resource
  ]
}

resource profiles_fd_sportdeets_name_homelab_cluster_homelab 'Microsoft.Cdn/profiles/origingroups/origins@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_homelab_cluster
  name: 'homelab'
  properties: {
    hostName: '67.7.88.82'
    httpPort: 80
    httpsPort: 443
    priority: 1
    weight: 1000
    enabledState: 'Enabled'
    enforceCertificateNameCheck: false
  }
  dependsOn: [
    profiles_fd_sportdeets_name_resource
  ]
}

resource profiles_fd_sportdeets_name_dev_logging_origin_logging_dev_sportdeets 'Microsoft.Cdn/profiles/origingroups/origins@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_dev_logging_origin
  name: 'logging-dev-sportdeets'
  properties: {
    hostName: 'logging-svc.azurewebsites.net'
    httpPort: 80
    httpsPort: 443
    originHostHeader: 'logging-svc.azurewebsites.net'
    priority: 1
    weight: 1000
    enabledState: 'Enabled'
    enforceCertificateNameCheck: true
  }
  dependsOn: [
    profiles_fd_sportdeets_name_resource
  ]
}

resource profiles_fd_sportdeets_name_dev_notification_origin_notification_dev_sportdeets 'Microsoft.Cdn/profiles/origingroups/origins@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_dev_notification_origin
  name: 'notification-dev-sportdeets'
  properties: {
    hostName: 'sportdeets-notification-dev-ezhkfffqffhhc0hp.eastus2-01.azurewebsites.net'
    httpPort: 80
    httpsPort: 443
    originHostHeader: 'sportdeets-notification-dev-ezhkfffqffhhc0hp.eastus2-01.azurewebsites.net'
    priority: 1
    weight: 1000
    enabledState: 'Enabled'
    enforceCertificateNameCheck: true
  }
  dependsOn: [
    profiles_fd_sportdeets_name_resource
  ]
}

resource profiles_fd_sportdeets_name_defaultorigingroup_origin_web1 'Microsoft.Cdn/profiles/origingroups/origins@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_defaultorigingroup
  name: 'origin-web1'
  properties: {
    hostName: 'sportdeetsweb1-bad4bcf9crgwavcq.eastus2-01.azurewebsites.net'
    httpPort: 80
    httpsPort: 443
    originHostHeader: 'sportdeetsweb1-bad4bcf9crgwavcq.eastus2-01.azurewebsites.net'
    priority: 1
    weight: 1000
    enabledState: 'Enabled'
    enforceCertificateNameCheck: true
  }
  dependsOn: [
    profiles_fd_sportdeets_name_resource
  ]
}

resource profiles_fd_sportdeets_name_dev_player_origin_player_dev_sportdeets 'Microsoft.Cdn/profiles/origingroups/origins@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_dev_player_origin
  name: 'player-dev-sportdeets'
  properties: {
    hostName: 'sportdeets-player-dev-aqfja9atahccctcd.eastus2-01.azurewebsites.net'
    httpPort: 80
    httpsPort: 443
    originHostHeader: 'sportdeets-player-dev-aqfja9atahccctcd.eastus2-01.azurewebsites.net'
    priority: 1
    weight: 1000
    enabledState: 'Enabled'
    enforceCertificateNameCheck: true
  }
  dependsOn: [
    profiles_fd_sportdeets_name_resource
  ]
}

resource profiles_fd_sportdeets_name_dev_producer_football_ncaa_origin_producer_football_ncaa_dev_sportdeets 'Microsoft.Cdn/profiles/origingroups/origins@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_dev_producer_football_ncaa_origin
  name: 'producer-football-ncaa-dev-sportdeets'
  properties: {
    hostName: 'producer-football-ncaa-dev-f9h9f0gseqf6g7b9.eastus2-01.azurewebsites.net'
    httpPort: 80
    httpsPort: 443
    originHostHeader: 'producer-football-ncaa-dev-f9h9f0gseqf6g7b9.eastus2-01.azurewebsites.net'
    priority: 1
    weight: 1000
    enabledState: 'Enabled'
    enforceCertificateNameCheck: true
  }
  dependsOn: [
    profiles_fd_sportdeets_name_resource
  ]
}

resource profiles_fd_sportdeets_name_prod_ui_origin_group_prod_ui_origin 'Microsoft.Cdn/profiles/origingroups/origins@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_prod_ui_origin_group
  name: 'prod-ui-origin'
  properties: {
    hostName: 'calm-grass-079c5ae0f.3.azurestaticapps.net'
    httpPort: 80
    httpsPort: 443
    originHostHeader: 'calm-grass-079c5ae0f.3.azurestaticapps.net'
    priority: 1
    weight: 1000
    enabledState: 'Enabled'
    enforceCertificateNameCheck: true
  }
  dependsOn: [
    profiles_fd_sportdeets_name_resource
  ]
}

resource profiles_fd_sportdeets_name_dev_provider_football_ncaa_origin_provider_football_ncaa_dev_sportdeets 'Microsoft.Cdn/profiles/origingroups/origins@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_dev_provider_football_ncaa_origin
  name: 'provider-football-ncaa-dev-sportdeets'
  properties: {
    hostName: 'provider-football-ncaa-dev-e6bxd3gsgvf5a0ev.eastus2-01.azurewebsites.net'
    httpPort: 80
    httpsPort: 443
    originHostHeader: 'provider-football-ncaa-dev-e6bxd3gsgvf5a0ev.eastus2-01.azurewebsites.net'
    priority: 1
    weight: 1000
    enabledState: 'Enabled'
    enforceCertificateNameCheck: true
  }
  dependsOn: [
    profiles_fd_sportdeets_name_resource
  ]
}

resource profiles_fd_sportdeets_name_dev_season_origin_season_dev_sportdeers 'Microsoft.Cdn/profiles/origingroups/origins@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_dev_season_origin
  name: 'season-dev-sportdeers'
  properties: {
    hostName: 'sportdeets-season-dev-fpffb9ameyduhhbf.eastus2-01.azurewebsites.net'
    httpPort: 80
    httpsPort: 443
    originHostHeader: 'sportdeets-season-dev-fpffb9ameyduhhbf.eastus2-01.azurewebsites.net'
    priority: 1
    weight: 1000
    enabledState: 'Enabled'
    enforceCertificateNameCheck: true
  }
  dependsOn: [
    profiles_fd_sportdeets_name_resource
  ]
}

resource profiles_fd_sportdeets_name_default_about_route 'Microsoft.Cdn/profiles/afdendpoints/routes@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_default
  name: 'about-route'
  properties: {
    customDomains: [
      {
        id: profiles_fd_sportdeets_name_about_sportdeets_com.id
      }
    ]
    originGroup: {
      id: profiles_fd_sportdeets_name_about_origin_group.id
    }
    ruleSets: []
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'HttpsOnly'
    linkToDefaultDomain: 'Disabled'
    httpsRedirect: 'Enabled'
    enabledState: 'Enabled'
  }
  dependsOn: [
    profiles_fd_sportdeets_name_resource
  ]
}

resource profiles_fd_sportdeets_name_default_admin 'Microsoft.Cdn/profiles/afdendpoints/routes@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_default
  name: 'admin'
  properties: {
    customDomains: [
      {
        id: profiles_fd_sportdeets_name_admin_sportdeets_com.id
      }
    ]
    originGroup: {
      id: profiles_fd_sportdeets_name_homelab_cluster.id
    }
    ruleSets: []
    supportedProtocols: [
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'HttpOnly'
    linkToDefaultDomain: 'Disabled'
    httpsRedirect: 'Enabled'
    enabledState: 'Enabled'
  }
  dependsOn: [
    profiles_fd_sportdeets_name_resource
  ]
}

resource profiles_fd_sportdeets_name_default_analytics_route 'Microsoft.Cdn/profiles/afdendpoints/routes@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_default
  name: 'analytics-route'
  properties: {
    customDomains: [
      {
        id: profiles_fd_sportdeets_name_analytics_sportdeets_com.id
      }
    ]
    originGroup: {
      id: profiles_fd_sportdeets_name_homelab_cluster.id
    }
    ruleSets: []
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'HttpOnly'
    linkToDefaultDomain: 'Disabled'
    httpsRedirect: 'Enabled'
    enabledState: 'Enabled'
  }
  dependsOn: [
    profiles_fd_sportdeets_name_resource
  ]
}

resource profiles_fd_sportdeets_name_default_api_internal_route 'Microsoft.Cdn/profiles/afdendpoints/routes@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_default
  name: 'api-internal-route'
  properties: {
    customDomains: [
      {
        id: profiles_fd_sportdeets_name_api_int_sportdeets_com.id
      }
    ]
    originGroup: {
      id: profiles_fd_sportdeets_name_homelab_cluster.id
    }
    ruleSets: []
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'HttpOnly'
    linkToDefaultDomain: 'Disabled'
    httpsRedirect: 'Enabled'
    enabledState: 'Enabled'
  }
  dependsOn: [
    profiles_fd_sportdeets_name_resource
  ]
}

resource profiles_fd_sportdeets_name_default_api_route 'Microsoft.Cdn/profiles/afdendpoints/routes@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_default
  name: 'api-route'
  properties: {
    customDomains: [
      {
        id: profiles_fd_sportdeets_name_api_sportdeets_com.id
      }
    ]
    originGroup: {
      id: profiles_fd_sportdeets_name_apim_origin_group.id
    }
    ruleSets: []
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'HttpsOnly'
    linkToDefaultDomain: 'Disabled'
    httpsRedirect: 'Enabled'
    enabledState: 'Enabled'
  }
  dependsOn: [
    profiles_fd_sportdeets_name_resource
  ]
}

resource profiles_fd_sportdeets_name_default_dev 'Microsoft.Cdn/profiles/afdendpoints/routes@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_default
  name: 'dev'
  properties: {
    customDomains: [
      {
        id: profiles_fd_sportdeets_name_dev_sportdeets_com_c2ce.id
      }
    ]
    originGroup: {
      id: profiles_fd_sportdeets_name_dev.id
    }
    ruleSets: []
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'MatchRequest'
    linkToDefaultDomain: 'Disabled'
    httpsRedirect: 'Enabled'
    enabledState: 'Enabled'
  }
  dependsOn: [
    profiles_fd_sportdeets_name_resource
  ]
}

resource profiles_fd_sportdeets_name_default_dev_api 'Microsoft.Cdn/profiles/afdendpoints/routes@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_default
  name: 'dev-api'
  properties: {
    customDomains: [
      {
        id: profiles_fd_sportdeets_name_api_dev_sportdeets_com_6dee.id
      }
    ]
    originGroup: {
      id: profiles_fd_sportdeets_name_dev_api_origin.id
    }
    ruleSets: []
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'MatchRequest'
    linkToDefaultDomain: 'Disabled'
    httpsRedirect: 'Enabled'
    enabledState: 'Enabled'
  }
  dependsOn: [
    profiles_fd_sportdeets_name_resource
  ]
}

resource profiles_fd_sportdeets_name_default_dev_contest 'Microsoft.Cdn/profiles/afdendpoints/routes@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_default
  name: 'dev-contest'
  properties: {
    customDomains: [
      {
        id: profiles_fd_sportdeets_name_contest_dev_sportdeets_com_895c.id
      }
    ]
    originGroup: {
      id: profiles_fd_sportdeets_name_dev_contest_origin.id
    }
    ruleSets: []
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'HttpsOnly'
    linkToDefaultDomain: 'Disabled'
    httpsRedirect: 'Enabled'
    enabledState: 'Enabled'
  }
  dependsOn: [
    profiles_fd_sportdeets_name_resource
  ]
}

resource profiles_fd_sportdeets_name_default_dev_franchise 'Microsoft.Cdn/profiles/afdendpoints/routes@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_default
  name: 'dev-franchise'
  properties: {
    customDomains: [
      {
        id: profiles_fd_sportdeets_name_franchise_dev_sportdeets_com_fdfd.id
      }
    ]
    originGroup: {
      id: profiles_fd_sportdeets_name_dev_franchise_origin.id
    }
    ruleSets: []
    supportedProtocols: [
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'HttpsOnly'
    linkToDefaultDomain: 'Disabled'
    httpsRedirect: 'Enabled'
    enabledState: 'Enabled'
  }
  dependsOn: [
    profiles_fd_sportdeets_name_resource
  ]
}

resource profiles_fd_sportdeets_name_default_dev_logging 'Microsoft.Cdn/profiles/afdendpoints/routes@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_default
  name: 'dev-logging'
  properties: {
    customDomains: [
      {
        id: profiles_fd_sportdeets_name_logging_dev_sportdeets_com_a407.id
      }
    ]
    originGroup: {
      id: profiles_fd_sportdeets_name_dev_logging_origin.id
    }
    ruleSets: []
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'MatchRequest'
    linkToDefaultDomain: 'Disabled'
    httpsRedirect: 'Enabled'
    enabledState: 'Enabled'
  }
  dependsOn: [
    profiles_fd_sportdeets_name_resource
  ]
}

resource profiles_fd_sportdeets_name_default_dev_notification 'Microsoft.Cdn/profiles/afdendpoints/routes@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_default
  name: 'dev-notification'
  properties: {
    customDomains: [
      {
        id: profiles_fd_sportdeets_name_notification_dev_sportdeets_com_c047.id
      }
    ]
    originGroup: {
      id: profiles_fd_sportdeets_name_dev_notification_origin.id
    }
    ruleSets: []
    supportedProtocols: [
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'HttpsOnly'
    linkToDefaultDomain: 'Disabled'
    httpsRedirect: 'Enabled'
    enabledState: 'Enabled'
  }
  dependsOn: [
    profiles_fd_sportdeets_name_resource
  ]
}

resource profiles_fd_sportdeets_name_default_dev_player 'Microsoft.Cdn/profiles/afdendpoints/routes@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_default
  name: 'dev-player'
  properties: {
    customDomains: [
      {
        id: profiles_fd_sportdeets_name_player_dev_sportdeets_com_1091.id
      }
    ]
    originGroup: {
      id: profiles_fd_sportdeets_name_dev_player_origin.id
    }
    ruleSets: []
    supportedProtocols: [
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'HttpsOnly'
    linkToDefaultDomain: 'Disabled'
    httpsRedirect: 'Enabled'
    enabledState: 'Enabled'
  }
  dependsOn: [
    profiles_fd_sportdeets_name_resource
  ]
}

resource profiles_fd_sportdeets_name_default_dev_producer_football_ncaa 'Microsoft.Cdn/profiles/afdendpoints/routes@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_default
  name: 'dev-producer-football-ncaa'
  properties: {
    customDomains: [
      {
        id: profiles_fd_sportdeets_name_producer_football_ncaa_dev_sportdeets_com_8e1c.id
      }
    ]
    originGroup: {
      id: profiles_fd_sportdeets_name_dev_producer_football_ncaa_origin.id
    }
    ruleSets: []
    supportedProtocols: [
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'HttpsOnly'
    linkToDefaultDomain: 'Disabled'
    httpsRedirect: 'Enabled'
    enabledState: 'Enabled'
  }
  dependsOn: [
    profiles_fd_sportdeets_name_resource
  ]
}

resource profiles_fd_sportdeets_name_default_dev_provider_football_ncaa 'Microsoft.Cdn/profiles/afdendpoints/routes@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_default
  name: 'dev-provider-football-ncaa'
  properties: {
    customDomains: [
      {
        id: profiles_fd_sportdeets_name_provider_football_ncaa_dev_sportdeets_com_84c5.id
      }
    ]
    originGroup: {
      id: profiles_fd_sportdeets_name_dev_provider_football_ncaa_origin.id
    }
    ruleSets: []
    supportedProtocols: [
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'HttpsOnly'
    linkToDefaultDomain: 'Disabled'
    httpsRedirect: 'Enabled'
    enabledState: 'Enabled'
  }
  dependsOn: [
    profiles_fd_sportdeets_name_resource
  ]
}

resource profiles_fd_sportdeets_name_default_dev_season 'Microsoft.Cdn/profiles/afdendpoints/routes@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_default
  name: 'dev-season'
  properties: {
    customDomains: [
      {
        id: profiles_fd_sportdeets_name_season_dev_sportdeets_com_7e55.id
      }
    ]
    originGroup: {
      id: profiles_fd_sportdeets_name_dev_season_origin.id
    }
    ruleSets: []
    supportedProtocols: [
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'HttpsOnly'
    linkToDefaultDomain: 'Disabled'
    httpsRedirect: 'Enabled'
    enabledState: 'Enabled'
  }
  dependsOn: [
    profiles_fd_sportdeets_name_resource
  ]
}

resource profiles_fd_sportdeets_name_default_grafana 'Microsoft.Cdn/profiles/afdendpoints/routes@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_default
  name: 'grafana'
  properties: {
    customDomains: [
      {
        id: profiles_fd_sportdeets_name_grafana_sportdeets_com.id
      }
    ]
    originGroup: {
      id: profiles_fd_sportdeets_name_homelab_cluster.id
    }
    ruleSets: []
    supportedProtocols: [
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'HttpOnly'
    linkToDefaultDomain: 'Disabled'
    httpsRedirect: 'Enabled'
    enabledState: 'Enabled'
  }
  dependsOn: [
    profiles_fd_sportdeets_name_resource
  ]
}

resource profiles_fd_sportdeets_name_default_logging_route 'Microsoft.Cdn/profiles/afdendpoints/routes@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_default
  name: 'logging-route'
  properties: {
    customDomains: [
      {
        id: profiles_fd_sportdeets_name_logging_sportdeets_com.id
      }
    ]
    originGroup: {
      id: profiles_fd_sportdeets_name_homelab_cluster.id
    }
    ruleSets: []
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'HttpOnly'
    linkToDefaultDomain: 'Disabled'
    httpsRedirect: 'Enabled'
    enabledState: 'Enabled'
  }
  dependsOn: [
    profiles_fd_sportdeets_name_resource
  ]
}

resource profiles_fd_sportdeets_name_default_qa 'Microsoft.Cdn/profiles/afdendpoints/routes@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_default
  name: 'qa'
  properties: {
    customDomains: [
      {
        id: profiles_fd_sportdeets_name_qa_sportdeets_com_9a7f.id
      }
    ]
    originGroup: {
      id: profiles_fd_sportdeets_name_defaultorigingroup.id
    }
    ruleSets: []
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'MatchRequest'
    linkToDefaultDomain: 'Disabled'
    httpsRedirect: 'Enabled'
    enabledState: 'Enabled'
  }
  dependsOn: [
    profiles_fd_sportdeets_name_resource
  ]
}

resource profiles_fd_sportdeets_name_default_default 'Microsoft.Cdn/profiles/afdendpoints/routes@2025-04-15' = {
  parent: profiles_fd_sportdeets_name_default
  name: 'default'
  properties: {
    customDomains: [
      {
        id: profiles_fd_sportdeets_name_www_sportdeets_com_a381.id
      }
      {
        id: profiles_fd_sportdeets_name_sportdeets_com_eb4e.id
      }
    ]
    originGroup: {
      id: profiles_fd_sportdeets_name_prod_ui_origin_group.id
    }
    ruleSets: []
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'HttpsOnly'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Enabled'
    enabledState: 'Enabled'
  }
  dependsOn: [
    profiles_fd_sportdeets_name_resource
  ]
}
